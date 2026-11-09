#!/usr/bin/env python3
"""Validated window operations for Window Deck. No daemon or disk state."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys

ADDRESS = re.compile(r"0x[0-9a-fA-F]{1,32}\Z")
ORIGIN = re.compile(r"omarchy-minimized-from-([1-9][0-9]{0,5})\Z")
MINIMIZED = "special:minimized"


class DeckError(Exception):
    pass


def run(arguments):
    try:
        result = subprocess.run(arguments, capture_output=True, text=True, timeout=4, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise DeckError("Compositor unavailable") from exc
    if result.returncode != 0 or len(result.stdout) > 8 * 1024 * 1024:
        raise DeckError("Compositor request failed")
    return result.stdout


def read_json(subject):
    try:
        value = json.loads(run(["hyprctl", "-j", subject]))
    except (ValueError, TypeError) as exc:
        raise DeckError("Invalid compositor response") from exc
    if not isinstance(value, list if subject == "clients" else dict):
        raise DeckError("Invalid compositor response")
    return value


def transaction(action, address, workspace, minimized=False):
    library = Path(__file__).with_name("operations.lua").read_text(encoding="utf-8")
    chunk = ("return (function()\nlocal execute = (function()\n" + library
             + "\nend)()\nexecute(" + json.dumps(action) + ", " + json.dumps(address)
             + ", " + str(workspace) + ", " + str(minimized).lower() + ")\nend)()")
    result = run(["hyprctl", "eval", chunk]).strip()
    if result != "ok":
        raise DeckError("Window operation rejected by compositor")


def valid_address(value):
    if not isinstance(value, str) or not ADDRESS.fullmatch(value):
        raise DeckError("Invalid window address")
    return value.lower()


def valid_workspace(value):
    if isinstance(value, bool) or not re.fullmatch(r"[1-9][0-9]{0,5}", str(value)):
        raise DeckError("Invalid workspace")
    return int(value)


def normalize_clients(clients):
    if not isinstance(clients, list):
        raise DeckError("Invalid client list")
    result = []
    for raw in clients[:10000]:
        if not isinstance(raw, dict) or raw.get("mapped") is False:
            continue
        try:
            address = valid_address(raw.get("address"))
        except DeckError:
            continue
        workspace = raw.get("workspace") or {}
        workspace_id = workspace.get("id", -1)
        minimized = workspace.get("name") == MINIMIZED
        tags = raw.get("tags") or []
        provenance = [tag for tag in tags if isinstance(tag, str) and tag.startswith("omarchy-minimized-from-")]
        origins = {int(match.group(1)) for tag in provenance if (match := ORIGIN.fullmatch(tag))}
        valid = all(ORIGIN.fullmatch(tag) for tag in provenance)
        origin = next(iter(origins)) if minimized and valid and len(origins) == 1 else None
        if not minimized and isinstance(workspace_id, int) and workspace_id > 0:
            origin = workspace_id
        result.append({
            "address": address,
            "title": str(raw.get("title") or raw.get("initialTitle") or "")[:4096],
            "appId": str(raw.get("class") or raw.get("initialClass") or "")[:512],
            "workspaceId": workspace_id,
            "origin": origin,
            "minimized": minimized,
            "focused": raw.get("focusHistoryID") == 0,
        })
    return result


def minimize(address=None):
    if address is None:
        raw = read_json("activewindow")
    else:
        address = valid_address(address)
        raw = next((c for c in read_json("clients") if c.get("address", "").lower() == address), None)
    if not raw:
        raise DeckError("Window no longer exists")
    address = valid_address(raw.get("address"))
    workspace = valid_workspace((raw.get("workspace") or {}).get("id"))
    transaction("minimize", address, workspace)


def restore(address, expected_workspace):
    address = valid_address(address)
    workspace = valid_workspace(expected_workspace)
    record = next((c for c in normalize_clients(read_json("clients")) if c["address"] == address), None)
    if not record or record["origin"] != workspace:
        raise DeckError("Window moved or no longer exists")
    transaction("restore", address, workspace, record["minimized"])


def restore_last():
    workspace = valid_workspace(read_json("activeworkspace").get("id"))
    clients = read_json("clients")[:10000]

    def focus_order(raw):
        value = raw.get("focusHistoryID") if isinstance(raw, dict) else None
        return value if type(value) is int and value >= 0 else float("inf")

    # The compositor's focus history survives separate shortcut invocations;
    # no daemon, timestamps or user files are needed for the restore order.
    for record in normalize_clients(sorted(clients, key=focus_order)):
        if record["minimized"] and record["origin"] == workspace:
            transaction("restore-last", record["address"], workspace, True)
            return


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="action", required=True)
    commands.add_parser("snapshot")
    commands.add_parser("restore-last")
    mini = commands.add_parser("minimize")
    mini.add_argument("address", nargs="?")
    show = commands.add_parser("restore")
    show.add_argument("address")
    show.add_argument("workspace")
    args = parser.parse_args(argv)
    try:
        if args.action == "snapshot":
            payload = {"clients": normalize_clients(read_json("clients"))}
        else:
            if args.action == "minimize":
                minimize(args.address)
            elif args.action == "restore-last":
                restore_last()
            else:
                restore(args.address, args.workspace)
            payload = {"ok": True}
    except DeckError as exc:
        print(json.dumps({"error": str(exc)}))
        return 1
    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
