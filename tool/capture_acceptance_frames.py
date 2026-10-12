#!/usr/bin/env python3
"""Drive Flutter's native integration screenshots and verify saved evidence.

On-device IntegrationTestWidgetsFlutterBinding.takeScreenshot sends actual
Flutter frames to the integration_driver_extended screenshot callback on the
CI host. Screenshot artifacts contain only fictional emulator test accounts.
No host-side simctl/adb screen scraping is used for stage evidence.
"""
import argparse
import hashlib
import os
import pathlib
import struct
import subprocess
import sys


def run():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=("ios", "android"), required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--attempt", type=int, choices=(1, 2), required=True)
    args = parser.parse_args()

    directory = "simulator_acceptance" if args.platform == "ios" else "android_acceptance"
    output = pathlib.Path("build") / directory
    output.mkdir(parents=True, exist_ok=True)
    logfile = output / f"flutter-drive-attempt-{args.attempt}.log"
    host = "127.0.0.1" if args.platform == "ios" else "10.0.2.2"
    command = [
        "flutter", "drive",
        "--driver=test_driver/integration_test.dart",
        "--target=integration_test/simulator_acceptance_test.dart",
        "-d", args.device, "--flavor", "staging",
        "--dart-define=USE_FIREBASE_EMULATORS=true",
        f"--dart-define=FIREBASE_EMULATOR_HOST={host}",
        "--dart-define=POLYCIRCLE_CAPTURE_ACCEPTANCE_SCREENSHOTS=true",
        "--dart-define=POLYCIRCLE_ACCEPTANCE_ADULT_SIGNAL=true",
        "--dart-define=POLYCIRCLE_ACCEPTANCE_LOCATION=true",
        "--no-pub",
    ]
    if args.platform == "android":
        # CI-only A/B: use the Skia software rendering path to distinguish
        # Linux emulator Impeller startup failure from Chat viewport defects.
        # The actual Android and iOS product renderer remains unchanged.
        command.append("--no-enable-impeller")
    environment = dict(os.environ)
    environment["POLYCIRCLE_ACCEPTANCE_OUTPUT_DIRECTORY"] = str(output)
    timeout = 1500 if args.platform == "ios" else 900
    print(f"Starting {args.platform} integration drive attempt {args.attempt}/2.", flush=True)
    with logfile.open("wb") as log:
        try:
            result = subprocess.run(
                command, stdout=log, stderr=subprocess.STDOUT,
                timeout=timeout, env=environment,
            )
            status = result.returncode
        except subprocess.TimeoutExpired:
            sys.stderr.write(f"Flutter drive exceeded {timeout}s.\n")
            status = 124

    # Preserve test failure details in GitHub Actions and stored artifacts.
    with logfile.open("r", encoding="utf-8", errors="replace") as log:
        for line in log:
            sys.stdout.write(line)
    sys.stdout.flush()
    if status != 0:
        return status

    names = {p.stem for p in output.glob("*.png") if p.stat().st_size > 1024}
    required = {
        "01-login", "03-discover", "03a-discover-pass-counter",
        "04-connections", "04a-member-profile", "05-circle",
        "05a-relationship-manager",
        "06-messages", "07-chat", "08-profile", "08a-profile-settings",
        "08b-profile-settings-actions", "09-safety",
    }
    missing = required - names
    if missing:
        sys.stderr.write("Missing real Flutter screen evidence: "
                         + ", ".join(sorted(missing)) + "\n")
        return 18
    # Reject a home-screen frame copied under every route name, and check
    # dimensions before accepting a PNG as readable simulator evidence.
    # Pixel-level visual approval remains a human signoff, NOT this test.
    hashes = {}
    for name in sorted(required):
        file = output / f"{name}.png"
        contents = file.read_bytes()
        if len(contents) < 40 or contents[:8] != b"\x89PNG\r\n\x1a\n":
            sys.stderr.write(f"Invalid PNG evidence: {file}\n")
            return 18
        width, height = struct.unpack(">II", contents[16:24])
        if width < 300 or height < 500:
            sys.stderr.write(
                f"Screenshot has implausible dimensions at {name}: "
                f"{width}x{height}\n"
            )
            return 18
        digest = hashlib.sha256(contents).hexdigest()
        if digest in hashes:
            sys.stderr.write(
                f"Duplicated device screenshot for {name} and "
                f"{hashes[digest]} (possible stale launcher capture).\n"
            )
            return 18
        hashes[digest] = name
    print(f"POLYCIRCLE_VISUAL_EVIDENCE:{len(required)} Flutter screenshots saved", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(run())
