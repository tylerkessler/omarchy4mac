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
# Legacy names below are kept so old plugins still work, but every one is a sunset tone now (tyler-os #1425):
# no cyan, no mint, no brand green or red anywhere on the bar.
export CYAN="0xff9d7bff"
export PINK="0xffff6fa3"
export HOTPINK="0xffff6fa3"
export GREEN="0xffc8b6ff"
export MINT="0xffc8b6ff"
export YELLOW="0xffffb52e"
export GOLD="0xffffca00"
export BLUE="0xff9d7bff"
export MAGENTA="0xffe066ff"
export LAVENDER="0xffc8b6ff"
export ORANGE="0xffff9a5c"
export RED="0xffff5a6e"
export GLOW="0x80ff8b4b"
export GLOW_PINK="0x80ff6392"
# One sunset gradient across the bar, left to right (tyler-os #1425): each pill takes the stop at its place, so neighbours blend.
# Static, never animated. lib/palette.py reads these same lines for the Python-drawn pills.
export SUN_LOGO="0xffffb52e"   # the Omarchy logo: a still yellow-orange sun, the left anchor
export GRAD_1="0xffff9a5c"     # peach: desktop + app
export GRAD_2="0xffff8b4b"     # orange: Spotify
export GRAD_3="0xffff6fa3"     # pink: YouTube, touch grass
export GRAD_4="0xffe066ff"     # magenta: computer use, clock
export GRAD_5="0xff9d7bff"     # violet: agent pills, music, CPU
export GRAD_6="0xffffca00"     # gold: battery island, the right anchor
# Status, in sunset: calm lavender (was green), amber (was yellow), deep coral (was red).
export STATUS_OK="0xffc8b6ff"
export STATUS_WARN="0xffffb52e"
export STATUS_BAD="0xffff5a6e"
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
# No brand colours on the bar (tyler-os #1425): the old Spotify green name now points at its sunset slot.
export SPOTIFY_GREEN="0xffff8b4b"
export SPOTIFY_GREEN_DIM="0x8cff8b4b"
# Desktops 1-5: one sunset step each, orange -> violet (rail.sunset_at((n-1)/4), computed).
# Full strength = the active desktop's pill; _DIM (35% alpha) = the inactive number.
export SPACE_1="0xffff8b4b"
export SPACE_2="0xffff6d80"
export SPACE_3="0xffe856c1"
export SPACE_4="0xffc04df2"
export SPACE_5="0xff8b5cf6"
export SPACE_1_DIM="0x59ff8b4b"
export SPACE_2_DIM="0x59ff6d80"
export SPACE_3_DIM="0x59e856c1"
export SPACE_4_DIM="0x59c04df2"
export SPACE_5_DIM="0x598b5cf6"
# The desktop number's own colour: halfway between the desktop's step and white, 80% opaque, so the bar behind bleeds through
# (pillcalc.mix_white; tests/test_pills.py keeps these in step).
export SPACE_1_TXT="0xccffc5a5"
export SPACE_2_TXT="0xccffb6bf"
export SPACE_3_TXT="0xccf3aae0"
export SPACE_4_TXT="0xccdfa6f8"
export SPACE_5_TXT="0xccc5adfa"
