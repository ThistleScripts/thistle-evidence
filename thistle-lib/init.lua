-- =====================================================================
-- Thistle-Lib — global namespace + shared helpers
-- ---------------------------------------------------------------------
-- Runs on BOTH server and client (shared_script). Defines the `Thistle`
-- global that everything else attaches to. Keeping it tiny on purpose —
-- consumers should not have to think about load order.
-- =====================================================================

Thistle = Thistle or {}

-- The version lives in one place: thistle-lib's fxmanifest.lua. This file
-- also runs inside consumer resources, so it reads the lib's metadata by
-- name; the fallback only applies if the lib isn't installed at all.
Thistle.VERSION = GetResourceMetadata('thistle-lib', 'version', 0) or '0.0.0'

local function parseVersion(v)
    local a, b, c = tostring(v or ''):match('^(%d+)%.?(%d*)%.?(%d*)')
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

--- True when the installed lib is at least `minVersion` ('0.3.0').
--- Compares numerically, so '0.10.0' is newer than '0.9.0' (a plain
--- string comparison gets that wrong).
---@param minVersion string
---@return boolean
function Thistle.VersionAtLeast(minVersion)
    local a1, b1, c1 = parseVersion(Thistle.VERSION)
    local a2, b2, c2 = parseVersion(minVersion)
    if a1 ~= a2 then return a1 > a2 end
    if b1 ~= b2 then return b1 > b2 end
    return c1 >= c2
end

--- True when this file is running inside thistle-lib itself rather than
--- inside a consumer that included it with '@thistle-lib/...'. Modules use
--- it so exports are only registered once, under thistle-lib's name.
function Thistle.IsLibResource()
    return GetCurrentResourceName() == 'thistle-lib'
end

--- FiveM's `exports` proxy can arrive as the first argument depending on
--- call style (`exports.x:fn()` vs `exports.x.fn()`). The proxy is the only
--- argument that carries a metatable, so strip it on that basis and keep
--- every real argument (strings, numbers, plain tables, nil).
function Thistle.StripSelf(a, ...)
    if type(a) == 'table' and getmetatable(a) ~= nil then return ... end
    return a, ...
end

-- =====================================================================
-- Region / currency formatting (client + server safe)
-- ---------------------------------------------------------------------
-- Consumers that don't already have their own preset table can lean on
-- this. Each preset bundles the locale symbol + date/number layout, so
-- scripts stay consistent across US / UK / EUR installs.
-- =====================================================================

Thistle.Region = {
    presets = {
        US  = { symbol = '$', thousands = ',', decimal = '.', dateSep = '/', dateOrder = 'mdy' },
        UK  = { symbol = '£', thousands = ',', decimal = '.', dateSep = '/', dateOrder = 'dmy' },
        EUR = { symbol = '€', thousands = '.', decimal = ',', dateSep = '.', dateOrder = 'dmy' },
    },
}

--- Resolve the preset by name, falling back to US. Case-insensitive.
function Thistle.Region.get(name)
    local key = tostring(name or 'US'):upper()
    return Thistle.Region.presets[key] or Thistle.Region.presets.US
end

--- Format an integer amount with the preset's thousands separator + symbol.
--- `overrideSymbol` (optional) lets a caller pass a custom currency char
--- while keeping the preset's number layout — matches how Config.currency
--- overrides work in Thistle-Banking.
function Thistle.Region.money(amount, presetName, overrideSymbol)
    local p = Thistle.Region.get(presetName)
    local n = tonumber(amount) or 0
    local sign = (n < 0) and '-' or ''
    local s = tostring(math.abs(math.floor(n)))
    -- Reverse trick to insert thousands separators every 3 digits.
    local formatted = s:reverse():gsub('(%d%d%d)', '%1' .. p.thousands):reverse()
    -- Strip a stray leading separator when the number isn't a multiple of 3.
    -- Escape the separator so pattern metachars (`.` in EUR) match literally.
    local escSep = p.thousands:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
    formatted = formatted:gsub('^' .. escSep, '')
    return sign .. (overrideSymbol or p.symbol) .. formatted
end

--- Format a UNIX timestamp using the preset's date layout.
function Thistle.Region.date(ts, presetName)
    local p = Thistle.Region.get(presetName)
    local t = os.date('*t', tonumber(ts) or os.time())
    local d, m, y = string.format('%02d', t.day), string.format('%02d', t.month), tostring(t.year)
    if p.dateOrder == 'mdy' then return m .. p.dateSep .. d .. p.dateSep .. y
    elseif p.dateOrder == 'dmy' then return d .. p.dateSep .. m .. p.dateSep .. y
    else return y .. p.dateSep .. m .. p.dateSep .. d end
end
