-- =====================================================================
-- Thistle-Lib · Callback wrapper (SERVER)
-- ---------------------------------------------------------------------
-- Server-side twin of client/callback.lua. Consumers hit
-- `Thistle.Callback.Register('foo:bar', fn)` and never touch ox_lib
-- directly; the transport layer stays swappable.
-- =====================================================================

Thistle = Thistle or {}
Thistle.Callback = Thistle.Callback or {}

--- Register a server-side callback (client → server). Signature is the
--- ox_lib.callback.register signature: cb(source, ...) → return values.
---@param name string
---@param cb   function
function Thistle.Callback.Register(name, cb)
    if type(lib) ~= 'table' or type(lib.callback) ~= 'table' or type(lib.callback.register) ~= 'function' then
        print('^1[thistle-lib]^0 Thistle.Callback.Register requires ox_lib to be started.')
        return
    end
    lib.callback.register(name, cb)
end

--- Fire a server → client callback and yield until the client responds.
--- Same behaviour as ox_lib.callback.await(name, source, ...).
---@param name string
---@param source number
---@vararg any
---@return any
function Thistle.Callback.Await(name, source, ...)
    if type(lib) ~= 'table' or type(lib.callback) ~= 'table' or type(lib.callback.await) ~= 'function' then
        print('^1[thistle-lib]^0 Thistle.Callback.Await requires ox_lib to be started.')
        return nil
    end
    return lib.callback.await(name, source, ...)
end
