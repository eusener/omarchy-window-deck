#!/usr/bin/env python3
"""Install or remove Window Deck without overwriting unrelated configuration."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import stat
import subprocess
import tempfile
import uuid

PLUGIN_ID = "eusener.window-deck"
MARKER = ".window-deck-owned.json"
BEGIN = "-- window-deck: begin"
END = "-- window-deck: end"
BLOCK = re.compile(r"(?m)^-- window-deck: begin\n.*?^-- window-deck: end\n?", re.S)


class InstallError(Exception):
    pass


def check_path(path):
    # Refuse symlinked ancestors too: the caller should choose the real config root.
    for part in (path, *path.parents):
        if part.is_symlink():
            raise InstallError(f"Symlinked path is not managed automatically: {part}")


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary = tempfile.mkstemp(prefix=".window-deck-", dir=path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def paths(config_home):
    config = Path(config_home).absolute()
    shell = config / "omarchy/shell.json"
    bindings = config / "hypr/bindings.lua"
    plugin = config / "omarchy/plugins" / PLUGIN_ID
    for path in (shell, bindings, plugin):
        check_path(path)
    return shell, bindings, plugin


def read_config(shell, bindings):
    if not shell.is_file() or not bindings.is_file():
        raise InstallError("Expected existing Omarchy shell.json and Hyprland bindings.lua")
    try:
        original_shell = shell.read_text(encoding="utf-8")
        config = json.loads(original_shell)
        if not isinstance(config, dict) or not isinstance(config.get("bar", {}).get("layout"), dict):
            raise ValueError("Missing bar layout")
        layout = config["bar"]["layout"]
        if not isinstance(layout.get("left"), list) or not isinstance(config.get("plugins", []), list):
            raise ValueError("Invalid bar or plugin entries")
    except (ValueError, TypeError, AttributeError) as exc:
        raise InstallError("Invalid shell configuration; nothing changed") from exc
    return config, original_shell, bindings.read_text(encoding="utf-8")


def marker_for(plugin):
    if not plugin.exists():
        return None
    if (plugin / '.git').exists():
        raise InstallError('Git-managed plugin: use omarchy plugin update/remove eusener.window-deck; this copy installer will not replace the checkout')
    try:
        marker = json.loads((plugin / MARKER).read_text(encoding="utf-8"))
        if marker.get("id") != PLUGIN_ID:
            raise ValueError("Unknown owner")
        return marker
    except (OSError, ValueError, AttributeError) as exc:
        raise InstallError(f"Existing directory is not owned by this installer: {plugin}") from exc


def binding_block(plugin):
    minimize = shlex.join(["python3", str(plugin / "backend.py"), "minimize"])
    summon = "omarchy-shell shell summon eusener.window-deck '{}'"
    return (BEGIN + "\n"
            '-- Super+Tab replaces Next workspace; Super+M minimizes in either layout.\n'
            f'o.rebind("SUPER + TAB", "Window Deck", {json.dumps(summon, ensure_ascii=False)})\n'
            f'o.rebind("SUPER + M", "Minimizar janela", {json.dumps(minimize, ensure_ascii=False)})\n'
            + END + "\n")


def validate_block(text, marker):
    matches = list(BLOCK.finditer(text))
    has_marker = BEGIN in text or END in text
    if len(matches) > 1 or (has_marker and not matches):
        raise InstallError("Malformed or duplicate Window Deck binding block")
    if matches and (not marker or matches[0].group() != marker.get("binding_block")):
        raise InstallError("Window Deck binding block was edited; preserve or remove it manually before continuing")
    return matches[0] if matches else None


def backup_files(shell, bindings):
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    backup = shell.parent / "backups" / ("window-deck-" + stamp + "-" + uuid.uuid4().hex[:8])
    check_path(backup)
    backup.mkdir(parents=True, mode=0o700)
    shutil.copy2(shell, backup / "shell.json")
    shutil.copy2(bindings, backup / "bindings.lua")
    return backup


def is_our_entry(entry):
    return isinstance(entry, dict) and entry.get("id") == PLUGIN_ID


def copy_runtime(source, stage):
    source = Path(source)
    files = list(source.glob("*.qml")) + list(source.glob("*.js")) + list(source.glob("*.lua"))
    files += [source / name for name in ("manifest.json", "qmldir", "backend.py", "install.py")]
    for optional in ("README.md", "LICENSE"):
        if (source / optional).is_file():
            files.append(source / optional)
    for item in files:
        shutil.copy2(item, stage / item.name)
    shutil.copytree(source / "i18n", stage / "i18n")
    build_runtime(stage)


def build_runtime(stage):
    """Use immutable entry-point URLs; QML engines retain same-path singletons."""
    manifest = json.loads((stage / "manifest.json").read_text(encoding="utf-8"))
    files = list(stage.glob("*.qml")) + list(stage.glob("*.js")) + list(stage.glob("*.lua"))
    files += [stage / "backend.py", stage / "qmldir"]
    files += list((stage / "i18n").glob("*.json"))
    digest = hashlib.sha256(manifest["version"].encode())
    for file in sorted(files):
        digest.update(file.relative_to(stage).as_posix().encode() + b"\0" + file.read_bytes())
    version = re.sub(r"[^A-Za-z0-9_]", "_", manifest["version"])
    relative = Path("runtime") / ("v_" + version + "_" + digest.hexdigest()[:12])
    for file in files:
        target = stage / relative / file.relative_to(stage)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(file, target)
    manifest["entryPoints"] = {kind: (relative / Path(path).name).as_posix()
                               for kind, path in manifest["entryPoints"].items()}
    (stage / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def install(config_home, source):
    shell, bindings, plugin = paths(config_home)
    config, old_shell, old_bindings = read_config(shell, bindings)
    previous = marker_for(plugin)
    match = validate_block(old_bindings, previous)
    layout = config["bar"]["layout"]
    bar_present = any(is_our_entry(e) for section in layout.values() if isinstance(section, list) for e in section)
    plugin_present = any(is_our_entry(e) for e in config.get("plugins", []))
    disabled = config.get("disabledPlugins", [])
    if not isinstance(disabled, list):
        raise InstallError("Invalid disabledPlugins configuration")
    marker = previous or {"id": PLUGIN_ID, "added_bar": not bar_present, "added_plugin": not plugin_present, "was_disabled": PLUGIN_ID in disabled}
    if not bar_present:
        left = layout["left"]
        position = next((i + 1 for i, e in enumerate(left) if isinstance(e, dict) and str(e.get("id", "")).endswith(".workspaces")), None)
        if position is None:
            raise InstallError("Workspace widget was not found in the left bar section")
        left.insert(position, {"id": PLUGIN_ID})
    if not plugin_present:
        config.setdefault("plugins", []).append({"id": PLUGIN_ID})
    if PLUGIN_ID in disabled:
        config["disabledPlugins"] = [entry for entry in disabled if entry != PLUGIN_ID]
    block = binding_block(plugin)
    marker["binding_block"] = block
    new_bindings = old_bindings[:match.start()] + block + old_bindings[match.end():] if match else old_bindings + ("" if old_bindings.endswith("\n") else "\n") + block
    new_shell = json.dumps(config, ensure_ascii=False, indent=2) + "\n"
    backup = backup_files(shell, bindings)
    plugin.parent.mkdir(parents=True, exist_ok=True)
    stage = Path(tempfile.mkdtemp(prefix=".window-deck-stage-", dir=plugin.parent))
    replaced = False
    published = False
    try:
        copy_runtime(source, stage)
        (stage / MARKER).write_text(json.dumps(marker, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        if plugin.exists():
            os.replace(plugin, backup / "plugin")
            replaced = True
        os.replace(stage, plugin)
        published = True
        atomic_write(shell, new_shell)
        atomic_write(bindings, new_bindings)
    except BaseException:
        # Restore with copies, so rollback does not depend on the failed writer.
        shutil.copy2(backup / "shell.json", shell)
        shutil.copy2(backup / "bindings.lua", bindings)
        if published:
            shutil.rmtree(plugin)
        if replaced:
            os.replace(backup / "plugin", plugin)
        raise
    finally:
        if stage.exists():
            shutil.rmtree(stage)
    return backup


def uninstall(config_home):
    shell, bindings, plugin = paths(config_home)
    marker = marker_for(plugin)
    if marker is None:
        raise InstallError("Window Deck is not installed by this installer")
    config, old_shell, old_bindings = read_config(shell, bindings)
    match = validate_block(old_bindings, marker)
    if marker.get("added_bar"):
        for section, entries in config["bar"]["layout"].items():
            if isinstance(entries, list):
                config["bar"]["layout"][section] = [entry for entry in entries if not is_our_entry(entry)]
    if marker.get("added_plugin"):
        config["plugins"] = [entry for entry in config.get("plugins", []) if not is_our_entry(entry)]
    if marker.get("was_disabled") and PLUGIN_ID not in config.get("disabledPlugins", []):
        config.setdefault("disabledPlugins", []).append(PLUGIN_ID)
    new_bindings = old_bindings[:match.start()] + old_bindings[match.end():] if match else old_bindings
    backup = backup_files(shell, bindings)
    try:
        atomic_write(shell, json.dumps(config, ensure_ascii=False, indent=2) + "\n")
        atomic_write(bindings, new_bindings)
        # Keep the removed runtime in the backup for recovery.
        os.replace(plugin, backup / "plugin")
    except BaseException:
        shutil.copy2(backup / "shell.json", shell)
        shutil.copy2(backup / "bindings.lua", bindings)
        raise
    return backup


def reload_session():
    problems = []
    for command in (["hyprctl", "reload"], ["hyprctl", "configerrors"], ["omarchy-shell", "shell", "rescanPlugins"]):
        try:
            result = subprocess.run(command, capture_output=True, text=True, timeout=10, check=False)
            output = result.stdout.strip()
            if result.returncode or (command[-1] == "configerrors" and output and output != "ok"):
                problems.append(shlex.join(command) + ": " + (result.stderr.strip() or output or "failed"))
        except (OSError, subprocess.TimeoutExpired) as exc:
            problems.append(shlex.join(command) + ": " + str(exc))
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config-home", type=Path, default=Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")))
    parser.add_argument("--uninstall", action="store_true")
    parser.add_argument("--no-reload", action="store_true", help="Prepare config without contacting the live desktop")
    args = parser.parse_args()
    try:
        backup = uninstall(args.config_home) if args.uninstall else install(args.config_home, Path(__file__).resolve().parent)
    except (InstallError, OSError) as exc:
        parser.exit(1, f"Window Deck: {exc}\n")
    print(("Removed" if args.uninstall else "Installed") + f" Window Deck. Backup: {backup}")
    if not args.no_reload:
        problems = reload_session()
        if problems:
            print("Files are prepared, but desktop activation needs attention:\n" + "\n".join(problems))
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
