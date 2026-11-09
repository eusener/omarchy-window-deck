#!/usr/bin/env python3
"""Check transparent compositor exports with Qt's real scene graph, offscreen."""

import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

with tempfile.TemporaryDirectory(prefix="window-deck-capture-") as directory:
    stage = Path(directory)
    # Isolate this component from the plugin's Omarchy-only singleton imports.
    (stage / "WindowCapture.qml").write_bytes((ROOT / "WindowCapture.qml").read_bytes())
    (stage / "capture_alpha.cpp").write_bytes((ROOT / "tests/capture_alpha.cpp").read_bytes())
    (stage / "capture.pro").write_text(
        "QT += gui quick\nCONFIG += console c++17\nSOURCES = capture_alpha.cpp\nTARGET = capture-alpha\n"
    )
    for command in (["qmake6", "capture.pro"], ["make", "-s", "-j2"]):
        result = subprocess.run(command, cwd=stage, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if result.returncode:
            print(result.stdout)
            raise SystemExit(result.returncode)
    runtime = stage / "runtime"
    runtime.mkdir(mode=0o700)
    module = stage / "Quickshell/Wayland"
    module.mkdir(parents=True)
    (module / "qmldir").write_text("module Quickshell.Wayland\n")
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_QPA_PLATFORMTHEME="",
               QT_QUICK_BACKEND="software", QT_FORCE_STDERR_LOGGING="1",
               XDG_RUNTIME_DIR=str(runtime), DISPLAY="", WAYLAND_DISPLAY="")
    result = subprocess.run([str(stage / "capture-alpha"), str(stage), str(stage)], env=env)
    raise SystemExit(result.returncode)
