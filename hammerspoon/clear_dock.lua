-- Clear dock: the Clear lists window, locked to the top of the right rail, under the rail's top row, on every desktop.
-- Clear is a Safari web app (Add to Dock), so it is found by bundle id. AeroSpace floats it (aerospace.toml "Clear" rule).
--   * SketchyBar checkmark (items/apps.sh) calls TKOS_CLEAR_DOCK.toggle().
--   * Lid open / wake / unlock: Clear loads in the background and snaps into place, without taking focus.
--   * Desktop change: aerospace.toml exec-on-workspace-change calls TKOS_CLEAR_DOCK.follow(), which moves the window to the
--     desktop you are on, so it floats in the same spot everywhere.
-- Geometry follows the rails: right rail = screen right - gap 8 - width 334 (aerospace.toml outer.right 350,
-- coach/rails_overlay.swift RIGHT_W). TOP sits one hairline under the rail's top row (Tyler's placement, 2026-11-19);
-- BOTTOM stops one gap above the YouTube dock. Override any of them with hs -c "TKOS_CLEAR_DOCK.geo.top = 210".
local M = {}
local PREV = TKOS_CLEAR_DOCK
if PREV and PREV.stop then PREV.stop() end
TKOS_CLEAR_DOCK = M

M.BUNDLE = "com.apple.Safari.WebApp.9964332B-A368-4B48-9F44-BA038F8D6CAA"
M.AERO = "/opt/homebrew/bin/aerospace"
M.geo = { gap = 8, railW = 334, top = 203, height = 652 }

local function app() return hs.application.get(M.BUNDLE) end

local function win()
  local a = app()
  if not a then return nil end
  for _, w in ipairs(a:allWindows()) do
    if w:isStandard() then return w end
  end
  return nil
end

function M.frame()
  local s = hs.screen.primaryScreen():fullFrame()   -- the menu bar screen, where SketchyBar and the rails live
  local g = M.geo
  return hs.geometry.rect(s.x + s.w - g.gap - g.railW, s.y + g.top, g.railW, g.height)
end

-- Snap into place on the focused desktop. Never focuses unless asked.
function M.place(focus)
  local w = win()
  if not w then return false end
  local ws = hs.execute(M.AERO .. " list-workspaces --focused"):gsub("%s+", "")
  if ws ~= "" then
    hs.execute(string.format("%s move-node-to-workspace --window-id %d %s", M.AERO, w:id(), ws))
  end
  local f = M.frame()
  local prev = hs.window.animationDuration
  hs.window.animationDuration = 0
  if w:isMinimized() then w:unminimize() end
  w:setFrame(f)
  local got = w:frame()   -- Clear has a minimum width; keep its right edge one gap from the screen edge anyway
  if got.w ~= f.w then w:setTopLeft(hs.geometry.point(f.x + f.w - got.w, f.y)) end
  hs.window.animationDuration = prev
  if focus then w:focus() else w:raise() end
  return true
end

-- Load Clear in the background (open -g never activates it), then snap it in once its window exists.
function M.show(focus)
  if M.place(focus) then return end
  hs.execute("/usr/bin/open -g -b " .. M.BUNDLE)
  local tries = 0
  if M.wait then M.wait:stop() end
  M.wait = hs.timer.doEvery(0.5, function()
    tries = tries + 1
    if M.place(focus) or tries > 20 then M.wait:stop(); M.wait = nil end
  end)
end

-- Desktop changed: follow only if Clear is up and not hidden.
function M.follow()
  local a = app()
  if a and not a:isHidden() then M.place(false) end
end

-- SketchyBar checkmark: open + focus, or hide when it is already in front.
function M.toggle()
  local a, w = app(), win()
  if a and w and not a:isHidden() and a:isFrontmost() then a:hide(); return end
  if a and a:isHidden() then a:unhide() end
  M.show(true)
end

local E = hs.caffeinate.watcher
M.watcher = E.new(function(ev)
  if ev == E.systemDidWake or ev == E.screensDidWake or ev == E.screensDidUnlock then
    hs.timer.doAfter(2, function() M.show(false) end)   -- let the display and AeroSpace settle first
  end
end)
M.watcher:start()

-- Displays plugged/unplugged or lid opened in clamshell: re-snap.
M.screens = hs.screen.watcher.new(function() hs.timer.doAfter(1.5, M.follow) end)
M.screens:start()

function M.stop()
  if M.watcher then M.watcher:stop() end
  if M.screens then M.screens:stop() end
  if M.wait then M.wait:stop() end
end

return M
