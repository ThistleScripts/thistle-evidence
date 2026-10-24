-- Add the following items to ox_inventory/data/items.lua
-- Do not change the item names inside the square brackets
-- You may change the item descriptions and labels of buttons

['evidence_laptop'] = {
    label = 'Protátil de Pruebas',
    description = 'Portátil para acceder a bases de datos de ADN y huellas dactilares',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_laptop'
    }
},
['evidence_box'] = {
    label = 'Caja de Pruebas',
    description = 'Caja para guardar pruebas',
    weight = 250,
    stack = false,
    close = false,
    buttons = {{
        label = 'Etiquetar',
        action = function(slot)
            exports['thistle-evidence']:evidence_box(slot)
        end
    }}
},
['forensic_kit'] = {
    label = 'Kit Forense',
    description = 'Necesitas este maletín para asegurar pruebas. El maletín puede usarse diez veces.',
    weight = 2500,
    close = false,
    stack = false,
    decay = true
},
['hydrogen_peroxide'] = {
    label = 'Peróxido de Hidrógeno',
    weight = 500,
    stack = true,
    client = {
        export = 'thistle-evidence.hydrogen_peroxide'
    }
},
['forensic_fingerprint_scanner'] = {
    label = 'Lector de Huellas Dactilares',
    description = 'Con esto puedes escanear la huella dactilar de la persona frente a ti. Si la huella coincide con una entrada en la base de datos, se te mostrará su identidad.',
    weight = 500,
    stack = false,
    close = true,
    consume = 0,
    client = {
        export = 'thistle-evidence.forensic_fingerprint_scanner',
    }
},
['collected_blood'] = {
    label = 'Muestra de Sangre',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'Copia de ADN',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_saliva'] = {
    label = 'Saliva recolectada',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'Copia de ADN',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_fingerprint'] = {
    label = 'CMuestra de Huella Dactilar',
    weight = 5,
    stack = false,
    buttons = {{
        label = 'Copia de huella dactilar',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "fingerprint")
        end
    }}
},
['collected_magazine'] = {
    label = 'Cargador Recolectado',
    weight = 200,
    stack = false
},
['collected_casing'] = {
    label = 'Casquillo recogido',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Copiar número de serie',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_bullet'] = {
    label = 'Bala recogida',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Copiar número de serie',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_gunshot_residue'] = {
    label = 'Residuos de disparo recolectados',
    weight = 5,
    stack = false
},
['collected_footprint'] = {
    label = 'Molde de huella',
    description = 'Molde de yeso de una huella de un escenario del crimen',
    weight = 300,
    stack = false
},
['collected_tyre_mark'] = {
    label = 'Foto de huella de neumático',
    description = 'Foto a escala de una huella de neumático de un escenario del crimen',
    weight = 20,
    stack = false
},
['steel_file'] = {
    label = 'Lima de acero',
    weight = 150,
    stack = false,
    decay = true,
    consume = 0.1,
    client = {
        export = 'thistle-evidence.steel_file'
    }
},
['spy_microphone'] = {
    label = 'Micrófono Espía',
    description = 'Micrófono para escuchar a las personas cercanas',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.spy_microphone'
    }
},
['forensic_microscope'] = {
    label = 'Microscopio forense',
    description = 'Microscopio para analizar las pruebas recogidas',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.forensic_microscope'
    }
},
['cleaning_kit'] = {
    label = 'Kit de limpieza',
    description = 'Guantes, bolsas y lejía para deshacerse de casquillos, balas y cargadores',
    weight = 500,
    stack = true
},
['scene_cleaning_kit'] = {
    label = 'Kit de limpieza de escena',
    description = 'Lejía, cepillos y bolsas para limpiar una escena. Algo podría pasarse por alto.',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.scene_cleaning_kit'
    }
},
['evidence_marker'] = {
    label = 'Kit de marcadores de pruebas',
    description = 'Juego reutilizable de marcadores para escenas del crimen',
    weight = 50,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_marker'
    }
},
['uv_floodlight'] = {
    label = 'Foco UV',
    description = 'Foco de trabajo que ilumina toda la escena del crimen con luz UV y muestra todas las pruebas a su alrededor',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_floodlight'
    }
},
['uv_spotlight'] = {
    label = 'Proyector UV',
    description = 'Lámpara UV direccional que ilumina un cono largo de la escena del crimen y muestra las pruebas en él',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.uv_spotlight'
    }
}

-- The UV flashlight is a weapon: see weapons.lua in this folder.
