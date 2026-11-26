# Pi Q6 Monitor — Android app

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

Each release has an unsigned `piq6-monitor-vX.Y.Z.ipa`. iPhones only run signed apps,
so a sideloading tool signs it with your (free) Apple ID while installing. With a
free Apple ID the app expires after **7 days**; install it again to renew.

On iPhone the app alerts only while it's open (iOS stops background checking), and
there are no home screen widgets.

### With xtool (Windows via WSL, Linux or macOS)

Based on xtool's docs (<https://github.com/xtool-org/xtool>); run `xtool --help` for
the exact options of your version.

1. **Windows only:** install WSL with Ubuntu (`wsl --install` in PowerShell), then run
   everything below inside Ubuntu.
2. Install the prerequisites xtool lists: the Swift toolchain from
   <https://www.swift.org/install/linux> and `sudo apt-get install usbmuxd`.
3. Install xtool:
   ```bash
   curl -fL "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" -o xtool
   chmod +x xtool && sudo mv xtool /usr/local/bin/
   ```
4. `xtool setup`. Choose **Password** (works with a free Apple ID; xtool suggests a
   spare Apple ID because this uses private Apple APIs) and sign in. Setup may also ask
   for **Xcode.xip** (a large download from developer.apple.com); xtool's docs don't
   say whether installing an existing .ipa can skip it.
5. Connect the iPhone by USB and tap **Trust** on the phone. On Windows, pass the
   phone into WSL with [usbipd-win](https://learn.microsoft.com/windows/wsl/connect-usb)
   (`usbipd list`, `usbipd bind --busid <id>`, `usbipd attach --wsl --busid <id>`).
   Check it's seen with `xtool devices`.
6. `xtool install piq6-monitor-vX.Y.Z.ipa`
7. On the iPhone: Settings → General → VPN & Device Management → trust your Apple ID,
   and (iOS 16+) Settings → Privacy & Security → **Developer Mode** → on.

### Simpler on Windows: Sideloadly

If xtool's setup needs Xcode.xip and that download is too big, Sideloadly
(<https://sideloadly.io>) is a Windows app that does the same job with a free Apple ID:
open the .ipa, enter your Apple ID, click Start. It needs Apple's iTunes and iCloud
(the versions from apple.com, not the Microsoft Store).

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
**piq6-monitor-apk** artifact. Download it from the run's page:
Actions → Build APK → latest run → Artifacts. It can also be started by hand
(Run workflow).

```powershell
gh run download --name piq6-monitor-apk
```

## Build locally

Run `flutter create --project-name piq6_monitor --org com.piq6 --platforms android .`
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
