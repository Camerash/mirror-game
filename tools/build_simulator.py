"""Export and build the unsigned Godot iOS Simulator app. No third-party modules."""

import os
from pathlib import Path
import platform
import plistlib
import subprocess


ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")


def run(*arguments: str, capture: bool = False) -> str:
    result = subprocess.run(
        ["rtk", "proxy", *arguments], cwd=ROOT, check=True, text=True,
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout or ""


def main() -> None:
    output = ROOT / "build" / "ios"
    output.mkdir(parents=True, exist_ok=True)
    (output.parent / ".gdignore").touch()
    run(GODOT, "--headless", "--path", str(ROOT), "--export-debug",
        "iOS Simulator", str(output / "Mirror.zip"))
    library = output / "Mirror.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
    architectures = run("xcrun", "lipo", "-archs", str(library), capture=True).split()
    host = platform.machine()
    architecture = host if host in architectures else "x86_64"
    if architecture not in architectures:
        raise RuntimeError(f"No supported Simulator architecture: {architectures}")
    print(f"Simulator architecture: {architecture}", flush=True)

    # The exporter adds empty privacy descriptions. This prototype uses none
    # of these services; remove only empty keys from the generated project.
    info = output / "Mirror/Mirror-Info.plist"
    with info.open("rb") as source:
        settings = plistlib.load(source)
    for key in ("NSCameraUsageDescription", "NSMicrophoneUsageDescription",
                "NSPhotoLibraryUsageDescription"):
        if settings.get(key) == "":
            settings.pop(key)
    with info.open("wb") as target:
        plistlib.dump(settings, target)

    run("xcodebuild", "-project", str(output / "Mirror.xcodeproj"),
        "-scheme", "Mirror", "-configuration", "Debug", "-sdk", "iphonesimulator",
        "-destination", "generic/platform=iOS Simulator", "-derivedDataPath",
        str(ROOT / "build/ios-derived"), f"ARCHS={architecture}",
        "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO",
        "CODE_SIGN_IDENTITY=", "DEVELOPMENT_TEAM=", "-quiet", "build")
    print("Built build/ios-derived/Build/Products/Debug-iphonesimulator/Mirror.app")


if __name__ == "__main__":
    main()
