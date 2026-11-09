#!/usr/bin/env python3
"""Build or verify the immutable runtime committed for native plugin installs."""

import argparse
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from install import build_runtime, copy_runtime


def check(root):
    with tempfile.TemporaryDirectory(prefix="window-deck-build-") as directory:
        stage = Path(directory)
        copy_runtime(root, stage)
        expected = json.loads((stage / "manifest.json").read_text())
        actual = json.loads((root / "manifest.json").read_text())
        if actual != expected:
            raise ValueError("manifest runtime is stale; run python3 scripts/build-runtime.py")
        runtime = Path(expected["entryPoints"]["overlay"]).parent
        for source in (stage / runtime).rglob("*"):
            if source.is_file():
                target = root / source.relative_to(stage)
                if not target.is_file() or target.read_bytes() != source.read_bytes():
                    raise ValueError(f"runtime missing or stale: {target.relative_to(root)}")
    return actual


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify without changing source files")
    args = parser.parse_args()
    try:
        if args.check:
            manifest = check(ROOT)
        else:
            build_runtime(ROOT)
            manifest = json.loads((ROOT / "manifest.json").read_text())
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Runtime: {exc}\n")
    print(("Verified" if args.check else "Built") + " " + str(Path(manifest["entryPoints"]["overlay"]).parent))


if __name__ == "__main__":
    main()
