"""YouTube and touch-grass pill logic (tyler-os #1381). Run: python3 -m unittest discover -s tests"""
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "sketchybar"
sys.path.insert(0, str(ROOT / "lib"))
import extras as ex  # noqa: E402

H = 3600


class YouTubeTest(unittest.TestCase):
    def test_watch_tab_gives_the_title(self):
        self.assertEqual(ex.youtube_title(["Brave Browser|Lofi beats - YouTube"]), "Lofi beats")

    def test_brave_suffix_and_notification_count_are_stripped(self):
        self.assertEqual(ex.youtube_title(["Brave Browser|(3) Lofi beats - YouTube - Brave"]), "Lofi beats")

    def test_real_brave_title_with_audio_tail_and_profile(self):
        raw = "Brave Browser|(5938) Vibe Coding a game ( mega jam day 2 ) - YouTube - Audio playing - High memory usage - 1.2 GB - Brave - Tyler"
        self.assertEqual(ex.youtube_title([raw]), "Vibe Coding a game ( mega jam day 2 )")

    def test_no_video_means_no_pill(self):
        for lines in ([], ["Brave Browser|YouTube"], ["Brave Browser|GitHub"], ["Safari|Song - YouTube"],
                      ["Brave Browser|Song - YouTube Music"]):
            self.assertIsNone(ex.youtube_title(lines), lines)

    def test_any_brave_window_counts(self):
        self.assertEqual(ex.youtube_title(["Ghostty|zsh", "Brave Browser|Docs", "Brave Browser|Talk - YouTube"]), "Talk")


class WidthTest(unittest.TestCase):
    def test_fits_means_longer_not_scrolling(self):
        px, chars, scrolls = ex.fit("a" * 50)
        self.assertEqual((chars, scrolls), (50, False))
        self.assertEqual(px, ex.label_width(50))

    def test_past_the_max_scrolls(self):
        self.assertEqual(ex.fit("a" * 200), (ex.label_width(ex.MAX_CHARS), ex.MAX_CHARS, True))

    def test_condensed_shrinks(self):
        self.assertEqual(ex.fit("a" * 50, condensed=True)[1], ex.CONDENSED_CHARS)

    def test_condensed_reads_the_cu_line(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "line"
            old = ex.CU_LINE
            try:
                ex.CU_LINE = f
                self.assertFalse(ex.condensed())
                f.write_text("1|123|agent")
                self.assertTrue(ex.condensed())
                f.write_text("0|123|agent")
                self.assertFalse(ex.condensed())
            finally:
                ex.CU_LINE = old


class GrassTest(unittest.TestCase):
    def run_ticks(self, idles, start=1000.0, step=60):
        st, now, out = {}, start, []
        for idle in idles:
            st, show, label = ex.grass_step(st, idle, now)
            out.append((show, label))
            now += step
        return st, out

    def test_hidden_until_two_hours(self):
        _, out = self.run_ticks([0] * 119)
        self.assertFalse(any(s for s, _ in out))
        _, out = self.run_ticks([0] * 121)
        self.assertTrue(out[-1][0])
        self.assertEqual(out[-1][1], "Touch grass · 2h 00m")

    def test_label_counts_up(self):
        st, show, label = ex.grass_step({"since": 0, "last": 2 * H + 14 * 60 - 60}, 0, 2 * H + 14 * 60)
        self.assertTrue(show)
        self.assertEqual(label, "Touch grass · 2h 14m")

    def test_ten_minutes_idle_is_a_break(self):
        st, show, _ = ex.grass_step({"since": 0, "last": 3 * H - 60}, 10 * 60, 3 * H)
        self.assertFalse(show)
        self.assertEqual(st["since"], 3 * H)

    def test_nine_minutes_idle_is_not(self):
        _, show, _ = ex.grass_step({"since": 0, "last": 3 * H - 60}, 9 * 60, 3 * H)
        self.assertTrue(show)

    def test_sleep_or_lid_shut_gap_is_a_break(self):
        st, show, _ = ex.grass_step({"since": 0, "last": 3 * H - 3600}, 0, 3 * H)
        self.assertFalse(show)
        self.assertEqual(st["since"], 3 * H)

    def test_snooze_hides_for_fifteen_minutes_then_returns(self):
        st = {"since": 0, "last": 2 * H, "snooze": 2 * H + ex.SNOOZE}
        _, show, _ = ex.grass_step(st, 0, 2 * H + 60)
        self.assertFalse(show)
        st["last"] = 2 * H + ex.SNOOZE - 60
        _, show, _ = ex.grass_step(st, 0, 2 * H + ex.SNOOZE)
        self.assertTrue(show)

    def test_a_break_clears_the_snooze(self):
        st, _, _ = ex.grass_step({"since": 0, "last": 5, "snooze": 10 ** 9}, 700, 100)
        self.assertEqual(st["snooze"], 0)


class PluginTest(unittest.TestCase):
    def test_plugin_scripts_parse(self):
        for f in ("plugins/youtube.sh", "plugins/touch_grass.sh", "lib/pill_item.sh", "sketchybarrc"):
            self.assertEqual(subprocess.run(["bash", "-n", str(ROOT / f)]).returncode, 0, f)

    def test_cli_youtube_and_width(self):
        out = subprocess.run([sys.executable, str(ROOT / "lib/extras.py"), "youtube"], input="Brave Browser|Hi - YouTube\n",
                             capture_output=True, text=True).stdout.strip()
        self.assertEqual(out, "Hi")
        out = subprocess.run([sys.executable, str(ROOT / "lib/extras.py"), "width", "abcd"], capture_output=True, text=True).stdout.split()
        self.assertEqual(out, [str(ex.label_width(4)), "4", "0"])


if __name__ == "__main__":
    unittest.main()
