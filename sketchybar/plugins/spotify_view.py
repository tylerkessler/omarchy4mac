#!/usr/bin/env python3
"""Draw the Spotify pill from the Spotify Web API (tyler-os coach/spotify_library.py `now`), no AppleScript, no Mac app needed.

Run by plugins/spotify.sh every few seconds (the API call itself is cached and rate limited in spotify_library.py)
and straight away on a track-change event.  Argument: --fresh for an event, so a cached answer is not reused.
The pill grows and shrinks with a tanh animation when the text length changes.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "lib"))
import pillcalc  # noqa: E402

HOME = Path.home()
LIB = Path(os.environ.get("TKOS_SPOTIFY_LIB", HOME / "Scripts/tyler-os-live/coach/spotify_library.py"))
STATE = Path(os.environ.get("TKOS_STATE_DIR", HOME / ".local/state/tyler-os-vault"))
MEMORY = HOME / ".cache" / "omarchy4mac" / "spotify_pill.json"      # the last width, to animate from
SB = os.environ.get("SKETCHYBAR", "/opt/homebrew/bin/sketchybar")
FRAMES = 18


def run(cmd: list[str], timeout: int = 8) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ""


def condensed() -> bool:
    """The computer-use banner is on (state line active|start|who), so Spotify gives the room back."""
    try:
        return (STATE / "computer_use.line").read_text().split("|", 1)[0].strip() == "1"
    except Exception:
        return False


def from_event(sender: str, info: str) -> dict | None:
    """Fallback when the Web API is not connected yet: the Mac app's own notification payload."""
    try:
        d = json.loads(info)
    except Exception:
        return None
    if sender == "media_change":
        if d.get("app") != "Spotify":
            return None
        st, name, artist = d.get("state", ""), d.get("title", ""), d.get("artist", "")
    else:
        st, name, artist = d.get("Player State", ""), d.get("Name", ""), d.get("Artist", "")
    return {"state": st.lower() if st.lower() in ("playing", "paused") else "idle", "name": name, "artist": artist, "saved": "?", "device": ""}


def commands(pl: dict, prev_width: int | None) -> list[list[str]]:
    """The sketchybar argument lists that draw this plan."""
    on = lambda b: "on" if b else "off"  # noqa: E731
    first = ["--set", "spotify", "drawing=on", f"label={pl['text']}", f"label.max_chars={pl['max_chars']}", f"icon.color={pl['icon_color']}",
             f"label.color={pl['label_color']}",
             "--set", "spotify_play", f"drawing={on(pl['show_play'])}", f"icon={pl['play_icon']}", f"icon.color={pl['icon_color']}",
             "--set", "spotify_next", f"drawing={on(pl['show_next'])}", f"icon.color={pl['icon_color']}",
             "--set", "spotify_star", f"drawing={on(pl['show_star'])}", f"icon={pl['star_icon']}", f"icon.color={pl['star_color']}"]
    if prev_width is None or prev_width == pl["width"]:
        return [first + ["--set", "spotify", f"label.width={pl['width']}"]]
    return [first + ["--animate", "tanh", str(FRAMES), "--set", "spotify", f"label.width={pl['width']}"]]


def main(argv: list[str]) -> int:
    fresh = "--fresh" in argv
    cmd = ["python3", str(LIB), "now"] + (["--fresh"] if fresh else [])
    p = pillcalc.parse_line(run(cmd))
    if p["state"] in ("error", "nologin", "relogin"):
        ev = from_event(os.environ.get("SENDER", ""), os.environ.get("INFO", ""))
        if ev:
            p = {**ev, "state": ev["state"]}
        elif p["state"] == "error":
            p = {**p, "state": "idle"}
    pl = pillcalc.plan(p, condensed())
    try:
        prev = json.loads(MEMORY.read_text()).get("width")
    except Exception:
        prev = None
    for args in commands(pl, prev):
        run([SB] + args, timeout=5)
    try:
        MEMORY.parent.mkdir(parents=True, exist_ok=True)
        MEMORY.write_text(json.dumps({"width": pl["width"]}))
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
