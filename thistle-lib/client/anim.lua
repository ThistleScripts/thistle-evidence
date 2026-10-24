-- =====================================================================
-- Thistle-Lib · Animation & model helpers (CLIENT)
-- ---------------------------------------------------------------------
-- Common pattern: request → wait-until-loaded → play → cleanup. Every
-- consumer script re-implements this differently and gets it subtly
-- wrong (missing timeouts, leaked models, forgotten anim-dict cleanup).
-- Centralised here so every Thistle script behaves consistently.
-- =====================================================================

Thistle = Thistle or {}
Thistle.Anim = Thistle.Anim or {}

local REQUEST_TIMEOUT_MS = 5000

--- Request an animation dict and yield until it's loaded or the timeout
--- expires. Returns true on success.
---@param dict string
---@param timeoutMs number?
---@return boolean
function Thistle.Anim.RequestDict(dict, timeoutMs)
    if not dict or dict == '' then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + (timeoutMs or REQUEST_TIMEOUT_MS)
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

--- Request a model. Same contract as RequestDict.
---@param model string|number
---@param timeoutMs number?
---@return boolean
function Thistle.Anim.RequestModel(model, timeoutMs)
    if not model then return false end
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    if HasModelLoaded(hash) then return true end
    RequestModel(hash)
    local deadline = GetGameTimer() + (timeoutMs or REQUEST_TIMEOUT_MS)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(10)
    end
    return true
end

--- Play an animation on a ped. Loads the dict first, plays with the
--- provided flags, and does not release the dict (callers usually want
--- to reuse it while the anim is running — call MarkAnimDictAsNoLongerNeeded
--- yourself once done).
---@param ped number
---@param dict string
---@param clip string
---@param opts table?  { blendIn, blendOut, duration, flag, playbackRate }
---@return boolean
function Thistle.Anim.Play(ped, dict, clip, opts)
    if not DoesEntityExist(ped) then return false end
    if not Thistle.Anim.RequestDict(dict) then return false end
    opts = opts or {}
    TaskPlayAnim(
        ped, dict, clip,
        opts.blendIn or 8.0,
        opts.blendOut or -8.0,
        opts.duration or -1,
        opts.flag or 1,
        opts.playbackRate or 0.0,
        false, false, false
    )
    return true
end

--- Stop an animation on a ped, but only if it's the exact clip we
--- started. Avoids stomping unrelated tasks the ped is running.
function Thistle.Anim.Stop(ped, dict, clip)
    if not DoesEntityExist(ped) then return end
    if not dict or not clip then
        ClearPedTasks(ped)
        return
    end
    if IsEntityPlayingAnim(ped, dict, clip, 3) then
        StopAnimTask(ped, dict, clip, 1.0)
    end
end
