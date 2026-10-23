local config <const> = require "config"

-- Shown under a labelled evidence box in the inventory, so boxes in a stash can be matched to cases
exports.ox_inventory:displayMetadata({
    caseNumber = locale("evidences.evidence_box_label_dialog.case_metadata"),
    labelledBy = locale("evidences.evidence_box_label_dialog.labelled_by_metadata")
})

exports("evidence_box", function(slot)
    local evidenceBoxItem

    for _, item in pairs(exports.ox_inventory:GetPlayerItems()) do
        if item and item.slot == slot then
            evidenceBoxItem = item
            break
        end
    end

    if evidenceBoxItem then
        local metadata <const> = evidenceBoxItem.metadata or {}

        -- we have to close the inventory to prevent the player from moving while focussing the input dialog after closing the inventory by himself
        exports.ox_inventory:closeInventory()
        local input <const> = Thistle.Input(locale("evidences.evidence_box_label_dialog.title"), {
            {
                type = "input",
                label = locale("evidences.evidence_box_label_dialog.case_textfield_title"),
                description = locale("evidences.evidence_box_label_dialog.case_textfield_details"),
                default = metadata.caseNumber or nil,
                required = false,
                max = 20
            },
            {
                type = "input",
                label = locale("evidences.evidence_box_label_dialog.name_textfield_title"),
                description = locale("evidences.evidence_box_label_dialog.name_textfield_details"),
                default = metadata.boxName or (not metadata.caseNumber and metadata.label) or nil, -- boxes labelled before case numbers
                required = false,
                max = 30
            },
            {
                type = "textarea",
                label = locale("evidences.evidence_box_label_dialog.description_textfield_title"),
                description = locale("evidences.evidence_box_label_dialog.description_textfield_details"),
                default = metadata.description or nil,
                required = false,
                autosize = true
            }
        })

        if input then
            TriggerServerEvent("evidences:renameEvidenceBox", slot, input)
        end
    end
end)

exports("copyEvidenceOwner", function(slot, type)
    local evidenceItem

    for _, item in pairs(exports.ox_inventory:GetPlayerItems()) do
        if item and item.slot == slot then
            evidenceItem = item
            break
        end
    end

    if evidenceItem then
        local metadata <const> = evidenceItem.metadata or {}

        if not metadata[type] then
            return        
        end

        if not metadata[type].analysed then
            config.notify({ key = "evidences.notifications.not_analysed" }, "error")
            return
        end

        local biometricData <const> = metadata[type].owner
        if biometricData then
            SendNUIMessage({
                action = "copyToClipboard",
                value = biometricData
            })

            config.notify({ key = "evidences.notifications.biometrics_pasted" }, "success")
        end
    end
end)

exports("copySerialNumber", function(slot)
    local evidenceItem

    for _, item in pairs(exports.ox_inventory:GetPlayerItems()) do
        if item and item.slot == slot then
            evidenceItem = item
            break
        end
    end

    if evidenceItem then
        local metadata <const> = evidenceItem.metadata or {}

        if not metadata.ballistics then
            return        
        end

        if not metadata.ballistics.analysed then
            config.notify({ key = "evidences.notifications.not_analysed" }, "error")
            return
        end

        local serial <const> = metadata.ballistics.serial
        if serial then
            SendNUIMessage({
                action = "copyToClipboard",
                value = serial
            })

            config.notify({ key = "evidences.notifications.serial_pasted" }, "success")
            return
        end

        config.notify({ key = "evidences.notifications.missing_serial" }, "error")
    end
end)

exports("steel_file", function(data, slot)
    exports.ox_inventory:useItem(data, function(data)
        TriggerServerEvent("evidences:removeSerialNumber")
    end)
end)