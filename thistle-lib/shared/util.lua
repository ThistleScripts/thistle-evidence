-- =====================================================================
-- Thistle-Lib · Shared utilities
-- ---------------------------------------------------------------------
-- Small helpers that are safe to run on both the server and the client.
-- Kept intentionally tiny — this file is a home for the sort of one-line
-- functions that would otherwise get copy-pasted into every consumer
-- resource. Anything larger (input dialogs, progress bars, callbacks)
-- lives in its own file so callers only pay for what they use.
-- =====================================================================

Thistle = Thistle or {}
Thistle.Util = Thistle.Util or {}

--- Distance between two vectors. Accepts vector2/3/4 or {x,y,z} tables so
--- consumers don't have to normalise coordinate shapes at every call site.
---@param a vector2|vector3|vector4|table
---@param b vector2|vector3|vector4|table
---@return number
function Thistle.Util.Distance(a, b)
    if not a or not b then return math.huge end
    local ax = a.x or a[1] or 0.0
    local ay = a.y or a[2] or 0.0
    local az = a.z or a[3] or 0.0
    local bx = b.x or b[1] or 0.0
    local by = b.y or b[2] or 0.0
    local bz = b.z or b[3] or 0.0
    local dx, dy, dz = ax - bx, ay - by, az - bz
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

--- Clamp a number to [min, max]. Returns min/max on nil input rather than
--- erroring — callers usually want a sane default when a config value is
--- missing or malformed.
function Thistle.Util.Clamp(n, min, max)
    n = tonumber(n) or min or 0
    if min and n < min then n = min end
    if max and n > max then n = max end
    return n
end

--- Round to the nearest integer. Lua's `math.floor(n + 0.5)` doesn't
--- handle negative numbers cleanly; this does.
function Thistle.Util.Round(n)
    n = tonumber(n) or 0
    if n >= 0 then return math.floor(n + 0.5) end
    return -math.floor(-n + 0.5)
end

--- Compute the base clean payout, business fee and dancer commission for
--- a laundering deposit. Centralised so client-side preview and
--- server-side authoritative accounting always agree.
---@param dirtyAmount   number  gross dirty cash the customer deposited
---@param businessFee   number  business fee as a fraction (0.15 = 15%)
---@param dancerCommission number  dancer commission as a fraction of the business fee (0.15 = 15% of the fee)
---@param dancerIsNpc   boolean  when true, dancer commission is forced to 0
---@return table  { clean, businessCut, dancerCut }
function Thistle.Util.CalculateLaunderingSplit(dirtyAmount, businessFee, dancerCommission, dancerIsNpc)
    local dirty = math.max(0, math.floor(tonumber(dirtyAmount) or 0))
    local feeRate = tonumber(businessFee) or 0
    local commRate = tonumber(dancerCommission) or 0
    local totalFee = math.floor(dirty * feeRate)
    local dancerCut = 0
    if not dancerIsNpc then
        dancerCut = math.floor(totalFee * commRate)
    end
    local businessCut = totalFee - dancerCut
    local clean = dirty - totalFee
    return {
        clean = clean,
        businessCut = businessCut,
        dancerCut = dancerCut,
    }
end
