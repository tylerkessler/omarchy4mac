#!/usr/bin/env bash
# TKOS Live chrome — the TKOS sunset (tyler-os rail.py SUN, the ticker's pills).
# Overlay for SketchyBar. Sourced after colors.sh so a `theme` shuffle
# still leaves the bar on the sunset: dusk-plum islands, orange → pink → magenta → violet.
# Light Omarchy themes skip the overlay so White / Latte still read.

_vibe_theme="$(cat "${HOME}/.config/theme-switcher/current" 2>/dev/null || true)"
case "$_vibe_theme" in
  catppuccin-latte|flexoki-light|white) unset _vibe_theme; return 0 2>/dev/null || exit 0 ;;
esac
unset _vibe_theme

# Same hexes as tyler live (coach/ops_events.py PALETTE) and tkos-night-flight.
export BG="0xff0b0b10"
export BG_TRANS="0xe00b0b10"
export BG_PILL="0xcc14142a"
export FG="0xfff4eefe"
export SURFACE="0xff1a1a2e"
export OVERLAY="0xff2a2a44"
export COMMENT="0xff6b5f86"
export DIM="0xff9a90b4"
export SOFT="0xffa99cc4"
export ACCENT="0xffff8b4b"   # sunset orange (was cyan)
export CYAN="0xff00e5ff"
export PINK="0xffff6392"
export HOTPINK="0xffff47c2"
export GREEN="0xff2dffc4"
export MINT="0xff2dffc4"
export YELLOW="0xffffd23f"
export GOLD="0xffffd23f"
export BLUE="0xff33b5ff"
export MAGENTA="0xffb388ff"
export LAVENDER="0xffb388ff"
export ORANGE="0xffff9e3d"
export RED="0xffff3d5a"
export GLOW="0x80ff8b4b"
export GLOW_PINK="0x80ff6392"
# The four sunset stops, one per island left to right, and the ticker's dusk-plum pill fill.
export SUN_1="0xffff8b4b"
export SUN_2="0xffff6392"
export SUN_3="0xffd148f0"
export SUN_4="0xff8b5cf6"
export PLUM="0xf0240f2e"
export HAIR_1="0x8cff8b4b"
export HAIR_2="0x8cff6392"
export HAIR_3="0x8cd148f0"
export HAIR_4="0x8c8b5cf6"
