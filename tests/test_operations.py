import json
import pathlib
import subprocess
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
OPERATIONS = ROOT / "operations.lua"


def window(address="0xabc", workspace=2, tags=None, **extra):
    name = extra.pop("workspace_name", "special:minimized" if workspace < 0 else str(workspace))
    return {"address": address, "workspace": {"id": workspace, "name": name},
            "tags": tags or [], "class": "foot", "title": "Terminal", "mapped": True, **extra}


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


class OperationTests(unittest.TestCase):
    """Run the real operations.lua against a small simulator of Hyprland's hl API.

    Guards and mutations execute in the same Lua call, as they do inside the
    compositor, so every rejection must leave the effect list empty.
    """

    def setUp(self):
        self.windows = [window()]
        self.focused = None
        self.active_workspace = 2
        self.fail_kind = ""
        self.focus_under_fullscreen = 1

    def run_lua(self, call):
        lua = f'''
local windows = {lua_value(self.windows)}
local effects = {{}}
local function descriptor(kind)
    return function(args) return {{kind=kind, args=args}} end
end
hl = {{ dsp = {{ window = {{tag=descriptor("tag"),move=descriptor("move"),alter_zorder=descriptor("raise"),fullscreen=descriptor("fullscreen")}}, focus=descriptor("focus") }} }}
function hl.get_windows() return windows end
function hl.get_window(selector)
    for _, w in ipairs(windows) do if "address:" .. w.address == selector then return w end end
end
function hl.get_active_workspace() return {{id={lua_value(self.active_workspace)}}} end
function hl.get_active_window() return {lua_value(self.focused)} end
function hl.get_config(name)
    assert(name == "misc:on_focus_under_fullscreen")
    return {lua_value(self.focus_under_fullscreen)}
end
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
local deck = dofile({lua_value(str(OPERATIONS))})
local ok, value = pcall(function() return {call} end)
for _, effect in ipairs(effects) do io.stderr:write(effect .. "\\n") end
io.write(tostring(ok and value ~= false))
'''
        result = subprocess.run(["lua", "-"], input=lua, capture_output=True, text=True, check=True)
        return result.stdout == "true", result.stderr.splitlines()

    def restore(self, address="0xabc", workspace=2):
        return self.run_lua(f"deck.execute('restore', {lua_value(address)}, {lua_value(workspace)})")

    # Super+M

    def test_minimize_works_without_floating_mode_and_returns_focus(self):
        self.focused = self.windows[0] = window(tags=["omarchy-minimized-from-9", "unrelated"])
        ok, effects = self.run_lua("deck.minimize()")
        self.assertTrue(ok)
        self.assertIn("tag:-omarchy-minimized-from-9", effects)
        self.assertIn("tag:+omarchy-minimized-from-2", effects)
        self.assertIn("move:special:minimized", effects)
        self.assertNotIn("tag:-unrelated", effects)
        self.assertEqual(effects[-1], "focus:2")

    def test_explicit_minimize_repairs_malformed_provenance(self):
        self.focused = self.windows[0] = window(tags=["omarchy-minimized-from-03", "omarchy-minimized-from-2"])
        ok, effects = self.run_lua("deck.minimize()")
        self.assertTrue(ok)
        self.assertIn("tag:-omarchy-minimized-from-03", effects)
        self.assertIn("tag:+omarchy-minimized-from-2", effects)

    def test_minimize_ignores_special_unmapped_or_missing_windows(self):
        for focused in (None, window(workspace=-99), window(workspace=-1, workspace_name="special:scratchpad"), window(mapped=False)):
            self.focused = focused
            self.windows = [focused or window()]
            with self.subTest(focused=focused):
                ok, effects = self.run_lua("deck.minimize()")
                self.assertFalse(ok)
                self.assertEqual(effects, [])

    def test_minimize_rechecks_workspace_of_live_window(self):
        self.windows = [window(workspace=3)]
        ok, effects = self.run_lua("deck.execute('minimize', '0xabc', 2)")
        self.assertFalse(ok)
        self.assertEqual(effects, [])

    def test_tag_failure_stops_before_moving(self):
        self.focused = self.windows[0]
        self.fail_kind = "tag"
        ok, effects = self.run_lua("deck.minimize()")
        self.assertFalse(ok)
        self.assertEqual(effects, [])

    # Overlay and bar restore

    def test_floating_window_is_raised(self):
        self.windows = [window(floating=True)]
        ok, effects = self.restore()
        self.assertTrue(ok)
        self.assertIn("raise:address:0xabc", effects)

    def test_restore_validates_origin_and_restores_to_it(self):
        self.windows = [window(workspace=-99, tags=["omarchy-minimized-from-12"])]
        ok, effects = self.restore(workspace=12)
        self.assertTrue(ok)
        self.assertEqual(effects, ["move:12", "focus:address:0xabc"])

    def test_focusing_normal_window_does_not_move_it(self):
        ok, effects = self.restore()
        self.assertTrue(ok)
        self.assertEqual(effects, ["focus:address:0xabc"])

    def test_restore_never_moves_window_from_another_workspace(self):
        self.windows = [window(workspace=3)]
        ok, effects = self.restore()
        self.assertFalse(ok)
        self.assertEqual(effects, [])

    def test_restore_rechecks_live_tags_and_existence(self):
        for live in ([], [window(workspace=-99)], [window(workspace=-99, tags=["omarchy-minimized-from-3"])],
                     [window(workspace=-99, tags=["omarchy-minimized-from-2", "omarchy-minimized-from-03"])],
                     [window(workspace=-99, tags=["omarchy-minimized-from-2", "omarchy-minimized-from-3"])],
                     [window(workspace=-99, tags=["omarchy-minimized-from-2"], mapped=False)]):
            self.windows = live
            with self.subTest(live=live):
                ok, effects = self.restore()
                self.assertFalse(ok)
                self.assertEqual(effects, [])

    def test_untrusted_address_or_workspace_rejected_before_any_effect(self):
        for address, workspace in (("0xabc;evil", 2), ("0xabc", -1), ("0xabc", 2.5), ("0xabc", 1000000), ("", 2)):
            with self.subTest(address=address, workspace=workspace):
                ok, effects = self.restore(address, workspace)
                self.assertFalse(ok)
                self.assertEqual(effects, [])

    def test_observed_state_is_enforced_only_when_passed(self):
        self.windows = [window(workspace=-99, tags=["omarchy-minimized-from-2"])]
        ok, effects = self.run_lua("deck.execute('restore', '0xabc', 2, false)")
        self.assertFalse(ok)
        self.assertEqual(effects, [])

    def test_chosen_window_takes_over_a_maximized_window(self):
        # Reproduces choosing a minimized window in the overlay while another
        # window of the workspace is maximized: it stayed hidden behind it.
        self.windows = [window(workspace=-99, tags=["omarchy-minimized-from-2"]), window("0xdef", fullscreen=1)]
        ok, effects = self.restore()
        self.assertTrue(ok)
        self.assertEqual(effects, ["move:2", "fullscreen:address:0xdef:maximized:unset",
                                   "fullscreen:address:0xabc:maximized:set", "focus:address:0xabc"])

    def test_chosen_tiled_window_takes_over_fullscreen_with_the_same_mode(self):
        self.windows = [window(), window("0xdef", fullscreen=2)]
        ok, effects = self.restore()
        self.assertTrue(ok)
        self.assertEqual(effects, ["fullscreen:address:0xdef:fullscreen:unset",
                                   "fullscreen:address:0xabc:fullscreen:set", "focus:address:0xabc"])

    def test_other_focus_under_fullscreen_settings_only_uncover_the_window(self):
        for setting in (0, 2):
            self.focus_under_fullscreen = setting
            self.windows = [window(workspace=-99, tags=["omarchy-minimized-from-2"]), window("0xdef", fullscreen=1)]
            with self.subTest(setting=setting):
                ok, effects = self.restore()
                self.assertTrue(ok)
                self.assertEqual(effects, ["move:2", "fullscreen:address:0xdef:maximized:unset", "focus:address:0xabc"])

    def test_maximized_windows_elsewhere_or_the_chosen_one_are_left_alone(self):
        self.windows = [window(fullscreen=1), window("0xdef", 3, fullscreen=1), window("0x123", fullscreen=1, mapped=False)]
        ok, effects = self.restore()
        self.assertTrue(ok)
        self.assertEqual(effects, ["focus:address:0xabc"])

    # Super+Ctrl+M

    def test_restore_last_chooses_recent_minimized_window_in_active_workspace(self):
        self.active_workspace = 12
        self.windows = [
            window("0xaaa", -99, ["omarchy-minimized-from-2"], focus_history_id=0),
            window("0xbbb", -99, ["omarchy-minimized-from-12"], focus_history_id=6),
            window("0xccc", -99, ["omarchy-minimized-from-12"], focus_history_id=2),
            window("0xddd", 12, focus_history_id=1),
        ]
        ok, effects = self.run_lua("deck.restore_last()")
        self.assertTrue(ok)
        self.assertEqual(effects, ["move:12", "focus:address:0xccc"])

    def test_restore_last_is_no_op_without_eligible_minimized_window(self):
        self.windows = [window(), window("0xaaa", -99, ["omarchy-minimized-from-12"]),
                        window("0xbbb", -99, ["omarchy-minimized-from-2", "omarchy-minimized-from-03"]),
                        window("0xccc", -99, ["omarchy-minimized-from-2"], mapped=False)]
        ok, effects = self.run_lua("deck.restore_last()")
        self.assertTrue(ok)
        self.assertEqual(effects, [])

    def test_restore_shortcut_unmaximizes_focused_window_without_minimized_windows(self):
        self.windows = []
        self.focused = window(fullscreen=1)
        ok, effects = self.run_lua("deck.restore_last()")
        self.assertTrue(ok)
        self.assertEqual(effects, ["fullscreen:address:0xabc:maximized:unset"])

    def test_restore_shortcut_prioritizes_unmaximizing_over_minimized_windows(self):
        self.windows = [window(workspace=-99, tags=["omarchy-minimized-from-2"])]
        self.focused = window("0xdef", fullscreen=1)
        ok, effects = self.run_lua("deck.restore_last()")
        self.assertTrue(ok)
        self.assertEqual(effects, ["fullscreen:address:0xdef:maximized:unset"])

    def test_restore_shortcut_never_unmaximizes_another_workspace_or_unmapped_window(self):
        self.windows = []
        for focused in (window(workspace=12, fullscreen=1), window(fullscreen=1, mapped=False),
                        window(fullscreen=2), None):
            self.focused = focused
            with self.subTest(focused=focused):
                ok, effects = self.run_lua("deck.restore_last()")
                self.assertTrue(ok)
                self.assertEqual(effects, [])

    def test_restore_shortcut_reports_rejected_unmaximize(self):
        self.windows = []
        self.focused = window(fullscreen=1)
        self.fail_kind = "fullscreen"
        ok, effects = self.run_lua("deck.restore_last()")
        self.assertFalse(ok)
        self.assertEqual(effects, [])

    def test_restore_last_transaction_rechecks_active_workspace(self):
        self.windows = [window(workspace=-99, tags=["omarchy-minimized-from-2"])]
        self.active_workspace = 12
        ok, effects = self.run_lua("deck.execute('restore-last', '0xabc', 2, true)")
        self.assertFalse(ok)
        self.assertEqual(effects, [])

    def test_restore_last_transaction_rejects_changed_origin(self):
        self.windows = [window(workspace=-99, tags=["omarchy-minimized-from-12"])]
        ok, effects = self.run_lua("deck.execute('restore-last', '0xabc', 2, true)")
        self.assertFalse(ok)
        self.assertEqual(effects, [])

    def test_restore_last_uses_valid_focus_history_before_unknown_values(self):
        self.windows = [window("0xaaa", -99, ["omarchy-minimized-from-2"], focus_history_id=-1),
                        window("0xbbb", -99, ["omarchy-minimized-from-2"], focus_history_id="0"),
                        window("0xccc", -99, ["omarchy-minimized-from-2"], focus_history_id=3)]
        ok, effects = self.run_lua("deck.restore_last()")
        self.assertTrue(ok)
        self.assertEqual(effects[-1], "focus:address:0xccc")

    # Bind integration

    def test_shortcut_reloads_the_module_on_each_press(self):
        self.focused = self.windows[0]
        ok, effects = self.run_lua("deck.shortcut('minimize')()")
        self.assertTrue(ok)
        self.assertIn("move:special:minimized", effects)

    def test_shortcut_rejects_unknown_actions(self):
        ok, effects = self.run_lua("deck.shortcut('execute')")
        self.assertFalse(ok)
        self.assertEqual(effects, [])


if __name__ == "__main__":
    unittest.main()
