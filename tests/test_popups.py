"""Parsers and rows for the right-group popups (tyler-os #1419). Run: python3 -m unittest discover -s tests"""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "sketchybar" / "lib"))
import popups as p  # noqa: E402

VM = """Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                                     3834.
Pages wired down:                              79763.
Pages purgeable:                                1000.
Anonymous pages:                              127813.
Pages occupied by compressor:                 199257.
"""
IOREG = '''    | "AdapterDetails" = {"Watts"=86,"Name"="87W USB-C Power Adapter"}
    | "Voltage" = 12350
    | "MaxCapacity" = 100
    | "CurrentCapacity" = 36
    | "CycleCount" = 809
    | "BatteryData" = {"FullChargeCapacity"=3662,"NominalChargeCapacity"=3792,"DesignCapacity"=4382,"MaxCapacity"=100}
    | "Amperage" = %s
    | "SystemPowerIn" = 42840
    | "SystemLoad" = 13299
    | "ExternalConnected" = Yes
    | "IsCharging" = %s
'''


class CpuMemTest(unittest.TestCase):
    def test_mem_used_is_app_plus_wired_plus_compressed(self):
        vm = p.parse_vm_stat(VM)
        self.assertEqual(vm["page"], 16384)
        self.assertEqual(p.mem_used(vm), (127813 - 1000 + 79763 + 199257) * 16384)

    def test_swap_load_and_top(self):
        self.assertEqual(p.parse_swap("vm.swapusage: total = 3072.00M  used = 1576.56M  free = 1495.44M  (encrypted)"), (1576.56, 3072.0))
        self.assertEqual(p.parse_loadavg("{ 10.50 12.55 26.26 }"), [10.5, 12.55, 26.26])
        top = "CPU usage: 50.0% user, 20.0% sys, 30.0% idle\nCPU usage: 8.5% user, 4.5% sys, 87.0% idle\n"
        self.assertEqual(p.parse_top_cpu(top), (8.5, 4.5, 87.0))        # the second sample, not the since-boot one
        self.assertIsNone(p.parse_top_cpu("nothing"))

    def test_ps_top_five(self):
        out = " 24.1 Brave Browser He\n 12.0 WindowServer\n  3.0 a\n  2.0 b\n  1.0 c\n  0.5 d\n"
        top = p.parse_ps(out)
        self.assertEqual(len(top), 5)
        self.assertEqual(top[0], ("Brave Browser He", 24.1))

    def test_rows_have_every_field(self):
        rows = p.cpu_rows((8.5, 4.5, 87.0), 4 * 2**30, 8 * 2**30, 2, 41, (1536.0, 3072.0), [1.0, 2.0, 3.0], 8, [("x", 5.0)] * 5, {"pct": 24, "mem": 329990144, "alloc": 1157677056, "watts": None})
        text = "\n".join(t for t, _ in rows)
        for want in ("13.0%", "4.0G / 8.0G", "50% used", "warn", "41% free", "1.5G / 3.0G", "1.00  2.00  3.00", "8 cores", "Top 5", "GPU       24%", "0.3G in use", "not reported"):
            self.assertIn(want, text)
        self.assertEqual(len(rows), 14)                                  # nine lines + 5 processes

    def test_gpu_parse(self):
        g = p.parse_gpu(p.run(["/usr/sbin/ioreg", "-rc", "IOAccelerator", "-d", "1"]))
        self.assertIsNotNone(g["pct"])
        self.assertEqual(p.parse_gpu('"Device Utilization %"=7,"In use system memory"=2147483648')["mem"], 2147483648)


class BatteryTest(unittest.TestCase):
    def test_signed_amperage(self):
        self.assertEqual(p.parse_ioreg(IOREG % ("18446744073709550000", "No"))["amperage"], 18446744073709550000 - (1 << 64))
        self.assertEqual(p.parse_ioreg(IOREG % ("2413", "Yes"))["amperage"], 2413)

    def test_pmset(self):
        got = p.parse_pmset(" -InternalBattery-0 (id=1)\t36%; charging; 2:08 remaining present: true")
        self.assertEqual(got, {"pct": 36, "state": "charging", "remaining": "2:08"})
        self.assertIsNone(p.parse_pmset("36%; discharging; (no estimate) present: true")["remaining"])

    def test_charging_rows(self):
        b = p.parse_ioreg(IOREG % ("2413", "Yes"))
        rows = [t for t, _ in p.battery_rows(b, {"pct": 36, "state": "charging", "remaining": "2:08"})]
        text = "\n".join(rows)
        for want in ("36%", "43W in of 86W adapter", "2h 08m to full", "2.41A  29.8W", "Health    87%", "3792 of 4382 mAh", "809"):
            self.assertIn(want, text)

    def test_discharge_rows(self):
        b = p.parse_ioreg(IOREG.replace("ExternalConnected\" = Yes", "ExternalConnected\" = No") % (str((1 << 64) - 1070), "No"))
        text = "\n".join(t for t, _ in p.battery_rows(b, {"pct": 80, "state": "discharging", "remaining": "4:10"}))
        self.assertIn("Discharge 1.07A  13.2W out", text)
        self.assertIn("4h 10m left", text)
        self.assertIn("13.3W drawn", text)


class MusicTest(unittest.TestCase):
    S = {"state": "playing", "name": "Song", "artist": "Band", "device": "Brit's Mac", "pos_ms": 60000, "dur_ms": 240000, "at": 100.0}

    def test_progress_moves_while_playing(self):
        rows = p.music_rows(self.S, 110.0)
        self.assertIn("1:10 ▰▰▰▰▰▰▱", rows[2][0])
        self.assertIn("4:00", rows[2][0])
        paused = p.music_rows({**self.S, "state": "paused"}, 110.0)
        self.assertIn("1:00", paused[2][0])

    def test_controls_and_star(self):
        text = [t for t, _ in p.music_rows(self.S, 100.0, "1")]
        self.assertIn("  Pause", text)
        self.assertIn("★ Saved to Library", text)

    def test_fire_tablet_has_no_controls(self):
        text = [t for t, _ in p.music_rows({**self.S, "device": "Yuri's Fire"}, 100.0)]
        self.assertFalse(any(t.strip() in ("Previous", "Pause", "Play", "Next") for t in text))
        self.assertTrue(any("controls off" in t for t in text))

    def test_not_connected_and_idle(self):
        self.assertEqual(p.music_rows({"state": "nologin"}, 0)[0][0], "Spotify is not connected")
        self.assertEqual(p.music_rows({"state": "idle"}, 0)[0][0], "Nothing playing")


if __name__ == "__main__":
    unittest.main()
