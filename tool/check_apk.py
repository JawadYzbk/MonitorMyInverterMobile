"""Fails if the built APK is missing what the alerts need.

Usage: python tool/check_apk.py build/app/outputs/flutter-apk/app-release.apk
"""
import sys
import zipfile

SOUNDS = ["grid_on", "grid_off", "low_battery"]
MANIFEST = [
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
    "com.pravera.flutter_foreground_task.service.ForegroundService",
    "es.antonborri.home_widget.HomeWidgetBackgroundReceiver",
] + [
    f"app.wattwise.wattwise.widgets.{w}"
    for w in ["BatteryWidget", "GridWidget", "PowerWidget", "OverviewWidget", "ForecastWidget", "TrendWidget"]
]


def contains(blob, text):
    return text.encode("utf-8") in blob or text.encode("utf-16le") in blob


def main(path):
    apk = zipfile.ZipFile(path)
    arsc = apk.read("resources.arsc")
    manifest = apk.read("AndroidManifest.xml")
    missing = [f"sound {s}" for s in SOUNDS if not contains(arsc, s)]
    missing += [m for m in MANIFEST if not contains(manifest, m)]
    if missing:
        sys.exit("APK is missing: " + ", ".join(missing))
    print("APK OK: sounds and manifest entries present")


if __name__ == "__main__":
    main(sys.argv[1])
