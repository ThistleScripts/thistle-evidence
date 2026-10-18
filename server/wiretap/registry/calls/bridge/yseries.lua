local phoneNumber = {}

function phoneNumber.getPhoneNumber(playerId)
    return exports.yseries:GetPhoneNumberBySourceId(playerId) or nil
end

return phoneNumber