#!/usr/bin/env bash
# Spotify marquee, event-driven (no update_freq). The song comes from the event itself:
#   spotify_change  Spotify's PlaybackStateChanged notification, $INFO = its userInfo ("Player State", "Name", "Artist")
#   media_change    SketchyBar's now-playing event, $INFO = {"app", "state", "title", "artist"} (other apps are ignored)
# Only a bare run (bar startup, a --trigger with no payload) asks Spotify itself, once, with a 2 s limit:
# a hung Spotify used to leave one stuck osascript per 5 s poll until the process table filled up.
source "$CONFIG_DIR/colors.sh"

# Hide the marquee, the next button and the star together.
hide() { sketchybar --set spotify drawing=off --set spotify_next drawing=off --set spotify_star drawing=off; exit 0; }

# Don't let osascript launch Spotify: only query if it's already running.
pgrep -x Spotify >/dev/null 2>&1 || hide

# Prints "state<TAB>track<TAB>artist" (state lower-case), or nothing.
from_info() {
  printf '%s' "$INFO" | /usr/bin/python3 -I -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if sys.argv[1] == "media_change":
    if d.get("app") != "Spotify":
        sys.exit(3)
    st, name, artist = d.get("state", ""), d.get("title", ""), d.get("artist", "")
else:
    st, name, artist = d.get("Player State", ""), d.get("Name", ""), d.get("Artist", "")
print("\t".join(str(x).replace("\t", " ") for x in (st.lower(), name, artist)))
' "$SENDER"
}

LINE=""
if [ -n "$INFO" ] && { [ "$SENDER" = "spotify_change" ] || [ "$SENDER" = "media_change" ]; }; then
  LINE="$(from_info)"
  [ $? -eq 3 ] && exit 0   # another app's media: leave the Spotify pill as it is
fi
if [ -z "$LINE" ]; then
  LINE="$(/usr/bin/perl -e 'alarm 2; exec @ARGV' /usr/bin/osascript -e 'tell application "Spotify" to (player state as string) & tab & (name of current track) & tab & (artist of current track)' 2>/dev/null)"
fi
IFS=$'\t' read -r STATE TRACK ARTIST <<<"$LINE"

[ "$STATE" = "playing" ] || [ "$STATE" = "paused" ] || hide
[ -n "$TRACK" ] || hide

if [ -n "$ARTIST" ]; then
  TEXT="$ARTIST - $TRACK"
else
  TEXT="$TRACK"
fi

# Bright + green when playing, dimmed when paused.
if [ "$STATE" = "playing" ]; then
  ICON_COLOR="$GREEN"; LABEL_COLOR="$FG"
else
  ICON_COLOR="$COMMENT"; LABEL_COLOR="$COMMENT"
fi

sketchybar --set spotify drawing=on icon="" icon.color="$ICON_COLOR" \
                         label="$TEXT" label.color="$LABEL_COLOR" \
           --set spotify_next drawing=on icon.color="$LABEL_COLOR"

# The star: ★ gold when the song is in Your Library, ☆ when it is not (or Spotify is not connected yet).
# state answers from a small memory, so this costs no network after the first look at a song.
STAR="$(python3 "$HOME/Scripts/tyler-os-live/coach/spotify_library.py" state 2>/dev/null)"
if [ "$STAR" = "1" ]; then
  sketchybar --set spotify_star drawing=on icon="★" icon.color="$YELLOW"
else
  sketchybar --set spotify_star drawing=on icon="☆" icon.color="$ICON_COLOR"
fi
