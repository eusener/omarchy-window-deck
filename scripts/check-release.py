#!/usr/bin/env python3
"""Check that a fresh clone is a self-contained native Omarchy plugin."""

import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    spec = importlib.util.spec_from_file_location("build_runtime", ROOT / "scripts/build-runtime.py")
    builder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(builder)
    manifest = builder.check(ROOT)
    if manifest.get("schemaVersion") != 1 or manifest.get("id") != "eusener.window-deck":
        raise ValueError("Unexpected plugin id or manifest schema")
    if not re.fullmatch(r"\d+\.\d+\.\d+", manifest.get("version", "")):
        raise ValueError("Expected a semantic version")
    expected = {"bar-widget": "barWidget", "overlay": "overlay"}
    if set(manifest.get("kinds", [])) != set(expected):
        raise ValueError("Expected bar-widget and overlay entry points")
    for kind, key in expected.items():
        relative = Path(manifest["entryPoints"][key])
        if relative.is_absolute() or ".." in relative.parts or not (ROOT / relative).is_file():
            raise ValueError(f"Invalid {kind} entry point")
    for file in ROOT.rglob("*"):
        if ".git" not in file.relative_to(ROOT).parts and file.is_symlink():
            raise ValueError(f"Plugin contains a symlink: {file.relative_to(ROOT)}")
    for relative in ("LICENSE", "README.md", "CHANGELOG.md", "operations.lua", "docs/preview.png"):
        if not (ROOT / relative).is_file():
            raise ValueError(f"Missing publication file: {relative}")
    for locale in ("en", "pt-BR"):
        json.loads((ROOT / "i18n" / (locale + ".json")).read_text())
    # The native validator is authoritative where Omarchy is installed.
    native = Path("/usr/share/omarchy/bin/omarchy-plugin-validate")
    if native.is_file():
        subprocess.run([str(native), str(ROOT)], check=True)
    print(f"Release {manifest['version']} ready for omarchy plugin add")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        sys.exit(f"Release check failed: {exc}")
