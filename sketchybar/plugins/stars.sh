#!/usr/bin/env bash
# Starred rail items (tyler-os docs/DESIGN.md, Rails): the gold star pill at the top left shows the count, its popup lists
# them. The right rail writes ~/.config/tkos/starred.json and fires `tkos_stars`; a click on a row opens the item.
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
FILE="${TKOS_STARS:-$HOME/.config/tkos/starred.json}"
STAR=""

if [ "$SENDER" = "mouse.exited.global" ]; then
  sketchybar --set stars popup.drawing=off
  exit 0
fi

rows=$(/usr/bin/python3 - "$FILE" <<'PY'
import json, sys
try:
    items = json.load(open(sys.argv[1])).get("items", [])
except Exception:
    items = []
print(len(items))
for x in items[:12]:
    target = x.get("open") or x.get("path") or ""
    name = " ".join(str(x.get("name") or "").split())[:44]
    if name and target:
        print(f"{name}\t{target}")
PY
)
count=$(printf '%s\n' "$rows" | head -1)
sketchybar --set stars label="${count:-0}"
sketchybar --remove '/stars\.r[0-9]+/' >/dev/null 2>&1
sketchybar --remove stars.head >/dev/null 2>&1

i=0
printf '%s\n' "$rows" | tail -n +2 | while IFS=$'\t' read -r name target; do
  [ -z "$name" ] && continue
  q=$(printf '%q' "$target")
  sketchybar --add item "stars.r$i" popup.stars \
             --set "stars.r$i" icon="$STAR" icon.color=0xffffca00 icon.font="GeistMono NF:Bold:13.0" \
                   icon.padding_left=12 icon.padding_right=8 \
                   label="$name" label.color=0xffffd6bd label.font="SF Pro Rounded:Semibold:14.0" label.padding_right=14 \
                   background.drawing=off \
                   click_script="open $q; sketchybar --set stars popup.drawing=off"
  i=$((i + 1))
done
