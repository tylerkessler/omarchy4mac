"""Walk pill + panel payload (tyler-os #1394). Pure functions plus a tiny CLI; no SketchyBar calls.

Reads walks.jsonl / walks_active.json / walk_samples.jsonl and GET /api/walk.
Never talks to CoreLocation. Empty-state when files and Digit are missing.

CLI:
  walk_data.py label     prints the pill label, or nothing to hide the pill
  walk_data.py panel     writes ~/.cache/omarchy4mac/walk_panel.html (JSON baked in)
  walk_data.py open      panel + toggle the Hammerspoon webview
  walk_data.py lid on|off   ~/Scripts/donna-walk-lid/mode (walk-lid only; no walk-start)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

M_PER_MI = 1609.344
TZ = ZoneInfo("America/New_York")
API = os.environ.get("TKOS_WALK_API", "http://127.0.0.1:8765/api/walk")
TRAIL_API = os.environ.get("TKOS_TRAIL_API", "http://127.0.0.1:8765/api/location/trail")
VAULT = Path(os.environ.get("TYLER_VAULT", Path.home() / "Vaults" / "Tyler's Vault"))
HEALTH = VAULT / "00_System" / "health"
WALKS = Path(os.environ.get("TKOS_WALKS_JSONL", HEALTH / "walks.jsonl"))
ACTIVE = Path(os.environ.get("TKOS_WALKS_ACTIVE", HEALTH / "walks_active.json"))
SAMPLES = Path(os.environ.get("TKOS_WALK_SAMPLES", HEALTH / "walk_samples.jsonl"))
LID_ENV = Path(os.environ.get("TKOS_WALK_LID_ENV", Path.home() / ".donna-walk-lid" / "WALK_LID_MODE.env"))
CACHE = Path(os.environ.get("TKOS_WALK_CACHE", Path.home() / ".cache" / "omarchy4mac"))
MODE_BIN = Path.home() / "Scripts" / "donna-walk-lid" / "mode"
WALK_NOTE = VAULT / "11_Grok_Bot" / "Donna" / "WALKING - Unplug and Lid Close.md"
LIVE_NOTE = VAULT / "00_System" / "context" / "WALK.md"
PLIST = Path.home() / "Library" / "LaunchAgents" / "com.tylerkessler.lifegui.walk.plist"
HERE = Path(__file__).resolve().parent
SKETCHY = HERE.parent
REPO = SKETCHY.parent
HTML_TMPL = Path(os.environ.get("TKOS_WALK_HTML", SKETCHY / "walk_panel.html"))
LUA = REPO / "hammerspoon" / "walk_panel.lua"


def fmt_mi(meters: float | None) -> str:
    if meters is None:
        return "0"
    miles = float(meters) / M_PER_MI
    s = f"{miles:.2f}".rstrip("0").rstrip(".")
    return s or "0"


def miles_of(meters: float | None) -> float:
    return round(float(meters or 0) / M_PER_MI, 3)


def fmt_dur(secs: float | None) -> str:
    s = int(float(secs or 0))
    if s < 60:
        return f"{s}s"
    m = s // 60
    if m < 60:
        return f"{m}m"
    return f"{m // 60}h {m % 60:02d}m"


def fmt_pace(elapsed_s: float | None, distance_m: float | None) -> str | None:
    miles = miles_of(distance_m)
    elapsed = float(elapsed_s or 0)
    if miles < 0.03 or elapsed <= 10:
        return None
    sec = elapsed / miles
    return f"{int(sec // 60)}:{int(sec % 60):02d}/mi"


def place_name(place) -> str:
    if not place:
        return ""
    if isinstance(place, str):
        return place.strip()
    if isinstance(place, dict):
        for k in ("name", "place_name", "label", "title"):
            v = place.get(k)
            if v:
                return str(v).strip()
    return ""


def parse_ts(ts: str | None) -> datetime | None:
    if not ts:
        return None
    try:
        d = datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
    except Exception:
        return None
    if d.tzinfo is None:
        d = d.replace(tzinfo=TZ)
    return d.astimezone(TZ)


def walk_day(walk: dict) -> datetime | None:
    return parse_ts(walk.get("ended_at") or walk.get("started_at"))


def parse_walks(lines: list[str]) -> list[dict]:
    rows = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except Exception:
            continue
    return rows


def load_walks(path: Path | None = None) -> list[dict]:
    p = path or WALKS
    try:
        return parse_walks(p.read_text(encoding="utf-8", errors="replace").splitlines())
    except FileNotFoundError:
        return []
    except Exception:
        return []


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return {}


def fetch_json(url: str, timeout: float = 0.4) -> dict | None:
    if not url:
        return None
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except Exception:
        return None


def live_status() -> dict:
    """Digit GET /api/walk, else walks_active.json. Never invents metrics."""
    st = fetch_json(API) if API else None
    if isinstance(st, dict) and st.get("ok") is not False:
        return st
    active = load_json(ACTIVE)
    if not active:
        return {}
    dist = active.get("distance_m")
    elapsed = active.get("elapsed_s")
    metrics = {}
    if active.get("phase") == "walk":
        metrics = {
            "miles": miles_of(dist),
            "pace": fmt_pace(elapsed, dist),
            "steps_est": None,
            "kcal_est": None,
            "effort": None,
            "activity": "walk",
            "one_liner": None,
        }
    return {**active, "metrics": metrics, "ok": True}


def in_range(walk: dict, start: datetime, end: datetime) -> bool:
    d = walk_day(walk)
    return bool(d and start <= d < end)


def sum_walks(walks: list[dict], start: datetime, end: datetime) -> dict:
    miles = 0.0
    dur = 0.0
    n = 0
    for w in walks:
        if not in_range(w, start, end):
            continue
        miles += miles_of(w.get("distance_m"))
        dur += float(w.get("elapsed_s") or 0)
        n += 1
    return {"miles": round(miles, 3), "duration_s": dur, "count": n}


def day_start(now: datetime) -> datetime:
    n = now.astimezone(TZ)
    return n.replace(hour=0, minute=0, second=0, microsecond=0)


def week_start(now: datetime) -> datetime:
    d = day_start(now)
    return d - timedelta(days=d.weekday())  # Monday


def today_miles(walks: list[dict], status: dict | None, now: datetime) -> float:
    d0 = day_start(now)
    total = sum_walks(walks, d0, d0 + timedelta(days=1))["miles"]
    st = status or {}
    if st.get("phase") == "walk":
        m = (st.get("metrics") or {}).get("miles")
        if m is None:
            m = miles_of(st.get("distance_m"))
        total += float(m or 0)
    return round(total, 3)


def day_buckets(walks: list[dict], days: int, now: datetime) -> list[dict]:
    d0 = day_start(now)
    out = []
    for i in range(days - 1, -1, -1):
        start = d0 - timedelta(days=i)
        end = start + timedelta(days=1)
        s = sum_walks(walks, start, end)
        out.append({"date": start.date().isoformat(), "miles": s["miles"], "count": s["count"]})
    return out


def pill_label(status: dict | None, today_mi: float, *, condensed: bool = False) -> str:
    """Walking: 'Walk · 1.24 mi'. Idle: 'Walk · 2.1 mi today' or 'Walk'."""
    st = status or {}
    if st.get("phase") == "walk":
        m = (st.get("metrics") or {}).get("miles")
        if m is None:
            m = miles_of(st.get("distance_m"))
        meters = float(m or 0) * M_PER_MI
        return f"Walk · {fmt_mi(meters)} mi"
    if today_mi > 0:
        label = f"Walk · {fmt_mi(today_mi * M_PER_MI)} mi today"
        if condensed and len(label) > 16:
            return f"Walk · {fmt_mi(today_mi * M_PER_MI)} mi"
        return label
    return "Walk"


def sources_present() -> bool:
    return WALKS.exists() or ACTIVE.exists() or bool(API)


def condensed() -> bool:
    try:
        from extras import condensed as cu

        return bool(cu())
    except Exception:
        return False


def route_label(walk: dict) -> str:
    a = place_name(walk.get("from_place"))
    b = place_name(walk.get("to_place"))
    if a and b:
        return f"{a} → {b}"
    return b or a or "—"


def summarize_walk(walk: dict, status: dict | None = None) -> dict:
    dist = walk.get("distance_m")
    elapsed = walk.get("elapsed_s")
    metrics = (status or {}).get("metrics") or {}
    started = parse_ts(walk.get("started_at"))
    return {
        "walk_id": walk.get("walk_id"),
        "phase": walk.get("phase") or "closed",
        "miles": miles_of(dist) if dist is not None else metrics.get("miles"),
        "miles_label": fmt_mi(dist) if dist is not None else fmt_mi((metrics.get("miles") or 0) * M_PER_MI),
        "duration": fmt_dur(elapsed if elapsed is not None else metrics.get("elapsed_s")),
        "duration_s": elapsed,
        "pace": metrics.get("pace") or walk.get("pace_min_per_mi") and f"{walk['pace_min_per_mi']}/mi" or fmt_pace(elapsed, dist),
        "steps_est": metrics.get("steps_est"),
        "kcal_est": metrics.get("kcal_est") if metrics.get("kcal_est") is not None else walk.get("kcal_est"),
        "effort": metrics.get("effort"),
        "activity": metrics.get("activity"),
        "from": place_name(walk.get("from_place") or walk.get("from_place")),
        "to": place_name(walk.get("to_place") or walk.get("dwell_place")),
        "route": route_label(walk),
        "started_at": walk.get("started_at"),
        "ended_at": walk.get("ended_at"),
        "date": started.strftime("%a %b %-d") if started else "",
        "clamshell": walk.get("clamshell"),
        "imu": walk.get("imu"),
    }


def downsample(pts: list[list[float]], n: int = 180) -> list[list[float]]:
    if len(pts) <= n:
        return pts
    if n < 2:
        return pts[:1]
    out = [pts[0]]
    step = (len(pts) - 1) / (n - 1)
    for i in range(1, n - 1):
        out.append(pts[int(round(i * step))])
    out.append(pts[-1])
    return out


def load_samples(walk_ids: set[str], path: Path | None = None, max_pts: int = 180) -> dict[str, list]:
    if not walk_ids:
        return {}
    p = path or SAMPLES
    buckets: dict[str, list] = {wid: [] for wid in walk_ids}
    try:
        with p.open(encoding="utf-8", errors="replace") as f:
            for line in f:
                if '"walk_id"' not in line:
                    continue
                try:
                    row = json.loads(line)
                except Exception:
                    continue
                wid = row.get("walk_id")
                if wid not in buckets:
                    continue
                lat, lon = row.get("lat"), row.get("lon")
                if lat is None or lon is None:
                    continue
                buckets[wid].append([float(lat), float(lon)])
    except FileNotFoundError:
        return {wid: [] for wid in walk_ids}
    except Exception:
        return {wid: [] for wid in walk_ids}
    return {wid: downsample(pts, max_pts) for wid, pts in buckets.items()}


def lid_status(path: Path | None = None) -> dict:
    env = {}
    p = path or LID_ENV
    try:
        for line in p.read_text(encoding="utf-8", errors="replace").splitlines():
            if "=" in line and not line.strip().startswith("#"):
                k, _, v = line.partition("=")
                env[k.strip()] = v.strip()
    except Exception:
        pass
    on = env.get("WALK_LID_MODE") == "1"
    return {"on": on, "label": "on" if on else "off", "armed_at": env.get("ARMED_AT") or "", "exists": p.exists()}


def tracker_status() -> dict:
    loaded = PLIST.exists()
    age_s = None
    active = load_json(ACTIVE)
    ts = parse_ts(active.get("updated_at") or (active.get("last_fix") or {}).get("ts"))
    if ts:
        age_s = max(0, int((datetime.now(TZ) - ts).total_seconds()))
    return {"loaded": loaded, "last_sample_age_s": age_s, "plist": str(PLIST) if loaded else ""}


def trail_fallback() -> list[list[float]]:
    data = fetch_json(TRAIL_API) if TRAIL_API else None
    if not isinstance(data, dict):
        return []
    pts = []
    for row in data.get("recent") or []:
        lat, lon = row.get("lat"), row.get("lon")
        if lat is not None and lon is not None:
            pts.append([float(lat), float(lon)])
    return downsample(pts)


def panel_payload(walks: list[dict] | None = None, status: dict | None = None, now: datetime | None = None,
                  samples: dict | None = None) -> dict:
    now = now or datetime.now(TZ)
    walks = walks if walks is not None else load_walks()
    status = status if status is not None else live_status()
    d0 = day_start(now)
    today = sum_walks(walks, d0, d0 + timedelta(days=1))
    week = sum_walks(walks, week_start(now), d0 + timedelta(days=1))
    if status.get("phase") == "walk":
        extra = float((status.get("metrics") or {}).get("miles") or miles_of(status.get("distance_m")))
        extra_s = float(status.get("elapsed_s") or (status.get("metrics") or {}).get("elapsed_s") or 0)
        today = {**today, "miles": round(today["miles"] + extra, 3),
                 "duration_s": today["duration_s"] + extra_s, "count": today["count"] + 1}
        week = {**week, "miles": round(week["miles"] + extra, 3),
                "duration_s": week["duration_s"] + extra_s, "count": week["count"] + 1}

    now_card = None
    if status.get("phase") == "walk":
        now_card = summarize_walk({
            "walk_id": status.get("walk_id"),
            "phase": "walk",
            "distance_m": status.get("distance_m") or ((status.get("metrics") or {}).get("miles") or 0) * M_PER_MI,
            "elapsed_s": status.get("elapsed_s") or (status.get("metrics") or {}).get("elapsed_s"),
            "from_place": status.get("from_place"),
            "to_place": status.get("dwell_place"),
            "started_at": status.get("started_at") or (load_json(ACTIVE).get("phase_since")),
        }, status)
    elif walks:
        now_card = summarize_walk(walks[-1])

    history = [summarize_walk(w) for w in reversed(walks[-20:])]
    want_ids = {h["walk_id"] for h in history if h.get("walk_id")}
    if status.get("walk_id"):
        want_ids.add(status["walk_id"])
    routes = samples if samples is not None else load_samples(want_ids)
    map_id = None
    if status.get("phase") == "walk" and status.get("walk_id") and routes.get(status["walk_id"]):
        map_id = status["walk_id"]
    else:
        for h in history:
            if routes.get(h["walk_id"]):
                map_id = h["walk_id"]
                break
    fallback = []
    if not map_id:
        fallback = trail_fallback()

    return {
        "empty": not walks and status.get("phase") != "walk",
        "now": now_card,
        "dwell_place": status.get("dwell_place") or place_name(status.get("from_place")),
        "phase": status.get("phase") or "unknown",
        "today": {**today, "miles_label": fmt_mi(today["miles"] * M_PER_MI), "duration": fmt_dur(today["duration_s"])},
        "week": {**week, "miles_label": fmt_mi(week["miles"] * M_PER_MI), "duration": fmt_dur(week["duration_s"])},
        "graph7": day_buckets(walks, 7, now),
        "graph30": day_buckets(walks, 30, now),
        "history": history,
        "routes": routes,
        "map_id": map_id,
        "trail_fallback": fallback,
        "lid": lid_status(),
        "tracker": tracker_status(),
        "notes": {
            "walk": WALK_NOTE.exists(),
            "live": LIVE_NOTE.exists(),
            "walk_url": _obsidian_url(WALK_NOTE),
            "live_url": _obsidian_url(LIVE_NOTE),
        },
        "pause_why": "Silence is only TKOS_WALK_SILENT=1 on the walk process; there is no persistent toggle.",
        "gps_why": "No GPS-logging flag. Tracker is read-only (do not unload the LaunchAgent).",
        "kcal_note": "kcal and steps are GPS+IMU estimates, not Apple Health.",
    }


def _obsidian_url(path: Path) -> str:
    try:
        rel = path.relative_to(VAULT).as_posix()
    except Exception:
        rel = path.name
    from urllib.parse import quote
    return "obsidian://open?vault=" + quote("Tyler's Vault") + "&file=" + quote(rel)


def emit_html(payload: dict | None = None) -> Path:
    payload = payload if payload is not None else panel_payload()
    tmpl = HTML_TMPL.read_text(encoding="utf-8")
    html = tmpl.replace("__WALK_JSON__", json.dumps(payload, default=str))
    CACHE.mkdir(parents=True, exist_ok=True)
    out = CACHE / "walk_panel.html"
    out.write_text(html, encoding="utf-8")
    (CACHE / "walk_panel.json").write_text(json.dumps(payload, default=str), encoding="utf-8")
    return out


def open_panel() -> int:
    html = emit_html()
    lua = LUA
    if not lua.exists():
        print(html)
        return 0
    # Toggle via Hammerspoon; do not hs.reload (that restarts the whole config).
    snippet = (
        f'dofile("{lua}"); '
        f'tkosWalkToggle("{html.as_posix()}")'
    )
    hs = "/opt/homebrew/bin/hs"
    cmd = [hs, "-c", snippet] if Path(hs).exists() else ["hs", "-c", snippet]
    try:
        subprocess.run(cmd, check=False, timeout=3)
    except Exception:
        return 1
    return 0


def label_cli() -> str:
    if not sources_present() and not WALKS.exists() and not ACTIVE.exists():
        st = live_status()
        if not st:
            return ""
    walks = load_walks()
    st = live_status()
    if not walks and not st and not WALKS.exists() and not ACTIVE.exists():
        return ""
    today = today_miles(walks, st, datetime.now(TZ))
    return pill_label(st, today, condensed=condensed())


def lid_set(which: str) -> int:
    if which not in ("on", "off"):
        return 2
    if not MODE_BIN.exists():
        print("missing donna-walk-lid/mode", file=sys.stderr)
        return 1
    # Walk-lid CLI only. Never donna-walk walk-start / walk-end (those post webhooks).
    r = subprocess.run([str(MODE_BIN), which], timeout=20)
    return r.returncode


def main(argv: list[str]) -> int:
    cmd = argv[0] if argv else ""
    if cmd == "label":
        print(label_cli())
        return 0
    if cmd == "panel":
        print(emit_html())
        return 0
    if cmd == "open":
        return open_panel()
    if cmd == "lid" and len(argv) > 1:
        return lid_set(argv[1])
    if cmd == "json":
        print(json.dumps(panel_payload(), default=str))
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
