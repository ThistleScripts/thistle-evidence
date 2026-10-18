local phoneNumber = {}

function phoneNumber.getPhoneNumber(playerId)
    return exports["lb-phone"]:GetEquippedPhoneNumber(playerId) or nil
end

return phoneNumber