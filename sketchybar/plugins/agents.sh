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
# Logo motion + TK colour ride this item's update (30 s; the python read is cached, ccusage stays at 10 min).
"$CONFIG_DIR/plugins/agent_status.sh"

COST="$(cached agents 600 spend)"
if [ -n "$COST" ] && [ "$COST" -gt 0 ]; then
  # Spend tier along the sunset (tyler-os #1161): under $5 orange, $20 pink, $50 magenta, more violet.
  if   [ "$COST" -lt 5 ];  then TIER="${SUN_1:-$ACCENT}"
  elif [ "$COST" -lt 20 ]; then TIER="${SUN_2:-$ACCENT}"
  elif [ "$COST" -lt 50 ]; then TIER="${SUN_3:-$ACCENT}"
  else TIER="${SUN_4:-$ACCENT}"; fi
  sketchybar --set "$NAME" drawing=on icon="󰚩" icon.color="$TIER" label="\$$COST" label.color="$TIER"
else
  sketchybar --set "$NAME" drawing=off
fi
