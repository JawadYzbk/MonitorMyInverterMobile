#!/usr/bin/env bash
# One-time setup for sideloading WattWise onto an iPhone with xtool.
# Run inside WSL (Ubuntu) or on Linux. Usually started by sideload.ps1.
#
# Installs xtool and signs in to your Apple ID. Only `xtool auth` is needed to
# install a ready-made .ipa; the Xcode.xip / iOS SDK step of `xtool setup` is
# only for building apps, so it's skipped here.
set -euo pipefail

BIN="$HOME/.local/bin"

echo "==> Installing helper packages (asks for your Ubuntu password)"
sudo apt-get update -qq
sudo apt-get install -y -qq curl python3 libimobiledevice-utils >/dev/null
# AppImages need FUSE 2 (package name differs by Ubuntu version).
sudo apt-get install -y -qq libfuse2t64 >/dev/null 2>&1 || sudo apt-get install -y -qq libfuse2 >/dev/null 2>&1 || true

echo "==> Downloading xtool"
mkdir -p "$BIN"
curl -fL --retry 5 "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o "$BIN/xtool.AppImage"
chmod +x "$BIN/xtool.AppImage"
# Wrapper: falls back to extract-and-run if FUSE isn't available in WSL.
cat > "$BIN/xtool" <<'EOF'
#!/usr/bin/env bash
if "$HOME/.local/bin/xtool.AppImage" --help >/dev/null 2>&1; then
  exec "$HOME/.local/bin/xtool.AppImage" "$@"
fi
APPIMAGE_EXTRACT_AND_RUN=1 exec "$HOME/.local/bin/xtool.AppImage" "$@"
EOF
chmod +x "$BIN/xtool"
case ":$PATH:" in *":$BIN:"*) ;; *) echo "export PATH=\"$BIN:\$PATH\"" >> "$HOME/.bashrc"; export PATH="$BIN:$PATH" ;; esac

if ! xtool --help >/dev/null 2>&1; then
  echo
  echo "xtool doesn't start. If the error mentions Swift libraries, install the Swift"
  echo "toolchain from https://www.swift.org/install/linux and run this script again."
  exit 1
fi
echo "xtool is installed."

if xtool auth status 2>/dev/null | grep -q "Logged in"; then
  echo "Already signed in to Apple."
  exit 0
fi

echo
echo "==> Sign in with your Apple ID"
echo "A free Apple ID works. xtool signs in through Apple's private sign-in API, so"
echo "xtool's authors suggest using a spare Apple ID. You'll be asked for the"
echo "password and then the 2-factor code Apple sends to your devices."
echo
xtool auth login --mode password
