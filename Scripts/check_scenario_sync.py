#!/usr/bin/env python3
"""Fail if this app's scenario drifts from the copy the library's LabStageTests assert.

The library's CI asserts the numbers in this app's screenshots by running `HybridInferenceLab` with a copy
of the scenario in Demo/DemoApp.swift. This script fetches that copy at the exact library version in
Package.resolved and compares the dataset blocks and the scenario configuration, so the claim
"LabStageTests asserts the screenshot numbers" cannot silently go stale.

Run from the repo root: python3 Scripts/check_scenario_sync.py
"""
import json
import pathlib
import re
import subprocess
import sys

RESOLVED = pathlib.Path("Demo.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved")
APP = pathlib.Path("Demo/DemoApp.swift")
RAW = "https://raw.githubusercontent.com/rajatslakhina/hybrid-inference-router-kit/v{version}/Tests/HybridInferenceTests/{name}"
BLOCKS = ["rules", "seed", "eval", "dayOne", "dayTwo"]
KEYS = ["title", "teacherModelID", "teacherFallback", "trafficBatches", "targetPrecision", "gate", "shadowCallsPerRun"]


def squash(text: str) -> str:
    return re.sub(r"\s+", "", text)


def block(source: str, name: str) -> str:
    match = re.search(r"static let " + name + r": \[[^\]]*\] = \[(.*?)\n    \]", source, re.S)
    if not match:
        sys.exit(f"block {name!r} not found")
    return squash(match.group(1))


def balanced(source: str, opener: str) -> str:
    start = source.find(opener)
    if start < 0:
        sys.exit(f"{opener!r} not found")
    depth = 0
    for index in range(start + len(opener) - 1, len(source)):
        depth += {"(": 1, ")": -1}.get(source[index], 0)
        if depth == 0:
            return squash(source[start:index + 1])
    sys.exit(f"unbalanced {opener!r}")


def key_line(source: str, key: str) -> str:
    match = re.search(r"^\s*" + key + r": (.+?),?\s*$", source, re.M)
    if not match:
        sys.exit(f"{key!r} not found")
    return squash(match.group(1))


def main() -> int:
    pins = json.loads(RESOLVED.read_text())["pins"]
    version = next(p["state"]["version"] for p in pins if p["identity"] == "hybrid-inference-router-kit")
    # curl uses the system trust store, which some Python installs do not.
    fetch = lambda name: subprocess.run(
        ["curl", "-fsSL", "--max-time", "30", RAW.format(version=version, name=name)],
        check=True, capture_output=True, text=True,
    ).stdout
    support, lab = fetch("TestSupport.swift"), fetch("LabStageTests.swift")
    app = APP.read_text()

    problems = [f"dataset block {n!r} differs" for n in BLOCKS if block(app, n) != block(support, n)]
    if balanced(app, "RouterConfiguration(") != balanced(lab, "RouterConfiguration("):
        problems.append("RouterConfiguration differs")
    problems += [f"{k!r} differs" for k in KEYS if key_line(app, k) != key_line(lab, k)]

    print(f"Compared Demo/DemoApp.swift with the library's test scenario at v{version}.")
    for problem in problems:
        print(f"  MISMATCH: {problem}")
    print("Scenario in sync." if not problems else f"{len(problems)} mismatch(es).")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
