"""Prints the release version, or the release notes for it, from pubspec.yaml + CHANGELOG.md.

  python tool/release_notes.py version   -> 1.1.0
  python tool/release_notes.py notes     -> markdown body for the GitHub Release
"""
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

INSTALL = """
---

### Install on Android

Download **piq6-monitor-v{v}.apk** below and open it on your phone (allow installing from this source if asked).

Already have an older version? Uninstall it first: each build is signed with a new debug key, so Android won't install it over the old one. Uninstalling removes saved settings, so you'll need to sign in again.

### Install on iPhone

Download **piq6-monitor-v{v}.ipa** below (it appears a few minutes after the APK, once the iPhone build finishes) and sideload it with a free Apple ID using [xtool](https://github.com/xtool-org/xtool), Sideloadly or AltStore. With a free Apple ID the app stops opening after 7 days; install it again to renew. Step-by-step: [README → Install on iPhone]({repo}#install-on-iphone).
"""

REPO_URL = os.environ.get("REPO_URL", "https://github.com/" + os.environ.get("GITHUB_REPOSITORY", ""))


def version():
    with open(os.path.join(ROOT, "pubspec.yaml"), encoding="utf-8") as f:
        m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", f.read(), re.M)
    if not m:
        sys.exit("No version in pubspec.yaml")
    return m.group(1)


def notes(v):
    with open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8") as f:
        text = f.read()
    m = re.search(rf"^## \[{re.escape(v)}\][^\n]*\n(.*?)(?=^## \[|\Z)", text, re.M | re.S)
    if not m:
        sys.exit(f"CHANGELOG.md has no section for {v} - add '## [{v}] - <date>' before releasing.")
    return m.group(1).strip() + "\n" + INSTALL.format(v=v, repo=REPO_URL)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    v = version()
    print(v if sys.argv[1:] == ["version"] else notes(v))
