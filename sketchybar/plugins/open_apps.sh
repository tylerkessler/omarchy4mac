#!/usr/bin/env bash
# Open apps on the right of the bar (tyler-os docs/DESIGN.md; 2026-11-17): every app with a window, as its icon. The focused
# one is gold, the rest are soft. Click an icon to switch to that app. Slots are oapp.0 (rightmost) to oapp.11.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/icon_map.sh"
A=/opt/homebrew/bin/aerospace
front="$($A list-windows --focused --format '%{app-name}' 2>/dev/null | head -1)"
args=(); i=0
while IFS= read -r app; do
  [ -z "$app" ] && continue
  [ "$i" -ge 12 ] && break
  __icon_map "$app"
  if [ "$app" = "$front" ]; then c=0xffffca00; else c=0xb0f4eefe; fi
  args+=(--set "oapp.$i" drawing=on icon="$icon_result" icon.color="$c" click_script="open -a \"$app\"")
  i=$((i + 1))
done < <($A list-windows --all --format '%{app-name}' 2>/dev/null | grep -v -x -E 'Hammerspoon|UserNotificationCenter' | sort -fur)
while [ "$i" -lt 12 ]; do args+=(--set "oapp.$i" drawing=off); i=$((i + 1)); done
sketchybar "${args[@]}"
