-- =====================================================================
-- Thistle-Lib · Callback wrapper (CLIENT)
-- ---------------------------------------------------------------------
-- Uniform surface for client → server callbacks so consumers never have
-- to touch ox_lib.callback directly. Same async/await semantics as
-- ox_lib.callback.await — this file is a thin passthrough today, kept as
-- its own module so we can swap the transport later without breaking
-- every consumer.
-- =====================================================================

Thistle = Thistle or {}
Thistle.Callback = Thistle.Callback or {}

--- Fire-and-forget async callback. Returns whatever the server returns.
--- Yields the calling coroutine until the response arrives.
---@param name string
---@vararg any
---@return any
function Thistle.Callback.Await(name, ...)
    if type(lib) ~= 'table' or type(lib.callback) ~= 'table' or type(lib.callback.await) ~= 'function' then
        print('^1[thistle-lib]^0 Thistle.Callback.Await requires ox_lib to be started.')
        return nil
    end
    return lib.callback.await(name, false, ...)
end

--- Register a client-side callback (server → client). Signature mirrors
--- ox_lib.callback.register so consumers get identical behaviour.
---@param name string
---@param cb   function
function Thistle.Callback.Register(name, cb)
    if type(lib) ~= 'table' or type(lib.callback) ~= 'table' or type(lib.callback.register) ~= 'function' then
        print('^1[thistle-lib]^0 Thistle.Callback.Register requires ox_lib to be started.')
        return
    end
    lib.callback.register(name, cb)
end
