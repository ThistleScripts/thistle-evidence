-- Add the following items to ox_inventory/data/items.lua
-- Do not change the item names inside the square brackets
-- You may change the item descriptions and labels of buttons

['evidence_laptop'] = {
	label = 'Kanıt Bilgisayarı',
	description = 'DNA ve parmak izi veritabanına erişim için dizüstü bilgisayar',
	weight = 1500,
	stack = true,
	close = true,
	client = {
		export = 'thistle-evidence.evidence_laptop'
	}
},
['evidence_box'] = {
	label = 'Kanıt Kutusu',
	description = 'Kanıtları saklamak için kutu',
	weight = 250,
	stack = false,
	close = false,
	buttons = {{
		label = 'Etiket',
		action = function(slot)
			exports['thistle-evidence']:evidence_box(slot)
		end
	}}
},
['forensic_kit'] = {
    label = 'Adli Tıp Kiti',
    description = 'Delilleri güvence altına almak için bu çantaya ihtiyacın var. Çanta on kez kullanılabilir.',
    weight = 2500,
    close = false,
    stack = false,
    decay = true
},
['hydrogen_peroxide'] = {
	label = 'Parmak İzi Temizleyici',
	weight = 500,
	stack = true,
	client = {
		export = 'thistle-evidence.hydrogen_peroxide'
	}
},
['fingerprint_scanner'] = {
	label = 'Parmak İzi Tarayıcısı',
	description = 'Bununla karşındaki kişinin parmak izini tarayabilirsin. Parmak izi veritabanındaki bir kayıtla eşleşirse, kimliği sana gösterilir.',
	weight = 500,
	stack = false,
	close = true,
	consume = 0,
	client = {
		export = 'thistle-evidence.fingerprint_scanner',
	}
},
['collected_blood'] = {
	label = 'Kan delili',
	weight = 200,
	stack = false,
    buttons = {{
        label = 'DNA Kopyası',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_saliva'] = {
    label = 'Tükürük delili',
    weight = 200,
    stack = false,
    buttons = {{
        label = 'DNA Kopyası',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "dna")
        end
    }}
},
['collected_fingerprint'] = {
	label = 'Delil Parmak İzi',
	weight = 5,
	stack = false,
    buttons = {{
        label = 'Parmak İzi Kopyası',
        action = function(slot)
            exports['thistle-evidence']:copyEvidenceOwner(slot, "fingerprint")
        end
    }}
},
['collected_magazine'] = {
	label = 'Şarjör Delili',
	weight = 200,
	stack = false
},
['collected_casing'] = {
    label = 'Toplanan mermi kovanı',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Seri numarasını kopyala',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_bullet'] = {
    label = 'Toplanan mermi',
    weight = 10,
    stack = false,
    buttons = {{
        label = 'Seri numarasını kopyala',
        action = function(slot)
            exports['thistle-evidence']:copySerialNumber(slot)
        end
    }}
},
['collected_gunshot_residue'] = {
    label = 'Toplanmış barut artığı',
    weight = 5,
    stack = false
},
['steel_file'] = {
    label = 'Çelik eğe',
    weight = 150,
    stack = false,
    decay = true,
    consume = 0.1,
    client = {
        export = 'thistle-evidence.steel_file'
    }
},
['spy_microphone'] = {
    label = 'Casus Mikrofon',
    description = 'Kişileri dinlemek için mikrofon',
    weight = 1500,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.spy_microphone'
    }
},
['forensic_microscope'] = {
    label = 'Adli mikroskop',
    description = 'Toplanan delilleri incelemek için mikroskop',
    weight = 3000,
    stack = false,
    close = true,
    client = {
        export = 'thistle-evidence.forensic_microscope'
    }
},
['cleaning_kit'] = {
    label = 'Temizlik kiti',
    description = 'Kovanlardan, mermilerden ve şarjörlerden kurtulmak için eldiven, poşet ve çamaşır suyu',
    weight = 500,
    stack = true
},
['evidence_marker'] = {
    label = 'Delil işaretçisi',
    description = 'Olay yerleri için numaralı işaretçi',
    weight = 50,
    stack = true,
    close = true,
    client = {
        export = 'thistle-evidence.evidence_marker'
    }
}

-- The UV flashlight is a weapon: see weapons.lua in this folder.
