"""Customises the iOS project that `flutter create --platforms ios .` generates.

  - app name shown under the icon: "Pi Q6 Monitor"
  - allows plain http:// gateways (self-hosted servers on the LAN or without TLS)
  - removes the template's widget test (it targets the template app)
"""
import os
import plistlib
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
PLIST = os.path.join(ROOT, "ios", "Runner", "Info.plist")
TEMPLATE_TEST = os.path.join(ROOT, "test", "widget_test.dart")


def main():
    if not os.path.exists(PLIST):
        sys.exit("ios/ is missing - run `flutter create --platforms ios .` first.")
    with open(PLIST, "rb") as f:
        info = plistlib.load(f)
    info["CFBundleDisplayName"] = "Pi Q6 Monitor"
    info["CFBundleName"] = "Pi Q6 Monitor"
    # The user types their own server address; it may be http:// on a home network.
    info["NSAppTransportSecurity"] = {"NSAllowsArbitraryLoads": True, "NSAllowsLocalNetworking": True}
    with open(PLIST, "wb") as f:
        plistlib.dump(info, f)
    print("patched", PLIST)
    if os.path.exists(TEMPLATE_TEST):
        with open(TEMPLATE_TEST, encoding="utf-8") as f:
            if "MyApp" in f.read():
                os.remove(TEMPLATE_TEST)
                print("removed template", TEMPLATE_TEST)


if __name__ == "__main__":
    main()
