-- Scope this workaround to the physically tested HP board.
local board_file = io.open("/sys/class/dmi/id/board_name", "r")
local supported = board_file and board_file:read("*l") == "8CBE"
if board_file then board_file:close() end
if not supported then return end

-- Optional HP workaround: Fn currently produces no distinct media events.
-- Keep ordinary F-keys available to applications. Super is the Windows key.
o.bind("SUPER + F3", "Brightness down", "omarchy brightness display 5%-", { locked = true, repeating = true })
o.bind("SUPER + F4", "Brightness up", "omarchy brightness display +5%", { locked = true, repeating = true })
o.bind("SUPER + F6", "Mute", "omarchy audio output volume mute-toggle", { locked = true })
o.bind("SUPER + F7", "Volume down", "omarchy audio output volume lower", { locked = true, repeating = true })
o.bind("SUPER + F8", "Volume up", "omarchy audio output volume raise", { locked = true, repeating = true })
