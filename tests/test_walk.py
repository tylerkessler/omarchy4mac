"""Walk pill + panel payload (tyler-os #1394). No network, no live MBA."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent.parent / "sketchybar"
sys.path.insert(0, str(ROOT / "lib"))
os.environ["TKOS_WALK_API"] = ""
os.environ["TKOS_TRAIL_API"] = ""
import walk_data as wd  # noqa: E402

TZ = ZoneInfo("America/New_York")
NOW = datetime(2026, 11, 13, 15, 0, tzinfo=TZ)


def walk(**kw):
    row = {
        "walk_id": kw.get("walk_id", "abc"),
        "started_at": kw.get("started_at", "2026-11-13T09:00:00-05:00"),
        "ended_at": kw.get("ended_at", "2026-11-13T09:30:00-05:00"),
        "distance_m": kw.get("distance_m", 1609.344),
        "elapsed_s": kw.get("elapsed_s", 1800),
        "from_place": kw.get("from_place", {"name": "A"}),
        "to_place": kw.get("to_place", {"name": "B"}),
        "kcal_est": kw.get("kcal_est"),
    }
    return row


class ParseTest(unittest.TestCase):
    def test_skips_bad_lines(self):
        rows = wd.parse_walks(["not json", "", json.dumps(walk()), "{"] )
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["walk_id"], "abc")

    def test_empty_file_is_empty_list(self):
        self.assertEqual(wd.parse_walks([]), [])

    def test_place_name_from_dict_or_string(self):
        self.assertEqual(wd.place_name({"name": "Earl Brown Park"}), "Earl Brown Park")
        self.assertEqual(wd.place_name("Chronic Guru"), "Chronic Guru")
        self.assertEqual(wd.place_name({"name": ""}), "")
        self.assertEqual(wd.place_name(None), "")


class SumTest(unittest.TestCase):
    def test_today_sums_closed_walks(self):
        walks = [
            walk(distance_m=1609.344),
            walk(walk_id="old", started_at="2026-11-12T21:00:00-05:00",
                 ended_at="2026-11-12T21:20:00-05:00", distance_m=3218.688),
        ]
        self.assertEqual(wd.today_miles(walks, {}, NOW), 1.0)

    def test_today_adds_active_walk_only_when_phase_is_walk(self):
        walks = [walk(distance_m=1609.344)]
        st = {"phase": "walk", "metrics": {"miles": 0.24}, "distance_m": 386}
        self.assertEqual(wd.today_miles(walks, st, NOW), 1.24)
        st_dwell = {"phase": "dwell", "metrics": {"miles": 0.24}, "distance_m": 386}
        self.assertEqual(wd.today_miles(walks, st_dwell, NOW), 1.0)

    def test_week_and_zeros_when_empty(self):
        z = wd.sum_walks([], wd.week_start(NOW), wd.day_start(NOW).replace(hour=0) )
        empty = wd.sum_walks([], NOW, NOW)
        self.assertEqual(empty, {"miles": 0.0, "duration_s": 0.0, "count": 0})
        walks = [walk(), walk(walk_id="y", started_at="2026-11-10T08:00:00-05:00",
                              ended_at="2026-11-10T08:20:00-05:00", distance_m=804.672)]
        week = wd.sum_walks(walks, wd.week_start(NOW), wd.day_start(NOW).replace(day=14))
        self.assertEqual(week["count"], 2)
        self.assertEqual(week["miles"], 1.5)

    def test_graph_has_one_bucket_per_day(self):
        walks = [walk()]
        g = wd.day_buckets(walks, 7, NOW)
        self.assertEqual(len(g), 7)
        self.assertEqual(g[-1]["date"], "2026-11-13")
        self.assertEqual(g[-1]["miles"], 1.0)
        self.assertEqual(g[0]["miles"], 0.0)


class LabelTest(unittest.TestCase):
    def test_walking_uses_metrics_miles(self):
        st = {"phase": "walk", "metrics": {"miles": 1.24}}
        self.assertEqual(wd.pill_label(st, 2.1), "Walk · 1.24 mi")

    def test_idle_today_and_empty(self):
        self.assertEqual(wd.pill_label({"phase": "dwell"}, 2.1), "Walk · 2.1 mi today")
        self.assertEqual(wd.pill_label({}, 0), "Walk")
        self.assertEqual(wd.pill_label(None, 0), "Walk")

    def test_condensed_drops_today(self):
        self.assertEqual(wd.pill_label({"phase": "dwell"}, 2.1, condensed=True), "Walk · 2.1 mi")

    def test_fmt_mi_strips_zeros(self):
        self.assertEqual(wd.fmt_mi(1609.344), "1")
        self.assertEqual(wd.fmt_mi(1.24 * 1609.344), "1.24")


class EmptyPanelTest(unittest.TestCase):
    def test_empty_payload(self):
        p = wd.panel_payload(walks=[], status={"phase": "dwell"}, now=NOW, samples={})
        self.assertTrue(p["empty"])
        self.assertIsNone(p["now"])
        self.assertEqual(p["today"]["miles"], 0.0)
        self.assertEqual(p["today"]["count"], 0)
        self.assertEqual(p["history"], [])
        self.assertIn("TKOS_WALK_SILENT", p["pause_why"])
        self.assertIn("read-only", p["gps_why"])

    def test_last_walk_when_idle(self):
        p = wd.panel_payload(walks=[walk()], status={"phase": "dwell"}, now=NOW, samples={})
        self.assertFalse(p["empty"])
        self.assertEqual(p["now"]["miles_label"], "1")
        self.assertEqual(p["now"]["route"], "A → B")
        self.assertEqual(p["today"]["count"], 1)

    def test_map_id_prefers_active_walk_with_samples(self):
        st = {"phase": "walk", "walk_id": "live", "distance_m": 400, "elapsed_s": 200, "metrics": {"miles": 0.25}}
        samples = {"live": [[29.0, -81.3], [29.01, -81.31]], "abc": [[29.02, -81.3]]}
        p = wd.panel_payload(walks=[walk()], status=st, now=NOW, samples=samples)
        self.assertEqual(p["map_id"], "live")
        self.assertEqual(p["now"]["phase"], "walk")


class LidAndSamplesTest(unittest.TestCase):
    def test_lid_on_from_env(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "WALK_LID_MODE.env"
            p.write_text("WALK_LID_MODE=1\nARMED_AT=x\n")
            st = wd.lid_status(p)
            self.assertTrue(st["on"])
            p.write_text("WALK_LID_MODE=0\n")
            self.assertFalse(wd.lid_status(p)["on"])
            self.assertFalse(wd.lid_status(Path(d) / "missing")["on"])

    def test_downsample_keeps_ends(self):
        pts = [[i, i] for i in range(1000)]
        out = wd.downsample(pts, 10)
        self.assertEqual(len(out), 10)
        self.assertEqual(out[0], [0, 0])
        self.assertEqual(out[-1], [999, 999])

    def test_load_samples_filters_by_id(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "s.jsonl"
            p.write_text(
                json.dumps({"walk_id": "a", "lat": 29.0, "lon": -81.3}) + "\n"
                + json.dumps({"walk_id": "b", "lat": 29.1, "lon": -81.4}) + "\n"
            )
            got = wd.load_samples({"a"}, p)
            self.assertEqual(got["a"], [[29.0, -81.3]])
            self.assertNotIn("b", got)


class PluginTest(unittest.TestCase):
    def test_scripts_parse(self):
        for f in ("plugins/walk.sh", "lib/walk_data.py", "walk_panel.html"):
            path = ROOT / f
            self.assertTrue(path.exists(), f)
        self.assertEqual(subprocess.run(["bash", "-n", str(ROOT / "plugins/walk.sh")]).returncode, 0)
        rc = subprocess.run(["python3", "-m", "py_compile", str(ROOT / "lib/walk_data.py")])
        self.assertEqual(rc.returncode, 0)

    def test_sketchybarrc_loads_walk_item(self):
        text = (ROOT / "sketchybarrc").read_text()
        self.assertIn("item walk left", text)
        self.assertIn("plugins/walk.sh", text)
        self.assertIn("0xff33b5ff", text)
        self.assertIn("walk_data.py open", text)

    def test_html_has_offline_fallback_and_placeholder(self):
        html = (ROOT / "walk_panel.html").read_text()
        self.assertIn("__WALK_JSON__", html)
        self.assertIn("offmap", html)
        self.assertIn("openstreetmap.org", html)

    def test_cli_label_empty_env(self):
        with tempfile.TemporaryDirectory() as d:
            env = os.environ.copy()
            env["TKOS_WALKS_JSONL"] = str(Path(d) / "missing.jsonl")
            env["TKOS_WALKS_ACTIVE"] = str(Path(d) / "missing.json")
            env["TKOS_WALK_API"] = ""
            env["TKOS_TRAIL_API"] = ""
            env["TYLER_VAULT"] = d
            out = subprocess.run([sys.executable, str(ROOT / "lib/walk_data.py"), "label"],
                                 capture_output=True, text=True, env=env)
            self.assertEqual(out.returncode, 0)
            self.assertEqual(out.stdout.strip(), "")


if __name__ == "__main__":
    unittest.main()
