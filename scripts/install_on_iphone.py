#!/usr/bin/env python3
"""List physical iPhones, or build, sign and install Quietly on a selected iPhone."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def physical_iphones():
    with tempfile.TemporaryDirectory(prefix="quietly-devices-") as folder:
        output = Path(folder) / "devices.json"
        subprocess.run(["xcrun", "devicectl", "list", "devices", "--json-output", str(output)],
                       check=True, stdout=subprocess.DEVNULL)
        devices = json.loads(output.read_text()).get("result", {}).get("devices", [])
    result = []
    for device in devices:
        properties = device.get("properties", {})
        hardware = properties.get("hardware", device.get("hardwareProperties", {}))
        state = properties.get("state", device.get("deviceProperties", {}))
        if hardware.get("reality") != "physical" or hardware.get("deviceType") != "iPhone":
            continue
        result.append({"identifier": device["identifier"], "udid": hardware.get("udid"),
                       "name": state.get("name", "iPhone")})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--list", action="store_true", help="List physical iPhones without installing anything")
    parser.add_argument("--device", help="Physical iPhone identifier from --list")
    parser.add_argument("--team", help="10-character Apple signing team ID from Xcode")
    parser.add_argument("--bundle-id", default="org.quietly.focus", help="Use a unique identifier if the default is unavailable")
    args = parser.parse_args()
    devices = physical_iphones()
    if not devices:
        print("No physical iPhone is available. Connect and unlock your iPhone, trust this Mac, and enable Developer Mode.")
        return 0 if args.list else 1
    if args.list:
        for device in devices:
            print(f"{device['name']}: {device['identifier']}")
        return 0
    if not args.device or not args.team:
        parser.error("Installation requires --device and --team. First sign into Xcode > Settings > Accounts.")
    if not re.fullmatch(r"[A-Z0-9]{10}", args.team):
        parser.error("--team must be a 10-character Apple team ID")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", args.bundle_id):
        parser.error("--bundle-id must be a reverse-domain identifier")
    device = next((d for d in devices if args.device in (d['identifier'], d['udid'])), None)
    if device is None or not device['udid']:
        parser.error("The selected device is not an available physical iPhone with a known UDID")
    derived = ROOT / "build/iPhone"
    subprocess.run(["xcodebuild", "-project", str(ROOT / "Quietly.xcodeproj"), "-scheme", "Quietly",
                    "-configuration", "Debug", "-destination", f"platform=iOS,id={device['udid']}",
                    "-derivedDataPath", str(derived), "-allowProvisioningUpdates",
                    f"DEVELOPMENT_TEAM={args.team}", f"PRODUCT_BUNDLE_IDENTIFIER={args.bundle_id}",
                    "CODE_SIGN_STYLE=Automatic", "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", "build"], check=True, cwd=ROOT)
    app = derived / "Build/Products/Debug-iphoneos/Quietly.app"
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    subprocess.run(["xcrun", "devicectl", "device", "install", "app", "--device", device['identifier'], str(app)], check=True)
    subprocess.run(["xcrun", "devicectl", "device", "process", "launch", "--device", device['identifier'], args.bundle_id], check=True)
    print("Quietly is installed and launched. Sign into Instagram on the iPhone, then enable message alerts in Settings.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
