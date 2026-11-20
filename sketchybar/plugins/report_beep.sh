#!/usr/bin/env bash
# Capture Beep Source (Reporting menu). Run it right after a mystery beep: it reads the last 2 minutes
# of macOS logs for whatever made a sound (Hey Siri wake-ups, speaker starts, system sounds, notification sounds, afplay/say)
# and saves a report to ~/.local/state/tyler-os-vault/beep_reports. The Reporting icon's label shows the verdict for 10 s.
NAME="${NAME:-report}"

DIR="$HOME/.local/state/tyler-os-vault/beep_reports"; mkdir -p "$DIR"
STAMP="$(date '+%Y%m%d-%H%M%S')"; OUT="$DIR/$STAMP.txt"
sketchybar --set "$NAME" label="checking…" label.drawing=on
(
  P='(process == "kernel" AND eventMessage CONTAINS "Hey Siri") OR (process == "Siri" AND eventMessage CONTAINS "invokeCampoService")
     OR (process == "coreaudiod" AND eventMessage CONTAINS "Speaker PerformStartIO returned") OR process BEGINSWITH "SystemSoundServer"
     OR (process == "usernoted" AND eventMessage CONTAINS[c] "sound") OR process == "afplay" OR process == "say"'
  LOG="$(/usr/bin/log show --last 2m --style compact --predicate "$P" 2>/dev/null | cut -c1-240)"
  SIRI=$(( $(grep -c 'Hey Siri.*first pass' <<<"$LOG") > 0 ? $(grep -c 'AppleAOPVoiceTrigger) (notice)' <<<"$LOG") : 0 ))
  SPK=$(grep -c "Speaker PerformStartIO returned" <<<"$LOG")
  SND=$(grep -cE "SystemSoundServer|usernoted" <<<"$LOG")
  PLAY="$(ps -axo comm= | grep -E '/(afplay|say)$' | xargs -n1 basename 2>/dev/null | sort -u | tr '\n' ' ')"
  if [ "$SIRI" -gt 0 ]; then V="Hey Siri woke ${SIRI}x"
  elif [ -n "$PLAY" ]; then V="playing: $PLAY"
  elif [ "$SND" -gt 0 ]; then V="system or notification sound"
  elif [ "$SPK" -gt 0 ]; then V="speaker started ${SPK}x, source unknown"
  else V="no sound in logs"; fi
  { echo "Beep report $STAMP: $V"; echo "Siri wakes $SIRI, speaker starts $SPK, system/notification sounds $SND, playing now: ${PLAY:-none}"
    echo; echo "Audio assertions:"; pmset -g assertions | grep -i audio; echo; echo "Log (last 2 min):"; echo "$LOG"; } >"$OUT"
  printf '%s\t%s\t%s\n' "$STAMP" "$V" "$OUT" >>"$DIR/index.tsv"
  sketchybar --set "$NAME" label="$V"
  sleep 10; sketchybar --set "$NAME" label.drawing=off
) >/dev/null 2>&1 &
