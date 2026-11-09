import importlib.util
import pathlib
import json
import subprocess
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("backend", ROOT / "backend.py")
backend = importlib.util.module_from_spec(spec)
spec.loader.exec_module(backend)


def client(address="0xabc", workspace=2, tags=None, **extra):
    name = extra.pop("workspace_name", "special:minimized" if workspace < 0 else str(workspace))
    return {"address": address, "workspace": {"id": workspace, "name": name},
            "tags": tags or [], "class": "foot", "title": "Terminal", "mapped": True, **extra}


class ModelTests(unittest.TestCase):
    def test_normal_and_minimized_origins_are_distinct(self):
        records = backend.normalize_clients([client(), client("0xdef", -99, ["omarchy-minimized-from-12"])])
        self.assertEqual([r["origin"] for r in records], [2, 12])
        self.assertEqual([r["minimized"] for r in records], [False, True])

    def test_ambiguous_invalid_or_missing_tags_never_guess(self):
        for tags in ([], ["omarchy-minimized-from-0"], ["omarchy-minimized-from-2", "omarchy-minimized-from-3"], ["omarchy-minimized-from-2oops"], ["omarchy-minimized-from-2", "omarchy-minimized-from-03"]):
            with self.subTest(tags=tags):
                self.assertIsNone(backend.normalize_clients([client(workspace=-99, tags=tags)])[0]["origin"])

    def test_special_workspace_and_unmapped_clients_are_not_normal_windows(self):
        rows = backend.normalize_clients([client(workspace=-1, workspace_name="special:scratchpad"), client("0xdef", mapped=False)])
        self.assertEqual(len(rows), 1)
        self.assertIsNone(rows[0]["origin"])
        self.assertFalse(rows[0]["minimized"])

    def test_invalid_addresses_are_omitted_and_titles_remain_plain_data(self):
        rows = backend.normalize_clients([client("bad; exec"), client(title='<img src="https://invalid/">')])
        self.assertEqual(len(rows), 1)
        self.assertTrue(rows[0]["title"].startswith("<img"))


def lua_value(value):
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return str(value).lower()
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "{" + ",".join(lua_value(v) for v in value) + "}"
    return "{" + ",".join("[" + lua_value(k) + "]=" + lua_value(v) for k, v in value.items()) + "}"


class ActionTests(unittest.TestCase):
    """Run the actual compositor-side chunk in Lua with a small HL simulator.

    The snapshot and live state deliberately differ in race regressions.
    This proves guards execute when mutations execute, not merely in Python.
    """

    def setUp(self):
        self.snapshot = client()
        self.live = client()
        self.effects = []
        self.calls = []
        self.fail_kind = ""
        self.active_workspace = 2
        self.live_workspace = 2
        self.focused = None
        self.mock_run = patch.object(backend, "run", side_effect=self.ipc).start()
        self.addCleanup(patch.stopall)

    def ipc(self, arguments):
        self.calls.append(arguments)
        if arguments[:2] == ["hyprctl", "-j"]:
            if arguments[2] == "activeworkspace":
                return json.dumps({"id": self.active_workspace})
            return json.dumps(self.snapshot if arguments[2] == "activewindow" or isinstance(self.snapshot, list) else ([self.snapshot] if self.snapshot else []))
        chunk = arguments[2] if arguments[1] == "eval" else "return hl.dispatch(" + arguments[2] + ")"
        lua = f'''
local live = {lua_value(self.live)}
local effects = {{}}
local function descriptor(kind)
    return function(args) return {{kind=kind, args=args}} end
end
hl = {{ dsp = {{ window = {{tag=descriptor("tag"),move=descriptor("move"),alter_zorder=descriptor("raise"),fullscreen=descriptor("fullscreen")}}, focus=descriptor("focus") }} }}
function hl.get_window(selector) return live end
function hl.get_active_workspace() return {{id={lua_value(self.live_workspace)}}} end
function hl.get_active_window() return {lua_value(self.focused)} end
function hl.dispatch(operation)
    if operation.kind == {lua_value(self.fail_kind)} then return {{ok=false,error="rejected"}} end
    local args = operation.args
    local target = args.window
    if type(target) == "table" then target = "address:" .. target.address end
    local effect = operation.kind .. ":" .. tostring(args.tag or args.workspace or target or "")
    if operation.kind == "fullscreen" then effect = effect .. ":" .. tostring(args.mode) .. ":" .. tostring(args.action) end
    effects[#effects+1] = effect
    return {{ok=true}}
end
local execute = assert(load({lua_value(chunk)}))
local ok, value = pcall(execute)
for _,effect in ipairs(effects) do io.stderr:write(effect .. "\\n") end
if ok and not (type(value) == "table" and value.ok == false) then print("ok") else print("error: transaction rejected") end
'''
        result = subprocess.run(["lua", "-"], input=lua, capture_output=True, text=True, check=True)
        self.effects.extend(result.stderr.splitlines())
        return result.stdout

    def test_minimize_works_without_floating_mode_and_returns_focus(self):
        self.snapshot = self.live = client(tags=["omarchy-minimized-from-9", "unrelated"])
        backend.minimize()
        self.assertIn("tag:-omarchy-minimized-from-9", self.effects)
        self.assertIn("tag:+omarchy-minimized-from-2", self.effects)
        self.assertIn("move:special:minimized", self.effects)
        self.assertEqual(self.effects[-1], "focus:2")
        self.assertEqual(sum(c[1] == "eval" for c in self.calls), 1)

    def test_explicit_minimize_repairs_malformed_provenance(self):
        self.snapshot = self.live = client(tags=["omarchy-minimized-from-03", "omarchy-minimized-from-2"])
        backend.minimize()
        self.assertIn("tag:-omarchy-minimized-from-03", self.effects)
        self.assertIn("tag:+omarchy-minimized-from-2", self.effects)

    def test_floating_window_is_raised(self):
        self.snapshot = self.live = client(floating=True)
        backend.restore("0xabc", 2)
        self.assertIn("raise:address:0xabc", self.effects)

    def test_restore_validates_origin_and_restores_to_it(self):
        self.snapshot = self.live = client(workspace=-99, tags=["omarchy-minimized-from-12"])
        backend.restore("0xabc", 12)
        self.assertIn("move:12", self.effects)
        self.assertIn("focus:address:0xabc", self.effects)

    def test_stale_restore_never_moves_window_from_another_workspace(self):
        self.snapshot = client(workspace=3)
        with self.assertRaises(backend.DeckError):
            backend.restore("0xabc", 2)
        self.assertEqual(self.effects, [])

    def test_restore_rechecks_after_snapshot_when_another_tool_moves_window(self):
        self.snapshot = client(workspace=-99, tags=["omarchy-minimized-from-2"])
        self.live = client(workspace=3)
        with self.assertRaises(backend.DeckError):
            backend.restore("0xabc", 2)
        self.assertEqual(self.effects, [])

    def test_minimize_rechecks_after_snapshot_when_window_moves(self):
        self.snapshot = client(workspace=2)
        self.live = client(workspace=3)
        with self.assertRaises(backend.DeckError):
            backend.minimize()
        self.assertEqual(self.effects, [])

    def test_restore_rechecks_live_tags_and_existence(self):
        self.snapshot = client(workspace=-99, tags=["omarchy-minimized-from-2"])
        for live in (None, client(workspace=-99, tags=["omarchy-minimized-from-3"]), client(workspace=-99, tags=["omarchy-minimized-from-2", "omarchy-minimized-from-03"])):
            self.live = live
            with self.subTest(live=live), self.assertRaises(backend.DeckError):
                backend.restore("0xabc", 2)
        self.assertEqual(self.effects, [])

    def test_missing_or_wrong_origin_window_is_not_restored(self):
        for record in (None, client(workspace=-99), client(workspace=-99, tags=["omarchy-minimized-from-3"])):
            self.snapshot = record
            with self.assertRaises(backend.DeckError):
                backend.restore("0xabc", 2)
        self.assertEqual(self.effects, [])

    def test_focusing_normal_window_does_not_move_it(self):
        backend.restore("0xabc", 2)
        self.assertFalse(any(e.startswith("move:") for e in self.effects))

    def test_untrusted_address_or_workspace_rejected_before_ipc(self):
        for address, workspace in (("0xabc;evil", 2), ("0xabc", -1), ("0xabc", "2;evil")):
            with self.subTest(address=address, workspace=workspace), self.assertRaises(backend.DeckError):
                backend.restore(address, workspace)
        self.assertEqual(self.calls, [])

    def test_tag_failure_stops_before_moving(self):
        self.fail_kind = "tag"
        with self.assertRaises(backend.DeckError):
            backend.minimize()
        self.assertEqual(self.effects, [])

    def test_restore_last_chooses_recent_minimized_window_in_active_workspace(self):
        self.active_workspace = self.live_workspace = 12
        self.snapshot = [
            client("0xaaa", -99, ["omarchy-minimized-from-2"], focusHistoryID=0),
            client("0xbbb", -99, ["omarchy-minimized-from-12"], focusHistoryID=6),
            client("0xccc", -99, ["omarchy-minimized-from-12"], focusHistoryID=2),
            client("0xddd", 12, focusHistoryID=1),
        ]
        self.live = self.snapshot[2]
        self.assertEqual(backend.main(["restore-last"]), 0)
        self.assertEqual(self.effects, ["move:12", "focus:address:0xccc"])

    def test_restore_last_is_no_op_without_eligible_minimized_window(self):
        self.snapshot = [client(), client("0xaaa", -99, ["omarchy-minimized-from-12"]),
                         client("0xbbb", -99, ["omarchy-minimized-from-2", "omarchy-minimized-from-03"])]
        self.assertEqual(backend.main(["restore-last"]), 0)
        self.assertEqual(self.effects, [])

    def test_restore_shortcut_unmaximizes_focused_window_without_minimized_windows(self):
        self.snapshot = []
        self.focused = client(fullscreen=1)
        backend.restore_last()
        self.assertEqual(self.effects, ["fullscreen:address:0xabc:maximized:unset"])

    def test_restore_shortcut_prioritizes_unmaximizing_over_minimized_windows(self):
        self.snapshot = self.live = client(workspace=-99, tags=["omarchy-minimized-from-2"])
        self.focused = client("0xdef", fullscreen=1)
        backend.restore_last()
        self.assertEqual(self.effects, ["fullscreen:address:0xdef:maximized:unset"])

    def test_restore_shortcut_never_unmaximizes_another_workspace_or_unmapped_window(self):
        self.snapshot = []
        for focused in (client(workspace=12, fullscreen=1), client(fullscreen=1, mapped=False),
                        client(fullscreen=2), None):
            self.focused = focused
            with self.subTest(focused=focused):
                backend.restore_last()
        self.assertEqual(self.effects, [])

    def test_restore_shortcut_reports_rejected_unmaximize(self):
        self.snapshot = []
        self.focused = client(fullscreen=1)
        self.fail_kind = "fullscreen"
        with self.assertRaises(backend.DeckError):
            backend.restore_last()
        self.assertEqual(self.effects, [])

    def test_restore_last_rechecks_active_workspace_before_moving(self):
        self.snapshot = self.live = client(workspace=-99, tags=["omarchy-minimized-from-2"])
        self.live_workspace = 12
        with self.assertRaises(backend.DeckError):
            backend.restore_last()
        self.assertEqual(self.effects, [])

    def test_restore_last_rejects_changed_origin(self):
        self.snapshot = client(workspace=-99, tags=["omarchy-minimized-from-2"])
        self.live = client(workspace=-99, tags=["omarchy-minimized-from-12"])
        with self.assertRaises(backend.DeckError):
            backend.restore_last()
        self.assertEqual(self.effects, [])

    def test_restore_last_uses_valid_focus_history_before_unknown_values(self):
        self.snapshot = [client("0xaaa", -99, ["omarchy-minimized-from-2"], focusHistoryID=-1),
                         client("0xbbb", -99, ["omarchy-minimized-from-2"], focusHistoryID="0"),
                         client("0xccc", -99, ["omarchy-minimized-from-2"], focusHistoryID=3)]
        self.live = self.snapshot[2]
        backend.restore_last()
        self.assertEqual(self.effects[-1], "focus:address:0xccc")


if __name__ == "__main__":
    unittest.main()
