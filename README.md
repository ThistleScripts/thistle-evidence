# thistle-evidence

> **Thistle Scripts | Forensic Evidence**

Item-based forensics for FiveM. Players leave blood, fingerprints, saliva, bullets, casings, magazines and gunshot residue behind, and police collect it, analyse it on an in-world evidence laptop and match it to citizens and registered firearms.

- Evidence on the ground, on vehicles (per door and seat), on props, on players and on weapons.
- Forensics lab: a full-screen station for analysing DNA, fingerprints, bullets, casings, magazines and gunshot residue, with case files that link every piece of evidence sharing a DNA profile, fingerprint or gun ID across cases.
- Every gun has an ID that its bullets and casings carry, even after the serial is filed off. Analysing them names the registered owner, or links evidence from an unregistered gun until it turns up.
- Bullet paths: with a forensic kit, each bullet shows a line back to where it was fired from, on vehicles too.
- In-world evidence laptop (Thistle design) with citizens, firearms registry and wiretap apps, and a shortcut into the lab.
- Wiretap phone calls (npwd, lb-phone, yseries, roadphone), radio channels and placeable spy microphones (needs pma-voice).
- Fingerprint scanner, evidence boxes, hydrogen peroxide to wipe traces, and steel files to file off serial numbers.
- Qbox, QBCore and ESX through thistle-lib.
- Server-validated: collecting, destroying and reporting evidence, placing laptops and microphones, and every laptop action are checked server-side.
- Optional Discord webhook logs per category via thistle-lib, or ox_lib's logger (Datadog, Grafana Loki, Fivemanage).

## Requirements

- thistle-lib (0.3.0+)
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_inventory](https://github.com/overextended/ox_inventory) (2.44.4+ recommended)
- [ox_target](https://github.com/overextended/ox_target)
- Qbox, QBCore or ESX
- OneSync
- [pma-voice](https://github.com/AvarianKnight/pma-voice) for the wiretap app (optional)

## Install

1. The built laptop and lab UI is included in `html/dui/laptop/dist`. After changing the UI source, rebuild it with `cd html/dui/laptop && bun install && bun run build` and commit the new `dist`.
2. Drop `thistle-evidence` in your resources folder and add `ensure thistle-evidence` **after** `ox_lib`, `thistle-lib`, `oxmysql`, `ox_inventory`, `ox_target` and your framework.
3. Add the items from one of the language files in [`setup/`](setup) ([en](setup/en_items.lua), [de](setup/de_items.lua), [es](setup/es_items.lua), [cs](setup/cs_items.lua), [tr](setup/tr_items.lua), [fr](setup/fr_items.lua), [ja](setup/ja_items.lua)) to `ox_inventory/data/items.lua`, and copy [`setup/images`](setup/images) to `ox_inventory/web/images/`.
4. On ox_inventory older than 2.44.4, make `evidence_box` a container in `ox_inventory/modules/items/containers.lua`:
    ```lua
    setContainerProperties('evidence_box', {
        slots = 20,
        maxWeight = 5000
    })
    ```
5. Adjust `config.lua`: job permissions, wiretap, logging and the glove, cuff and death checks for your clothing and police scripts.

Database tables are created on first start. The language follows `setr ox:locale`; translations live in `locales/`.

### Upgrading from evidences 1.x

1. Stop and remove `evidences`. The database tables are unchanged, so laptops, citizens, notes, biometrics, wiretap logs and registered firearms carry over.
2. The resource is now named `thistle-evidence`, so the item exports changed. Re-paste the items from `setup/` (they call `thistle-evidence.<export>` and `exports['thistle-evidence']:…`).
3. Other resources using the API call `exports['thistle-evidence']` instead of `exports.evidences` (`syncEvidence`, `getFingerprint`, `getDNA`, `registerFirearm`). Event names (`evidences:*`) are unchanged.
4. Logging: `config.logging.webhook` became `config.logging.webhooks` with per-category URLs (`default`, `evidences`, `citizens`, `wiretap`, `firearms`).
5. ND_Core and ox_core are no longer supported (thistle-lib supports Qbox, QBCore and ESX).
6. Analysis moved from the laptop's DNA, Fingerprint and Ballistics apps to the forensics lab. Evidence analysed before the upgrade still shows as analysed, but only evidence analysed in the lab appears in case files.

## Usage

| Action | How |
| --- | --- |
| Collect evidence | Target it with a `forensic_kit` (jobs from `config.permissions.collect`) |
| Destroy evidence | Target it; fingerprints and blood need `hydrogen_peroxide` |
| Take fingerprints / DNA | Target a player with a `forensic_kit`; they get a consent prompt unless cuffed or down |
| Place / pick up a laptop | Use `evidence_laptop`, then target it to pick it back up |
| Use a laptop | Target it (`config.permissions.access`) |
| Analyse evidence | Open the Forensics Lab from a laptop, or at a station from `config.forensicsLab.stations` |
| Look up a case file | Lab → Case files, then paste a gun ID, DNA profile or fingerprint |
| See a bullet's path | Hold a `forensic_kit` and use the targeting eye near the bullet |
| Scan a fingerprint | Use `fingerprint_scanner`; the other player targets it |
| Place a spy microphone | Use `spy_microphone` |
| Clear evidence around you | `/clearEvidences <radius>` (`group.admin`) |
