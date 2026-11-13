"""Sunset focused-window border (tyler-os #1392). Run: python3 -m unittest tests.test_borders"""
import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BORDERSRC = ROOT / "borders" / "bordersrc"
LIVE_VIBE = ROOT / "sketchybar" / "live_vibe.sh"

SUN_1 = "0xffff8b4b"
SUN_4 = "0xff8b5cf6"
PLUM_RGB = "240f2e"
TOKYO_BLUE = "0xff7aa2f7"
TOKYO_OVERLAY = "0xff414868"


def _src() -> str:
    return BORDERSRC.read_text()


class BordersrcTest(unittest.TestCase):
    def test_parses(self):
        self.assertEqual(subprocess.run(["bash", "-n", str(BORDERSRC)]).returncode, 0)

    def test_keeps_width_style_hidpi_blacklist_and_transparent_bg(self):
        src = _src()
        self.assertIn("style=round", src)
        self.assertIn("width=5.0", src)
        self.assertIn("hidpi=on", src)
        self.assertIn("background_color=0x00000000", src)
        self.assertIn('blacklist="UserNotificationCenter"', src)

    def test_active_is_sunset_diagonal_not_tokyo_blue(self):
        src = _src()
        self.assertNotIn(TOKYO_BLUE, src)
        self.assertRegex(
            src,
            r'active_color="gradient\(top_left=' + SUN_1 + r",bottom_right=" + SUN_4 + r'\)"',
        )

    def test_inactive_is_subtle_plum_not_tokyo_overlay(self):
        src = _src()
        self.assertNotIn(TOKYO_OVERLAY, src)
        m = re.search(r"inactive_color=(0x[0-9a-fA-F]{8})", src)
        self.assertIsNotNone(m)
        hex8 = m.group(1).lower()
        self.assertTrue(hex8.endswith(PLUM_RGB), hex8)
        alpha = int(hex8[2:4], 16)
        self.assertGreaterEqual(alpha, 0x80)
        self.assertLess(alpha, 0xF0)

    def test_comment_is_tkos_sunset(self):
        src = _src()
        self.assertIn("TKOS sunset", src)
        self.assertNotIn("Tokyo Night", src)

    def test_palette_matches_live_vibe(self):
        vibe = LIVE_VIBE.read_text()
        self.assertIn(f'SUN_1="{SUN_1}"', vibe)
        self.assertIn(f'SUN_4="{SUN_4}"', vibe)
        self.assertIn(f'PLUM="0xf0{PLUM_RGB}"', vibe)


if __name__ == "__main__":
    unittest.main()
