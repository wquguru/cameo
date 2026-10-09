#!/usr/bin/env python3
"""Handles a character submission issue (the "character" workflow).

  check    reads the form, downloads the attached .mov, checks it and replies on the issue.
  publish  (after a maintainer adds the "approved" label) does the same checks, uploads the
           video to R2, adds the gallery entry and poster, and opens a pull request.

The issue body is untrusted: it is only ever parsed here, never passed to a shell.
Environment: GH_TOKEN, GITHUB_REPOSITORY, ISSUE_NUMBER, ISSUE_BODY; publish also needs
R2_ACCOUNT_ID, R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY (a token scoped to the bucket).
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUCKET = "cameo-characters"
ORIGIN = "https://cameo.wqu.guru"
MARKER = "<!-- cameo-bot -->"
ATTACHMENT = re.compile(r"https://github\.com/user-attachments/(?:assets|files)/[A-Za-z0-9._/-]+")
CATEGORIES = {"animal": "animal", "person": "person", "other": "other"}
DOWNLOAD_LIMIT = 20 * 1024 * 1024  # generous; the check reports anything over 10 MB


def run(*args, capture=False, env=None, check=True):
    return subprocess.run(args, cwd=ROOT, check=check, text=True, env=env,
                          stdout=subprocess.PIPE if capture else None)


def parse_form(body):
    """Issue forms render as '### <label>' sections."""
    fields = {}
    for section in re.split(r"^### ", body or "", flags=re.M)[1:]:
        label, _, value = section.partition("\n")
        value = value.strip()
        fields[label.split("/")[0].strip().lower()] = "" if value == "_No response_" else value
    name = fields.get("character name", "").splitlines()[0].strip() if fields.get("character name") else ""
    author = fields.get("credit as", "").splitlines()[0].strip() if fields.get("credit as") else ""
    category = CATEGORIES.get(fields.get("category", "").split("/")[0].strip().lower(), "")
    video = ATTACHMENT.search(fields.get("video", ""))
    problems = []
    if not name:
        problems.append("Missing a character name. 缺少角色名。")
    if not author:
        problems.append("Missing a credit. 缺少署名。")
    if not category:
        problems.append("Missing a category. 缺少分类。")
    if not video:
        problems.append("No video attached: drag the .mov into the Video field. 没有附上视频：请把 .mov 拖进「视频」一栏。")
    return {"name": name[:60], "author": author[:60], "category": category,
            "video": video.group(0) if video else ""}, problems


def download(url, folder):
    path = Path(folder) / "submission.mov"
    result = run("curl", "-fsSL", "--retry", "3", "--max-filesize", str(DOWNLOAD_LIMIT), "-o", str(path), url, check=False)
    return path if result.returncode == 0 and path.exists() else None


def check_video(path):
    result = run("swift", "scripts/character-check.swift", str(path), capture=True, check=False)
    try:
        return json.loads(result.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return {"ok": False, "problems": ["The video could not be read. 无法读取这个视频。"]}


def comment(issue, text):
    """Creates the bot's comment, or replaces it so the issue keeps one up-to-date report."""
    repo = os.environ["GITHUB_REPOSITORY"]
    body = f"{MARKER}\n{text}"
    ids = run("gh", "api", f"repos/{repo}/issues/{issue}/comments", "--paginate",
              "-q", f'.[] | select(.body | startswith("{MARKER}")) | .id', capture=True).stdout.split()
    if ids:
        run("gh", "api", "-X", "PATCH", f"repos/{repo}/issues/comments/{ids[-1]}", "-f", f"body={body}", capture=True)
    else:
        run("gh", "issue", "comment", issue, "--body", body, capture=True)


def label(issue, name, present):
    flag = "--add-label" if present else "--remove-label"
    run("gh", "issue", "edit", issue, flag, name, capture=True, check=False)


def report_table(facts):
    return ("| | |\n|---|---|\n"
            f"| Format / 格式 | {facts.get('codec', '?')}, {'transparent / 透明' if facts.get('alpha') else 'opaque / 不透明'} |\n"
            f"| Size / 尺寸 | {facts.get('width', '?')} × {facts.get('height', '?')} px |\n"
            f"| Length / 时长 | {facts.get('duration', '?')} s |\n"
            f"| File / 文件 | {round(facts.get('bytes', 0) / 1024)} KB |\n")


def review(issue):
    """Shared by check and publish. Returns (form, video path, facts) or None after replying."""
    form, problems = parse_form(os.environ.get("ISSUE_BODY", ""))
    facts = {}
    path = None
    if not problems:
        path = download(form["video"], tempfile.mkdtemp())
        if not path:
            problems.append("The video could not be downloaded (or is over 20 MB). 视频无法下载（或超过 20 MB）。")
        else:
            facts = check_video(path)
            problems += facts.get("problems", [])
    if problems:
        text = "### ❌ Needs changes / 需要修改\n\n" + "\n".join(f"- {p}" for p in problems)
        if facts:
            text += "\n\n" + report_table(facts)
        text += "\n\nEdit this issue to fix it and the check runs again. 编辑本 Issue 修改后会自动重新检查。"
        comment(issue, text)
        label(issue, "needs-changes", True)
        return None
    label(issue, "needs-changes", False)
    return form, path, facts


def slug(name, issue, taken):
    ascii_name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    base = re.sub(r"[^a-z0-9]+", "-", ascii_name.lower()).strip("-")[:40] or f"character-{issue}"
    return base if base not in taken else f"{base}-{issue}"


def publish(issue, form, path):
    for key in ("R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY"):
        if not os.environ.get(key):
            comment(issue, f"### ⚠️ Can't publish / 无法发布\n\n`{key}` is not configured for this repository.")
            sys.exit(1)
    entries = json.loads((ROOT / "gallery/characters.json").read_text())
    character = slug(form["name"], issue, {e["id"] for e in entries})
    url = f"{ORIGIN}/characters/{character}.mov"

    run("swift", "scripts/gallery-entry.swift", str(path), character, form["name"], form["author"], url, form["category"])

    env = dict(os.environ, AWS_ACCESS_KEY_ID=os.environ["R2_ACCESS_KEY_ID"],
               AWS_SECRET_ACCESS_KEY=os.environ["R2_SECRET_ACCESS_KEY"], AWS_DEFAULT_REGION="auto")
    run("aws", "s3", "cp", str(path), f"s3://{BUCKET}/characters/{character}.mov",
        "--endpoint-url", f"https://{os.environ['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com",
        "--content-type", "video/quicktime", "--cache-control", "public, max-age=86400", "--only-show-errors", env=env)
    published = Path(tempfile.mkdtemp()) / "check.mov"
    run("curl", "-fsSL", "--retry", "5", "--retry-all-errors", "--retry-delay", "3", "-o", str(published), url)
    if hashlib.sha256(published.read_bytes()).digest() != hashlib.sha256(path.read_bytes()).digest():
        sys.exit(f"{url} does not match the submitted file")

    branch = f"character/{character}"
    run("git", "config", "user.name", "github-actions[bot]")
    run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    run("git", "checkout", "-B", branch)
    run("git", "add", "gallery")
    run("git", "commit", "-m", f"Add character {form['name']} (#{issue})")
    run("git", "push", "-f", "origin", branch)
    pr = run("gh", "pr", "create", "--base", "main", "--head", branch,
             "--title", f"Add character: {form['name']}",
             "--body", f"Closes #{issue}\n\nVideo: {url}\n\nMerging deploys the gallery.", capture=True).stdout.strip()
    comment(issue, f"### 🚀 Published to the gallery's storage / 已上传\n\n{url}\n\n"
                   f"It goes live when {pr} is merged. 合并 {pr} 后上线。")


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    issue = os.environ["ISSUE_NUMBER"]
    reviewed = review(issue)
    if mode == "check":
        if reviewed:
            form, _, facts = reviewed
            comment(issue, "### ✅ Looks good / 检查通过\n\n"
                           f"**{form['name']}** by {form['author']} · {form['category']}\n\n" + report_table(facts) +
                           "\nA maintainer will review it soon. 维护者会尽快审核。")
    elif mode == "publish":
        if not reviewed:
            sys.exit(1)
        form, path, _ = reviewed
        publish(issue, form, path)
    else:
        sys.exit("usage: character_submission.py check|publish")


if __name__ == "__main__":
    main()
