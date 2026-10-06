#!/usr/bin/env python3
"""Reject pull request descriptions that lack current, embedded visual evidence.

A human still has to confirm that the images and video show the change. This
script only checks structure: real remote embeds, no local paths or placeholder
copy, and an Evidence-SHA line for the commit under review.
"""
import argparse
from pathlib import Path
import json
import re
import sys


HEADING = re.compile(r"^## +(.+?)\s*$", re.MULTILINE)
IMAGE = re.compile(r"!\[[^\]]*\]\((https://[^)\s]+)\)|<img\b[^>]*\bsrc=[\"'](https://[^\"']+)[\"']", re.IGNORECASE)
VIDEO = re.compile(r"<video\b|https://\S+\.(?:mp4|webm|mov)(?:\?\S*)?|https://github\.com/user-attachments/\S+", re.IGNORECASE)
LOCAL = re.compile(r"/opt/cursor|file://|\.\./|src=[\"'][^\"']*(?:/workspace|/tmp/)", re.IGNORECASE)
PLACEHOLDER = re.compile(r"\b(?:placeholder|todo|lorem ipsum|screenshot of whatever)\b", re.IGNORECASE)
SHA = re.compile(r"Evidence-SHA:\s*([0-9a-f]{40})\b")
RUN_URL = re.compile(r"https://github\.com/[^\s)]+/actions/runs/\d+")
CHECKSUM = re.compile(r"\b[0-9a-f]{64}\b")


def section(body, title):
    matches = list(HEADING.finditer(body))
    for index, match in enumerate(matches):
        if match.group(1).strip().lower() != title.lower():
            continue
        end = matches[index + 1].start() if index + 1 < len(matches) else len(body)
        return body[match.end():end]
    return ""


def problems(body, head_sha, require_preview=False):
    errors = []
    if not isinstance(body, str) or not body.strip():
        return ["Pull request description is empty."]
    screenshots = section(body, "Screenshots")
    video = section(body, "Video")
    if not screenshots.strip():
        errors.append("Missing a Screenshots section.")
    elif not IMAGE.search(screenshots):
        errors.append("Screenshots section needs an embedded https image, not only text.")
    if not video.strip():
        errors.append("Missing a Video section.")
    elif not VIDEO.search(video):
        errors.append("Video section needs a playable https video embed or link, not only text.")
    for name, text in (("Screenshots", screenshots), ("Video", video)):
        if LOCAL.search(text):
            errors.append(f"{name} section contains a local-only path.")
        if PLACEHOLDER.search(text):
            errors.append(f"{name} section still contains placeholder wording.")
    found = SHA.search(body)
    if not found:
        errors.append("Description must contain 'Evidence-SHA: <40-character commit>'.")
    elif head_sha and found.group(1) != head_sha:
        errors.append(f"Evidence-SHA {found.group(1)} does not match the reviewed commit {head_sha}.")
    if require_preview:
        if "msgblast Dev" not in body or "msgblast Demo" not in body:
            errors.append("Cursor branch previews must name both msgblast Dev and msgblast Demo.")
        if "fixture" not in body.lower():
            errors.append("The demo download must be labeled as a fixture.")
        if not RUN_URL.search(body):
            errors.append("Description needs the Actions run URL for the preview artifacts.")
        if not CHECKSUM.search(body):
            errors.append("Description needs the preview ZIP SHA-256 checksums.")
        if re.search(r"updates\.msgblast\.app/(?:latest\.zip|downloads/)", body):
            errors.append("Preview downloads must stay on Actions artifacts, not the production update host.")
    return errors


def body_from_event(path):
    event = json.loads(Path(path).read_text())
    pull_request = event.get("pull_request") or {}
    return pull_request.get("body") or ""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--body-file")
    parser.add_argument("--event-file")
    parser.add_argument("--head", required=True)
    parser.add_argument("--require-preview", action="store_true")
    args = parser.parse_args()
    if args.event_file:
        body = body_from_event(args.event_file)
    elif args.body_file:
        body = Path(args.body_file).read_text()
    else:
        parser.error("Provide --body-file or --event-file")
    errors = problems(body, args.head, require_preview=args.require_preview)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print("Pull request evidence structure matches", args.head)
    print("A human still has to confirm the images and video show this change.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
