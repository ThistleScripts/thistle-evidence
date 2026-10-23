-- Add the following items to ox_inventory/data/items.lua
-- Do not change the item names inside the square brackets
-- You may change the item descriptions and labels of buttons

['evidence_laptop'] = {
    label = 'Laptop',
    description = 'Laptop zum Zugriff auf DNA- und Fingerabdruck-Datenbank',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_laptop'
    }
},
['evidence_box'] = {
    label = 'Evidence-Box',
    description = 'Box zur Aufbewahrung von Beweisstücken',
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
    label = 'Spurensicherungskoffer',
    description = 'Du benötigst diesen Koffer, um Beweismittel zu sichern. Der Koffer kann zehn Mal verwendet werden.',
    weight = 2500,
    close = false,
    stack = false,
    decay = true
},
['hydrogen_peroxide'] = {
    label = 'Wasserstoffperoxid',
    weight = 500,
    stack = true,
    client = {
        export = 'thistle-evidence.hydrogen_peroxide'
    }
},
['forensic_fingerprint_scanner'] = {
    label = 'Fingerabdruckscanner',
    description = 'Hiermit kannst den Fingerabdruck deines Gegenübers einscannen. Bei einem Datenbanktreffer zu dem Fingerabdruck wird dir dessen Identität angezeigt.',
    weight = 500,
    stack = false,
    close = true,
    consume = 0,
    client = {
        export = 'thistle-evidence.forensic_fingerprint_scanner',
    }
},
['collected_blood'] = {
    label = 'Gesichertes Blut',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'DNS kopieren',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_saliva'] = {
    label = 'Gesicherter Speichel',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'DNS kopieren',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_fingerprint'] = {
    label = 'Gesicherter Fingerabdruck',
    weight = 5,
    stack = false,
    buttons = {{
        label = 'Fingerabdruck kopieren',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "fingerprint")
        end
    }}
},
['collected_magazine'] = {
    label = 'Gesichertes Magazin',
    weight = 200,
    stack = false
},
['collected_casing'] = {
    label = 'Gesicherte Hülse',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Seriennummer kopieren',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_bullet'] = {
    label = 'Gesicherte Kugel',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Seriennummer kopieren',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_gunshot_residue'] = {
    label = 'Gesicherte Schmauchspuren',
    weight = 5,
    stack = false
},
['steel_file'] = {
    label = 'Feile',
    weight = 150,
    stack = false,
    decay = true,
    consume = 0.1,
    client = {
        export = 'thistle-evidence.steel_file'
    }
},
['spy_microphone'] = {
    label = 'Abhörwanze',
    description = 'Mikrofon zum Überwachen von Personen in der Nähe',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.spy_microphone'
    }
},
['forensic_microscope'] = {
    label = 'Forensik-Mikroskop',
    description = 'Mikroskop zur Analyse gesicherter Beweise',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.forensic_microscope'
    }
},
['cleaning_kit'] = {
    label = 'Reinigungsset',
    description = 'Handschuhe, Beutel und Bleiche, um Hülsen, Projektile und Magazine zu beseitigen',
    weight = 500,
    stack = true
},
['evidence_marker'] = {
    label = 'Beweismarker-Set',
    description = 'Wiederverwendbares Set Beweismarker für Tatorte',
    weight = 50,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_marker'
    }
},
['uv_floodlight'] = {
    label = 'UV-Flutlicht',
    description = 'Arbeitsleuchte, die einen ganzen Tatort in UV-Licht taucht und alle Spuren darum sichtbar macht',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_floodlight'
    }
},
['uv_spotlight'] = {
    label = 'UV-Strahler',
    description = 'Gerichtete UV-Lampe, die einen langen Bereich eines Tatorts ausleuchtet und die Spuren darin sichtbar macht',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_spotlight'
    }
}

-- The UV flashlight is a weapon: see weapons.lua in this folder.
