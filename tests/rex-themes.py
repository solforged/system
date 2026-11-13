"""Rex theme updates without touching the running app or user preferences."""
import importlib.util
import json
import plistlib
import tempfile
import unittest
from pathlib import Path
from subprocess import CompletedProcess
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "rex_themes", Path(__file__).resolve().parents[1] / "modules/darwin/apps/rex-themes.py"
)
themes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(themes)


class ThemesTest(unittest.TestCase):
    def test_merge_preserves_other_themes_and_is_idempotent(self):
        old = [{"id": "mine"}, {"id": "solforge", "color": "old"}]
        new = [{"id": "solforge", "color": "new"}]
        merged = themes.merge_themes(old, new)
        self.assertEqual(merged, [old[0], new[0]])
        self.assertEqual(themes.merge_themes(merged, new), merged)

    def test_unchanged_preferences_are_not_written(self):
        data = [{"id": "solforge"}]
        exported = plistlib.dumps({"Workspace.customThemes": json.dumps(data).encode()})
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "themes.json"
            source.write_text(json.dumps(data))
            with patch.object(themes.subprocess, "run", return_value=CompletedProcess([], 0, exported, b"")) as run:
                themes.main(source)
                run.assert_called_once()

    def test_writes_data_without_replacing_unrelated_preferences(self):
        exported = plistlib.dumps({"Workspace.customThemes": b'[{"id":"mine"}]', "unrelated": True})
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "themes.json"
            source.write_text('[{"id":"solforge"}]')
            with patch.object(themes.subprocess, "run", return_value=CompletedProcess([], 0, exported, b"")) as run:
                themes.main(source)
                args = run.call_args.args[0]
                self.assertEqual(args[:5], ["/usr/bin/defaults", "write", "com.superlogical.rex", "Workspace.customThemes", "-data"])
                self.assertEqual(json.loads(bytes.fromhex(args[5])), [{"id": "mine"}, {"id": "solforge"}])


if __name__ == "__main__":
    unittest.main()
