-- Walking control panel (tyler-os #1394). Toggle from SketchyBar: walk_data.py open.
-- Floating Hammerspoon webview, Esc closes, all spaces. Does not hs.reload.

tkosWalkPanel = tkosWalkPanel or { wv = nil, esc = nil }

local function closePanel()
  if tkosWalkPanel.esc then tkosWalkPanel.esc:delete(); tkosWalkPanel.esc = nil end
  if tkosWalkPanel.wv then
    pcall(function() tkosWalkPanel.wv:delete() end)
    tkosWalkPanel.wv = nil
  end
end

local function screenFrame()
  local s = hs.screen.mainScreen():fullFrame()
  local w, h = 920, 640
  return hs.geometry.rect(s.x + (s.w - w) / 2, s.y + (s.h - h) / 2, w, h)
end

local function handleUrl(url)
  if not url then return end
  if url:find("lid%-on") then
    hs.task.new(os.getenv("HOME") .. "/Scripts/donna-walk-lid/mode", nil, { "on" }):start()
  elseif url:find("lid%-off") then
    hs.task.new(os.getenv("HOME") .. "/Scripts/donna-walk-lid/mode", nil, { "off" }):start()
  elseif url:find("close") then
    closePanel()
  end
end

function tkosWalkToggle(htmlPath)
  if tkosWalkPanel.wv then
    closePanel()
    return
  end
  local rect = screenFrame()
  local wv = hs.webview.new(rect)
  wv:windowStyle({ "titled", "closable", "nonactivating", "utility" })
  wv:windowTitle("Walk")
  wv:allowTextEntry(true)
  wv:allowGestures(true)
  wv:closeOnEscape(true)
  wv:deleteOnClose(true)
  wv:level(hs.drawing.windowLevels.floating)
  wv:behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.stationary)
  wv:darkMode(true)
  wv:navigationCallback(function(_, _, nav)
    local url = type(nav) == "string" and nav or tostring(nav)
    if url and url:find("tkos%-walk:") then
      handleUrl(url)
      return false
    end
    return true
  end)
  wv:windowCallback(function(action)
    if action == "closing" then closePanel() end
  end)
  wv:url("file://" .. htmlPath)
  wv:show()
  wv:bringToFront(true)
  tkosWalkPanel.wv = wv
  tkosWalkPanel.esc = hs.hotkey.bind({}, "escape", function() closePanel() end)
end
