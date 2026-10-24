-- =====================================================================
-- Thistle-Lib · Discord webhook logger (SERVER)
-- ---------------------------------------------------------------------
-- Ported verbatim from Thistle-Banking, then generalised:
--   • no dependency on Config.webhooks — consumers pass their own routing
--     table via Thistle.Webhook.configure(cfg)
--   • same routing rules: per-category URL → falls back to default → silent
--   • per-URL FIFO queue with 250 ms gap so a busy resource can't burst
--     past Discord's ~30 req/min per-webhook rate limit
--   • hardcoded Thistle Scripts avatar so every embed carries the brand
-- =====================================================================

Thistle = Thistle or {}
Thistle.Webhook = {}

-- Per-URL FIFO queues so posts land in-order and paced.
local _queues = {}
-- Per-consumer routing config: `{ default = url, botName = 'X', <cat> = url, ... }`
local _cfg    = { default = '', botName = 'Thistle Scripts' }

-- Hardcoded brand avatar for every webhook post. Intentionally NOT in
-- the caller's config table — same avatar across every Thistle script.
local BRAND_AVATAR = 'https://customer-assets.emergentagent.com/job_fivem-dev-tools-6/artifacts/kj6irlxz_osLogo.webp'

-- Sensible embed colour presets. Consumers can override per-call by
-- passing `opts.color`.
local DEFAULT_COLORS = {
    info    = 0x3498DB,   -- blue
    warn    = 0xF1C40F,   -- yellow
    success = 0x2ECC71,   -- green
    error   = 0xE74C3C,   -- red
    debug   = 0x95A5A6,   -- grey
}

--- Merge a consumer-supplied config into our routing table. Repeatable —
--- each call replaces the previous config for the caller's process.
function Thistle.Webhook.configure(cfg)
    if type(cfg) ~= 'table' then return end
    _cfg = {}
    for k, v in pairs(cfg) do _cfg[k] = v end
    if type(_cfg.botName) ~= 'string' or _cfg.botName == '' then
        _cfg.botName = 'Thistle Scripts'
    end
end

local function urlFor(category)
    local specific = _cfg[category]
    if type(specific) == 'string' and specific ~= '' then return specific end
    if type(_cfg.default) == 'string' and _cfg.default ~= '' then return _cfg.default end
    return nil
end

local function processQueue(url)
    local q = _queues[url]
    if not q or q.busy then return end
    q.busy = true
    CreateThread(function()
        while #q.items > 0 do
            local payload = table.remove(q.items, 1)
            PerformHttpRequest(url, function(statusCode)
                if statusCode and statusCode >= 400 then
                    print(('^1[thistle-lib webhook]^0 Discord returned %s for %s')
                        :format(tostring(statusCode), tostring(payload._category or '?')))
                end
            end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
            Wait(250)
        end
        q.busy = false
    end)
end

local function enqueue(url, payload)
    if not _queues[url] then _queues[url] = { busy = false, items = {} } end
    _queues[url].items[#_queues[url].items + 1] = payload
    processQueue(url)
end

--- Public API.
---@param category string   any key on the consumer's routing table
---@param opts table        { title, description, color?, fields?, footer? }
function Thistle.Webhook.send(category, opts)
    local url = urlFor(category)
    if not url or type(opts) ~= 'table' then return end

    local resolvedColor = opts.color
    if type(resolvedColor) == 'string' then resolvedColor = DEFAULT_COLORS[resolvedColor] end

    local embed = {
        title       = opts.title or category,
        description = opts.description or '',
        color       = resolvedColor or 0x607D8B,
        timestamp   = os.date('!%Y-%m-%dT%H:%M:%S.000Z'),
        fields      = opts.fields or {},
        footer      = { text = opts.footer or ('Thistle Scripts · ' .. category) },
    }

    enqueue(url, {
        username   = _cfg.botName or 'Thistle Scripts',
        avatar_url = BRAND_AVATAR,
        embeds     = { embed },
        _category  = category,
    })
end

--- Small helper: builds a `fields` array from {name, value, inline?} triples.
function Thistle.Webhook.fields(...)
    local out, args = {}, { ... }
    for i = 1, #args do
        local f = args[i]
        if type(f) == 'table' and f[1] and f[2] then
            out[#out + 1] = { name = tostring(f[1]), value = tostring(f[2]), inline = f[3] ~= false }
        end
    end
    return out
end

-- =====================================================================
-- Export bindings — allows resources that don't want to use the
-- `Thistle` global to reach the webhook via exports instead.
-- =====================================================================

if Thistle.IsLibResource() then
    exports('WebhookSend',      function(...) local category, opts = Thistle.StripSelf(...) return Thistle.Webhook.send(category, opts) end)
    exports('WebhookConfigure', function(...) local cfg = Thistle.StripSelf(...) return Thistle.Webhook.configure(cfg) end)
end
