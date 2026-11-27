-- ~/.hammerspoon/init.lua
--
-- Reload Hammerspoon's config from the menu bar (🔨 icon → "Reload Config")
-- or by running `hs.reload()` in the Hammerspoon Console after editing this file.

-- Claude Code voice output for the session in the active tmux pane
-- (~/.claude/hooks/voice.py). Triggered from AeroSpace's workspace mode
-- (F13 then V or R, see aerospace/.aerospace.toml.*), which opens
-- hammerspoon://voice?cmd=<command>. Do not bind F13 here: AeroSpace owns it,
-- and a second global F13 hotkey makes AeroSpace miss every other press.
--   cmd=hotkey         toggle voice output
--   cmd=hotkey-repeat  repeat the last message
local voiceCommands = { ["hotkey"] = true, ["hotkey-repeat"] = true }

hs.urlevent.bind("voice", function(_, params)
  local command = params.cmd
  if not voiceCommands[command] then
    hs.alert.show("Unknown voice command: " .. tostring(command))
    return
  end
  hs.task.new("/usr/bin/python3", function(_, stdout)
    hs.alert.show(stdout ~= "" and stdout or "Voice command failed")
  end, { os.getenv("HOME") .. "/.claude/hooks/voice.py", command }):start()
end)
