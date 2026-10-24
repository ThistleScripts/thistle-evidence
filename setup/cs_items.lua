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
['swab_kit'] = {
    label = 'Sada výtěrů',
    description = 'Sterilní tyčinky a zkumavky na stěr z úst a test povýstřelových zplodin. Lze použít desetkrát.',
    weight = 300,
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
['collected_footprint'] = {
    label = 'Odlitek stopy',
    description = 'Sádrový odlitek stopy z místa činu',
    weight = 300,
    stack = false
},
['collected_tyre_mark'] = {
    label = 'Fotografie stopy pneumatiky',
    description = 'Fotografie stopy pneumatiky z místa činu s měřítkem',
    weight = 20,
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
['scene_cleaning_kit'] = {
    label = 'Sada na úklid místa činu',
    description = 'Bělidlo, kartáče a pytle na vyčištění místa. Něco se může přehlédnout.',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.scene_cleaning_kit'
    }
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
    label = 'Reflektor na stopy',
    description = 'Pracovní světlo, které osvítí celé místo činu UV světlem a ukáže všechny stopy kolem',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_floodlight'
    }
},
['uv_spotlight'] = {
    label = '360° světlo na stopy',
    description = 'UV lampa, která svítí všude kolem sebe a ukáže stopy na místě činu',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_spotlight'
    }
}

-- The UV flashlight is a weapon: see weapons.lua in this folder.
