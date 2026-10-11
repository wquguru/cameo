#!/usr/bin/env python3
"""Character packages (docs/package-spec.md) submitted as a .zip.

  unpack <package.zip> <folder>          checks the archive, extracts it and prints the package folder
  pack <package-folder> <out.zip> <id>   writes a clean zip of just the manifest, its clips and poster
  preview <package-folder>               prints the clip the gallery shows (the idle clip)

The archive is untrusted: entries are checked before anything is written (no absolute or ".."
paths, no links, a few dozen files, bounded unpacked size), only the package's own files are
extracted, and the manifest may only point at .mov files inside the package. A package is
accepted with manifest.json at the root of the zip or inside one top-level folder (what Finder's
Compress makes); Finder's __MACOSX and .DS_Store entries are ignored.
"""
import json
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath

MAX_FILES = 64
MAX_UNPACKED = 200 * 1024 * 1024  # ProRes barely compresses, so this only stops zip bombs


class PackageError(Exception):
    pass


def is_zip(path):
    with open(path, "rb") as f:
        return f.read(4) == b"PK\x03\x04"


def _members(archive):
    members = []
    for info in archive.infolist():
        name = info.filename
        path = PurePosixPath(name)
        if name.startswith("__MACOSX/") or path.name == ".DS_Store" or path.name.startswith("._"):
            continue  # Finder's extras
        if "\\" in name or path.is_absolute() or ".." in path.parts or not path.parts:
            raise PackageError(f"Unsafe path in the zip: {name}. 压缩包里有不安全的路径：{name}。")
        if stat.S_ISLNK(info.external_attr >> 16):
            raise PackageError(f"The zip contains a link: {name}. 压缩包里有链接文件：{name}。")
        members.append(info)
    files = [m for m in members if not m.is_dir()]
    if len(files) > MAX_FILES:
        raise PackageError(f"The zip has {len(files)} files; at most {MAX_FILES}. 压缩包有 {len(files)} 个文件，最多 {MAX_FILES} 个。")
    if sum(m.file_size for m in files) > MAX_UNPACKED:
        raise PackageError("The zip unpacks to more than 200 MB. 压缩包解压后超过 200 MB。")
    return files


def _root(files):
    """The folder inside the zip that holds manifest.json: "" or one top-level folder."""
    manifests = [PurePosixPath(m.filename) for m in files if PurePosixPath(m.filename).name == "manifest.json"]
    for depth in (1, 2):
        found = [p for p in manifests if len(p.parts) == depth]
        if len(found) == 1:
            return "" if depth == 1 else found[0].parts[0] + "/"
        if len(found) > 1:
            break
    raise PackageError("No manifest.json in the zip (zip the package folder made by cameo-video-package). "
                       "压缩包里没有 manifest.json（请压缩 cameo-video-package 生成的角色包文件夹）。")


def _clip_paths(manifest):
    clips = manifest.get("clips") if isinstance(manifest, dict) else None
    if not isinstance(clips, list) or not clips:
        raise PackageError("manifest.json lists no clips. manifest.json 里没有片段。")
    paths = []
    for clip in clips:
        file = clip.get("file") if isinstance(clip, dict) else None
        path = PurePosixPath(file) if isinstance(file, str) else None
        if not path or path.is_absolute() or ".." in path.parts or "\\" in file or path.suffix.lower() != ".mov":
            raise PackageError(f"Bad clip file in manifest.json: {file!r}. manifest.json 里的片段文件不合法：{file!r}。")
        paths.append(str(path))
    return paths


def unpack(zip_path, folder):
    """Extracts the package's own files into folder and returns the package folder."""
    try:
        archive = zipfile.ZipFile(zip_path)
    except zipfile.BadZipFile:
        raise PackageError("Not a readable zip. 不是可读取的 zip 压缩包。")
    with archive:
        files = _members(archive)
        root = _root(files)
        by_name = {m.filename: m for m in files}
        try:
            manifest = json.loads(archive.read(by_name[root + "manifest.json"]))
        except (ValueError, UnicodeDecodeError):
            raise PackageError("manifest.json is not valid JSON. manifest.json 不是合法的 JSON。")
        wanted = ["manifest.json", *_clip_paths(manifest)]
        if root + "poster.png" in by_name:
            wanted.append("poster.png")
        package = Path(folder) / "package"
        written = 0  # sizes in the zip may lie, so count what really comes out
        for name in dict.fromkeys(wanted):
            member = by_name.get(root + name)
            if not member:
                raise PackageError(f"The zip is missing {name}. 压缩包里缺少 {name}。")
            target = package / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(member) as source, open(target, "wb") as out:
                while chunk := source.read(1 << 20):
                    written += len(chunk)
                    if written > MAX_UNPACKED:
                        raise PackageError("The zip unpacks to more than 200 MB. 压缩包解压后超过 200 MB。")
                    out.write(chunk)
    return package


def preview(package):
    """The clip that stands for the package in the gallery: its idle clip, else its first."""
    clips = json.loads((Path(package) / "manifest.json").read_text())["clips"]
    clip = next((c for c in clips if isinstance(c, dict) and c.get("kind") == "idle"), clips[0])
    return Path(package) / clip["file"]


def pack(package, zip_path, name):
    """Zips a checked package folder as <name>/manifest.json, <name>/clips/…, stored (ProRes and
    HEVC don't compress), so unzipping it gives one folder Cameo can open."""
    package = Path(package)
    manifest = json.loads((package / "manifest.json").read_text())
    files = ["manifest.json", *_clip_paths(manifest)]
    if (package / "poster.png").exists():
        files.append("poster.png")
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_STORED) as archive:
        for file in dict.fromkeys(files):
            archive.write(package / file, f"{name}/{file}")


def main():
    try:
        if len(sys.argv) == 4 and sys.argv[1] == "unpack":
            print(unpack(sys.argv[2], sys.argv[3]))
        elif len(sys.argv) == 5 and sys.argv[1] == "pack":
            pack(sys.argv[2], sys.argv[3], sys.argv[4])
        elif len(sys.argv) == 3 and sys.argv[1] == "preview":
            print(preview(sys.argv[2]))
        else:
            sys.exit(__doc__)
    except PackageError as error:
        sys.exit(str(error))


if __name__ == "__main__":
    main()
