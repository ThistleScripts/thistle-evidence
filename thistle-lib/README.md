# thistle-lib

Shared helpers for [Thistle Scripts](https://github.com/) FiveM resources. Zero UI, no database, no assumptions about the game world — just the same battle-tested framework bridge, Discord webhook logger, and number/date formatting the Thistle scripts use internally, extracted so you don't have to copy them into every resource.

## Contents

| Module                      | Where       | What it gives you                                                                                             |
|-----------------------------|-------------|---------------------------------------------------------------------------------------------------------------|
| `Thistle.Framework` (in `Thistle.*`) | server      | qb / qbx / esx auto-detect, player lookup, license, money add/remove, notify, has-item, usable items, all-players list |
| `Thistle.Inventory`         | server      | item count / add / remove, list registered items, list a player's items (ox_inventory first, then the framework's inventory) |
| `Thistle.Perms`             | server      | ACE group checks                                                                                             |
| `Thistle.Target`            | client      | ox_target / qb-target / built-in "[E]" fallback behind one API                                               |
| `Thistle.Placement`         | client      | in-world pickers: `Start` (ghost prop / ped / vehicle, rotate, height, radius, model cycling) and `run` (light raycast point / box / sphere) |
| `Thistle.Input` / `Menu` / `Progress` / `NotifyClient`, `Thistle.Anim`, `Thistle.Callback` | client | UI, model/anim loading and callbacks over ox_lib |
| `Thistle.Webhook`           | server      | Discord embed sender with per-URL rate-limited FIFO queue                                                    |
| `Thistle.Region`            | shared      | US / UK / EUR currency + date formatting                                                                     |
| `Thistle.BankBridge`        | server      | Vendor-neutral money API + registration slot so a banking resource can serve calls coming from vendor impersonations |
| `Thistle.BankCompat`        | server      | Impersonates `qb-banking` / `Renewed-Banking` / `okokBanking` exports in-process — no separate compat resources needed |

## Install

1. Drop the `thistle-lib` folder into `resources/`.
2. Ensure it starts **before** any consumer script:
   ```
   ensure thistle-lib
   ensure your-other-script
   ```
3. Use it from a consumer in one of two ways:

   **Exports** (no manifest changes): `exports['thistle-lib']:GetPlayerObject(src)`.

   **Includes** — load the modules you need straight into your own Lua state, so
   `Thistle.*` works directly with no cross-resource hop. Only what you include
   exists in your resource; `init.lua` alone gives you `Region`, the version helpers
   and `StripSelf`, nothing else.
   ```lua
   shared_scripts { '@ox_lib/init.lua', '@thistle-lib/init.lua' }
   server_scripts { '@thistle-lib/server/framework.lua', '@thistle-lib/server/inventory.lua' }
   client_scripts { '@thistle-lib/client/target.lua', '@thistle-lib/client/ui.lua' }
   dependency 'thistle-lib'
   ```
   Included modules never register exports under your resource's name.

## Framework bridge — quick example

```lua
-- server-side
local src = 1
local P   = Thistle.GetPlayerObject(src)
if not P then return end

local cid  = Thistle.GetIdentifier(P)
local name = Thistle.GetCharacterName(P)
local funds = Thistle.GetFunds(P)  -- { cash = 500, bank = 12000 }

if Thistle.RemoveMoney(P, 250, 'bank', 'Widget purchase') then
    Thistle.Notify(src, { title = 'Store', description = 'Bought a widget.', type = 'success' })
end

Thistle.RegisterUsableItem('mystery_box', function(source, item)
    -- your open-the-box handler
end)
```

If you don't want to use the global, every helper is also exposed as an export:
```lua
local P = exports['thistle-lib']:GetPlayerObject(src)
```

## Targets — quick example

```lua
-- client-side, ox_target / qb-target / fallback chosen automatically
local handle = Thistle.Target.AddEntity(entity, {
    { label = 'Open crate', icon = 'fas fa-box', onSelect = function() TriggerServerEvent('my:open') end },
})
Thistle.Target.RemoveEntity(handle)

local zone = Thistle.Target.AddSphereZone({ coords = vec3(100.0, 200.0, 30.0), radius = 2.0, options = { … } })
Thistle.Target.Remove(zone)
```
Options use the ox_target shape and are converted for qb-target. With neither running, the
nearest zone shows `[E] label` via ox_lib text UI. Exports: `TargetAddEntity`,
`TargetRemoveEntity`, `TargetAddSphereZone`, `TargetAddBoxZone`, `TargetRemove`, `TargetBackend`.

## Placement — quick example

```lua
-- client-side; yields, so run it in a thread
CreateThread(function()
    local r = Thistle.Placement.Start({ mode = 'prop', model = 'prop_laptop_01a', models = { … } })
    if not r then return end  -- cancelled
    TriggerServerEvent('my:save', r.coords, r.heading, r.model)
end)
```
Ped and vehicle models get a ped / vehicle preview on the ground; `result.kind` is
`'object'`, `'ped'` or `'vehicle'`.
`mode = 'point'` shows a marker instead of a ghost prop; `radius` adds a resizable ring;
`requireHit = true` only confirms while aiming at a surface; `startAt` teleports the player
near an existing position first; `showHelp` / `hideHelp` let you draw the key help in your own
UI. Controls: aim, E or left-click to confirm, Backspace / right-click to cancel, scroll to
rotate, PgUp/PgDn height, ←/→ model, ↑/↓ radius, G = your own position.
Returns `{ coords, heading, model?, radius? }` or `nil`. Export: `PlacementStart(opts)`.

### Raycast placer — `Thistle.Placement.run`

A lighter picker with no ghost model: aim at a surface, see a point / box / sphere preview,
confirm. Load the module into your resource (picking waits frame by frame, and Lua can't
yield across a call into another resource):

```lua
-- fxmanifest.lua
client_scripts {
    '@thistle-lib/client/placement.lua',
    'client/main.lua',
}
```

```lua
-- client/main.lua (inside a thread or NUI callback)
SetNuiFocus(false, false)                -- hide your UI first
local spot = Thistle.Placement.run({
    shape  = 'box',                      -- 'point' (default) | 'box' | 'sphere'
    size   = vec3(1.0, 1.0, 2.0),        -- box width / depth / height
    rotate = true,                       -- scroll to rotate, SHIFT for 1° steps
})
SetNuiFocus(true, true)
if spot then print(spot.x, spot.y, spot.z, spot.w) end   -- nil when cancelled
```

Controls: **E / left-click** sets, **scroll** rotates (when `rotate = true`), **right-click / Backspace / ESC** cancels. Other options: `radius` (sphere), `zOffset` (box base relative to the hit point), `heading` (start heading; otherwise it follows the camera), `headingOffset` (default 180, facing the player), `distance` (default 60 m), `flags` (shape test flags, default world + vehicles + objects), `colour`, `help` (custom ox_lib text UI line, or `false` to draw your own), and `onFrame(coords, heading)` for extra drawing.

`Thistle.Placement.raycast(distance?, flags?, ignore?)` returns the camera hit point on its own (`coords, entity, normal`, or `nil`). `Thistle.Placement.drawBox` and `drawSphere` are exposed too. Only one picker (`Start` or `run`) runs at a time; a second call returns `nil`.

## Discord webhooks — quick example

```lua
-- Once at boot, tell the lib where your webhooks live. Same rules as
-- Thistle-Banking: per-category URL → falls back to `default` → silent.
Thistle.Webhook.configure({
    default    = '',                                         -- catch-all fallback
    botName    = 'My Script',
    purchases  = 'https://discord.com/api/webhooks/.../purchases',
    refunds    = 'https://discord.com/api/webhooks/.../refunds',
})

-- Then just log events wherever they happen.
Thistle.Webhook.send('purchases', {
    title       = 'Widget sold',
    description = ('%s bought a widget for %s'):format(name, Thistle.Region.money(250, 'US')),
    color       = 'success',                                 -- info | warn | success | error | debug — or a hex int
    fields      = Thistle.Webhook.fields(
        { 'Buyer',  name,  true },
        { 'Amount', '$250', true }
    ),
})
```

**Rate limiting** is handled for you: posts to the same webhook URL are queued and dispatched with a 250 ms gap, staying comfortably under Discord's ~30 requests/minute per-webhook limit even on a busy server.

**Brand avatar** is baked in. Every embed carries the Thistle Scripts logo — this is intentional and not overridable via config.

## Region / currency formatting

```lua
Thistle.Region.money(1234567, 'US')  --> "$1,234,567"
Thistle.Region.money(1234567, 'EUR') --> "€1.234.567"
Thistle.Region.money(1234567, 'UK')  --> "£1,234,567"
Thistle.Region.money(-50,     'US')  --> "-$50"

Thistle.Region.date(os.time(), 'US')  --> "05/06/2026"
Thistle.Region.date(os.time(), 'EUR') --> "06.05.2026"
```

## Banking-vendor compatibility

Third-party FiveM scripts (jobs, shops, drug labs, heists) are usually hardcoded to a specific banking resource's exports:

```lua
exports['qb-banking']:AddMoney(source, 500, 'Paycheck')
exports['Renewed-Banking']:addAccountMoney('ambulance', 250)
exports['okokBanking']:RemoveMoney(source, 100)
```

If your server runs **only** Thistle-Banking, none of those exports would exist and every one of those third-party scripts would break. `thistle-lib` fixes that in one step — **no extra resources to install, no folder renames**.

At boot, `Thistle.BankCompat` registers event handlers for `__cfx_export_qb-banking_*`, `__cfx_export_Renewed-Banking_*` and `__cfx_export_okokBanking_*` inside thistle-lib itself. FiveM's `exports['<res>']:<name>(...)` syntax is sugar over those events, so a third-party script's call flows like this:

```
Third-party script
       │
       ▼
exports['qb-banking']:AddMoney(src, 500, 'Paycheck')
       │
       ▼   (fires __cfx_export_qb-banking_AddMoney event)
       │
       ▼
thistle-lib · bank_compat.lua                ← impersonated handler
       │
       ▼
Thistle.BankBridge.AddMoney(...)             ← thistle-lib
       │
       ▼
Thistle-Banking backend                      ← touches the real accounts + logs to Discord webhook
```

**Currently impersonated exports:**

| Vendor              | Exports                                                                                                                             |
|---------------------|-------------------------------------------------------------------------------------------------------------------------------------|
| `qb-banking`        | `AddMoney`, `RemoveMoney`, `GetAccount`, `GetAccountBalance`, `CreateJobAccount`, `CreateGangAccount`, `CreatePlayerAccount`, `CreateBankStatement` |
| `Renewed-Banking`   | `getAccountMoney`, `addAccountMoney`, `removeAccountMoney`, `handleTransaction`, `CreateJobAccount`                                 |
| `okokBanking` (V1 + V2) | `GetAccount`, `AddMoney`, `RemoveMoney`, `AddTransaction` (V2), `GetPlayerTransactions` (V2)                                    |
| `wasabi_banking`    | `AddMoney`, `RemoveMoney`, `GetAccountBalance`, `CreateJobAccount`, `Transaction`, `GetPlayerAccounts`, savings/shared stubs        |
| `fd_banking`        | `GetAccount`, `GetGangAccount`, `AddMoney`, `AddGangMoney`, `RemoveMoney`, `RemoveGangMoney`, `getPersonalAccount`, `getBusinessAccount`, `getAccountById`, `getAccountByIban`, `getAccountOwner`, `getMember`, `getAccountMembers`, `doTransfer`, invoice stubs |
| `tgg-banking`       | Server: `GetSocietyAccount`, `GetAccountByIban`, `GetPersonalAccountByPlayerId(/Identifier)`, `CreateBusinessAccount`, `GetAccountMoneyByIban`, `GetSocietyAccountMoney`, `AddSocietyMoney`, `RemoveSocietyMoney`, `AddTransaction`, freeze/terminate + loans stubs. Client: `OpenBank`, `CloseBank`, `IsDisabled`, `ToggleDisabled` |

> Note: `qb-banking` and `okokBanking` `AddMoney`/`RemoveMoney` are **society-account based** (first arg is an account name like `"police"`), not player-based — that mirrors their real docs verbatim. Player personal-bank money in those setups is normally manipulated via the underlying core (`qb-core` / `ESX`). `wasabi_banking` is polymorphic: the first arg is a `type` (`'bank'` / `'cash'` / `'society'` / `'shared'` / `'savings'`); Thistle-Banking has no savings concept so those calls return `false` with a one-time console warning.

**Coexistence:** If a real vendor resource *is* installed and started (e.g. you actually have `qb-banking` running on your server), thistle-lib detects it via `GetResourceState` and skips impersonating that vendor — no export collision.

**Adding vendors:** open `server/bank_compat.lua`, copy an existing `installXxxBanking()` block, adjust the vendor name + export list, and forward each call into `Thistle.BankBridge`. It's usually one line per export.

## Versioning

The version lives in one place: `version` in `fxmanifest.lua`. `Thistle.VERSION` reads it
(also from inside consumers), so it can't drift. Check for a minimum version with
`Thistle.VersionAtLeast`, which compares numerically — a plain string comparison would think
`'0.10.0'` is older than `'0.9.0'`:

```lua
if not Thistle.VersionAtLeast('0.3.0') then
    error('This script requires thistle-lib >= 0.3.0. Please update.')
end
```

**0.5.0** — `Thistle.Inventory.ListItems` / `GetItems`; `Thistle.Placement.run` raycast
placer (from Thistle-StashCreator) alongside `Start`.

**0.4.0** — `Thistle.Placement` (from the events World Builder), props, peds and vehicles.

**0.3.0** — target bridge, `GetLicense`, include mode, `VersionAtLeast`; exports accept
both `exports.x:fn()` and `exports.x.fn()` call styles.

## Design principles

* **Small on purpose.** Anything script-specific (bank cards, credit scores, invoices) belongs in the consumer script, not here. If a helper only exists to serve one script, it doesn't earn a spot in the lib.
* **No load-order gotchas.** `Thistle` global is populated in the `shared_scripts` phase — you never have to worry about whether the lib finished booting before your callback fires.
* **Fail loud, not silent.** Wrong framework → clear console warning at boot. Bad webhook URL → the queue keeps running, Discord's status code is printed. No swallowed errors.

## Contributing rules of thumb

* Rule of three: don't add a helper until it appears in **three** separate scripts.
* Every public function needs a doc-comment describing its inputs, returns, and side effects.
* Any behaviour change to an existing helper is a breaking change → bump the minor version.
