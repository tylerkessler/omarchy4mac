#!/usr/bin/env bash
# Keyboard logo: a bare ⌘ glyph right after the TK monogram, like the Omarchy sun and TK: no pill, no ring (tyler-os #1437).
# Same font and spacing as TK (TK's icon.padding_right 8 + item padding 4 + this icon.padding_left 4 = the sun-to-TK gap).
# 19pt since 2026-11-16 (a touch bigger than TK, Sunset Royal). Static sunset peach, TK's tone (tyler-os #1425). Left click opens the TKOS shortcut page (bin/tkos-keymap, tyler-os /shortcut); right click opens the floating keyboard cheat sheet on the frontmost app's
# shortcuts (same as alt-shift-/). Sourced from sketchybarrc, which moves it after tk; bin/keysheet does the work.
sketchybar --add item keys left \
           --set keys \
                 icon="⌘" icon.font="Hack Nerd Font:Bold:19.0" \
                 icon.color="${GRAD_1:-$ACCENT}" \
                 icon.padding_left=4 icon.padding_right=8 \
                 icon.shadow.drawing=off \
                 label.drawing=off \
                 background.drawing=off \
                 padding_left=0 \
                 click_script='if [ "$BUTTON" = "right" ]; then "$HOME/.local/bin/keysheet"; else "$HOME/.local/bin/tkos-keymap"; fi'
