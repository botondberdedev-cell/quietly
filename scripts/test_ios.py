#!/usr/bin/env python3
"""Run app-host WebKit and native UI checks on an installed iPhone simulator."""
import argparse
import datetime
import json
import re
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def simctl(*args):
    return subprocess.check_output(["xcrun", "simctl", *args], text=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", help="Existing simulator UDID; otherwise use/create Quietly QA iPhone")
    parser.add_argument("--result-bundle", help="New .xcresult path (must not already exist)")
    parser.add_argument("--only-testing", action="append", default=[], help="Xcode test target or test identifier")
    args = parser.parse_args()
    device = args.device
    if not device:
        runtimes = [r for r in json.loads(simctl("list", "runtimes", "--json"))["runtimes"]
                    if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]
        if not runtimes:
            raise SystemExit("Install an iOS simulator runtime in Xcode Settings > Components, then retry.")
        runtimes.sort(key=lambda r: tuple(map(int, r["version"].split("."))), reverse=True)
        # Prefer a regular iPhone. A newer runtime may only support a foldable.
        candidates = [(r, t) for r in runtimes for t in r.get("supportedDeviceTypes", [])
                      if re.fullmatch(r"iPhone \d+", t.get("name", ""))]
        if not candidates:
            candidates = [(r, t) for r in runtimes for t in r.get("supportedDeviceTypes", [])
                          if t.get("productFamily") == "iPhone" or t.get("name", "").startswith("iPhone")]
        if not candidates:
            raise SystemExit("No installed runtime reports a compatible iPhone device type.")
        runtime, phone = candidates[0]
        devices = json.loads(simctl("list", "devices", "available", "--json"))["devices"].get(runtime["identifier"], [])
        existing = next((d for d in devices if d["name"].startswith("Quietly QA")
                         and d.get("deviceTypeIdentifier") == phone["identifier"]), None)
        if existing:
            device = existing["udid"]
        else:
            device = simctl("create", "Quietly QA iPhone", phone["identifier"], runtime["identifier"]).strip()
    output = Path(args.result_bundle) if args.result_bundle else ROOT / "test-results" / (datetime.datetime.now().strftime("native-%Y%m%d-%H%M%S") + ".xcresult")
    output = output.expanduser().resolve()
    if output.exists():
        raise SystemExit(f"Result bundle already exists: {output}. Choose a new path.")
    output.parent.mkdir(parents=True, exist_ok=True)
    print(f"Testing simulator {device}; results: {output}", flush=True)
    subprocess.run(["xcrun", "simctl", "bootstatus", device, "-b"], check=True)
    command = ["xcodebuild", "-project", str(ROOT / "Quietly.xcodeproj"), "-scheme", "Quietly",
               "-destination", f"platform=iOS Simulator,id={device}", "-parallel-testing-enabled", "NO",
               "-derivedDataPath", str(ROOT / "build/DerivedData"), "-resultBundlePath", str(output),
               "CODE_SIGNING_ALLOWED=NO", "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", "test"]
    command.extend("-only-testing:" + value for value in args.only_testing)
    raise SystemExit(subprocess.call(command, cwd=ROOT))


if __name__ == "__main__":
    main()
