"""Width, state and colour logic for the bar's pills (tyler-os #1381). Run: python3 -m unittest discover -s tests"""
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "sketchybar"
sys.path.insert(0, str(ROOT / "lib"))
sys.path.insert(0, str(ROOT / "plugins"))
import pillcalc as pc  # noqa: E402
import spotify_view as sv  # noqa: E402


class WidthTest(unittest.TestCase):
    def test_label_width_is_chars_times_glyph(self):
        self.assertEqual(pc.label_width(0), 0)
        self.assertEqual(pc.label_width(10), round(10 * pc.CHAR_W))

    def test_max_width_is_two_to_three_times_the_old_32(self):
        self.assertTrue(64 <= pc.MAX_CHARS <= 96)

    def test_short_title_fits_exactly_and_does_not_scroll(self):
        pl = pc.plan({"state": "playing", "name": "Money", "artist": "Dire Straits", "saved": "0"})
        self.assertEqual(pl["max_chars"], len("Dire Straits - Money"))
        self.assertFalse(pl["scrolls"])
        self.assertEqual(pl["width"], pc.label_width(len("Dire Straits - Money")))

    def test_a_title_longer_than_the_32_char_old_max_still_fits_now(self):
        pl = pc.plan({"state": "playing", "name": "x" * 50, "artist": "Artist", "saved": "?"})
        self.assertFalse(pl["scrolls"])
        self.assertGreater(pl["max_chars"], 32)

    def test_only_past_the_max_does_it_scroll(self):
        pl = pc.plan({"state": "playing", "name": "x" * 200, "artist": "A", "saved": "?"})
        self.assertTrue(pl["scrolls"])
        self.assertEqual(pl["max_chars"], pc.MAX_CHARS)

    def test_condensed_caps_the_room_and_hides_controls_but_keeps_the_design(self):
        full = pc.plan({"state": "playing", "name": "x" * 60, "artist": "A", "saved": "1"})
        small = pc.plan({"state": "playing", "name": "x" * 60, "artist": "A", "saved": "1"}, condensed=True)
        self.assertEqual(small["max_chars"], pc.CONDENSED_CHARS)
        self.assertTrue(small["scrolls"])
        self.assertFalse(small["show_play"] or small["show_next"])
        self.assertTrue(small["show_star"])
        for k in ("label_color", "icon_color", "star_icon"):
            self.assertEqual(small[k], full[k])


class StateTest(unittest.TestCase):
    def test_playing_is_full_white_paused_dimmer(self):
        playing = pc.plan({"state": "playing", "name": "S", "artist": "A"})
        paused = pc.plan({"state": "paused", "name": "S", "artist": "A"})
        self.assertEqual(playing["label_color"], pc.FG)
        self.assertEqual(paused["label_color"], pc.with_alpha(pc.FG, 0xB3))
        self.assertEqual((playing["play_icon"], paused["play_icon"]), ("", ""))

    def test_nothing_playing_keeps_the_pill_with_the_last_song_dimmed(self):
        pl = pc.plan({"state": "idle", "name": "S", "artist": "A", "saved": "1"})
        self.assertEqual(pl["text"], "A - S")
        self.assertEqual(pl["label_color"], pc.with_alpha(pc.FG, 0x73))
        self.assertFalse(pl["show_next"] or pl["show_star"])
        self.assertTrue(pl["show_play"])

    def test_no_song_at_all_says_spotify(self):
        self.assertEqual(pc.plan({"state": "idle"})["text"], "Spotify")
        self.assertEqual(pc.plan({"state": "error"})["text"], "Spotify")

    def test_not_connected_says_so_instead_of_hiding(self):
        self.assertEqual(pc.plan({"state": "nologin"})["text"], "Spotify - connect")
        self.assertEqual(pc.plan({"state": "relogin"})["text"], "Spotify - connect")

    def test_star_shows_saved_or_not_from_the_api_answer(self):
        saved = pc.plan({"state": "playing", "name": "S", "artist": "A", "saved": "1"})
        no = pc.plan({"state": "playing", "name": "S", "artist": "A", "saved": "0"})
        self.assertEqual((saved["star_icon"], saved["star_color"]), ("★", pc.YELLOW))
        self.assertEqual(no["star_icon"], "☆")
        self.assertNotEqual(no["star_color"], pc.YELLOW)

    def test_parse_line(self):
        self.assertEqual(pc.parse_line("playing\tSong\tArt\t1\tiPhone")["device"], "iPhone")
        self.assertEqual(pc.parse_line("idle\t\t\t?\t")["state"], "idle")
        for bad in ("", "garbage", '{"logged_in": false}', "playing\tonly"):
            self.assertEqual(pc.parse_line(bad)["state"], "error")


class ViewTest(unittest.TestCase):
    PL = pc.plan({"state": "playing", "name": "Song", "artist": "Art", "saved": "0"})

    def test_first_draw_and_same_width_do_not_animate(self):
        for prev in (None, self.PL["width"]):
            (args,) = sv.commands(self.PL, prev)
            self.assertNotIn("--animate", args)

    def test_a_new_width_animates_with_tanh(self):
        (args,) = sv.commands(self.PL, self.PL["width"] + 40)
        i = args.index("--animate")
        self.assertEqual(args[i + 1:i + 3], ["tanh", str(sv.FRAMES)])
        self.assertTrue(15 <= sv.FRAMES <= 20)
        self.assertIn(f"label.width={self.PL['width']}", args[i:])

    def test_the_pill_is_always_drawn(self):
        for st in ("playing", "paused", "idle", "nologin", "error"):
            (args,) = sv.commands(pc.plan({"state": st}), None)
            self.assertIn("drawing=on", args[:3])

    def test_condensed_follows_the_computer_use_line(self):
        with tempfile.TemporaryDirectory() as d:
            old = sv.STATE
            sv.STATE = Path(d)
            try:
                self.assertFalse(sv.condensed())
                (Path(d) / "computer_use.line").write_text("1|1700000000|agent\n")
                self.assertTrue(sv.condensed())
                (Path(d) / "computer_use.line").write_text("0|0|\n")
                self.assertFalse(sv.condensed())
            finally:
                sv.STATE = old

    def test_mac_app_event_is_the_fallback_until_the_api_is_connected(self):
        ev = sv.from_event("spotify_change", '{"Player State": "Playing", "Name": "N", "Artist": "A"}')
        self.assertEqual((ev["state"], ev["name"]), ("playing", "N"))
        self.assertIsNone(sv.from_event("media_change", '{"app": "Music", "title": "x"}'))
        self.assertIsNone(sv.from_event("spotify_change", ""))


class ColourTest(unittest.TestCase):
    def test_mix_white_is_halfway_and_semi_transparent(self):
        self.assertEqual(pc.mix_white("0xff000000"), "0xcc7f7f7f")
        self.assertEqual(pc.mix_white("0xffffffff"), "0xccffffff")

    def test_desktop_number_colours_match_the_desktop_steps(self):
        vibe = (ROOT / "live_vibe.sh").read_text()
        for n in range(1, 6):
            step = re.search(rf'export SPACE_{n}="(0x\w+)"', vibe).group(1)
            txt = re.search(rf'export SPACE_{n}_TXT="(0x\w+)"', vibe).group(1)
            self.assertEqual(txt, pc.mix_white(step), f"desktop {n}")


class ConfigTest(unittest.TestCase):
    def test_scripts_parse(self):
        for f in [ROOT / "sketchybarrc", ROOT / "pill.sh", *ROOT.glob("plugins/*.sh")]:
            r = subprocess.run(["bash", "-n", str(f)], capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, f"{f.name}: {r.stderr}")

    def test_every_island_uses_the_one_pill_design(self):
        rc = (ROOT / "sketchybarrc").read_text()
        brackets = re.findall(r"--set (vibe_\w+) \$\(pill_args", rc)
        self.assertEqual(set(brackets), {"vibe_left", "vibe_music", "vibe_center", "vibe_right"})
        self.assertNotIn("_PILL=(", rc)

    def test_pill_args_gives_the_same_shape_to_every_accent(self):
        def args(accent):
            cmd = f'CONFIG_DIR={ROOT}; PLUM=0xf0240f2e; OVERLAY=0xff2a2a44; . {ROOT}/pill.sh; pill_args "{accent}"'
            return subprocess.run(["bash", "-c", cmd], capture_output=True, text=True).stdout.split()
        shape = lambda a: [x for x in a if not x.startswith(("background.border_color", "background.shadow.color"))]  # noqa: E731
        self.assertEqual(shape(args("0xff1db954")), shape(args("0xff8b5cf6")))
        self.assertIn("background.border_color=0xff1db954", args("0xff1db954"))
        self.assertIn("background.shadow.drawing=off", args("0xff1db954"))   # no glow or shadow (#1418)
        self.assertIn("background.corner_radius=14", args(""))

    def test_the_desktop_number_has_no_chip(self):
        rc = (ROOT / "sketchybarrc").read_text()
        block = rc[rc.index("--add item space left"):rc.index("# Separator")]
        self.assertIn("background.drawing=off", block)
        self.assertNotIn("background.color", block)
        plug = (ROOT / "plugins/aerospace.sh").read_text()
        self.assertIn("background.drawing=off", plug)
        self.assertNotIn("background.drawing=on", plug)

    def test_no_polling_osascript_for_spotify(self):
        for f in ("spotify.sh", "spotify_click.sh", "spotify_star.sh", "spotify_view.py"):
            body = (ROOT / "plugins" / f).read_text()
            code = "\n".join(l for l in body.splitlines() if not l.lstrip().startswith("#"))
            if f != "spotify_click.sh" and f != "spotify_star.sh":
                self.assertNotIn("osascript", code, f)


if __name__ == "__main__":
    unittest.main()
