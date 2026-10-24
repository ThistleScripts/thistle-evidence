-- =====================================================================
-- Thistle-Lib · Client UI helpers (input dialogs + progress bars)
-- ---------------------------------------------------------------------
-- Consumer scripts talk to `Thistle.Input(...)` / `Thistle.Progress(...)`
-- so the underlying UI implementation is swappable. Today we sit on top
-- of ox_lib (already a hard dep of thistle-lib via fxmanifest), but no
-- consumer resource ever references ox_lib directly — that lets us
-- rip-and-replace with a native Thistle UI in a later minor version
-- without breaking downstream code.
-- =====================================================================

Thistle = Thistle or {}

--- Show an input dialog. Signature matches ox_lib.inputDialog so callers
--- can pass whatever they'd give to ox_lib and get identical behaviour.
--- Returns the same array of values ox_lib returns (or nil on cancel).
---
--- Example:
--- ```lua
--- local values = Thistle.Input('Wash Cash', {
---     { type = 'number', label = 'Amount', min = 100, max = 100000 },
--- })
--- if not values then return end
--- local amount = values[1]
--- ```
---@param title string
---@param fields table
---@param opts   table?
---@return table|nil
function Thistle.Input(title, fields, opts)
    if type(lib) ~= 'table' or type(lib.inputDialog) ~= 'function' then
        print('^1[thistle-lib]^0 Thistle.Input requires ox_lib to be started.')
        return nil
    end
    return lib.inputDialog(title, fields, opts)
end

--- Show an alert / confirm dialog. Returns 'confirm' or 'cancel'.
---@param opts table  { header, content, centered?, cancel?, labels? }
---@return string|nil
function Thistle.Alert(opts)
    if type(lib) ~= 'table' or type(lib.alertDialog) ~= 'function' then return nil end
    return lib.alertDialog(opts)
end

--- Progress bar — blocking (yields until finished or cancelled).
--- Returns true on completion, false if cancelled.
---
--- Consumer scripts should pass ox_lib-shaped opts:
--- ```lua
--- Thistle.Progress({
---     duration = 5000,
---     label    = 'Washing cash…',
---     canCancel = true,
---     anim = { dict = 'anim@mp_player_intcelebrationmale@thumbs_up', clip = 'thumbs_up' },
---     disable = { move = false, car = true, combat = true },
--- })
--- ```
---@param opts table
---@return boolean
function Thistle.Progress(opts)
    if type(lib) ~= 'table' or type(lib.progressBar) ~= 'function' then
        print('^1[thistle-lib]^0 Thistle.Progress requires ox_lib to be started.')
        return false
    end
    return lib.progressBar(opts) and true or false
end

--- Circular progress variant — same contract, uses ox_lib's progressCircle.
function Thistle.ProgressCircle(opts)
    if type(lib) ~= 'table' or type(lib.progressCircle) ~= 'function' then return false end
    return lib.progressCircle(opts) and true or false
end

--- Cancel any active progress bar started via Thistle.Progress / ProgressCircle.
function Thistle.ProgressCancel()
    if type(lib) == 'table' and type(lib.cancelProgress) == 'function' then
        lib.cancelProgress()
    end
end

--- Register + immediately show a context menu. Signature matches
--- ox_lib.registerContext + lib.showContext, but consumers only need
--- one call. `def` is the full context definition (id, title, options,
--- optionally menu / onExit / etc.).
---@param def table
function Thistle.Menu(def)
    if type(def) ~= 'table' or not def.id then return end
    if type(lib) ~= 'table' or type(lib.registerContext) ~= 'function' then
        print('^1[thistle-lib]^0 Thistle.Menu requires ox_lib to be started.')
        return
    end
    lib.registerContext(def)
    lib.showContext(def.id)
end

--- Hide any active menu opened via Thistle.Menu.
function Thistle.MenuHide()
    if type(lib) == 'table' and type(lib.hideContext) == 'function' then
        lib.hideContext()
    end
end

--- Client-side notify shim — mirrors the server-side Thistle.Notify but
--- callable from client code without a round-trip. Same options table.
function Thistle.NotifyClient(settings)
    if type(lib) == 'table' and type(lib.notify) == 'function' then
        lib.notify(settings or {})
        return
    end
    -- Fallback: fire the event ox_lib listens on. Same shape either way.
    TriggerEvent('ox_lib:notify', settings or {})
end
