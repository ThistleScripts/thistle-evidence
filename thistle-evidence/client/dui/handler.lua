require "client.dui.focus"
require "client.dui.laptops.item"
require "client.dui.laptops.sync"
require "client.dui.laptops.target"

local dui <const> = require "client.dui.dui"
local texture <const> = require "client.dui.laptops.texture.texture"

-- render the dui on the laptop's screen
texture.replace("script_rt_tvscreen", dui.dictName, dui.txtName)
-- The screensaver shows before anyone uses the laptop, so send the brand line ("<config.cityName> Evidence") up front.
-- The DUI page takes a moment to load, so repeat it a few times.
local config <const> = require "config"
CreateThread(function()
    for _, delay in ipairs({ 1000, 4000, 10000 }) do
        Wait(delay)
        dui:sendMessage({ action = "brand", brand = ("%s Evidence"):format(config.cityName or "Thistle") })
    end
end)
