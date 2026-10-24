-- Add the following items to ox_inventory/data/items.lua
-- Do not change the item names inside the square brackets
-- You may change the item descriptions and labels of buttons

['evidence_laptop'] = {
    label = 'Ordinateur de preuves',
    description = 'Ordinateur permettant d’accéder à la base de données ADN et d’empreintes digitales',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_laptop'
    }
},
['evidence_box'] = {
    label = 'Boîte de preuves',
    description = 'Boîte pour stocker des preuves',
    weight = 250,
    stack = false,
    close = false,
    buttons = {{
        label = 'Étiqueter',
        action = function(slot)
            exports['thistle-evidence']:evidence_box(slot)
        end
    }}
},
['forensic_kit'] = {
    label = 'Kit de police scientifique',
    description = 'Vous avez besoin de ce kit pour sécuriser les preuves. La mallette peut être utilisée dix fois.',
    weight = 2500,
    close = false,
    stack = false,
    decay = true
},
['hydrogen_peroxide'] = {
    label = 'Peroxyde d\'hydrogène',
    weight = 500,
    stack = true,
    client = {
        export = 'thistle-evidence.hydrogen_peroxide'
    }
},
['forensic_fingerprint_scanner'] = {
    label = 'Scanner d\'empreintes',
    description = 'Grâce à cela, vous pouvez scanner l’empreinte digitale de la personne en face de vous. Si l’empreinte correspond à une entrée dans la base de données, son identité s’affichera.',
    weight = 500,
    stack = false,
    close = true,
    consume = 0,
    client = {
        export = 'thistle-evidence.forensic_fingerprint_scanner',
    }
},
['collected_blood'] = {
    label = 'Sang collecté',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'Copie d\'ADN',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_saliva'] = {
    label = 'Salive collectée',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'Copie d\'ADN',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_fingerprint'] = {
    label = 'Empreinte collectée',
    weight = 5,
    stack = false,
    buttons = {{
        label = 'Copie d\'empreinte',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "fingerprint")
        end
    }}
},
['collected_magazine'] = {
    label = 'Chargeur collecté',
    weight = 200,
    stack = false
},
['collected_casing'] = {
    label = 'Douille collectée',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Copier le numéro de série',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_bullet'] = {
    label = 'Balle collectée',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Copier le numéro de série',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_gunshot_residue'] = {
    label = 'Résidus de tir prélevés',
    weight = 5,
    stack = false
},
['collected_footprint'] = {
    label = 'Moulage d’empreinte',
    description = 'Moulage en plâtre d’une empreinte de pas d’une scène de crime',
    weight = 300,
    stack = false
},
['collected_tyre_mark'] = {
    label = 'Photo de trace de pneu',
    description = 'Photo à l’échelle d’une trace de pneu d’une scène de crime',
    weight = 20,
    stack = false
},
['steel_file'] = {
    label = 'Lime en acier',
    weight = 150,
    stack = false,
    decay = true,
    consume = 0.1,
    client = {
        export = 'thistle-evidence.steel_file'
    }
},
['spy_microphone'] = {
    label = 'Micro-espion',
    description = 'Microphone pour l’observation des personnes à proximité',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.spy_microphone'
    }
},
['forensic_microscope'] = {
    label = 'Microscope médico-légal',
    description = 'Microscope pour analyser les preuves collectées',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.forensic_microscope'
    }
},
['cleaning_kit'] = {
    label = 'Kit de nettoyage',
    description = 'Gants, sacs et javel pour se débarrasser des douilles, balles et chargeurs',
    weight = 500,
    stack = true
},
['scene_cleaning_kit'] = {
    label = 'Kit de nettoyage de scène',
    description = 'Javel, brosses et sacs pour nettoyer une scène. Quelque chose pourrait être oublié.',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.scene_cleaning_kit'
    }
},
['evidence_marker'] = {
    label = 'Kit de marqueurs de preuve',
    description = 'Jeu réutilisable de marqueurs pour les scènes de crime',
    weight = 50,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_marker'
    }
},
['uv_floodlight'] = {
    label = 'Projecteur UV',
    description = 'Projecteur de chantier qui éclaire toute une scène de crime en UV et révèle toutes les preuves autour',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_floodlight'
    }
},
['uv_spotlight'] = {
    label = 'Spot UV',
    description = 'Lampe UV directionnelle qui éclaire un long cône de la scène de crime et révèle les preuves qui s’y trouvent',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_spotlight'
    }
}

-- The UV flashlight is a weapon: see weapons.lua in this folder.
