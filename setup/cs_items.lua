-- Add the following items to ox_inventory/data/items.lua
-- Do not change the item names inside the square brackets
-- You may change the item descriptions and labels of buttons

['evidence_laptop'] = {
    label = 'Evidenční notebook',
    description = 'Notebook pro přístup do databáze DNA a otisků prstů',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_laptop'
    }
},
['evidence_box'] = {
    label = 'Krabička na důkazy',
    description = 'Krabička k uložení důkazů',
    weight = 250,
    stack = false,
    close = false,
    buttons = {{
        label = 'Štítek',
        action = function(slot)
            exports['thistle-evidence']:evidence_box(slot)
        end
    }}
},
['forensic_kit'] = {
    label = 'Forenzní sada',
    description = 'Tento kufr potřebuješ k zajištění důkazů. Kufr lze použít desetkrát.',
    weight = 2500,
    close = false,
    stack = false,
    decay = true
},
['hydrogen_peroxide'] = {
    label = 'Peroxid vodíku',
    weight = 500,
    stack = true,
    client = {
        export = 'thistle-evidence.hydrogen_peroxide'
    }
},
['forensic_fingerprint_scanner'] = {
    label = 'Skener otisků prstů',
    description = 'Tímto můžeš naskenovat otisk prstu osoby naproti tobě. Pokud se otisk shoduje s databází, zobrazí se ti její identita.',
    weight = 500,
    stack = false,
    close = true,
    consume = 0,
    client = {
        export = 'thistle-evidence.forensic_fingerprint_scanner',
    }
},
['collected_blood'] = {
    label = 'Odebraná krev',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'Kopie DNA',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_saliva'] = {
    label = 'Odebraná slina',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'Kopie DNA',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_fingerprint'] = {
    label = 'Odebraný otisk prstu',
    weight = 5,
    stack = false,
    buttons = {{
        label = 'Kopie otisku prstu',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "fingerprint")
        end
    }}
},
['collected_magazine'] = {
    label = 'Odebraný zásobník',
    weight = 200,
    stack = false
},
['collected_casing'] = {
    label = 'Sebraná nábojnice',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Kopírovat sériové číslo',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_bullet'] = {
    label = 'Sebraný náboj',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Kopírovat sériové číslo',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_gunshot_residue'] = {
    label = 'Zajištěné povýstřelové zplodiny',
    weight = 5,
    stack = false
},
['steel_file'] = {
    label = 'Ocelový pilník',
    weight = 150,
    stack = false,
    decay = true,
    consume = 0.1,
    client = {
        export = 'thistle-evidence.steel_file'
    }
},
['spy_microphone'] = {
    label = 'Špionážní mikrofon',
    description = 'Mikrofon pro pozorování lidí v okolí',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.spy_microphone'
    }
},
['forensic_microscope'] = {
    label = 'Forenzní mikroskop',
    description = 'Mikroskop pro analýzu zajištěných důkazů',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.forensic_microscope'
    }
},
['cleaning_kit'] = {
    label = 'Čisticí sada',
    description = 'Rukavice, sáčky a bělidlo na odstranění nábojnic, projektilů a zásobníků',
    weight = 500,
    stack = true
},
['evidence_marker'] = {
    label = 'Sada označovačů důkazů',
    description = 'Opakovaně použitelná sada označovačů pro místa činu',
    weight = 50,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_marker'
    }
},
['uv_floodlight'] = {
    label = 'UV reflektor',
    description = 'Pracovní světlo, které osvítí celé místo činu UV světlem a ukáže všechny stopy kolem',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_floodlight'
    }
},
['uv_spotlight'] = {
    label = 'UV reflektor (směrový)',
    description = 'Směrová UV lampa, která osvítí dlouhý kužel místa činu a ukáže v něm stopy',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_spotlight'
    }
}

-- The UV flashlight is a weapon: see weapons.lua in this folder.
