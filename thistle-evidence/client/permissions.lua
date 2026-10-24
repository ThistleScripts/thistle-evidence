-- What the evidence admin panel lets this officer do (server/permissions.lua), kept here so targets can check it
-- every frame. The server re-checks every action anyway; this only hides what the officer can't use.
local permissions = {}

local capabilities = {}

local function refresh()
    capabilities = Thistle.Callback.Await("evidences:getCapabilities") or capabilities
end

RegisterNetEvent("evidences:capabilities", function(value)
    if type(value) == "table" then
        capabilities = value
    end
end)

-- Picking or switching character changes who the server sees, so look again now and then
CreateThread(function()
    while not GlobalState[("%s:ready"):format(cache.resource)] do
        Wait(1000)
    end

    while true do
        refresh()
        Wait(30000)
    end
end)

---@param capability string
---@return boolean
function permissions.has(capability)
    return capabilities[capability] == true
end

-- Collecting saliva and gunshot residue takes a swab; everything else at a scene is collecting
local swabTypes <const> = { saliva = true, gunshot_residue = true }

---@param evidenceType string
---@return boolean
function permissions.canCollect(evidenceType)
    if swabTypes[evidenceType] then
        return permissions.has("swab") or permissions.has("collect")
    end
    return permissions.has("collect")
end

return permissions
