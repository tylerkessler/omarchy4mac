"""Pure logic for the bar's pills: text width, Spotify's view of a player state, the desktop number's colour.

No SketchyBar calls in here, so tests/test_pills.py can check every rule.  plugins/spotify_view.py applies the result.
"""
from __future__ import annotations

# Hack Nerd Font Bold 13 is monospace: 0.602 em per glyph.
CHAR_W = 7.83
MAX_CHARS = 80          # was 32; Tyler asked for 2-3x (tyler-os #1381). Longer than this scrolls.
CONDENSED_CHARS = 16    # while the computer-use banner (or another urgent item) needs the room
FG = "0xfff4eefe"
YELLOW = "0xffffd23f"
SPOTIFY_GREEN = "0xff1db954"
PLAYING_STATES = ("playing", "paused")


def label_width(chars: int) -> int:
    """Pixels the label needs for this many characters."""
    return round(max(chars, 0) * CHAR_W)


def with_alpha(color: str, alpha: int) -> str:
    """0xAARRGGBB with the alpha byte replaced (alpha 0-255)."""
    return f"0x{max(0, min(255, alpha)):02x}{color[4:]}"


def mix_white(color: str, alpha: int = 0xCC) -> str:
    """Halfway between a colour and white, semi-transparent, so the desktop behind it bleeds through (the desktop number)."""
    r, g, b = (int(color[i:i + 2], 16) for i in (4, 6, 8))
    return "0x{:02x}{:02x}{:02x}{:02x}".format(alpha, (r + 255) // 2, (g + 255) // 2, (b + 255) // 2)


def parse_line(line: str) -> dict:
    """spotify_library.py `now` -> {'state','name','artist','saved','device'}; anything unreadable is state 'error'."""
    parts = (line or "").rstrip("\n").split("\t")
    if len(parts) < 4 or parts[0] not in ("playing", "paused", "idle", "nologin", "relogin", "error"):
        return {"state": "error", "name": "", "artist": "", "saved": "?", "device": ""}
    parts += [""] * (5 - len(parts))
    return {"state": parts[0], "name": parts[1], "artist": parts[2], "saved": parts[3], "device": parts[4]}


def plan(p: dict, condensed: bool = False) -> dict:
    """What the Spotify pill shows for one player state.

    The pill never hides.  Nothing playing keeps the last song dimmed, or says Spotify (and what is missing) when there is none.
    If the text fits, the pill is exactly as long as it needs (no scrolling); past the cap the label scrolls inside the cap.
    """
    state = p.get("state", "error")
    name, artist = p.get("name", ""), p.get("artist", "")
    song = f"{artist} - {name}" if artist and name else (name or artist)
    live = state in PLAYING_STATES and bool(song)
    if state == "nologin" or state == "relogin":
        text, alpha = ("Spotify - connect" if not song else song), 0x80
    elif song:
        text, alpha = song, {"playing": 0xFF, "paused": 0xB3}.get(state, 0x73)
    else:
        text, alpha = "Spotify", 0x73
    cap = CONDENSED_CHARS if condensed else MAX_CHARS
    shown = min(len(text), cap)
    saved = p.get("saved", "?")
    return {
        "text": text,
        "max_chars": shown,
        "width": label_width(shown),
        "scrolls": len(text) > cap,
        "label_color": with_alpha(FG, alpha),
        "icon_color": with_alpha(FG, alpha),
        "play_icon": "" if state == "playing" else "",     # pause while playing, play otherwise
        "show_play": not condensed,
        "show_next": live and not condensed,
        "show_star": live,
        "star_icon": "★" if saved == "1" else "☆",
        "star_color": YELLOW if saved == "1" else with_alpha(FG, alpha if saved == "0" else 0x73),
    }
