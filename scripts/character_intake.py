#!/usr/bin/env python3
"""Turns website uploads into submission issues (the "intake" workflow).

The upload Worker (upload/) leaves each accepted video in pending/ of the private cameo-uploads
bucket, with the form fields as object metadata. This script checks every pending video with
AVFoundation, moves good ones to submitted/ and opens a "character" issue for review that
points at it (r2:submitted/<id>.mov); videos that fail are deleted. Approving the issue then
publishes it like any other submission (character_submission.py publish).
Environment: GH_TOKEN, GITHUB_REPOSITORY, R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY.
"""
import json
import re
import tempfile
import urllib.parse
from pathlib import Path

from character_submission import UPLOADS, check_video, comment, report_table, run, s3, s3api

LABELS = {"animal": "Animal / 动物", "person": "Person / 人物", "other": "Other / 其他"}
KEY = re.compile(r"^pending/([0-9a-f-]{36})\.mov$")


def issue_body(name, author, category, ref, uploader):
    return (f"### Character name / 角色名\n\n{name}\n\n"
            f"### Credit as / 署名\n\n{author}\n\n"
            f"### Category / 分类\n\n{LABELS[category]}\n\n"
            f"### Video / 视频\n\n{ref}\n\n"
            "### Rights / 权利\n\n- [X] Confirmed by the uploader on the gallery website. 上传者已在网站上确认。\n\n"
            "_Submitted through the gallery website. 通过角色库网站投稿。_\n\n"
            f"<sub>Uploader / 上传者: `{uploader or 'unknown'}` (anonymous; ban with "
            "`wrangler kv key put --namespace-id c7ab0970f2e147e28e69924342cfc672 --remote ban:<id> 1`)</sub>")


def main():
    listing = json.loads(s3api("list-objects-v2", "--bucket", UPLOADS, "--prefix", "pending/") or "{}")
    for item in listing.get("Contents", []):
        key = item["Key"]
        match = KEY.match(key)
        if not match:
            continue
        upload = match.group(1)
        meta = json.loads(s3api("head-object", "--bucket", UPLOADS, "--key", key)).get("Metadata", {})
        name = urllib.parse.unquote(meta.get("name", "")).strip()[:60]
        author = urllib.parse.unquote(meta.get("author", "")).strip()[:60]
        category = meta.get("category", "")
        uploader = re.sub(r"[^0-9a-f]", "", meta.get("uploader", ""))[:64]
        path = Path(tempfile.mkdtemp()) / "upload.mov"
        s3("cp", f"s3://{UPLOADS}/{key}", str(path))
        facts = check_video(path)
        if not name or not author or category not in LABELS or not facts.get("ok"):
            print(f"Rejecting {key}: {facts.get('problems') or 'missing fields'}")
            s3("rm", f"s3://{UPLOADS}/{key}")
            continue
        submitted = f"submitted/{upload}.mov"
        s3("mv", f"s3://{UPLOADS}/{key}", f"s3://{UPLOADS}/{submitted}")
        url = run("gh", "issue", "create", "--title", f"[Character] {name}", "--label", "character",
                  "--body", issue_body(name, author, category, f"r2:{submitted}", uploader), capture=True).stdout.strip()
        issue = url.rstrip("/").rsplit("/", 1)[-1]
        comment(issue, "### ✅ Looks good / 检查通过\n\n"
                       f"**{name}** by {author} · {category}\n\n" + report_table(facts) +
                       "\nAdd the `approved` label to publish it. 添加 `approved` 标签即可发布。")
        print(f"Opened {url} for {key}")


if __name__ == "__main__":
    main()
