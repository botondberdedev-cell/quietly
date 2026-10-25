#!/usr/bin/env python3
"""Build an unsigned device IPA and a source feed for SideStore/AltStore Classic.

Each installer signs the IPA with the recipient's own account. This script never
uses the publisher's signing identity, provisioning profiles, or login cookies.
"""
import argparse
import hashlib
import json
import plistlib
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="build/sideload")
    args = parser.parse_args()
    release = json.loads((ROOT / "release.json").read_text())
    version, build, tag = release["version"], release["build"], release["tag"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or not re.fullmatch(r"\d+", build):
        raise SystemExit("Invalid release version/build")
    if not re.fullmatch(r"v[0-9A-Za-z.-]+", tag):
        raise SystemExit("Invalid release tag")
    output = (ROOT / args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    (ROOT / "build").mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="quietly-package-", dir=ROOT / "build") as folder:
        staging = Path(folder)
        archive = staging / "Quietly.xcarchive"
        subprocess.run([
            "xcodebuild", "-project", str(ROOT / "Quietly.xcodeproj"), "-scheme", "Quietly",
            "-configuration", "Release", "-destination", "generic/platform=iOS",
            "-archivePath", str(archive), "-derivedDataPath", str(ROOT / "build/SideloadDerivedData"),
            "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "DEVELOPMENT_TEAM=",
            f"MARKETING_VERSION={version}", f"CURRENT_PROJECT_VERSION={build}",
            "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES", "archive"
        ], check=True, cwd=ROOT)
        app = archive / "Products/Applications/Quietly.app"
        info = plistlib.loads((app / "Info.plist").read_bytes())
        assert info["CFBundleShortVersionString"] == version
        assert info["CFBundleVersion"] == build
        assert info["CFBundleSupportedPlatforms"] == ["iPhoneOS"]
        assert info["CFBundleIdentifier"] == "org.quietly.focus"
        assert (app / "PrivacyInfo.xcprivacy").is_file()
        assert (app / "LICENSE.txt").is_file()
        for name in ("filters.js", "single-post.js", "message-alerts.js"):
            assert (app / name).read_bytes() == (ROOT / "Quietly/Resources" / name).read_bytes()
        forbidden = [p for p in app.rglob("*") if p.name in ("embedded.mobileprovision", "_CodeSignature")
                     or p.suffix in (".p12", ".p8", ".mobileprovision", ".xcuserstate")]
        if forbidden:
            raise SystemExit("Signing/personal files unexpectedly present; package was not created")
        ipa = output / f"Quietly-{version}.ipa"
        with zipfile.ZipFile(ipa, "w", zipfile.ZIP_DEFLATED) as bundle:
            for file in sorted(app.rglob("*")):
                if file.is_file():
                    bundle.write(file, "Payload/Quietly.app/" + file.relative_to(app).as_posix())
    repo = release["repository"]
    website = f"https://github.com/{repo}"
    download = f"{website}/releases/download/{tag}"
    icon = f"https://raw.githubusercontent.com/{repo}/main/Quietly/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    notes = "Own-profile and followed-profile videos remain accessible. Selected Reels open one at a time; the endless Reels feed stays blocked. Early testing release; Instagram layouts can change."
    source = {
        "name": "Quietly", "identifier": "org.quietly.source",
        "subtitle": "Keep your friends. Leave the endless feed.",
        "description": "Free, MIT-licensed early releases of Quietly for SideStore and AltStore Classic.",
        "website": website, "iconURL": icon, "tintColor": "214D3B",
        "apps": [{
            "name": "Quietly", "bundleIdentifier": info["CFBundleIdentifier"],
            "developerName": "Botond Berde", "subtitle": "Instagram, one intentional visit at a time.",
            "localizedDescription": "Browse people you follow, Stories, messages and your own profile. Open shared videos individually, with the endless Reels and Explore feeds blocked. Free and open source. Early beta: layout changes can affect filtering. Message alerts work while open, not in the background. Requires Instagram sign-in and seven-day signing refreshes with a free Apple account.",
            "iconURL": icon, "tintColor": "214D3B", "category": "social",
            "versions": [{"version": version, "buildVersion": build, "date": release["date"],
                          "localizedDescription": notes, "downloadURL": f"{download}/{ipa.name}",
                          "size": ipa.stat().st_size, "minOSVersion": info["MinimumOSVersion"]}],
            "appPermissions": {"entitlements": [], "privacy": {}}
        }], "news": []
    }
    source_path = output / "quietly-source.json"
    source_path.write_text(json.dumps(source, indent=2) + "\n")
    shutil.copyfile(ROOT / "docs/sideloading.md", output / "INSTALL.md")
    shutil.copyfile(ROOT / "docs/releases/0.2.0.md", output / "RELEASE-NOTES.md")
    files = [ipa, source_path, output / "INSTALL.md", output / "RELEASE-NOTES.md"]
    (output / "SHA256SUMS").write_text("".join(
        f"{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n" for file in files))
    print(f"Ready for recipient signing: {ipa} ({ipa.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
