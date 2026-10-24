# thistle-evidence

> **Thistle Scripts | Forensic Evidence**

Item-based forensics for FiveM. Players leave blood, fingerprints, saliva, bullets, casings, magazines and gunshot residue behind, and police collect it, analyse it on an in-world evidence laptop and match it to citizens and registered firearms.

- Evidence on the ground, on vehicles (per door and seat), on props, on players and on weapons. Whoever sits in a vehicle without gloves leaves prints on their seat, the driver's on the steering wheel, and evidence collected from a vehicle records where in it it was found and the plate, so the lab can tell the driver from the passengers.
- Forensics lab: officers target a microscope to analyse DNA, fingerprints, bullets, casings, magazines and gunshot residue in a full-screen lab, with case files that link every piece of evidence sharing a DNA profile, fingerprint or gun ID across cases. Microscopes stand at fixed stations from the config or are placed with the `forensic_microscope` item.
- Every gun has an ID that its bullets and casings carry, even after the serial is filed off. Analysing them names the registered owner, or links evidence from an unregistered gun until it turns up.
- Evidence survives restarts: ground evidence, evidence on vehicles (by plate) and on players (by character) are saved to the database and put back (`config.persistence`).
- Bullets in players: a player who has been shot carries the bullet (matched to the gun) until it's collected from them.
- Bullet paths: pointing the UV light at a bullet shows a line back to where it was fired from, on vehicles too.
- Booking terminals: officers target a spot in the cells (e.g. a computer in your MLO, `config.bookingTerminals.stations`) to open a booking screen, find or create the suspect's record, put the fingerprint and DNA swab taken from them on file and add notes.
- In-world evidence laptop: an Evidence app to review everything analysed and the evidence you carry, add notes and link DNA profiles and fingerprints to citizens, plus citizens, firearms registry and wiretap apps. Analysis itself only happens at a microscope.
- Your city's name on the laptop, the lab and the Discord logs (`config.cityName`, shown as "<name> Evidence").
- Wiretap phone calls (npwd, lb-phone, yseries, roadphone), radio channels and placeable spy microphones (needs pma-voice).
- UV flashlight: hold right click to shine it where you look, while still walking and strafing. Evidence nearby glows faintly while it's on, evidence it has shown glows brightly so it can be found and collected, and blood, casings, bullets, magazines and traces on vehicles and props only show up in its beam (can be turned off in `config.uvLight`).
- Evidence markers: officers pick a numbered marker prop from a menu and click to put down as many as they need, then pick them up one at a time or all at once.
- UV lamps: officers stand an Evidence Spotlight (`uv_floodlight`, 12 m round it) or a 360 Evidence Light (`uv_spotlight`, 25 m round it) at a scene, and the evidence they light shows up and can be collected without holding a flashlight.
- Evidence ages: the longer a trace lies at a scene before it's collected, the more likely its analysis is partial (prints and DNA list a few possible citizens) or unreadable (`config.evidenceAging`). Old ground evidence disappears after two days.
- Footprints on soft ground (mud, sand, snow, dirt) and tyre marks from hard braking or wheelspin. A footprint cast shows the shoe (men's or women's, size, tread) and direction; a tyre mark photo shows the vehicle model (`config.footprints`, `config.tyreMarks`).
- Scene cleaning kit: anyone can scrub a scene with bleach, wiping the ground evidence around them, though some may be missed (`config.sceneCleaning`).
- Chain of custody: evidence boxes labelled with a case number are sealed, and opening one breaks the seal with who and when. Evidence lockers at the station log everything put in and taken out.
- Case board: the laptop's Cases app ties a case number to its suspects, DNA profiles, fingerprints and gun IDs, officers' notes and where its evidence boxes are kept. Add evidence to a case straight from the Evidence app.
- Forensic reports: copy a case file from the lab as text, and forensic matches can be posted to their own webhook.
- Evidence admin panel (`/evidenceadmin`): clear ground evidence from the whole map, by type or all at once, and choose which officers can use the laptop and each of its apps, the microscopes, collecting, swabs, fingerprints, the UV flashlight and lamps, markers and lockers. Admins are listed by licence in `permissions.lua`. The booking terminal stays open to every officer.
- Firearm registration terminals (`config.firearmTerminals`): like the booking terminal, any officer can target one to register a gun they're carrying to a citizen, creating the citizen's record first if needed (when citizens aren't synced). No laptop needed.
- Swab kit (`swab_kit`): any officer can take DNA mouth swabs and test for gunshot residue without a full forensic kit, e.g. on someone in custody.
- Fingerprint scanner: target a player and choose Scan fingerprint to check their print against the database (they're asked first unless cuffed or down), or hold it out for them to put a finger on. With no match, the officer gets the print on a fingerprint card (and their clipboard) to put on the citizen's record.
- Evidence boxes, steel files to file off serial numbers, and items to destroy evidence: hydrogen peroxide for biological traces and a cleaning kit for casings, bullets and magazines (`config.destroyItems`).
- Qbox, QBCore and ESX through thistle-lib.
- Server-validated: collecting, destroying and reporting evidence, placing laptops and microphones, and every laptop action are checked server-side.
- Optional Discord webhook logs per category via thistle-lib, or ox_lib's logger (Datadog, Grafana Loki, Fivemanage).

## Requirements

- thistle-lib (0.3.0+), included in this repo next to this folder ([`../thistle-lib`](../thistle-lib))
- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- [ox_inventory](https://github.com/overextended/ox_inventory) (2.44.4+ recommended)
- [ox_target](https://github.com/overextended/ox_target)
- Qbox, QBCore or ESX
- OneSync
- [pma-voice](https://github.com/AvarianKnight/pma-voice) for the wiretap app (optional)

## Install

1. The built laptop and lab UI is included in `html/dui/laptop/dist`. After changing the UI source, rebuild it with `cd html/dui/laptop && bun install && bun run build` and commit the new `dist`.
2. Drop `thistle-evidence` and the bundled `thistle-lib` in your resources folder (skip `thistle-lib` if you already run the same or a newer version) and add `ensure thistle-evidence` **after** `ox_lib`, `thistle-lib`, `oxmysql`, `ox_inventory`, `ox_target` and your framework.
3. Add the items (including `uv_floodlight` and `uv_spotlight`) from one of the language files in [`setup/`](setup) ([en](setup/en_items.lua), [de](setup/de_items.lua), [es](setup/es_items.lua), [cs](setup/cs_items.lua), [tr](setup/tr_items.lua), [fr](setup/fr_items.lua), [ja](setup/ja_items.lua)) to `ox_inventory/data/items.lua`, the UV flashlight from [`setup/weapons.lua`](setup/weapons.lua) to `ox_inventory/data/weapons.lua`, and copy [`setup/images`](setup/images) to `ox_inventory/web/images/`.
4. On ox_inventory older than 2.44.4, make `evidence_box` a container in `ox_inventory/modules/items/containers.lua`:
    ```lua
    setContainerProperties('evidence_box', {
        slots = 20,
        maxWeight = 5000
    })
    ```
5. Put your Rockstar licence in `admins` in `permissions.lua`, then use `/evidenceadmin` in game to choose what each officer can do. Out of the box only the laptop, the wiretap app and the microscopes are locked; everything else is open to every officer with the job.
6. Adjust `config.lua`: your city name, job permissions, microscope stations, wiretap, logging and the glove, cuff and death checks for your clothing and police scripts.

Database tables are created on first start. The language follows `setr ox:locale`; translations live in `locales/`.

### Upgrading from evidences 1.x

1. Stop and remove `evidences`. The database tables are unchanged, so laptops, citizens, notes, biometrics, wiretap logs and registered firearms carry over.
2. The resource is now named `thistle-evidence`, so the item exports changed. Re-paste the items from `setup/` (they call `thistle-evidence.<export>` and `exports['thistle-evidence']:…`).
3. Other resources using the API call `exports['thistle-evidence']` instead of `exports.evidences` (`syncEvidence`, `getFingerprint`, `getDNA`, `registerFirearm`). Event names (`evidences:*`) are unchanged.
4. Logging: `config.logging.webhook` became `config.logging.webhooks` with per-category URLs (`default`, `evidences`, `citizens`, `wiretap`, `firearms`).
5. ND_Core and ox_core are no longer supported (thistle-lib supports Qbox, QBCore and ESX).
6. Analysis moved from the laptop's DNA, Fingerprint and Ballistics apps to the forensics lab. Evidence analysed before the upgrade still shows as analysed, but only evidence analysed in the lab appears in case files.
7. The fingerprint scanner item is now `forensic_fingerprint_scanner` (it was `fingerprint_scanner`, which other scripts also use). Replace the old entry in `ox_inventory/data/items.lua`, copy the renamed image, and swap any `fingerprint_scanner` in shops or stashes.

## Usage

| Action | How |
| --- | --- |
| Find evidence | Equip the UV flashlight (`WEAPON_UVFLASHLIGHT`), hold right click to shine it, and point it at the faint hints around the scene. What it shows stays visible for 15 seconds to collect |
| Light up a scene | Use an Evidence Spotlight (`uv_floodlight`) or a 360 Evidence Light (`uv_spotlight`) and place it; the evidence it lights shows up. Target it to pick it back up |
| Mark evidence | Use the `evidence_marker` kit, pick a prop, then click to place (scroll rotates, ENTER or ESC finishes). Target a marker to pick it up, or to pick up every marker at the scene |
| Collect evidence | Target it with a `forensic_kit` (jobs from `config.permissions.collect`) |
| Destroy evidence | Target it with the item from `config.destroyItems` (`hydrogen_peroxide` or `cleaning_kit`) |
| Take fingerprints / DNA | Target a player with a `forensic_kit`; they get a consent prompt unless cuffed or down |
| Place / pick up a laptop | Use `evidence_laptop`, then target it to pick it back up |
| Use a laptop | Target it (`config.permissions.access`) |
| Analyse evidence | Target a microscope (`config.permissions.access`) |
| Place / pick up a microscope | Use `forensic_microscope`, then target it to pick it back up (`config.forensicsLab.permissions`) |
| Review evidence / link it to a citizen | Laptop → Evidence: pick it from the evidence log or what you carry |
| Look up a case file | Lab → Case files, then paste a gun ID, DNA profile or fingerprint |
| See a bullet's path | Point the UV light at the bullet |
| Label an evidence box | Right-click it in your inventory → Label: a case number and a name (shown as "Case 1042 · Davis Ave shooting"), and a description. It keeps the label in stashes |
| Book a suspect | Take their fingerprints and DNA with a `forensic_kit`, then target a booking terminal: pick their record and put the samples you carry on file |
| Store evidence | Target an evidence locker (`config.evidenceLockers`) to open it, or to view who put in and took out what |
| Copy a report | Lab → open a case file → Copy report |
| Clean a scene | Use a `scene_cleaning_kit` and scrub for 30 seconds: ground evidence within 4 m is wiped, though some may be missed |
| Scan a fingerprint | Use `forensic_fingerprint_scanner`; the other player targets it |
| Place a spy microphone | Use `spy_microphone` |
| Clear evidence around you | `/clearEvidences <radius>` (`group.admin`) |

## For other scripts

Leave the player's fingerprints on something they touch, such as an ATM keypad, a till, a safe or a lockpicked door. Nothing is left when they wear gloves. The print is revealed under UV and collected like any other, and the label shows where it was found.

```lua
-- client, on the player touching it
exports["thistle-evidence"]:leaveFingerprint(coords, "ATM keypad") -- coords is optional (in front of their hands)

-- server
exports["thistle-evidence"]:leaveFingerprint(playerId, coords, "Till")
```

Also available on the server: `syncEvidence`, `getFingerprint`, `getDNA` and `registerFirearm`.
