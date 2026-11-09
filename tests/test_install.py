import importlib.util
import json
import shlex
import shutil
import subprocess
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("installer", ROOT / "install.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="window deck '")
        self.root = Path(self.temp.name)
        self.shell = self.root / "omarchy/shell.json"
        self.bindings = self.root / "hypr/bindings.lua"
        self.shell.parent.mkdir(parents=True)
        self.bindings.parent.mkdir()
        self.original = {"bar": {"layout": {"left": [{"id": "omarchy.menu"}, {"id": "omarchy.workspaces"}], "right": [{"id": "personal.audio"}]}}, "plugins": [{"id": "personal.plugin"}], "custom": 42}
        self.shell.write_text(json.dumps(self.original))
        self.bindings.write_text('-- user bindings\no.bind("SUPER + E", "Editor", "editor")\n')

    def tearDown(self):
        self.temp.cleanup()

    def install(self):
        return installer.install(self.root, ROOT)

    def test_installs_after_workspaces_and_enables_overlay_without_losing_settings(self):
        backup = self.install()
        data = json.loads(self.shell.read_text())
        self.assertEqual([e["id"] for e in data["bar"]["layout"]["left"]], ["omarchy.menu", "omarchy.workspaces", installer.PLUGIN_ID])
        self.assertEqual(data["plugins"], [{"id": "personal.plugin"}, {"id": installer.PLUGIN_ID}])
        self.assertEqual(data["custom"], 42)
        self.assertEqual(json.loads((backup / "shell.json").read_text()), self.original)
        self.assertTrue((self.root / "omarchy/plugins" / installer.PLUGIN_ID / "Deck.qml").is_file())
        self.assertIn('o.rebind("SUPER + TAB"', self.bindings.read_text())
        self.assertIn('o.rebind("SUPER + M"', self.bindings.read_text())

    def test_repeated_install_has_no_duplicate_entries_or_blocks(self):
        self.install()
        first = self.shell.read_text(), self.bindings.read_text()
        self.install()
        self.assertEqual(first, (self.shell.read_text(), self.bindings.read_text()))

    def test_window_shortcuts_dispatch_restore_and_native_maximize(self):
        self.install()
        target = self.root / 'omarchy/plugins' / installer.PLUGIN_ID
        block = installer.BLOCK.search(self.bindings.read_text()).group()
        script = '''
local bindings = {}
o = {rebind = function(keys, label, action) bindings[keys] = action end}
hl = {dsp = {window = {fullscreen = function(options) return options end}}}
''' + block + '''
assert(type(bindings["SUPER + M"]) == "string")
assert(type(bindings["SUPER + CTRL + M"]) == "string")
local maximize = bindings["SUPER + CTRL + SHIFT + M"]
assert(type(maximize) == "table" and maximize.mode == "maximized" and maximize.action == "set")
io.write(bindings["SUPER + CTRL + M"])
'''
        result = subprocess.run(['lua', '-'], input=script, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(shlex.split(result.stdout), ['python3', str(target / 'backend.py'), 'restore-last'])

    def test_ui_updates_get_fresh_entry_urls_for_the_running_qml_engine(self):
        with tempfile.TemporaryDirectory(prefix='deck-source-') as directory:
            source = Path(directory) / 'source'
            shutil.copytree(ROOT, source, ignore=shutil.ignore_patterns('.git', '__pycache__', 'docs'))
            installer.install(self.root, source)
            target = self.root / 'omarchy/plugins' / installer.PLUGIN_ID
            first = json.loads((target / 'manifest.json').read_text())['entryPoints']
            palette = source / 'DeckPalette.qml'
            palette.write_text(palette.read_text() + '\n// Updated UI revision\n')
            installer.install(self.root, source)
            second = json.loads((target / 'manifest.json').read_text())['entryPoints']
            self.assertNotEqual(first['overlay'], second['overlay'])
            self.assertNotEqual(first['barWidget'], second['barWidget'])
            runtime = (target / second['overlay']).parent
            self.assertTrue((runtime / 'DeckPalette.qml').is_file())
            self.assertTrue((runtime / 'qmldir').is_file())
            self.assertTrue((runtime / 'Model.js').is_file())
            self.assertTrue((runtime / 'backend.py').is_file())
            self.assertTrue((runtime / 'operations.lua').is_file())
            self.assertTrue((runtime / 'i18n/pt-BR.json').is_file())
            installer.install(self.root, source)
            third = json.loads((target / 'manifest.json').read_text())['entryPoints']
            self.assertEqual(second, third)

    def test_uninstall_preserves_new_user_changes(self):
        self.install()
        data = json.loads(self.shell.read_text())
        data["custom"] = "changed after install"
        data["plugins"].append({"id": "personal.new"})
        self.shell.write_text(json.dumps(data))
        self.bindings.write_text(self.bindings.read_text() + '-- more personal bindings\n')
        installer.uninstall(self.root)
        data = json.loads(self.shell.read_text())
        self.assertEqual(data["custom"], "changed after install")
        self.assertIn({"id": "personal.new"}, data["plugins"])
        self.assertNotIn(installer.PLUGIN_ID, [x["id"] for x in data["plugins"]])
        self.assertIn('-- more personal bindings', self.bindings.read_text())
        self.assertNotIn('-- window-deck: begin', self.bindings.read_text())

    def test_unowned_directory_is_never_overwritten(self):
        target = self.root / "omarchy/plugins" / installer.PLUGIN_ID
        target.mkdir(parents=True)
        (target / "personal.txt").write_text("keep me")
        with self.assertRaises(installer.InstallError):
            self.install()
        self.assertEqual((target / "personal.txt").read_text(), "keep me")
        self.assertEqual(json.loads(self.shell.read_text()), self.original)

    def test_legacy_installer_never_replaces_a_git_managed_checkout(self):
        self.install()
        target = self.root / 'omarchy/plugins' / installer.PLUGIN_ID
        (target / '.git').mkdir()
        (target / '.git/keep').write_text('git checkout metadata')
        before = self.shell.read_text(), self.bindings.read_text()
        for operation in (self.install, lambda: installer.uninstall(self.root)):
            with self.subTest(operation=operation), self.assertRaises(installer.InstallError):
                operation()
            self.assertEqual((target / '.git/keep').read_text(), 'git checkout metadata')
            self.assertEqual(before, (self.shell.read_text(), self.bindings.read_text()))

    def test_user_edited_managed_block_stops_uninstall_before_changes(self):
        self.install()
        self.bindings.write_text(self.bindings.read_text().replace('"Window Deck"', '"My Deck"'))
        before = self.shell.read_text(), self.bindings.read_text()
        with self.assertRaises(installer.InstallError):
            installer.uninstall(self.root)
        self.assertEqual(before, (self.shell.read_text(), self.bindings.read_text()))

    def test_preexisting_enablement_entries_survive_uninstall(self):
        data = self.original
        data["plugins"].append({"id": installer.PLUGIN_ID, "personalSetting": True})
        self.shell.write_text(json.dumps(data))
        self.install()
        installer.uninstall(self.root)
        self.assertIn({"id": installer.PLUGIN_ID, "personalSetting": True}, json.loads(self.shell.read_text())["plugins"])

    def test_symlinked_target_is_rejected(self):
        other = self.root / "other"
        other.mkdir()
        self.shell.unlink()
        self.shell.symlink_to(other / "shell.json")
        with self.assertRaises(installer.InstallError):
            self.install()

    def test_partial_configuration_write_rolls_back_plugin_and_files(self):
        original_write = installer.atomic_write
        count = 0

        def fail_second(path, content):
            nonlocal count
            count += 1
            if count == 2:
                raise OSError("simulated disk error")
            return original_write(path, content)

        before = self.shell.read_text(), self.bindings.read_text()
        with patch.object(installer, "atomic_write", side_effect=fail_second), self.assertRaises(OSError):
            self.install()
        self.assertEqual(before, (self.shell.read_text(), self.bindings.read_text()))
        self.assertFalse((self.root / "omarchy/plugins" / installer.PLUGIN_ID).exists())


if __name__ == "__main__":
    unittest.main()
