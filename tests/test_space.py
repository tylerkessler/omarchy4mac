"""Workspace digit (plugins/aerospace.sh, tyler-os #1337). Run: python3 -m unittest discover -s tests"""
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "sketchybar"
SCRIPT = ROOT / "plugins" / "aerospace.sh"


class DigitTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.calls = self.tmp / "calls"
        fake = self.tmp / "sketchybar"
        fake.write_text(f'#!/bin/sh\necho "$@" >> "{self.calls}"\n')
        fake.chmod(0o755)

    def run_event(self, sender, native=None, aerospace="4"):
        """native = the Space the window server says is active; SketchyBar's $INFO always says 2 and is ignored."""
        env = dict(os.environ, PATH=f"{self.tmp}:{os.environ['PATH']}", CONFIG_DIR=str(ROOT), NAME="space",
                   SENDER=sender, FOCUSED_WORKSPACE=aerospace, SPACE_STATE_FILE=str(self.tmp / "native"),
                   INFO='{\n\t"display-1": 2\n}', NATIVE_SPACE_CMD=f"echo {native if native is not None else ''}")
        subprocess.run(["bash", str(SCRIPT)], env=env, check=True)

    def digit(self):
        if not self.calls.exists():
            return None
        line = self.calls.read_text().strip().splitlines()[-1]
        return next(a.split("=", 1)[1] for a in line.split() if a.startswith("icon="))

    def test_screenshot_repeat_keeps_aerospace_digit(self):
        self.run_event("space_change", native=2)                   # Ctrl+Right to native Space 2
        self.assertEqual(self.digit(), "2")
        self.run_event("aerospace_workspace_change", aerospace="4")  # then AeroSpace goes to 4
        self.assertEqual(self.digit(), "4")
        self.run_event("space_change", native=2)                   # screenshot re-sends Space 2
        self.assertEqual(self.digit(), "4")

    def test_ctrl_arrows_still_move_the_digit(self):
        self.run_event("space_change", native=1)
        self.run_event("space_change", native=3)
        self.assertEqual(self.digit(), "3")
        self.run_event("space_change", native=1, aerospace="5")    # back on Space 1 = AeroSpace's answer
        self.assertEqual(self.digit(), "5")

    def test_screenshot_bounce_on_space_one_keeps_aerospace(self):
        self.run_event("aerospace_workspace_change", aerospace="4")
        self.run_event("space_change", native=1)                   # $INFO says 2, the window server says 1
        self.assertEqual(self.digit(), "4")

    def test_unknown_native_space_keeps_the_digit(self):
        self.run_event("aerospace_workspace_change", aerospace="4")
        self.run_event("space_change")                             # helper timed out or failed
        self.assertEqual(self.digit(), "4")

    def test_reload_on_space_one_keeps_aerospace(self):
        self.run_event("space_change", native=1, aerospace="3")
        self.assertEqual(self.digit(), "3")


if __name__ == "__main__":
    unittest.main()
