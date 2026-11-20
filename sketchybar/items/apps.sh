#!/usr/bin/env bash
# Quick-access glyphs right after the keyboard logo, before Claudia (tyler-os docs/DESIGN.md; 2026-11-17).
# Same no-pill style as the sun, TK and the keyboard: one colour each. name|glyph|colour|click command.
while IFS='|' read -r name glyph color cmd; do
  [ -z "$name" ] && continue
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
                   click_script="$cmd"
done <<EOF
msgs||${GRAD_3:-0xffff6fa3}|open -a Messages
outlook||${GRAD_5:-0xff9d7bff}|open -a 'Microsoft Outlook'
vault||${GRAD_4:-0xffe066ff}|open 'obsidian://open?vault=Tyler%27s%20Vault'
digit||${GRAD_1:-0xffff9a5c}|open http://127.0.0.1:8765/
clear||0xff4cd964|/opt/homebrew/bin/hs -c 'TKOS_CLEAR_DOCK.toggle()'
tkset||0xffe4d2ff|open http://127.0.0.1:8765/settings
EOF
