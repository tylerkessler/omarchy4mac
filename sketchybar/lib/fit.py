#!/usr/bin/env python3
"""Fit guard for the top bar (tyler-os #1440): left and right items never draw on top of each other.

SketchyBar lays the left group out from the left edge and the right group from the right edge and lets them overlap when the
screen is too narrow. This measures the gap between the last left item and the first right item on every display and, when they
meet, hides optional items one group at a time (DROP order). A group comes back only when the gap is wider than the width it had
when hidden plus a margin, so nothing flickers. Hiding sets associated_display to a display that does not exist, which leaves
each item's own drawing= alone (session_md.py, touch_grass.sh and the rest keep toggling drawing as before).

Run by the `fit` item (sketchybarrc) on a slow timer and on the events that change widths. State: ~/.cache/omarchy4mac/fit.json.
    fit.py            measure and fix
    fit.py status     print the gap and what is hidden
    TKOS_FIT_SHRINK=408 fit.py   act as if the screen were 1512 pt wide on a 1920 pt one
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

SB = "/opt/homebrew/bin/sketchybar"
STATE = Path.home() / ".cache" / "omarchy4mac" / "fit.json"
MIN_GAP = 12        # pt between the left and right groups before something goes
BACK_MARGIN = 24    # extra room a hidden group needs before it comes back
NOWHERE = "9"       # a display id that does not exist
SHRINK = float(os.environ.get("TKOS_FIT_SHRINK", "0"))   # test aid: pretend the screen is this many pt narrower (1920 -> 1512: 408)

# First to go first. The agents pill, CPU pill, clock and battery (right) and the left run up to the music pill always stay.
DROP = [
    ("session files", ["smd.gap", "smd.chip.0", "smd.chip.1", "smd.chip.2", "smd.chip.3", "smd.chip.4", "smd"]),
    ("touch grass", ["touch_grass"]),
    ("load dot", ["load"]),
    ("music icon", ["music_gap_r", "music_pop"]),
]
CENTER_OR_BRACKET = ("vibe_", "cpu_pill", "smd_pill", "cu_box")


def sb(*args: str) -> str:
    try:
        return subprocess.run([SB, *args], capture_output=True, text=True, timeout=3).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def query(name: str) -> dict:
    try:
        return json.loads(sb("--query", name) or "{}")
    except json.JSONDecodeError:
        return {}


def bar_items() -> list[str]:
    try:
        items = json.loads(sb("--query", "bar") or "{}").get("items", [])
    except json.JSONDecodeError:
        return []
    # Popup rows (cpu.r1, music_pop.art, ...) live under their pill, not on the bar.
    return [i for i in items if "." not in i or i.startswith("smd.")]


def rects(item: dict) -> dict[str, tuple[float, float]]:
    """display key -> (x, width) for each display the item is drawn on."""
    out = {}
    for disp, r in (item.get("bounding_rects") or {}).items():
        x, w = r["origin"][0], r["size"][0]
        if x > -9000 and w > 1:
            out[disp] = (x, w)
    return out


def measure() -> tuple[float | None, dict[str, float]]:
    """Smallest gap over all displays, and the drawn width of every item that is on screen."""
    left_end: dict[str, float] = {}
    right_start: dict[str, float] = {}
    widths: dict[str, float] = {}
    for name in bar_items():
        if name.startswith(CENTER_OR_BRACKET):
            continue
        d = query(name)
        pos = (d.get("geometry") or {}).get("position")
        if pos not in ("left", "right"):
            continue
        for disp, (x, w) in rects(d).items():
            widths[name] = max(widths.get(name, 0), w)
            if pos == "left":
                left_end[disp] = max(left_end.get(disp, 0), x + w)
            else:
                right_start[disp] = min(right_start.get(disp, 1e9), x)
    gaps = [right_start[k] - left_end[k] for k in left_end if k in right_start]
    return (min(gaps) - SHRINK if gaps else None), widths


def displays() -> str:
    try:
        ids = [str(d["arrangement-id"]) for d in json.loads(sb("--query", "displays") or "[]")]
    except (json.JSONDecodeError, KeyError):
        ids = []
    return ",".join(ids) or "1"


def load_state() -> list[list]:
    try:
        return json.loads(STATE.read_text())
    except (OSError, json.JSONDecodeError):
        return []


def save_state(hidden: list[list]) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(hidden))


def show(group: str, on: bool) -> None:
    where = displays() if on else NOWHERE
    items = dict(DROP)[group]
    sb(*[a for i in items for a in ("--set", i, f"associated_display={where}")])


def fit() -> int:
    if os.environ.get("SENDER") not in (None, "routine", "forced"):
        time.sleep(0.8)                            # let the pills finish their grow/shrink animation first
    hidden = load_state()
    for _ in range(len(DROP) + 1):
        gap, widths = measure()
        if gap is None:
            break
        names = [g for g, _ in hidden]
        if gap < MIN_GAP:
            nxt = next(((g, items) for g, items in DROP if g not in names and any(i in widths for i in items)), None)
            if not nxt:
                break
            g, items = nxt
            hidden.append([g, sum(widths.get(i, 0) + 8 for i in items if i in widths)])
            show(g, False)
        elif hidden and gap >= hidden[-1][1] + MIN_GAP + BACK_MARGIN:
            g, _w = hidden.pop()
            show(g, True)
        else:
            break
        save_state(hidden)
        time.sleep(0.3)
    save_state(hidden)
    return 0


def status() -> int:
    gap, _ = measure()
    hidden = load_state()
    print(f"gap {gap:.0f} pt" if gap is not None else "gap unknown")
    print("hidden: " + (", ".join(f"{g} ({w:.0f} pt)" for g, w in hidden) or "nothing"))
    return 0


if __name__ == "__main__":
    sys.exit(status() if sys.argv[1:] == ["status"] else fit())
