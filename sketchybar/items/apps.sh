#!/usr/bin/env bash
# Messages and Outlook launchers: bare glyphs right after the keyboard logo, before Claudia (tyler-os docs/DESIGN.md, 2026-11-16).
# Same no-pill style as the sun, TK and the keyboard: one sunset step each (Messages pink, Outlook violet). Click opens the app.
for spec in "msgs||${GRAD_3:-0xffff6fa3}|Messages" "outlook||${GRAD_5:-0xff9d7bff}|Microsoft Outlook"; do
  IFS='|' read -r name glyph color app <<<"$spec"
  sketchybar --add item "$name" left \
             --set "$name" \
                   icon="$glyph" \
                   icon.font="GeistMono NF:Bold:16.5" \
                   icon.color="$color" \
                   icon.padding_left=4 icon.padding_right=8 \
                   icon.shadow.drawing=off \
                   label.drawing=off \
                   background.drawing=off \
                   padding_left=0 \
                   click_script="open -a '$app'"
done
