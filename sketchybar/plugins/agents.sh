#!/usr/bin/env bash
# Coding-agent usage, like Omarchy's agents widget: today's Claude Code spend
# from the local session logs (ccusage reads ~/.claude/projects). Hidden until
# there is any usage today.
source "$CONFIG_DIR/colors.sh"

source "$CONFIG_DIR/plugins/cache.sh"

# ccusage is a heavy node run: one copy at a time, reused for 10 minutes.
spend() {
  PATH="$HOME/.bun/bin:$PATH" bunx ccusage daily --json --since "$(date +%Y%m%d)" 2>/dev/null \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(round(sum(x.get("totalCost",0) for x in d.get("daily",[]))))'
}
COST="$(cached agents 600 spend)"
if [ -n "$COST" ] && [ "$COST" -gt 0 ]; then
  sketchybar --set "$NAME" drawing=on icon="󰚩" icon.color="$ACCENT" label="\$$COST" label.color="$FG"
else
  sketchybar --set "$NAME" drawing=off
fi
