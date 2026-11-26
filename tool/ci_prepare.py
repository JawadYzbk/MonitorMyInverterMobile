"""Customises the Android project that `flutter create` generates.

Run after `flutter create --platforms android .` (CI does this on every build):
  - copies android_overlay/ (home screen widgets) into android/
  - adds the permissions, the background (foreground) service and the widgets to AndroidManifest.xml
  - sets the app label
  - enables core library desugaring (needed by flutter_local_notifications)
  - removes the template's widget test (it targets the template app)
  - writes the alert sounds to res/raw
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MANIFEST = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
GRADLE_KTS = os.path.join(ROOT, "android", "app", "build.gradle.kts")
GRADLE = os.path.join(ROOT, "android", "app", "build.gradle")

# flutter_local_notifications and androidx.core 1.19 need compileSdk 37+
# (newer than Flutter's template default). This doesn't change which phones can install it.
COMPILE_SDK = 37
TEMPLATE_TEST = os.path.join(ROOT, "test", "widget_test.dart")

PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
    "android.permission.RECEIVE_BOOT_COMPLETED",
    "android.permission.WAKE_LOCK",
    "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
]

SERVICE = """
        <!-- Background monitoring (flutter_foreground_task). Do not rename. -->
        <service
            android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
            android:foregroundServiceType="specialUse"
            android:exported="false">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="Monitors a home solar inverter and alerts when grid power or the battery changes" />
        </service>
        <meta-data
            android:name="app.wattwise.service.NOTIFICATION_ICON"
            android:resource="@drawable/ic_stat_wattwise" />
        <!-- Default small icon for alert notifications. -->
        <meta-data
            android:name="com.dexterous.flutterlocalnotifications.default_icon"
            android:resource="@drawable/ic_stat_wattwise" />
"""


OVERLAY = os.path.join(ROOT, "android_overlay")

# Home screen widgets (android_overlay/.../widgets/Widgets.kt) and their provider info XML.
WIDGETS = {
    "BatteryWidget": "widget_battery_info",
    "GridWidget": "widget_grid_info",
    "PowerWidget": "widget_power_info",
    "OverviewWidget": "widget_overview_info",
    "ForecastWidget": "widget_forecast_info",
    "TrendWidget": "widget_trend_info",
}


def widget_receivers():
    out = []
    for cls, info in WIDGETS.items():
        out.append(f"""
        <receiver android:name=".widgets.{cls}" android:exported="false">
            <intent-filter>
                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
            </intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/{info}" />
        </receiver>""")
    # Refresh button on the widgets (home_widget interactivity).
    out.append("""
        <receiver android:name="es.antonborri.home_widget.HomeWidgetBackgroundReceiver" android:exported="true">
            <intent-filter>
                <action android:name="es.antonborri.home_widget.action.BACKGROUND" />
            </intent-filter>
        </receiver>
""")
    return "".join(out)


def copy_overlay():
    """Copies android_overlay/ into android/ (widget Kotlin code, layouts, drawables)."""
    for base, _, files in os.walk(OVERLAY):
        rel = os.path.relpath(base, OVERLAY)
        dest = os.path.join(ROOT, "android", rel)
        os.makedirs(dest, exist_ok=True)
        for f in files:
            shutil.copyfile(os.path.join(base, f), os.path.join(dest, f))
    print("copied", OVERLAY)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def patch_manifest():
    xml = read(MANIFEST)
    perms = "".join(
        f'    <uses-permission android:name="{p}" />\n' for p in PERMISSIONS if p not in xml
    )
    if perms:
        xml = re.sub(r"(\s*)<application", "\n" + perms + r"\1<application", xml, count=1)
    if "flutter_foreground_task.service.ForegroundService" not in xml:
        xml = xml.replace("</application>", SERVICE + "    </application>", 1)
    if ".widgets.BatteryWidget" not in xml:
        xml = xml.replace("</application>", widget_receivers() + "    </application>", 1)
    xml = re.sub(r'android:label="[^"]*"', 'android:label="WattWise"', xml, count=1)
    write(MANIFEST, xml)
    print("patched", MANIFEST)


def patch_gradle():
    if os.path.exists(GRADLE_KTS):
        g = read(GRADLE_KTS)
        g = re.sub(r"compileSdk\s*=\s*[^\n]+", f"compileSdk = {COMPILE_SDK}", g, count=1)
        if "isCoreLibraryDesugaringEnabled" not in g:
            g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
        if "desugar_jdk_libs" not in g:
            g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        write(GRADLE_KTS, g)
        print("patched", GRADLE_KTS)
    elif os.path.exists(GRADLE):
        g = read(GRADLE)
        g = re.sub(r"compileSdk(Version)?\s*=?\s*[^\n]+", f"compileSdk = {COMPILE_SDK}", g, count=1)
        if "coreLibraryDesugaringEnabled" not in g:
            g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", g, count=1)
        if "desugar_jdk_libs" not in g:
            g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        write(GRADLE, g)
        print("patched", GRADLE)
    else:
        sys.exit("No android/app/build.gradle(.kts) found - run `flutter create` first.")


def drop_template_test():
    if os.path.exists(TEMPLATE_TEST) and "MyApp" in read(TEMPLATE_TEST):
        os.remove(TEMPLATE_TEST)
        print("removed template", TEMPLATE_TEST)


if __name__ == "__main__":
    if not os.path.exists(MANIFEST):
        sys.exit("android/ is missing - run `flutter create --platforms android .` first.")
    copy_overlay()
    patch_manifest()
    patch_gradle()
    drop_template_test()
    subprocess.run([sys.executable, os.path.join(ROOT, "tool", "make_sounds.py")], check=True)
