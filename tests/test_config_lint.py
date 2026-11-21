"""Config lint for aerospace.toml and the launchd plists (omarchy4mac #1672). Needs Python 3.11+ for tomllib.
Run: python3.11 -m unittest discover -s tests"""
import plistlib
import re
import unittest
from pathlib import Path

try:
    import tomllib
except ImportError:  # system python 3.9: skip instead of fail
    tomllib = None

ROOT = Path(__file__).resolve().parent.parent


@unittest.skipIf(tomllib is None, "needs Python 3.11+")
class AerospaceTest(unittest.TestCase):
    def setUp(self):
        self.text = (ROOT / "aerospace" / "aerospace.toml").read_text()
        self.cfg = tomllib.loads(self.text)

    def test_config_version_two(self):
        self.assertEqual(self.cfg["config-version"], 2)

    def test_persistent_workspaces_cover_bindings(self):
        used = set(re.findall(r"workspace (\d+)", self.text))
        self.assertTrue(used <= set(self.cfg["persistent-workspaces"]), used)

    def test_window_rules_have_no_shadowed_rule(self):
        # AeroSpace runs only the first matching rule, so a generic rule above a
        # specific one for the same app hides the specific one.
        generic = set()
        for rule in self.cfg["on-window-detected"]:
            app = rule["if"].get("app-id")
            specific = len(rule["if"]) > 1
            self.assertFalse(specific and app in generic, f"{app} specific rule is shadowed")
            self.assertFalse(not specific and app in generic, f"{app} has two generic rules")
            if not specific:
                generic.add(app)

    def test_every_binding_has_a_command(self):
        for mode in self.cfg["mode"].values():
            for key, cmd in mode["binding"].items():
                self.assertTrue(cmd, key)


class PlistTest(unittest.TestCase):
    def test_plists_parse(self):
        for path in (ROOT / "launchd").glob("*.plist"):
            with path.open("rb") as f:
                self.assertIn("Label", plistlib.load(f), path.name)


if __name__ == "__main__":
    unittest.main()
