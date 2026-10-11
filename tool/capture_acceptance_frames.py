#!/usr/bin/env python3
"""Record real emulator frames at named integration-test checkpoints.

This is fictional local-Firebase QA evidence, not manual/real-device signoff.
"""
import argparse
import pathlib
import queue
import re
import subprocess
import sys
import threading
import time


def capture_frame(platform, device, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    if platform == "ios":
        result = subprocess.run(
            ["xcrun", "simctl", "io", device, "screenshot", str(destination)],
            capture_output=True, timeout=12,
        )
    else:
        with destination.open("wb") as image_file:
            result = subprocess.run(
                ["adb", "-s", device, "exec-out", "screencap", "-p"],
                stdout=image_file, stderr=subprocess.PIPE, timeout=12,
            )
    valid = result.returncode == 0 and destination.exists()
    valid = valid and destination.stat().st_size > 1024
    if not valid:
        destination.unlink(missing_ok=True)
        sys.stderr.write(f"Screen capture failed: {destination.name}: {result.stderr[-500:]!r}\n")
    else:
        sys.stdout.write(f"POLYCIRCLE_FRAME:{destination}\n")
        sys.stdout.flush()
    return valid


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--platform", choices=("ios", "android"), required=True)
    parser.add_argument("--device", required=True)
    parser.add_argument("--attempt", type=int, choices=(1, 2), required=True)
    args = parser.parse_args()
    directory = "simulator_acceptance" if args.platform == "ios" else "android_acceptance"
    output = pathlib.Path("build") / directory
    output.mkdir(parents=True, exist_ok=True)
    logfile = output / f"flutter-test-attempt-{args.attempt}.log"
    host = "127.0.0.1" if args.platform == "ios" else "10.0.2.2"
    command = [
        "flutter", "test", "integration_test/simulator_acceptance_test.dart",
        "-d", args.device, "--flavor", "staging",
        "--dart-define=USE_FIREBASE_EMULATORS=true",
        f"--dart-define=FIREBASE_EMULATOR_HOST={host}",
        "--dart-define=POLYCIRCLE_CAPTURE_ACCEPTANCE_SCREENSHOTS=false",
        "--dart-define=POLYCIRCLE_CAPTURE_HOST_FRAMES=true",
        "--dart-define=POLYCIRCLE_ACCEPTANCE_ADULT_SIGNAL=true",
        "--dart-define=POLYCIRCLE_ACCEPTANCE_LOCATION=true",
        "--no-pub",
    ]
    child = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", bufsize=1,
    )
    lines = queue.Queue()

    def read_output():
        assert child.stdout is not None
        for line in child.stdout:
            lines.put(line)
        lines.put(None)

    threading.Thread(target=read_output, daemon=True).start()
    max_seconds = 1500 if args.platform == "ios" else 900
    deadline = time.monotonic() + max_seconds
    frames = set()
    failed = False
    timed_out = False
    with logfile.open("w", encoding="utf-8") as log:
        while True:
            if time.monotonic() > deadline:
                timed_out = True
                child.terminate()
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
                break
            try:
                line = lines.get(timeout=0.25)
            except queue.Empty:
                continue
            if line is None:
                break
            sys.stdout.write(line)
            sys.stdout.flush()
            log.write(line)
            log.flush()
            marker = re.search(r"POLYCIRCLE_ACCEPTANCE:([0-9]{2}[a-z]?-[a-z0-9-]+)", line)
            if marker:
                label = marker.group(1)
                if label not in frames:
                    destination = output / f"{label}-attempt-{args.attempt}.png"
                    try:
                        if capture_frame(args.platform, args.device, destination):
                            frames.add(label)
                        else:
                            failed = True
                    except (OSError, subprocess.TimeoutExpired) as error:
                        sys.stderr.write(f"Capture exception at {label}: {error}\n")
                        failed = True
    if timed_out:
        sys.stderr.write(f"Flutter acceptance exceeded {max_seconds}s; retry allowed.\n")
        return 124
    result = child.wait()
    if result == 0 and (failed or len(frames) < 8):
        sys.stderr.write(f"Missing visual evidence: {len(frames)} frames; expected >=8 with no failures.\n")
        return 18
    return result


if __name__ == "__main__":
    sys.exit(main())
