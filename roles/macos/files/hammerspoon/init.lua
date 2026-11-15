-- ~/.hammerspoon/init.lua
--
-- Clipboard → browser opener for local dev URLs of the form http://wb:294xx
-- (e.g. http://wb:29442). When the clipboard changes and its contents match
-- the pattern exactly, the URL is opened in the default browser via hs.urlevent.
--
-- Reload Hammerspoon's config from the menu bar (🔨 icon → "Reload Config")
-- or by running `hs.reload()` in the Hammerspoon Console after editing this file.

local logger      = hs.logger.new("wbWatcher", "debug")
local URL_PATTERN = "^http://wb:294%d%d$"

-- The pasteboard watcher fires on each clipboard CHANGE. It does NOT fire
-- for whatever is already on the clipboard when Hammerspoon starts up.
local watcher = hs.pasteboard.watcher.new(function(content)
  -- The watcher can hand us non-string types (images, file URLs, etc.).
  if type(content) ~= "string" then return end

  -- DEBUG: log every clipboard change so we can see exactly what the
  -- pasteboard is handing us. Look for stray whitespace, trailing slashes,
  -- BOMs, or surrounding text that would silently break the URL match.
  logger.d("clipboard: " .. hs.inspect(content))

  if not content:match(URL_PATTERN) then return end

  logger.i("Opening: " .. content)
  hs.urlevent.openURL(content)
end):start()

-- Confirmation banner on every (re)load — proves the watcher started.
hs.alert.show("wb:294xx watcher ✓ (debug on)")

-- Uncomment to spam the Hammerspoon console with every clipboard change
-- while debugging. Comment back out when done.
--
-- hs.pasteboard.watcher.new(function(c) logger.d(tostring(c)) end):start()
