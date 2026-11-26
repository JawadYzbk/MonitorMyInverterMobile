# Changelog

Each version here becomes a GitHub Release with the APK attached. To release:
bump `version:` in `pubspec.yaml`, add a section below with the same number, push to `main`.

## [1.2.0] - 2026-11-26

### New name and icon

- The app is now called **WattWise**, with a new icon: a green-to-blue lightning bolt in a gauge ring. On Android 13+ it also follows your themed-icon colours. Notifications use a matching white bolt in the status bar.

### New: iPhone version

- Each release now also has **wattwise-vX.Y.Z.ipa** for iPhone. It's unsigned: install it with a free Apple ID using xtool (or Sideloadly / AltStore), which signs it for your phone. See "Install on iPhone" below.
- On iPhone, grid and battery alerts work **while the app is open**, because iOS doesn't let apps keep checking in the background. Home screen widgets are Android-only for now.

### Changed

- The low-battery alarm no longer goes off for a one-off empty reading (0 V / 0 %) from the cloud; the battery has to read low twice in a row.
- **The app no longer has a built-in server.** On first sign-in, enter the address of your MonitorMyInverter gateway. It's saved on your phone only (change it later in Settings). Addresses without `http://` or `https://` use https, except local ones (IP address, `localhost`, `.local`), which use http.

## [1.1.0] - 2026-11-26

### New: home screen widgets

Long-press your home screen → Widgets → **WattWise**. Six widgets:

- **Battery** (2×2): level, voltage, charging or draining amps, and a level bar. Turns red below your alert level.
- **Grid power** (2×2): on or off, how long it has been that way, and when the forecast expects the next change.
- **Power now** (2×2): solar and home load in watts, and whether you have spare power or are drawing from the battery or grid.
- **Overview** (4×2): battery, grid, solar and load side by side, like the app's main screen.
- **Grid forecast** (4×2): next expected grid change with its likely window, the last 24 hours hour by hour, the expected next 24 hours, and today's grid hours and cuts.
- **Trends** (4×2): chart of solar, load and battery over the last 4 hours, plus how fast the battery is rising or falling.

Tap a widget to open the app. The ↻ button on the wide widgets refreshes without opening it. With background monitoring on, the widgets update every 15 seconds (forecast and charts every 5 minutes). Each widget shows when it was last updated and flags old readings.

## [1.0.0] - 2026-11-26

First Android version of WattWise.

- **Overview**: battery, grid, solar and home-load tiles; low-battery banner; grid forecast with next change, next-24-hours strip, usual daily schedule and weekly stats; power chart (1 / 2 / 4 h); grid hours for the last 24 hours and a 7-day heatmap.
- **History**: every stored reading, with date, load, battery-voltage and model filters, sorting and paging.
- **Settings**: low-battery alert level, alarm / voice / grid-sound switches, background monitoring, inverter picker, recent readings, server address, sign out.
- **Alerts**: chime when grid power comes back, falling tones when it goes off, siren plus spoken warning when the battery is low (repeats every 2 minutes while low), including while the app is closed.
