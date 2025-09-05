require "lib.moonloader"

local CopsSkins = {280, 281, 282, 283, 284, 285, 286, 288, 76, 306, 307, 309, 302, 310, 311, 303, 304, 305, 266, 267, 265}
local bratki = {'Lik_Glars', 'Oliver_Jones', 'Noah_Weissberg', 'Rocco_Parondi', 'Sereja_Mavrodi', 'Yuki_Blare', 'Solomon_Bogdanov'}


function main()
    while not isSampAvailable() do wait (0) end
    while true do
        IsCopSkin()
        wait(0)
    end
end

function IsCopSkin()
    if isCharOnFoot(PLAYER_PED) then
        local stealedfunc = GetCopsInRadius(35)
        if stealedfunc then
            printStringNow('Raise the barrier!', 400)
            setGameKeyState(21,255)
            wait(100)
            setGameKeyState(21,255)
        end
    end
end

function GetCopsInRadius(radius)

    for _, pedHandle in ipairs(getAllChars()) do
        local pedCar = storeCarCharIsInNoSave(pedHandle)

        if sampGetPlayerIdByCharHandle(pedHandle) then -- проверка на то, Браток ли это
            local _, pedID = sampGetPlayerIdByCharHandle(pedHandle)
            local pedNickName = sampGetPlayerNickname(pedID)
            for _, value in ipairs(bratki) do
                if pedNickName == value then
                    if isCharInAnyCar(pedHandle) and getDistanceBetweenPlayerAndCar(pedCar, radius) then
                        return true
                    end
                end
            end
        end

        for _, value in ipairs(CopsSkins) do -- проверка на то, Коп ли это
            if getCharModel(pedHandle) == value then
                if isCharInAnyCar(pedHandle) and getDistanceBetweenPlayerAndCar(pedCar, radius) then
                    return true
                end
            end
        end

        if isCharInAnyCar(pedHandle) then
            if isCharInAnyCar(pedHandle) and getDistanceBetweenPlayerAndCar(pedCar, radius) then
                return true
            end
        end
    end

    return false
end

function getDistanceBetweenPlayerAndCar(pedCarParameter, radius)
    local x1, y1, z1 = getCharCoordinates(PLAYER_PED)
    local x2, y2, z2 = getCarCoordinates(pedCarParameter)
    if getDistanceBetweenCoords3d(x1, y1, z1, x2, y2, z2) <= radius and z1 - z2 <= 4 and getCarSpeed(pedCarParameter) > 1 then
        return true
    end
end