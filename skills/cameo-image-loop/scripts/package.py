#!/usr/bin/env python3
"""Package a batch into ONE zip, delivery and source material separated inside.

Usage:
    package.py --root <batch_dir> --name <batch_name> [--dest <dir>]
Batch layout: <batch_dir>/work/{mov,sheets}, <batch_dir>/notes.md,
              <batch_dir>/work/{grids,cells,person}.

Produces <dest>/<name>.zip with:
    <name>/mov/*.mov  <name>/sheets/*.jpg  <name>/notes.md   (delivery)
    <name>/originals/grids/*.png                            (raw Design outputs)
    <name>/originals/cells/*.png                            (slices)
    <name>/originals/person/*.png                           (raw Layer outputs)
"""
import argparse, os, shutil, subprocess, tempfile


def place(src, dst):
    """Hard-link when possible (same volume), else copy."""
    try:
        os.link(src, dst)
    except OSError:
        shutil.copy2(src, dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--dest", default=".")
    args = ap.parse_args()
    root = os.path.normpath(args.root)
    os.makedirs(args.dest, exist_ok=True)

    staging = tempfile.mkdtemp(prefix=f"{args.name}_pkg_", dir=args.dest)
    top = os.path.join(staging, args.name)
    links = [
        ("work/mov", "mov"),
        ("work/sheets", "sheets"),
        ("notes.md", "notes.md"),
        ("work/grids", "originals/grids"),
        ("work/cells", "originals/cells"),
        ("work/person", "originals/person"),
    ]
    for src_rel, dst_rel in links:
        src = os.path.join(root, src_rel)
        if not os.path.exists(src):
            continue
        dst = os.path.join(top, dst_rel)
        os.makedirs(os.path.dirname(dst) if os.path.isfile(src) else dst, exist_ok=True)
        if os.path.isfile(src):
            place(src, dst)
        else:
            for f in os.listdir(src):
                place(os.path.join(src, f), os.path.join(dst, f))

    out = os.path.abspath(os.path.join(args.dest, f"{args.name}.zip"))
    if os.path.exists(out):
        os.remove(out)
    subprocess.run(["zip", "-qr", out, args.name], cwd=staging, check=True)
    shutil.rmtree(staging)
    summary = [l for l in subprocess.run(["unzip", "-l", out], capture_output=True, text=True)
               .stdout.split("\n") if " file" in l]
    n = summary[-1].split()[-2] if summary else "?"
    print(out, os.path.getsize(out) // 1024, "KB,", n, "files")


if __name__ == "__main__":
    main()
