"""Logic for the YouTube and touch-grass pills (tyler-os #1381). Pure functions plus a tiny CLI; no SketchyBar calls.

CLI (called by plugins/youtube.sh and plugins/touch_grass.sh):
  extras.py youtube            stdin = `aerospace list-windows` lines "app|title"; prints the video title or nothing
  extras.py grass IDLE_NS      one tick of the touch-grass timer; prints "show|label" (show is 1 or 0)
  extras.py grass-snooze       snooze the pill for 15 minutes
  extras.py width TEXT [CAP]   prints "pixels chars scrolls(0|1)" for a label
  extras.py condensed          prints 1 while the computer-use banner needs the room
"""
from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path

CHAR_W = 7.83            # Hack Nerd Font Bold 13 is monospace
MAX_CHARS = 80
CONDENSED_CHARS = 16
GRASS_AFTER = 2 * 3600   # active this long without a break
BREAK_IDLE = 10 * 60     # a break is 10+ minutes idle...
TICK_GAP = 3 * 60        # ...or a gap between ticks (lid shut, asleep): ticks come every 60 s
SNOOZE = 15 * 60

STATE_DIR = Path(os.environ.get("TKOS_STATE_DIR", Path.home() / ".local/state/tyler-os-vault"))
GRASS_FILE = Path(os.environ.get("TKOS_GRASS_FILE", Path.home() / ".cache/omarchy4mac/touch_grass.json"))
CU_LINE = Path(os.environ.get("TKOS_CU_LINE", STATE_DIR / "computer_use.line"))


def label_width(chars: int) -> int:
    return round(max(chars, 0) * CHAR_W)


def fit(text: str, condensed: bool = False) -> tuple[int, int, bool]:
    """(pixels, chars shown, scrolls). If the text fits the pill is exactly as long as it needs; only past the cap does it scroll."""
    cap = CONDENSED_CHARS if condensed else MAX_CHARS
    shown = min(len(text), cap)
    return label_width(shown), shown, len(text) > cap


def youtube_title(lines: list[str]) -> str | None:
    """The video title from Brave's window titles ("app|title" per line), or None when no YouTube video is open.
    Brave puts "<video> - YouTube" on a watch tab, with a "(3) " prefix when YouTube has notifications and a tail
    like " - Audio playing - Brave - <profile>". YouTube Music and the YouTube home page do not count."""
    for line in lines:
        app, _, title = line.partition("|")
        if app.strip() != "Brave Browser":
            continue
        # "<video> - YouTube" then Brave's own tail: " - Audio playing - High memory usage - 1.2 GB - Brave - <profile>"
        m = re.match(r"^(?:\(\d+\)\s*)?(.+?) - YouTube(?: - .*)?$", title.strip())
        title = m.group(1).strip() if m else ""
        if title:
            return title
    return None


def fmt_elapsed(secs: float) -> str:
    m = int(secs // 60)
    return f"{m // 60}h {m % 60:02d}m" if m >= 60 else f"{m}m"


def grass_step(state: dict, idle_secs: float, now: float) -> tuple[dict, bool, str]:
    """One 60-second tick. state = {'since', 'last', 'snooze'}. Returns (new state, show the pill, its label).

    A break (10+ minutes idle, or a gap since the last tick because the lid was shut or the Mac slept) restarts the clock
    and clears the pill. The pill shows once the clock reads 2 hours and the snooze (15 minutes after a click) is over."""
    since, last, snooze = state.get("since"), state.get("last"), state.get("snooze", 0)
    if since is None or last is None or idle_secs >= BREAK_IDLE or now - last > TICK_GAP:
        since, snooze = now, 0
    elapsed = now - since
    show = elapsed >= GRASS_AFTER and now >= snooze
    return {"since": since, "last": now, "snooze": snooze}, show, f"Touch grass · {fmt_elapsed(elapsed)}"


def _load(path: Path) -> dict:
    try:
        return json.loads(path.read_text())
    except Exception:
        return {}


def _save(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data))


def condensed() -> bool:
    """The computer-use banner is on (cu_bar.py writes 'active|start|text')."""
    try:
        return CU_LINE.read_text().split("|", 1)[0].strip() == "1"
    except Exception:
        return False


def main(argv: list[str]) -> int:
    cmd = argv[0] if argv else ""
    if cmd == "youtube":
        print(youtube_title(sys.stdin.read().splitlines()) or "")
    elif cmd == "grass":
        st, show, label = grass_step(_load(GRASS_FILE), float(argv[1]) / 1e9, time.time())
        _save(GRASS_FILE, st)
        print(f"{int(show)}|{label}")
    elif cmd == "grass-snooze":
        st = _load(GRASS_FILE)
        st["snooze"] = time.time() + SNOOZE
        _save(GRASS_FILE, st)
    elif cmd == "width":
        px, chars, scrolls = fit(argv[1], len(argv) > 2 and argv[2] == "condensed")
        print(px, chars, int(scrolls))
    elif cmd == "condensed":
        print(int(condensed()))
    else:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
