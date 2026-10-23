-- Add the following items to ox_inventory/data/items.lua
-- Do not change the item names inside the square brackets
-- You may change the item descriptions and labels of buttons

['evidence_laptop'] = {
    label = 'Evidence Laptop',
    description = 'Laptop for accessing DNA and fingerprint database',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_laptop'
    }
},
['evidence_box'] = {
    label = 'Evidence Box',
    description = 'Box to store evidences',
    weight = 250,
    stack = false,
    close = false,
    buttons = {{
        label = 'Label',
        action = function(slot)
            exports['thistle-evidence']:evidence_box(slot)
        end
    }}
},
['forensic_kit'] = {
    label = 'Forensic Kit',
    description = 'You need this kit to secure evidences. The case can be used ten times.',
    weight = 2500,
    close = false,
    stack = false,
    decay = true
},
['hydrogen_peroxide'] = {
    label = 'Hydrogen peroxide',
    weight = 500,
    stack = true,
    client = {
        export = 'thistle-evidence.hydrogen_peroxide'
    }
},
['fingerprint_scanner'] = {
    label = 'Fingerprint Scanner',
    description = 'With this, you can scan the fingerprint of the person opposite you. If the fingerprint matches a database entry, their identity will be displayed to you.',
    weight = 500,
    stack = false,
    close = true,
    consume = 0,
    client = {
        export = 'thistle-evidence.fingerprint_scanner',
    }
},
['collected_blood'] = {
    label = 'Collected Blood',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'Copy DNA',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_saliva'] = {
    label = 'Collected Saliva',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'Copy DNA',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_fingerprint'] = {
    label = 'Collected Fingerprint',
    weight = 5,
    stack = false,
    buttons = {{
        label = 'Copy Fingerprint',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "fingerprint")
        end
    }}
},
['collected_magazine'] = {
    label = 'Collected Magazine',
    weight = 200,
    stack = false
},
['collected_casing'] = {
    label = 'Collected Casing',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Copy Serial Number',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_bullet'] = {
    label = 'Collected Bullet',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Copy Serial Number',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_gunshot_residue'] = {
    label = 'Collected Gunshot Residue',
    weight = 5,
    stack = false
},
['steel_file'] = {
    label = 'Steel File',
    weight = 150,
    stack = false,
    decay = true,
    consume = 0.1,
    client = {
        export = 'thistle-evidence.steel_file'
    }
},
['spy_microphone'] = {
    label = 'Spy Microphone',
    description = 'Microphone for observing nearby people',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.spy_microphone'
    }
},
['forensic_microscope'] = {
    label = 'Forensic Microscope',
    description = 'Microscope for analysing collected evidence',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.forensic_microscope'
    }
},
['uv_flashlight'] = {
    label = 'UV Flashlight',
    description = 'Shows blood, fingerprints and other traces under UV light',
    weight = 400,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_flashlight'
    }
},
['cleaning_kit'] = {
    label = 'Cleaning Kit',
    description = 'Gloves, bags and bleach to get rid of casings, bullets and magazines',
    weight = 500,
    stack = true
},
['evidence_marker'] = {
    label = 'Evidence Marker',
    description = 'Numbered marker for crime scenes',
    weight = 50,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_marker'
    }
}
