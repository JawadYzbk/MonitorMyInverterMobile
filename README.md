# WattWise — Android & iPhone app

Native Flutter app for the MonitorMyInverter gateway. It shows the same things as the
web dashboard (`MonitorMyInverter-frontend`) and alerts like the Windows tray app
(`ShinePlatform/tray_app.py`).

## What it does

- **Overview**: battery, grid, solar and home-load tiles; low-battery banner; grid
  forecast (next change, next 24 h strip, usual daily schedule, weekly stats); power
  chart (1 / 2 / 4 h); grid hours for the last 24 h and a 7-day heatmap.
- **History**: every stored reading, with date/load/battery-voltage/model filters,
  sorting and paging.
- **Settings**: low-battery alert level, alarm / voice / grid-sound switches,
  background monitoring, inverter picker, recent readings, server address, sign out.
- **Background monitoring**: a foreground service polls every 15 s while the app is
  closed. Its notification shows battery, grid, load and solar, like the tray icon.
  It plays a chime when grid power comes back, falling tones when it goes off, and a
  siren plus a spoken warning when the battery is low (every 2 min while low).

The app has no built-in server: enter the address of your own MonitorMyInverter
gateway on the sign-in screen (change it later in Settings). It is saved on the
phone only. The password is kept in the phone's encrypted storage and is only used
to sign in again when the server forgets the session.

## Download

Get the latest APK from the repo's **Releases** page. Each release lists what changed
(from [CHANGELOG.md](CHANGELOG.md)).

## Install on iPhone

Each release has an unsigned `wattwise-vX.Y.Z.ipa`. iPhones only run signed apps, so
[xtool](https://github.com/xtool-org/xtool) signs it with your Apple ID while it
installs it. A **free Apple ID** works; the app then stops opening after **7 days**,
and you renew it by running the install again.

On iPhone the app alerts only while it's open (iOS stops background checking), and
there are no home screen widgets.

### Windows: one command (xtool in WSL)

You need, once:

- **WSL with Ubuntu**: in PowerShell run `wsl --install -d Ubuntu`, restart, open
  Ubuntu once and create your Linux user.
- **iTunes** (Microsoft Store or apple.com): open it, plug in the iPhone by USB, unlock
  it and tap **Trust**. WattWise's script reaches the phone through iTunes' Apple Mobile
  Device Service, so no USB passthrough into WSL is needed.

Then, with the iPhone plugged in and unlocked, open **PowerShell as administrator** in
this folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File tool\sideload\sideload.ps1
```

The first time, it installs xtool in Ubuntu (asks for your Ubuntu password) and signs
in to Apple: enter your Apple ID, password and the 2-factor code. xtool's authors
suggest a spare Apple ID, since this sign-in uses Apple's private API. After that,
the same command downloads the latest WattWise from Releases and installs it. To
install a file you already have, add `-Ipa C:\Downloads\wattwise-vX.Y.Z.ipa`.

First install on the phone only:

1. Settings → General → **VPN & Device Management** → your Apple ID → **Trust**.
2. iOS 16+: Settings → Privacy & Security → **Developer Mode** → on (the phone restarts).

Every 7 days (free Apple ID): plug in and run the same command again.

What the script does: [`tool/sideload/sideload.ps1`](tool/sideload/sideload.ps1)
forwards port 27015 (Apple Mobile Device Service) into WSL on the WSL network adapter
only, then runs [`setup-wsl.sh`](tool/sideload/setup-wsl.sh) (first time) and
[`install.sh`](tool/sideload/install.sh) in Ubuntu.

### Linux or macOS

```bash
bash tool/sideload/setup-wsl.sh   # once: installs xtool, signs in to Apple
bash tool/sideload/install.sh     # each time: latest release, signed + installed
```

On Linux, `usbmuxd` must be running for the USB connection
(`sudo apt-get install usbmuxd`).

### Notes

- Installing only needs `xtool auth`. The Xcode.xip download that `xtool setup` asks
  for is for building apps, so these scripts skip it.
- Doing it by hand: `xtool auth login --mode password`, then
  `xtool install wattwise-vX.Y.Z.ipa` (add `--udid <id>` if several devices are connected;
  `xtool devices` lists them).
- "No iPhone found": unlock the phone, check iTunes shows it, and run the PowerShell
  window as administrator. If your WSL uses mirrored networking, run `install.sh` in
  Ubuntu with `USBMUXD_SOCKET_ADDRESS=127.0.0.1:27015`.
- Free Apple IDs can have only a few sideloaded apps at once (Apple's limit).

### Alternative: Sideloadly

[Sideloadly](https://sideloadly.io) is a Windows app that does the same with a free
Apple ID, without WSL: open the .ipa, enter your Apple ID, click Start. It needs iTunes
and iCloud from apple.com.

## Releasing a new version

1. Bump `version:` in `pubspec.yaml` (e.g. `1.1.0+2` → `1.2.0+3`).
2. Add a `## [1.2.0] - <date>` section to `CHANGELOG.md` describing the changes.
3. Push to `main`. CI builds, tests and publishes release `v1.2.0` with the APK.

## Home screen widgets

Six widgets (Battery, Grid power, Power now, Overview, Grid forecast, Trends). Their
native code lives in `android_overlay/` (Kotlin + layouts) and is copied into the
generated `android/` project by `tool/ci_prepare.py`. Data comes from
`lib/services/widget_sync.dart`.

## Build on GitHub Actions (no local SDK needed)

Every push to `main` runs `.github/workflows/build-apk.yml`. It generates the
Android project (`flutter create` + `tool/ci_prepare.py`), runs `flutter analyze`
and the unit tests, builds a release APK, and uploads it as the
**wattwise-apk** artifact. Download it from the run's page:
Actions → Build APK → latest run → Artifacts. It can also be started by hand
(Run workflow).

```powershell
gh run download --name wattwise-apk
```

## Build locally

Run `flutter create --project-name wattwise --org app.wattwise --platforms android .`
and `python tool\ci_prepare.py` once first; the `android/` folder is not committed.

```powershell
D:\Development\src\flutter\bin\flutter.bat pub get
python tool\make_sounds.py        # only needed if res/raw/*.wav are missing
D:\Development\src\flutter\bin\flutter.bat build apk --release
```

The APK is written to `build\app\outputs\flutter-apk\app-release.apk`. It is signed
with the debug key, which is fine for installing on your own phone.

Install on a phone connected by USB (USB debugging on):

```powershell
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

## Tests

```powershell
D:\Development\src\flutter\bin\flutter.bat test
```
