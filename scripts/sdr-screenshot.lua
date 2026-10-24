-- Ctrl+S: SDR-bright screenshot of an HDR frame (tone-mapped), then back to HDR
local keys = {"target-colorspace-hint","target-trc","target-prim","target-peak","screenshot-format","screenshot-jpeg-quality"}
local function sdr_shot()
  local saved = {}
  for _,k in ipairs(keys) do saved[k] = mp.get_property(k) end
  mp.set_property("target-colorspace-hint","no")
  mp.set_property("target-trc","srgb")
  mp.set_property("target-prim","bt.709")
  mp.set_property("target-peak","auto")
  mp.set_property("screenshot-format","jpg")
  mp.set_property("screenshot-jpeg-quality","95")
  mp.add_timeout(0.4, function()
    mp.commandv("screenshot","window")
    mp.add_timeout(0.3, function()
      for _,k in ipairs(keys) do if saved[k] then mp.set_property(k, saved[k]) end end
      mp.osd_message("SDR screenshot saved", 2)
    end)
  end)
end
mp.add_key_binding("ctrl+s", "sdr-screenshot", sdr_shot)
