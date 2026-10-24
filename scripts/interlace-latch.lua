-- interlace-latch.lua: per-file interlace latch for the [Interlaced-Deint-Lock] auto profile (and the HFR interlaced check).
-- Sets user-data/ilace = true the first time video-frame-info/interlaced reports true for the current file,
-- and resets it to false on every start-file, so the latch never carries over to the next file.
-- mpv.conf profile-cond: p["user-data/ilace"] == true  (profile-restore=copy-equal undoes deinterlace=yes when it resets)
local mp = require 'mp'

local latched = false

local function set_latch(v)
    latched = v
    mp.set_property_native('user-data/ilace', v)
end

mp.register_event('start-file', function()
    set_latch(false)
end)

mp.observe_property('video-frame-info/interlaced', 'native', function(_, v)
    if v == true and not latched then
        mp.msg.verbose('interlaced frame seen, latching deinterlace for this file')
        set_latch(true)
    end
end)

set_latch(false)