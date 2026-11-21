# Shortcut audit, November 21 2026

Fixes part of omarchy4mac/tyler-os #1672 and #1268. Read-only: nothing was reloaded, restarted or rebound.
Source: the vault Keymap `inventory.py` run against the live config (265 bindings, 21 sources), plus live process checks.

## Live state
| Check | Result |
|---|---|
| skhd | Running (LaunchAgent `com.jackielii.skhd`, service enabled). The Nov 3 "not running" note is stale. |
| AeroSpace 0.21.3 dry-run | One warning: `config-version = 1`. Fixed here (see below). |
| Karabiner | Running, `karabiner.json` parses. 13 bindings. |
| Hammerspoon | Running. `init.lua` and `clear_dock.lua` pass a LuaJIT syntax check. |
| Window rules | 127 rules. The only repeated app is Ghostty: the screensaver float sits above the Ghostty pin, which is correct. No shadowed rules. Brave web apps use `com.brave.Browser.app.*` ids and are not caught by the Brave pin. |
| Theme switcher log | Already separate: the listener writes `~/Library/Logs/theme-appearance.log`, the keepalive writes `aerospace-keepalive.log`. |

## What changed
- `config-version = 2` and an explicit `persistent-workspaces = ['1'..'5']`. Version 1 inferred that list from the workspace numbers in the bindings; version 2 starts empty, so spelling it out keeps behavior the same.
- `tests/test_config_lint.py` guards the above and the rule order.
- No bind was added, removed or changed.

## Clashes between sources (live)
| Keys | Owners | Verdict |
|---|---|---|
| ⇧⌘1 to ⇧⌘5 | AeroSpace, macOS screenshots, Drafts | macOS screenshot keys are switched off, so AeroSpace wins. Drafts binds ⇧⌘1 and ⇧⌘2 itself. Moving that is an app setting, needs Tyler. |
| ⌃← ⌃→ | AeroSpace, macOS Spaces | macOS side is off (#1412). Fine. |
| ⌘← ⌘→ | AeroSpace focus, Ghostty line jump | AeroSpace wins everywhere; Ghostty line start/end is lost. Known, standing decision. |
| ⌥⇧C | AeroSpace (Claude), Brave extension "ask-muse" | App bind. Move the Brave extension shortcut (chrome://extensions/shortcuts). Not scriptable, needs Tyler. |
| ⇧⌘/ | AeroSpace (1Password), macOS Help menu | AeroSpace wins. Fine. |
| ⇧⌘Space | Hammerspoon apps menu, 1Password Quick Access (default, not overridden) | Hammerspoon wins. Fine. |
| ⌥Space | Alfred, Raycast, ChatGPT (not running) | Raycast now owns ⌘Space (#1655). Alfred still claims ⌥Space. Needs Tyler. |
| ⇪R, ⇪N | skhd and Karabiner | Karabiner fires first, so the skhd line never runs. Harmless but dead. |
| ⇪A | skhd /admin, macOS Launchpad (off) | skhd wins. Fine. |

## Dead binds (target app missing)
Omarchy binds, left alone on purpose: ⇧⌘W Typora, ⌃⌘S LocalSend, ⌃⌘. HandBrake, ⇧⌘D lazydocker. They do nothing or open an empty Ghostty until the app is installed.

## Needs Tyler's yes (nothing here was changed)
1. **R1 through R10 and Hyper-V simplification plan.** The plan text is not in the Keymap project, the Oct 18 session note, #908, #1368 or the Donna briefs. Please point to it or resend it.
2. ⌘⇧B/C/A/M/O collide with Brave's own keys (Oct 18 note).
3. Drafts ⇧⌘1 and ⇧⌘2 against AeroSpace workspace moves.
4. Alfred versus Raycast on ⌥Space.
5. Install or drop Typora, LocalSend, HandBrake, lazydocker so the four dead binds work.
6. Hyper+R, Hyper+V and Hyper+C call the dev checkout `~/Scripts/tyler-os` while everything else runs `tyler-os-live` (Oct 18 finding).

## Housekeeping (listed, nothing deleted)
`~/.config/karabiner`: 8 `karabiner.json.bak*` files. `~/.config/skhd`: 2 `skhdrc.bak*` files. `~/.hammerspoon`: `init.lua.bak-20261008-031703`, plus `omarchy_init_link.lua`, a second symlink to the same `init.lua`.

## Not verified
The new config was linted by parsing (tomllib) and the CLI dry-run before this change. AeroSpace can only dry-run the live path, so the final dry-run runs after merge, and no reload was done.
