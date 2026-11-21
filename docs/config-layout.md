# Config layout proposal (#1675)

No issue lays out an agreed structure for the scattered keyboard and window-manager files, so this is a proposal, not a move. Only files that already have a home in this repo were touched (none moved).

## Today
| Live path | Where the source lives | Link |
|---|---|---|
| `~/.aerospace.toml` | `aerospace/aerospace.toml` (this repo) | symlink, kept |
| `~/.hammerspoon/init.lua`, `clear_dock.lua` | `hammerspoon/` (this repo) | symlinks, kept |
| `~/.hammerspoon/omarchy_init_link.lua` | same `init.lua` | duplicate link, remove after Tyler confirms |
| `~/.hammerspoon/claude_paste.lua` | loose file, not in a repo | proposed: `hammerspoon/claude_paste.lua` |
| `~/.config/skhd/skhdrc` | not in a repo (has a `tyler-os digit open` block written by tyler-os) | proposed: tyler-os owns it |
| `~/.config/karabiner/karabiner.json` | not in a repo (tyler-os edits it) | proposed: tyler-os owns it |
| `~/Library/LaunchAgents/com.omarchy-mac.*.plist` | `launchd/` with `/Users/YOU` placeholders filled by `install.sh` | copy, kept |

## Proposed
- omarchy4mac owns what Omarchy ships: `aerospace/`, `hammerspoon/`, `launchd/`, `bin/`.
- tyler-os dotfiles own what the TK OS layer writes: skhd, Karabiner, Raycast.
- Live paths stay symlinks into whichever repo owns the file. Never copy.
- Before moving skhdrc or karabiner.json, tyler-os needs to stop rewriting them in place.
