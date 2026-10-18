local config <const> = require "config"
local framework <const> = require "common.frameworks.framework"
local model <const> = `prop_spycam`

local SpyMicrophone = lib.class("SpyMicrophone")

function SpyMicrophone:constructor(label, coords)
    self.label = label
    self.coords = vector4(coords.x, coords.y, coords.z, coords.w)
    self.entity = nil

    self:register()
end

function SpyMicrophone:register()
    local this <const> = self
    self.points = {

        lib.points.new({
            coords = this.coords,
            distance = 15,
            onEnter = function()
                if not this.entity then
                    lib.requestModel(model)
                    local entity <const> = CreateObject(model, this.coords.x, this.coords.y, this.coords.z, false, true)
                    FreezeEntityPosition(entity, true)
                    SetEntityCoords(entity, this.coords.x, this.coords.y, this.coords.z)
                    SetEntityHeading(entity, this.coords.w)
                    SetModelAsNoLongerNeeded(model)

                    local mayCollectSpyMicrophone <const> = framework.hasPermission(config.wiretap.spyMicrophones.permissions)
                    
                    exports.ox_target:addLocalEntity(entity, {
                        name = "spy_microphone_" .. this.label,
                        label = locale("spy_microphone.target_collect"),
                        icon = "fa-solid fa-hand",
                        distance = 2,
                        onSelect = function(data)
                            TriggerServerEvent("evidences:destroySpyMicrophone", this.label)
                            lib.playAnim(cache.ped, "mp_common", "givetake1_a")
                        end
                    })

                    this.entity = entity
                end
            end,
            onExit = function()
                if this.entity then
                    exports.ox_target:removeLocalEntity(this.entity, "spy_microphone_" .. this.label)

                    if DoesEntityExist(this.entity) then
                        DeleteObject(this.entity)
                    end

                    this.entity = nil
                end
            end
        }),

        lib.points.new({
            coords = this.coords,
            distance = config.wiretap.spyMicrophones.radius,
            onEnter = function()
                TriggerServerEvent("evidences:addSpyMicrophoneTarget", this.label)
            end,
            onExit = function()
                TriggerServerEvent("evidences:removeSpyMicrophoneTarget", this.label)
            end
        })

    }
end

function SpyMicrophone:unregister()
    for i, point in ipairs(self.points or {}) do
        if i == 1 then
            point:onExit()
        end

        point:remove()
    end
end

return SpyMicrophone