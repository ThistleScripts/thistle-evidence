-- =====================================================================
-- thistle-lib / server / perms.lua
-- =====================================================================
-- Small permission helpers so downstream resources don't reinvent the
-- wheel. Currently exposes ACE-group membership checks — used by
-- Thistle-Banking's admin panel to gate the entire Admin tab behind
-- `group.god` / `group.admin` (or any list of ACE groups the server
-- owner picks in their config).
--
-- All helpers are exported via `Thistle.Perms.*` and also as direct
-- `exports['thistle-lib']:PermsHasAceAny(...)` so callers can reach
-- them without depending on the Thistle namespace.
-- =====================================================================

Thistle = Thistle or {}
Thistle.Perms = Thistle.Perms or {}

--- True if the given player src is a member of ANY of the listed ACE groups.
--- Accepts either a single group string OR a table of group names.
--- Uses FiveM's built-in `IsPlayerAceAllowed`, which walks the principal
--- inheritance tree — so `group.admin` inheriting `group.moderator` still
--- matches when you check for `group.moderator`.
---
--- @param src     number  player server id
--- @param groups  string|table  one ACE group or a list of them
--- @return boolean
function Thistle.Perms.HasAceAny(src, groups)
    if not src or not groups then return false end
    if type(groups) == 'string' then
        return IsPlayerAceAllowed(src, groups) and true or false
    end
    if type(groups) ~= 'table' then return false end
    for _, g in pairs(groups) do
        if type(g) == 'string' and g ~= '' and IsPlayerAceAllowed(src, g) then
            return true
        end
    end
    return false
end

-- Colon/dot-safe export. Called via either:
--   exports['thistle-lib']:PermsHasAceAny(src, groups)   -- self injected by Lua
--   exports['thistle-lib'].PermsHasAceAny(src, groups)   -- no self
--
-- The FiveM exports proxy IS a non-empty table (it carries every export
-- function on itself), so the "non-empty table => payload" heuristic used
-- elsewhere in the lib mis-identifies it as data and shifts every real
-- argument down by one. Since we know the expected shape here — first
-- real arg is ALWAYS the player src (a number) — we can detect the
-- colon-call reliably by looking at the type of arg 2: if arg1 is a
-- table AND arg2 is a number, arg1 is the proxy and gets stripped.
if Thistle.IsLibResource() then
    exports('PermsHasAceAny', function(...)
        local a1, a2, a3 = ...
        local src, groups
        if type(a1) == 'table' and type(a2) == 'number' then
            -- Called via colon syntax: (proxyTable, src, groups)
            src, groups = a2, a3
        else
            -- Called via dot syntax: (src, groups)
            src, groups = a1, a2
        end
        return Thistle.Perms.HasAceAny(src, groups)
    end)
end
