require "lib.moonloader"

local kppThread
local autoShlagbaumActive = false
local CopsSkins = {280, 281, 282, 283, 284, 285, 286, 288, 76, 306, 307, 309, 302, 310, 311, 303, 304, 305, 266, 267, 265}
local bratki = {'Lik_Glars', 'Oliver_Jones', 'Noah_Weissberg', 'Rocco_Parondi', 'Sereja_Mavrodi', 'Yuki_Blare', 'Solomon_Bogdanov', 'Molly_Baila', 'Vegas_Young', 'Liya_Carter', 'Shatter_Bones'}


function main()
    while not isSampAvailable() do wait (0) end

    sampRegisterChatCommand('kpp', IsCopSkin)

    while true do

        wait(0)
    end
end

function IsCopSkin()
    autoShlagbaumActive = not autoShlagbaumActive
    if autoShlagbaumActive then
        kppThread = lua_thread.create(function ()
            while true do
                if autoShlagbaumActive and isCharOnFoot(PLAYER_PED) then
                    if IsCopsInRadius(35) then
                        printStringNow('Raise the barrier!', 400)
                        setGameKeyState(21,255)
                        wait(100)
                        setGameKeyState(21,255)
                    end
                end
                wait(0)
            end
        end)
    else
        kppThread:terminate()
    end
    sampAddChatMessage(autoShlagbaumActive and 'Авто шлагбаум включен' or 'Авто шлагбаум выключен', -1)

    
    
end

function IsCopsInRadius(radius)

    for _, pedHandle in ipairs(getAllChars()) do
        local pedCar = storeCarCharIsInNoSave(pedHandle)

        if sampGetPlayerIdByCharHandle(pedHandle) then -- проверка на то, Браток ли это
            local _, pedID = sampGetPlayerIdByCharHandle(pedHandle)
            local pedNickName = sampGetPlayerNickname(pedID)
            for _, value in ipairs(bratki) do
                if pedNickName == value then
                    if isCharInAnyCar(pedHandle) and IsCarInRadius(pedCar, radius) then
                        return true
                    end
                end
            end
        end

        for _, value in ipairs(CopsSkins) do -- проверка на то, Коп ли это
            if getCharModel(pedHandle) == value then
                if isCharInAnyCar(pedHandle) and IsCarInRadius(pedCar, radius) then
                    return true
                end
            end
        end

        if isCharInAnyCar(pedHandle) then
            if getCarModel(pedCar) == 433 then -- проверка на то, Barracks ли это
                if isCharInAnyCar(pedHandle) and IsCarInRadius(pedCar, radius) then
                    return true
                end
            end
        end
    end

    return false
end

function IsCarInRadius(pedCarParameter, radius)
    local x1, y1, z1 = getCharCoordinates(PLAYER_PED)
    local x2, y2, z2 = getCarCoordinates(pedCarParameter)
    if getDistanceBetweenCoords3d(x1, y1, z1, x2, y2, z2) <= radius and z1 - z2 <= 4 and z2 - z1 <= 4 and getCarSpeed(pedCarParameter) >= 1 then
        return true
    end
end