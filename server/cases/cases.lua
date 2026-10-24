-- Case board (the laptop's Cases app): a case ties together its suspects, the DNA profiles, fingerprints and gun IDs
-- in it, officers' notes, and the evidence boxes labelled with its case number in the evidence lockers.
local config <const> = require "config"
local framework <const> = require "server.framework"
local database <const> = require "server.database"
local citizens <const> = require "server.citizens.citizens"
local logger <const> = require "server.logger"

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_cases (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            caseNumber VARCHAR(20) NOT NULL UNIQUE,
            title VARCHAR(100) NOT NULL,
            status ENUM('open', 'closed') NOT NULL DEFAULT 'open',
            createdBy TEXT NOT NULL,
            createdAt BIGINT NOT NULL,
            updatedAt BIGINT NOT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

-- What's linked to a case: a suspect (ref is their citizen identifier) or a DNA profile, fingerprint or gun ID
MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_case_links (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            caseId INT NOT NULL,
            kind ENUM('suspect', 'dna', 'fingerprint', 'ballistics') NOT NULL,
            ref VARCHAR(100) NOT NULL,
            addedBy TEXT NOT NULL,
            addedAt BIGINT NOT NULL,
            UNIQUE (caseId, kind, ref),
            FOREIGN KEY (caseId) REFERENCES evidence_cases(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

MySQL.update.await(
    [[
        CREATE TABLE IF NOT EXISTS evidence_case_notes (
            id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
            caseId INT NOT NULL,
            text TEXT NOT NULL,
            author TEXT NOT NULL,
            at BIGINT NOT NULL,
            FOREIGN KEY (caseId) REFERENCES evidence_cases(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]]
)

local linkKinds <const> = { suspect = true, dna = true, fingerprint = true, ballistics = true }

local function deny()
    return { success = false, response = "laptop.notifications.no_permission.description" }
end

local function now()
    return os.time() * 1000
end

local function text(value, maxLength)
    if type(value) ~= "string" then
        return nil
    end

    value = value:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, maxLength)
    return value ~= "" and value or nil
end

local function touch(caseId)
    database.update("UPDATE evidence_cases SET updatedAt = ? WHERE id = ?", now(), caseId)
end

-- Registers a case board callback that needs laptop access and gets its arguments as a table
local function register(name, handler)
    Thistle.Callback.Register(name, function(source, arguments)
        if not framework.hasPermission(config.permissions.access, source) then
            return deny()
        end

        return handler(source, type(arguments) == "table" and arguments or {})
    end)
end

-- Cases, most recently worked on first, searchable by number or title, ten at a time
register("evidences:cases:list", function(_, arguments)
    local searchText <const> = text(arguments.searchText, 50) or ""
    local pattern <const> = "%" .. searchText:gsub("\\", "\\\\"):gsub("%%", "\\%%"):gsub("_", "\\_") .. "%"

    return database.query(
        [[
            SELECT c.*,
                (SELECT COUNT(*) FROM evidence_case_links l WHERE l.caseId = c.id AND l.kind = 'suspect') AS suspects,
                (SELECT COUNT(*) FROM evidence_case_links l WHERE l.caseId = c.id AND l.kind <> 'suspect') AS evidence
            FROM evidence_cases c
            WHERE ? = '' OR c.caseNumber LIKE ? OR c.title LIKE ?
            ORDER BY c.status = 'closed', c.updatedAt DESC
            LIMIT 10 OFFSET ?
        ]],
        searchText, pattern, pattern, math.max(0, math.floor(tonumber(arguments.offset) or 0))
    )
end)

-- One case with everything linked to it
register("evidences:cases:get", function(_, arguments)
    local id <const> = tonumber(arguments.id)
    local case <const> = id and database.selectFirstRow("SELECT * FROM evidence_cases WHERE id = ?", id)
    if not case or not case.success or not case.response then
        return { success = false }
    end

    local result <const> = case.response
    local links <const> = database.query("SELECT * FROM evidence_case_links WHERE caseId = ? ORDER BY addedAt", id)
    local notes <const> = database.query("SELECT * FROM evidence_case_notes WHERE caseId = ? ORDER BY at DESC", id)

    result.suspects, result.evidence = {}, {}
    for _, link in ipairs(links.success and links.response or {}) do
        if link.kind == "suspect" then
            local citizen <const> = citizens.getCitizen(link.ref)
            link.citizen = citizen and citizen.success and citizen.response or nil
            result.suspects[#result.suspects + 1] = link
        else
            -- how many analysed pieces share the ID, from the forensics lab
            local count <const> = database.selectFirstColumn("SELECT COUNT(*) FROM forensic_matches WHERE kind = ? AND matchKey = ?", link.kind, link.ref)
            link.matches = count.success and tonumber(count.response) or 0
            result.evidence[#result.evidence + 1] = link
        end
    end

    result.notes = notes.success and notes.response or {}

    -- the case's evidence boxes and items, as the evidence lockers last recorded them
    local storage <const> = database.query(
        [[
            SELECT l.* FROM evidence_locker_log l
            JOIN (SELECT locker, label, MAX(id) AS id FROM evidence_locker_log WHERE caseNumber = ? GROUP BY locker, label) latest
                ON latest.id = l.id
            ORDER BY l.at DESC
        ]],
        result.caseNumber
    )
    result.storage = storage.success and storage.response or {}

    return { success = true, response = result }
end)

register("evidences:cases:create", function(source, arguments)
    local caseNumber <const> = text(arguments.caseNumber, 20)
    local title <const> = text(arguments.title, 100)
    if not caseNumber or not title then
        return { success = false }
    end

    local existing <const> = database.selectFirstColumn("SELECT id FROM evidence_cases WHERE caseNumber = ?", caseNumber)
    if existing.success and existing.response then
        return { success = false, response = "laptop.desktop_screen.cases_app.errors.exists" }
    end

    local officer <const> = framework.getPlayerName(source)
    local created <const> = database.insert(
        "INSERT INTO evidence_cases (caseNumber, title, createdBy, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?)",
        caseNumber, title, officer, now(), now()
    )

    if not created.success then
        return { success = false }
    end

    logger.log(source, "Case opened", { caseNumber = caseNumber, title = title })
    return { success = true, response = { id = created.response, caseNumber = caseNumber, title = title, status = "open", createdBy = officer, createdAt = now(), updatedAt = now(), suspects = 0, evidence = 0 } }
end)

register("evidences:cases:update", function(source, arguments)
    local id <const> = tonumber(arguments.id)
    local title <const> = text(arguments.title, 100)
    local status <const> = (arguments.status == "open" or arguments.status == "closed") and arguments.status or nil
    if not id or (not title and not status) then
        return { success = false }
    end

    local result <const> = database.update(
        "UPDATE evidence_cases SET title = COALESCE(?, title), status = COALESCE(?, status), updatedAt = ? WHERE id = ?",
        title, status, now(), id
    )

    if status then
        logger.log(source, status == "closed" and "Case closed" or "Case reopened", { id = id })
    end

    return result
end)

register("evidences:cases:addLink", function(source, arguments)
    local id <const> = tonumber(arguments.id)
    local kind <const> = linkKinds[arguments.kind] and arguments.kind or nil
    local ref = text(arguments.ref, 100)
    if not id or not kind or not ref then
        return { success = false }
    end

    if kind ~= "suspect" then
        ref = ref:upper()
    end

    local result <const> = database.insert(
        "INSERT IGNORE INTO evidence_case_links (caseId, kind, ref, addedBy, addedAt) VALUES (?, ?, ?, ?, ?)",
        id, kind, ref, framework.getPlayerName(source), now()
    )

    if result.success then
        touch(id)
    end

    return result
end)

register("evidences:cases:removeLink", function(_, arguments)
    local id <const>, linkId <const> = tonumber(arguments.id), tonumber(arguments.linkId)
    if not id or not linkId then
        return { success = false }
    end

    touch(id)
    return database.update("DELETE FROM evidence_case_links WHERE id = ? AND caseId = ?", linkId, id)
end)

register("evidences:cases:addNote", function(source, arguments)
    local id <const> = tonumber(arguments.id)
    local note <const> = text(arguments.text, 2000)
    if not id or not note then
        return { success = false }
    end

    touch(id)
    return database.insert(
        "INSERT INTO evidence_case_notes (caseId, text, author, at) VALUES (?, ?, ?, ?)",
        id, note, framework.getPlayerName(source), now()
    )
end)
