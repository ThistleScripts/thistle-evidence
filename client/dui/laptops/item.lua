local config <const> = require "config"
local player <const> = require "client.player"
local placement <const> = require "client.utils.placement"
local permissions <const> = require "client.permissions"

local isPlacing = false

local function placeLaptop()
    local info <const> = player.getInfo()
    if info.setupIncomplete then
        return
    end

    if not info.permissions.place or not permissions.has("laptop") then
        config.notify({ key = "laptop.notifications.no_permission" }, "error")
        return
    end

    local coords <const> = placement.place("p_laptop_02_s", locale("laptop.notifications.input_help"))

    -- The server takes the item, so a laptop can't be placed without one
    if coords and Thistle.Callback.Await("evidences:placeLaptop", coords) then
        lib.playAnim(cache.ped, "mp_common", "givetake1_a")
    end
end

exports("evidence_laptop", function(data, slot)
    if isPlacing then
        return
    end

    -- ox_inventory calls this export from its own resource, so the waiting (permission callback, model load, placement) runs in a thread
    isPlacing = true
    CreateThread(function()
        local success <const>, err <const> = pcall(placeLaptop)
        isPlacing = false

        if not success then
            error(err)
        end
    end)
end)
