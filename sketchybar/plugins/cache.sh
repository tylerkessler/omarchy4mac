#!/usr/bin/env bash
# Shared by plugins that run something heavy (brew outdated, bunx ccusage): one copy at a time, and the
# result is reused for max_age seconds, so wake / display events and a forced `--update` only redraw.
# Usage: source "$CONFIG_DIR/plugins/cache.sh"; cached <name> <max_age_s> <command...>   -> prints the output
cached() {
  local name="$1" max="$2"; shift 2
  local dir="$HOME/.cache/sketchybar"
  local out="$dir/$name.out" lock="$dir/$name.lock" now mt lt
  mkdir -p "$dir"
  now=$(date +%s)
  mt=$(stat -f %m "$out" 2>/dev/null || echo 0)
  if [ $((now - mt)) -ge "$max" ]; then
    lt=$(stat -f %m "$lock" 2>/dev/null || echo "$now")
    [ -d "$lock" ] && [ $((now - lt)) -ge 600 ] && rmdir "$lock" 2>/dev/null   # a killed run left its lock behind
    if mkdir "$lock" 2>/dev/null; then
      if "$@" >"$out.tmp" 2>/dev/null; then mv -f "$out.tmp" "$out"; else rm -f "$out.tmp"; touch "$out"; fi
      rmdir "$lock" 2>/dev/null
    fi
  fi
  cat "$out" 2>/dev/null
}
