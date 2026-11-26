#!/usr/bin/env bash
# Installs WattWise on a connected iPhone with xtool (signs it with your Apple ID).
# Run inside WSL (usually via sideload.ps1) or on Linux/macOS.
#
#   install.sh                 download the latest release .ipa and install it
#   install.sh path/to/app.ipa install a specific .ipa
#
# Free Apple ID: the app stops opening after 7 days. Run this again to renew.
set -euo pipefail

REPO="JawadYzbk/MonitorMyInverterMobile"
IPA="${1:-}"
export PATH="$HOME/.local/bin:$PATH"

command -v xtool >/dev/null || { echo "xtool isn't installed: run setup-wsl.sh first."; exit 1; }

# In WSL, talk to the iPhone through iTunes' Apple Mobile Device Service on
# Windows (port 27015, forwarded by sideload.ps1) instead of USB passthrough.
if grep -qi microsoft /proc/version 2>/dev/null && [ -z "${USBMUXD_SOCKET_ADDRESS:-}" ]; then
  host="$(ip route list default | awk '{print $3}')"
  export USBMUXD_SOCKET_ADDRESS="$host:27015"
  echo "Using the iPhone connection from Windows ($USBMUXD_SOCKET_ADDRESS)"
fi

if ! xtool auth status 2>/dev/null | grep -q "Logged in"; then
  echo "Not signed in to Apple yet."
  xtool auth login --mode password
fi

echo "==> Looking for your iPhone"
if command -v ideviceinfo >/dev/null && ! name="$(ideviceinfo -k DeviceName 2>/dev/null)"; then
  echo "No iPhone found. Check that:"
  echo "  - it's plugged in by USB and unlocked, and you tapped Trust on it"
  echo "  - iTunes is installed on Windows and shows the phone"
  echo "  - sideload.ps1 ran as administrator (it forwards the connection into WSL)"
  exit 1
fi
[ -n "${name:-}" ] && echo "Found: $name"

if [ -z "$IPA" ]; then
  echo "==> Finding the latest WattWise release"
  url="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | python3 -c '
import json, sys
assets = json.load(sys.stdin).get("assets", [])
ipa = [a["browser_download_url"] for a in assets if a["name"].endswith(".ipa")]
print(ipa[0] if ipa else "")')"
  if [ -z "$url" ]; then
    echo "The latest release has no .ipa yet (the iPhone build may still be running)."
    exit 1
  fi
  IPA="${TMPDIR:-/tmp}/$(basename "$url")"
  echo "Downloading $(basename "$url")"
  curl -fL --retry 5 -C - -o "$IPA" "$url"
fi

echo "==> Signing with your Apple ID and installing"
xtool install "$IPA"

cat <<'EOF'

Installed. First time on this iPhone:
  1. Settings > General > VPN & Device Management > your Apple ID > Trust
  2. iOS 16+: Settings > Privacy & Security > Developer Mode > On (the phone restarts)
Then open WattWise. With a free Apple ID, run this again within 7 days to renew it.
EOF
