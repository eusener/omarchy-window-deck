#!/usr/bin/env python3
"""Open an isolated Window Deck to compare capture transports on a live desktop."""

import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--transport", choices=("shm", "default"), default="shm")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="window-deck-diagnostic-") as directory:
        stage = Path(directory)
        (stage / "plugin").symlink_to(ROOT)
        for name in ("Commons", "Ui"):
            (stage / name).symlink_to(Path("/usr/share/omarchy/shell") / name)
        (stage / "shell.qml").write_text('''import QtQuick
import Quickshell
import "plugin" as Deck

ShellRoot {
    Deck.Deck {
        id: deck
        onOpenedChanged: if (!opened) Qt.quit()
    }
    Timer {
        interval: 300
        running: true
        onTriggered: deck.open("{}")
    }
}
''')
        env = dict(os.environ)
        if args.transport == "shm":
            env["QS_DISABLE_DMABUF"] = "1"
        else:
            env.pop("QS_DISABLE_DMABUF", None)
        print("Window Deck diagnostic: " + args.transport + ". Esc closes this isolated selector.", flush=True)
        print("Your installed plugin and shell configuration are unchanged.", flush=True)
        return subprocess.run(["quickshell", "-p", str(stage / "shell.qml")], env=env).returncode


if __name__ == "__main__":
    raise SystemExit(main())
