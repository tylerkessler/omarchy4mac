"""Home sweep (bin/aerospace-home, tyler-os #1625). Run: python3 -m unittest discover -s tests"""
import importlib.machinery
import importlib.util
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCRIPT = REPO / "bin" / "aerospace-home"
CONF = REPO / "aerospace" / "aerospace.toml"


def load():
    loader = importlib.machinery.SourceFileLoader("aerospace_home", str(SCRIPT))
    spec = importlib.util.spec_from_loader("aerospace_home", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


H = load()
RULES = H.parse_rules(CONF.read_text())


class RulesTest(unittest.TestCase):
    def test_every_rule_block_is_read(self):
        blocks = len(re.findall(r"^\[\[on-window-detected\]\]\s*$", CONF.read_text(), re.M))
        self.assertEqual(len(RULES), blocks)

    def test_homes(self):
        home = lambda app, title="": (H.match(RULES, app, title) or {}).get("workspace")  # noqa: E731
        self.assertEqual(home("com.mitchellh.ghostty", "TKOS"), "1")
        self.assertEqual(home("com.brave.Browser"), "2")
        self.assertEqual(home("com.anthropic.claudefordesktop"), "3")
        self.assertEqual(home("com.apple.MobileSMS"), "4")
        self.assertEqual(home("com.apple.Notes"), "5")

    def test_first_match_wins(self):
        r = H.match(RULES, "com.mitchellh.ghostty", "org.omarchy.screensaver")
        self.assertIsNone(r["workspace"], "the screensaver float rule sits above the Ghostty pin")

    def test_floats_and_unknown_apps_stay_put(self):
        self.assertIsNone(H.match(RULES, "com.1password.1password", "")["workspace"])
        self.assertIsNone(H.match(RULES, "com.logi.cp-dev-mgr", "")["workspace"])
        self.assertIsNone(H.match(RULES, "com.apple.TextEdit", ""), "TextEdit has no rule: it is the pin popup's test app")

    def test_startup_command_runs_the_sweep(self):
        self.assertRegex(CONF.read_text(), r"(?m)^after-startup-command = \[.*aerospace-home --startup")


class SweepTest(unittest.TestCase):
    def test_moves_only_misplaced_windows(self):
        tmp = Path(tempfile.mkdtemp())
        log = tmp / "calls"
        sep = "\x1f"
        rows = [["11", "4", "com.anthropic.claudefordesktop", "Claude", "Claude"],
                ["12", "4", "com.mitchellh.ghostty", "Ghostty", "TKOS"],
                ["13", "2", "com.brave.Browser", "Brave Browser", "Hub"],
                ["14", "4", "com.1password.1password", "1Password", "Vault"],
                ["15", "4", "com.apple.TextEdit", "TextEdit", "Untitled"]]
        listing = "\\n".join(sep.join(r) for r in rows)
        fake = tmp / "aerospace"
        fake.write_text(f'#!/bin/sh\necho "$@" >> "{log}"\n'
                        f'case "$1" in list-windows) printf "{listing}\\n";; list-workspaces) echo 4;; esac\n')
        fake.chmod(0o755)
        bar = tmp / "sketchybar"
        bar.write_text(f'#!/bin/sh\necho "bar $@" >> "{log}"\n')
        bar.chmod(0o755)
        env = dict(os.environ, AEROSPACE_BIN=str(fake), SKETCHYBAR_BIN=str(bar), AEROSPACE_CONF=str(CONF))
        out = subprocess.run(["python3", str(SCRIPT)], env=env, capture_output=True, text=True, timeout=20)
        self.assertEqual(out.returncode, 0, out.stderr)
        calls = log.read_text().splitlines()
        moves = [c for c in calls if c.startswith("move-node-to-workspace")]
        self.assertEqual(moves, ["move-node-to-workspace --window-id 11 3", "move-node-to-workspace --window-id 12 1"])
        self.assertIn("bar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=4", calls)

        dry = subprocess.run(["python3", str(SCRIPT), "--dry-run"], env=env, capture_output=True, text=True, timeout=20)
        self.assertIn("would move Claude 4 -> 3", dry.stdout)


if __name__ == "__main__":
    unittest.main()
