#!/usr/bin/env python3
"""CPU/memory, music and battery popups for the right group of the bar (tyler-os #1419).

Pure parsers and row builders first (tests/test_popups.py checks them), then the sketchybar glue.
  popups.py cpu-tick        the CPU/RAM pill: one read, redraws the popup too only while it is open
  popups.py fill NAME       draw one popup's rows now (cpu | music | battery)
  popups.py ctl ACTION      music controls: playpause | next | prev | star
No API call happens unless the music popup is open or a control was clicked. Controls never wake or take over a device:
nothing active = nothing happens, and Yuri's Fire tablet is left alone.
"""
from __future__ import annotations

import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

HOME = Path.home()
SB = os.environ.get("SKETCHYBAR", "/opt/homebrew/bin/sketchybar")
CACHE = Path(os.environ.get("TKOS_BAR_CACHE", HOME / ".cache" / "omarchy4mac"))
LIB = Path(os.environ.get("TKOS_SPOTIFY_DIR", HOME / "Scripts/tyler-os-live/coach"))
OPEN_FILE = CACHE / "popup_open"
WHITE = "0xffffffff"
DIM = "0xffa99cc4"
GREEN = "0xff1db954"
AMBER = "0xffffd23f"
RED = "0xffff3d5a"
FIRE = re.compile(r"fire|kindle|yuri|amazon|echo", re.I)   # devices that are never ours to control
CPU_ROWS, MUSIC_ROWS, BATT_ROWS = 15, 8, 8


def run(cmd: list[str], timeout: float = 4) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ""


# ---------- parsers ----------

def parse_vm_stat(text: str) -> dict:
    """vm_stat -> {'page': bytes, 'wired': pages, 'anon': pages, 'purgeable': pages, 'compressed': pages, 'free': pages}."""
    m = re.search(r"page size of (\d+) bytes", text)
    out = {"page": int(m.group(1)) if m else 16384}
    keys = {"Pages wired down": "wired", "Anonymous pages": "anon", "Pages purgeable": "purgeable",
            "Pages occupied by compressor": "compressed", "Pages free": "free"}
    for line in text.splitlines():
        k, _, v = line.partition(":")
        if k.strip() in keys:
            out[keys[k.strip()]] = int(re.sub(r"\D", "", v) or 0)
    return out


def mem_used(vm: dict) -> int:
    """Bytes in use the way Activity Monitor counts them: app memory (anonymous minus purgeable) + wired + compressed."""
    pages = max(vm.get("anon", 0) - vm.get("purgeable", 0), 0) + vm.get("wired", 0) + vm.get("compressed", 0)
    return pages * vm.get("page", 16384)


def parse_swap(text: str) -> tuple[float, float]:
    """sysctl vm.swapusage -> (used MB, total MB)."""
    t = re.search(r"total = ([\d.]+)M", text)
    u = re.search(r"used = ([\d.]+)M", text)
    return (float(u.group(1)) if u else 0.0, float(t.group(1)) if t else 0.0)


def parse_loadavg(text: str) -> list[float]:
    return [float(x) for x in re.findall(r"\d+\.\d+", text)][:3]


def parse_top_cpu(text: str) -> tuple[float, float, float] | None:
    """The LAST 'CPU usage:' line of `top -l 2` (the first sample is since boot) -> (user, sys, idle) percent."""
    hits = re.findall(r"CPU usage:\s*([\d.]+)% user,\s*([\d.]+)% sys,\s*([\d.]+)% idle", text)
    return tuple(float(x) for x in hits[-1]) if hits else None  # type: ignore[return-value]


def parse_ps(text: str, n: int = 5) -> list[tuple[str, float]]:
    """`ps -Aceo pcpu,comm -r` -> the top n (name, cpu%)."""
    rows = []
    for line in text.splitlines():
        m = re.match(r"\s*([\d.]+)\s+(.+)$", line)
        if m:
            rows.append((m.group(2).strip(), float(m.group(1))))
    return rows[:n]


def parse_free_pct(text: str) -> int | None:
    m = re.search(r"free percentage:\s*(\d+)%", text)
    return int(m.group(1)) if m else None


def parse_gpu(text: str) -> dict:
    """ioreg -rc IOAccelerator PerformanceStatistics -> {'pct', 'mem' (bytes in use), 'alloc' (bytes), 'watts' (None unless reported)}."""
    def num(key: str) -> int | None:
        m = re.search(r'"%s"\s*=\s*(\d+)' % re.escape(key), text)
        return int(m.group(1)) if m else None
    pw = re.search(r'"(?:GPU|gpu)[ _]?[Pp]ower[^"]*"\s*=\s*(\d+)', text)
    return {"pct": num("Device Utilization %"), "mem": num("In use system memory"),
            "alloc": num("Alloc system memory"), "watts": int(pw.group(1)) / 1000 if pw else None}


PRESSURE = {1: ("normal", GREEN), 2: ("warn", AMBER), 4: ("critical", RED)}


def parse_ioreg(text: str) -> dict:
    """AppleSmartBattery -> the numbers the battery popup needs (mA, mV, mAh, mW as ioreg gives them)."""
    def num(key: str, scope: str = text) -> int | None:
        m = re.search(r'"%s"\s*=\s*(-?\d+)' % key, scope)
        return int(m.group(1)) if m else None

    def yes(key: str) -> bool:
        return bool(re.search(r'"%s"\s*=\s*Yes' % key, text))

    amp = re.search(r'^\s*\|?\s*"Amperage"\s*=\s*(\d+)', text, re.M)
    amperage = int(amp.group(1)) if amp else 0
    if amperage >= 1 << 63:
        amperage -= 1 << 64                          # discharge shows up as an unsigned 64-bit number
    batt = re.search(r'"BatteryData"\s*=\s*\{[^}]*\}', text)
    bd = batt.group(0) if batt else ""
    adapter = re.search(r'"AdapterDetails"\s*=\s*\{[^}]*?"Watts"=(\d+)', text)
    return {
        "pct": num("CurrentCapacity"), "max_pct": num("MaxCapacity"), "cycles": num("CycleCount"),
        "design": num("DesignCapacity", bd) or num("DesignCapacity"),
        "nominal": num("NominalChargeCapacity", bd) or num("NominalChargeCapacity") or num("AppleRawMaxCapacity"),
        "full": num("FullChargeCapacity", bd),
        "voltage": num("Voltage"), "amperage": amperage,
        "power_in": num("SystemPowerIn"), "system_load": num("SystemLoad"),
        "adapter_w": int(adapter.group(1)) if adapter else None,
        "charging": yes("IsCharging"), "plugged": yes("ExternalConnected"),
    }


def parse_pmset(text: str) -> dict:
    """pmset -g batt -> {'pct', 'state', 'remaining': 'H:MM'|None}."""
    m = re.search(r"(\d+)%;\s*([a-z ]+?);\s*(?:(\d+:\d+) remaining|\(no estimate\)|[^;]*)", text)
    return {"pct": int(m.group(1)) if m else None, "state": m.group(2).strip() if m else "",
            "remaining": m.group(3) if m and m.group(3) and m.group(3) != "0:00" else None}


# ---------- row builders ----------

def gb(b: float) -> str:
    return f"{b / 2**30:.1f}G"


def cpu_rows(cpu: tuple[float, float, float] | None, used: int, total: int, pressure: int, free_pct: int | None,
             swap: tuple[float, float], load: list[float], cores: int, procs: list[tuple[str, float]],
             gpu: dict | None = None) -> list[tuple[str, str]]:
    """(text, colour) per popup line, header first."""
    pname, pcol = PRESSURE.get(pressure, ("normal", GREEN))
    rows = []
    if cpu:
        rows.append((f"CPU       {cpu[0] + cpu[1]:4.1f}%   user {cpu[0]:.1f}  sys {cpu[1]:.1f}", WHITE))
    else:
        rows.append(("CPU       reading...", DIM))
    rows.append((f"Memory    {gb(used)} / {gb(total)}  {used * 100 / max(total, 1):.0f}% used", WHITE))
    rows.append((f"Pressure  {pname}" + (f"  ({free_pct}% free)" if free_pct is not None else ""), pcol))
    rows.append((f"Swap      {swap[0] / 1024:.1f}G / {swap[1] / 1024:.1f}G", WHITE))
    rows.append(("Load      " + "  ".join(f"{x:.2f}" for x in load) + f"   ({cores} cores)", WHITE))
    g = gpu or {}
    rows.append((f"GPU       {g['pct']}%" if g.get("pct") is not None else "GPU       unknown", WHITE))
    rows.append((f"GPU mem   {gb(g['mem'])} in use" + (f" of {gb(g['alloc'])} allocated" if g.get("alloc") else "") if g.get("mem") is not None else "GPU mem   unknown", WHITE))
    rows.append((f"GPU power {g['watts']:.1f}W" if g.get("watts") is not None else "GPU power not reported on this Mac", DIM))
    rows.append(("Top 5 by CPU", DIM))
    for name, pct in procs:
        rows.append((f"  {name[:22]:<22} {pct:5.1f}%", WHITE))
    return rows


def hm(text: str | None) -> str:
    if not text:
        return "estimating"
    h, m = text.split(":")
    return f"{int(h)}h {int(m):02d}m"


def battery_rows(b: dict, pm: dict) -> list[tuple[str, str]]:
    pct = pm.get("pct") if pm.get("pct") is not None else b.get("pct")
    state = pm.get("state") or ("charging" if b.get("charging") else "on battery")
    rows = [(f"Battery   {pct}%   {state}", WHITE)]
    volts = (b.get("voltage") or 0) / 1000
    amps = abs(b.get("amperage") or 0) / 1000
    watts = amps * volts
    if b.get("charging"):
        rows.append((f"Power     {(b.get('power_in') or 0) / 1000:.0f}W in" + (f" of {b['adapter_w']}W adapter" if b.get("adapter_w") else ""), WHITE))
        rows.append((f"Time      {hm(pm.get('remaining'))} to full", WHITE))
        rows.append((f"Charge    {amps:.2f}A  {watts:.1f}W into the battery", WHITE))
    elif b.get("plugged"):
        rows.append((f"Power     {(b.get('power_in') or 0) / 1000:.0f}W in, holding", WHITE))
        rows.append(("Time      on the charger", WHITE))
        rows.append((f"Charge    {amps:.2f}A  {watts:.1f}W", WHITE))
    else:
        rows.append((f"Power     {(b.get('system_load') or 0) / 1000:.1f}W drawn by the Mac", WHITE))
        rows.append((f"Time      {hm(pm.get('remaining'))} left", WHITE))
        rows.append((f"Discharge {amps:.2f}A  {watts:.1f}W out of the battery", WHITE))
    nom, des = b.get("nominal"), b.get("design")
    if nom and des:
        health = nom * 100 / des
        rows.append((f"Health    {health:.0f}%   max {nom} of {des} mAh", WHITE if health >= 80 else AMBER))
    else:
        rows.append(("Health    unknown", DIM))
    rows.append((f"Cycles    {b.get('cycles', '?')}", WHITE))
    rows.append(("Open battery watch...", DIM))
    return rows


def clock(sec: float) -> str:
    s = max(int(sec), 0)
    return f"{s // 60}:{s % 60:02d}"


def progress_bar(pos_ms: float, dur_ms: float, width: int = 20) -> str:
    frac = 0.0 if dur_ms <= 0 else min(max(pos_ms / dur_ms, 0.0), 1.0)
    full = round(frac * width)
    return "▰" * full + "▱" * (width - full)


def music_rows(s: dict | None, now: float, star: str = "?") -> list[tuple[str, str]]:
    """Rows for the music popup. s = the last /me/player sample {'state','name','artist','device','pos_ms','dur_ms','at'} or None."""
    if not s or s.get("state") in ("nologin", "relogin"):
        return [("Spotify is not connected", WHITE), ("Run: tyler spotify login", DIM)]
    if not s.get("name"):
        return [("Nothing playing", WHITE), ("Start Spotify on a device", DIM)]
    pos = s.get("pos_ms", 0) + ((now - s.get("at", now)) * 1000 if s.get("state") == "playing" else 0)
    locked = bool(FIRE.search(s.get("device", "")))
    rows = [(s["name"][:34], WHITE), (s.get("artist", "")[:34], DIM),
            (f"{clock(pos / 1000)} {progress_bar(pos, s.get('dur_ms', 0))} {clock(s.get('dur_ms', 0) / 1000)}", GREEN)]
    dev = s.get("device", "")
    if locked:
        rows.append((f"On {dev[:26]}: controls off", AMBER))
    else:
        rows.append(("  Previous", WHITE))
        rows.append(("  Pause" if s.get("state") == "playing" else "  Play", WHITE))
        rows.append(("  Next", WHITE))
    rows.append((("★ Saved to Library" if star == "1" else "☆ Save to Library") if star in ("0", "1") else "☆ Save to Library", AMBER if star == "1" else WHITE))
    return rows


# ---------- sketchybar glue ----------

def sb(*args: str) -> None:
    run([SB, *args], timeout=5)


def draw(name: str, rows: list[tuple[str, str]], slots: int) -> None:
    """Set the popup's row items; unused slots are hidden."""
    args: list[str] = []
    for i in range(1, slots + 1):
        if i <= len(rows):
            text, col = rows[i - 1]
            args += ["--set", f"{name}.r{i}", "drawing=on", f"label={text}", f"label.color={col}"]
        else:
            args += ["--set", f"{name}.r{i}", "drawing=off"]
    sb(*args)


def popup_open(name: str) -> bool:
    try:
        return OPEN_FILE.read_text().strip() == name
    except OSError:
        return False


def sysctl(key: str) -> str:
    return run(["/usr/sbin/sysctl", "-n", key] if not key.startswith("vm.swap") else ["/usr/sbin/sysctl", key], 2).strip()


def read_cpu() -> tuple[float, float, float] | None:
    return parse_top_cpu(run(["/usr/bin/top", "-l", "2", "-s", "1", "-n", "0"], 6))


def read_gpu() -> dict:
    return parse_gpu(run(["/usr/sbin/ioreg", "-rc", "IOAccelerator", "-d", "1"], 3))


def read_mem() -> tuple[int, int]:
    vm = parse_vm_stat(run(["/usr/bin/vm_stat"], 2))
    try:
        total = int(sysctl("hw.memsize"))
    except ValueError:
        total = 0
    return mem_used(vm), total


def cpu_tick() -> int:
    CACHE.mkdir(parents=True, exist_ok=True)
    lock = open(CACHE / "cpu_tick.lock", "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0                                   # a slower read is still running: never pile up
    cpu = read_cpu()
    used, total = read_mem()
    ram = used * 100 / total if total else 0
    pct = f"{cpu[0] + cpu[1]:.0f}%" if cpu else "--%"
    gpu = read_gpu()
    gp = f"{gpu['pct']}%" if gpu.get("pct") is not None else "--%"
    sb("--set", "cpu", f"label=CPU {pct} RAM {ram:.0f}% GPU {gp}")
    if popup_open("cpu"):
        fill_cpu(cpu)
    return 0


def fill_cpu(cpu: tuple[float, float, float] | None = None) -> None:
    cpu = cpu or read_cpu()
    used, total = read_mem()
    try:
        pressure = int(sysctl("kern.memorystatus_vm_pressure_level"))
    except ValueError:
        pressure = 1
    free_pct = parse_free_pct(run(["/usr/bin/memory_pressure"], 3))
    try:
        cores = int(sysctl("hw.ncpu"))
    except ValueError:
        cores = 0
    rows = cpu_rows(cpu, used, total, pressure, free_pct, parse_swap(sysctl("vm.swapusage")),
                    parse_loadavg(sysctl("vm.loadavg")), cores, parse_ps(run(["/bin/ps", "-Aceo", "pcpu,comm", "-r"], 3)), read_gpu())
    draw("cpu", rows, CPU_ROWS)


def fill_battery() -> None:
    b = parse_ioreg(run(["/usr/sbin/ioreg", "-rn", "AppleSmartBattery"], 3))
    pm = parse_pmset(run(["/usr/bin/pmset", "-g", "batt"], 3))
    draw("battery", battery_rows(b, pm), BATT_ROWS)


# music: one /me/player sample at most every 8 s while the popup is open; the bar between samples is worked out locally.
SAMPLE = CACHE / "music_sample.json"


def spotify():
    sys.path.insert(0, str(LIB))
    try:
        import spotify_library as sl  # type: ignore
        return sl
    except Exception:
        return None


def sample(force: bool = False) -> dict | None:
    fake = os.environ.get("TKOS_MUSIC_FAKE")
    if fake:
        d = json.loads(Path(fake).read_text())
        return {**d, "at": time.time()}
    try:
        s = json.loads(SAMPLE.read_text())
        if not force and time.time() - s.get("at", 0) < 8:
            return s
    except Exception:
        pass
    sl = spotify()
    if not sl or not sl.token():
        return {"state": "nologin", "at": time.time()}
    status, body = sl._call("GET", "/me/player", {"additional_types": "episode"})
    if status == 429 or status == 0:
        try:
            return json.loads(SAMPLE.read_text())
        except Exception:
            return None
    item = (body or {}).get("item") or {} if status == 200 else {}
    imgs = (item.get("album") or {}).get("images") or []
    s = {"state": ("playing" if body.get("is_playing") else "paused") if item else "idle", "at": time.time(),
         "name": item.get("name", ""), "id": item.get("id", "") if item.get("type") != "episode" else "",
         "artist": ", ".join(a.get("name", "") for a in item.get("artists", [])[:2]),
         "device": ((body or {}).get("device") or {}).get("name", ""),
         "pos_ms": (body or {}).get("progress_ms") or 0, "dur_ms": item.get("duration_ms") or 0,
         "art": (imgs[1] if len(imgs) > 1 else imgs[0]).get("url", "") if imgs else ""} if item else {"state": "idle", "at": time.time()}
    CACHE.mkdir(parents=True, exist_ok=True)
    SAMPLE.write_text(json.dumps(s))
    return s


def art_path(url: str) -> str:
    """The album cover on disk (downloaded once per image); '' when there is none."""
    if not url:
        return ""
    if url.startswith("/") and Path(url).exists():
        return url
    p = CACHE / "art" / (hashlib.sha1(url.encode()).hexdigest()[:16] + ".jpg")
    if not p.exists():
        try:
            p.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(url, timeout=6) as r:
                p.write_bytes(r.read())
            for old in sorted(p.parent.glob("*.jpg"), key=lambda x: x.stat().st_mtime)[:-20]:
                old.unlink()                       # keep the last 20 covers
        except Exception:
            return ""
    return str(p)


def fill_music(force: bool = False) -> None:
    s = sample(force)
    star = "?"
    sl = spotify() if s and s.get("id") and not os.environ.get("TKOS_MUSIC_FAKE") else None
    if sl:
        c = sl.cached(s["id"])
        star = "1" if c else "0" if c is False else "?"
    elif s and os.environ.get("TKOS_MUSIC_FAKE"):
        star = str(s.get("saved", "?"))
    rows = music_rows(s, time.time(), star)
    art = art_path((s or {}).get("art", "")) if s and s.get("name") else ""
    if art:
        sb("--set", "music_pop.art", "drawing=on", f"background.image={art}", "background.image.drawing=on")
    else:
        sb("--set", "music_pop.art", "drawing=off")
    draw("music_pop", rows, MUSIC_ROWS)
    # row indexes of the controls shift with the row count; click scripts are rebound to match
    for i, (text, _) in enumerate(rows, 1):
        act = {"  Previous": "prev", "  Pause": "playpause", "  Play": "playpause", "  Next": "next"}.get(text)
        if text.endswith("Save to Library") or text.startswith("★"):
            act = "star"
        sb("--set", f"music_pop.r{i}", "click_script=" + (f"python3 {Path(__file__).resolve()} ctl {act}" if act else ""))


def ctl(action: str) -> int:
    """Music controls. Only ever acts on a device that is already playing or paused, and never on Yuri's Fire tablet."""
    sl = spotify()
    if not sl or not sl.token():
        return 1
    if action == "star":
        sl.toggle()
        fill_music(force=True)
        return 0
    s = sample(force=True)
    if not s or s.get("state") not in ("playing", "paused") or FIRE.search(s.get("device", "")):
        return 1
    route = {"prev": ("POST", "/me/player/previous"), "next": ("POST", "/me/player/next"),
             "playpause": ("PUT", "/me/player/pause" if s["state"] == "playing" else "/me/player/play")}.get(action)
    if route:
        sl._call(route[0], route[1], {})
        time.sleep(0.4)
        fill_music(force=True)
    return 0


def main(argv: list[str]) -> int:
    cmd = argv[0] if argv else ""
    if cmd == "cpu-tick":
        return cpu_tick()
    if cmd == "fill" and len(argv) > 1:
        {"cpu": fill_cpu, "battery": fill_battery, "music": lambda: fill_music(True)}.get(argv[1], lambda: None)()
        return 0
    if cmd == "tick-music":
        fill_music()
        return 0
    if cmd == "ctl" and len(argv) > 1:
        return ctl(argv[1])
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
