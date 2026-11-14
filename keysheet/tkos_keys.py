#!/usr/bin/env python3
"""TKOS shortcuts page for KeySheet, built from the real config files (never hand-typed).

Reads AeroSpace, the TKOS tmux bindings, Ghostty and skhd, writes one HTML page and prints its path.
bin/keysheet tkos runs this, then opens KeySheet on the page (KEYSHEET_PAGE).
"""
import html
import os
import re
import sys
from pathlib import Path

HOME = Path.home()
SOURCES = {
    "AeroSpace": Path(os.environ.get("TKOS_KEYS_AEROSPACE", HOME / ".aerospace.toml")),
    "tmux (prefix Ctrl-a)": Path(os.environ.get("TKOS_KEYS_TMUX", HOME / ".tmux.conf")),
    "Ghostty": Path(os.environ.get("TKOS_KEYS_GHOSTTY", HOME / ".config/ghostty/config")),
    "skhd (Hyper = Caps Lock)": Path(os.environ.get("TKOS_KEYS_SKHD", HOME / ".config/skhd/skhdrc")),
}


def short(action: str) -> str:
    action = action.strip().strip("'\"")
    action = re.sub(r"(exec-and-forget|run-shell -b|run-shell)\s+", "", action)
    action = re.sub(r"[~$]\S*/(\S+)", r"\1", action) if len(action) > 70 else action
    return action[:90]


def aerospace(p: Path):
    rows, on = [], False
    for line in p.read_text().splitlines():
        s = line.strip()
        if s.startswith("["):
            on = "binding" in s
            continue
        m = re.match(r"^([A-Za-z0-9\-]+)\s*=\s*(.+)$", s) if on and not s.startswith("#") else None
        if m:
            note = re.search(r"#\s*(.+)$", m.group(2))
            rows.append((m.group(1), note.group(1) if note else short(re.sub(r"\s+#.*$", "", m.group(2)))))
    return rows


def tmux(p: Path):
    rows = []
    for line in p.read_text().splitlines():
        m = re.match(r"^bind\s+((?:-\w+\s+(?:\w+\s+)?)*)(\S+)\s+(.+)$", line.strip())
        if not m:
            continue
        flags, key, cmd = m.groups()
        table = re.search(r"-T\s+(\w+)", flags)
        prefix = "" if "-n" in flags.split() else ("Ctrl-a " + (table.group(1) + " " if table else ""))
        rows.append((prefix + key, short(cmd)))
    return rows


def ghostty(p: Path):
    rows = []
    for line in p.read_text().splitlines():
        m = re.match(r"^keybind\s*=\s*([^=]+)=(.+)$", line.strip())
        if m:
            rows.append((m.group(1), short(m.group(2))))
    return rows


def skhd(p: Path):
    rows = []
    for line in p.read_text().splitlines():
        m = re.match(r"^([a-z0-9 +]+?\s-\s\S+)\s*:\s*(.+)$", line.strip())
        if m:
            keys = m.group(1).replace("cmd + alt + ctrl + shift", "Hyper").replace(" - ", " ")
            rows.append((keys, short(m.group(2))))
    return rows


PARSERS = {"AeroSpace": aerospace, "tmux (prefix Ctrl-a)": tmux, "Ghostty": ghostty, "skhd (Hyper = Caps Lock)": skhd}

CSS = """body{background:#120a1c;color:#f3e9ff;font:13px -apple-system,sans-serif;margin:0;padding:26px 34px}
h1{font-size:20px;margin:0 0 4px;color:#ff8b4b}p.sub{margin:0 0 18px;color:#9a8aae}
section{break-inside:avoid;margin:0 0 22px}h2{font-size:14px;color:#ff6392;border-bottom:1px solid #3a2750;padding-bottom:4px}
.grid{columns:2;column-gap:36px}.row{display:flex;gap:12px;padding:2px 0}
kbd{flex:0 0 190px;font:12px ui-monospace,Menlo,monospace;color:#d148f0}span{color:#e6dcf3;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}"""


def main() -> None:
    body = []
    for name, path in SOURCES.items():
        try:
            rows = PARSERS[name](path)
        except OSError:
            rows = []
        items = "".join(f"<div class=row><kbd>{html.escape(k)}</kbd><span>{html.escape(a)}</span></div>" for k, a in rows)
        body.append(f"<section><h2>{html.escape(name)} · {len(rows)}</h2><div class=grid>{items or '<span>no file</span>'}</div></section>")
    page = f"<!doctype html><meta charset=utf-8><title>TKOS keys</title><style>{CSS}</style><h1>TKOS shortcuts</h1><p class=sub>Built from the live config files each time. Esc closes.</p>{''.join(body)}"
    out = Path(os.environ.get("TKOS_KEYS_OUT", HOME / ".cache/omarchy4mac/tkos-keys.html"))
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(page)
    print(out)


if __name__ == "__main__":
    sys.exit(main())
