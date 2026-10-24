local lastHealth = nil

CreateThread(function() -- detects healing
    Wait(500)
    lastHealth = GetEntityHealth(cache.ped)
    
    while true do
        local health <const> = GetEntityHealth(cache.ped)
        if lastHealth < health then
            lastHealth = health
        end

        -- backwards, since destroy() removes the entry from the list
        for i = #EvidencesAtCoords, 1, -1 do
            local evidence <const> = EvidencesAtCoords[i]
            if evidence.evidenceType == "blood" and evidence:isExposedToRain() then
                evidence:destroy()
            end
        end
        
        Wait(500)
    end
end)

AddEventHandler("gameEventTriggered", function(name, args)
    if name == "CEventNetworkEntityDamage" then
        if args[1] == cache.ped then
            local ped <const> = cache.ped
            local damageAmount <const> = lastHealth - GetEntityHealth(cache.ped)
            
            if damageAmount > 5 then
                -- item blood
                -- only when another player did it: anyone else (a local, an animal) has no weapon to bloody
                if (args[12] or 0) == 1 and DoesEntityExist(args[2]) and IsPedAPlayer(args[2]) then
                    local victim <const> = cache.serverId
                    local attacker <const> = GetPlayerServerId(NetworkGetPlayerIndexFromPed(args[2]))
                    if attacker > 0 and attacker ~= victim then
                        TriggerServerEvent("evidences:syncEvidence", "blood",
                            victim, "atWeaponOf", attacker)
                    end
                end
                
                -- vehicle blood
                if cache.vehicle and cache.seat and not IsPedOnAnyBike(ped) then
                    TriggerServerEvent("evidences:syncEvidence", "blood", cache.serverId,
                        "atVehicleSeat", NetworkGetNetworkIdFromEntity(cache.vehicle), cache.seat, {
                            plate = GetVehicleNumberPlateText(cache.vehicle)
                        })
                    return
                end

                -- ground blood
                local coords <const> = GetEntityCoords(cache.ped)
                local success <const>, groundZ <const> = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
                if success then
                    TriggerServerEvent("evidences:syncEvidence", "blood", cache.serverId,
                        "atCoords", vector3(coords.x, coords.y, groundZ))
                end
            end

            lastHealth = GetEntityHealth(cache.ped)
        end
    end
end)
