"""The bar's one palette for the Python-drawn pills (tyler-os #1425): read straight from live_vibe.sh, so shell and Python never drift.

    from palette import C
    C["GRAD_4"], C["STATUS_BAD"], ...

Every colour is a TKOS sunset tone. A name missing from live_vibe.sh falls back to the default below.
"""
from __future__ import annotations

import re
from pathlib import Path

VIBE = Path(__file__).resolve().parent.parent / "live_vibe.sh"
DEFAULTS = {
    "FG": "0xfff4eefe", "DIM": "0xff9a90b4", "SOFT": "0xffa99cc4", "PLUM": "0xf0240f2e",
    "SUN_LOGO": "0xffffb52e", "GRAD_1": "0xffff9a5c", "GRAD_2": "0xffff8b4b", "GRAD_3": "0xffff6fa3",
    "GRAD_4": "0xffe066ff", "GRAD_5": "0xff9d7bff", "GRAD_6": "0xffffca00",
    "STATUS_OK": "0xffc8b6ff", "STATUS_WARN": "0xffffb52e", "STATUS_BAD": "0xffff5a6e",
}


def load(path: Path = VIBE) -> dict[str, str]:
    out = dict(DEFAULTS)
    try:
        for k, v in re.findall(r'^export ([A-Z0-9_]+)="(0x[0-9a-fA-F]{8})"', path.read_text(), re.M):
            out[k] = v.lower()
    except OSError:
        pass
    return out


C = load()
