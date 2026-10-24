local database = {}

local function execute(fun, query, ...)
    local args = {...}
    local callback <const> = type(args[#args]) == "function" and table.remove(args)
    local success <const>, response = pcall(fun, query, args)

    if success and callback then
        response = callback(response)
    end

    if not success then
        lib.print.error(response)
    end

    return {
        success = success,
        response = response
    }
end

---@param query
---@param ... any parameters
---@param callback? fun
---@return table {
--     success = success
--     response = callback(number of rows affected by the query)
-- }
function database.update(query, ...)
    return execute(MySQL.update.await, query, ...)
end

function database.insert(query, ...)
    return execute(MySQL.insert.await, query, ...)
end

function database.selectFirstColumn(query, ...)
    return execute(MySQL.scalar.await, query, ...)
end

function database.selectFirstRow(query, ...)
    return execute(MySQL.single.await, query, ...)
end

function database.query(query, ...)
    return execute(MySQL.query.await, query, ...)
end

return database