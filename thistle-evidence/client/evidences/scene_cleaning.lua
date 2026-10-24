-- The scene cleaning kit (server/evidences/scene_cleaning.lua): kneel and scrub with bleach for a while; ground
-- evidence around is wiped, though some may be missed.
local config <const> = require "config"

local settings <const> = config.sceneCleaning
local isCleaning = false

local function clean()
    if not Thistle.Callback.Await("evidences:startSceneCleaning") then
        return
    end

    local finished <const> = lib.progressBar({
        duration = settings.duration,
        label = locale("scene_cleaning.progress"),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = "amb@world_human_maid_clean@", clip = "base", flag = 1 },
        prop = { model = `prop_blox_spray`, bone = 28422, pos = vec3(0.04, -0.02, -0.02), rot = vec3(0.0, 0.0, 0.0) }
    })

    if not finished then
        config.notify({ key = "scene_cleaning.cancelled" }, "inform")
        return
    end

    local cleaned <const> = Thistle.Callback.Await("evidences:finishSceneCleaning")
    if cleaned == false or cleaned == nil then
        config.notify({ key = "scene_cleaning.failed" }, "error")
        return
    end

    config.notify({ key = "scene_cleaning.done" }, "success")
end

exports("scene_cleaning_kit", function()
    if isCleaning or cache.vehicle then
        return
    end

    -- ox_inventory calls this export from its own resource, so the waiting runs in a thread
    isCleaning = true
    CreateThread(function()
        local success <const>, err <const> = pcall(clean)
        isCleaning = false

        if not success then
            error(err)
        end
    end)
end)
