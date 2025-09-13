require "lib.moonloader"
local imgui = require 'mimgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local ffi = require('ffi')
local inicfg = require('inicfg')
local wm = require 'windows.message'
local vkeys = require 'vkeys'

-- INI ФАЙЛ
defaultSettings = {
    MAIN = {
        radius = 35,
        postKPP = 1,
        customPosTimer = false,
        customPosX = 0,
        customPosY = 0,
        passByNick = false,
        passBarracks = true,
        mode = 1,
        depth = 4
    }
}

local settings = inicfg.load(defaultSettings, 'PoliceShlagbaumHelper.ini')
inicfg.save(settings, "PoliceShlagbaumHelper.ini")

-- переменные мимгуи
local new = imgui.new
local WinState = new.bool(true)
local checkboxBarracks = new.bool(settings.MAIN.passBarracks)
local checkboxShlagbaum = new.bool(false)
local checkboxDoklad = new.bool(false)
local checkboxPassByNick = new.bool(settings.MAIN.passByNick)
local radioMode = new.int(settings.MAIN.mode)
local inputField = new.char[256]()
local SliderRadiusCars = new.int(settings.MAIN.radius)

local faicons = require('fAwesome6')

imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
    blackorangetheme()
    local config = imgui.ImFontConfig()
    config.MergeMode = true
    config.PixelSnapH = true
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)
    imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), 14, config, iconRanges)
end)

-- скины копов, фбр
local CopsSkins = {280, 281, 282, 283, 284, 285, 286, 288, 76, 306, 307, 309, 302, 310, 311, 303, 304, 305, 266, 267, 265}
io.open(getGameDirectory().."//moonloader//config//FriendsList.txt", "a")

local friendsList = {}

-- переменные для чека активности и потоков
local autoShlagbaumActive = false
local kppThread
local autoDokladActive = false
local dokladThread

-- переменные рендера и Таймера
local font_flag = require('moonloader').font_flag
local Font = renderCreateFont('Arial', 24, font_flag.SHADOW + font_flag.ITALICS + font_flag.BOLD)

math.randomseed(os.clock())
local second = math.random(20, 59)
local minute = 7
local text = minute .. ':0' .. second
local screenX, screenY = getScreenResolution()
local TimerPosX, TimerPosY



-- КОД
function main()
    while not isSampAvailable() do wait (0) end

    UpdateFriendsList()

    sampRegisterChatCommand('kpp', function ()
        checkboxShlagbaum[0] = not checkboxShlagbaum[0]
        RunAutoShlagbaum()
    end)
    sampRegisterChatCommand('doklad', function ()
        checkboxDoklad[0] = not checkboxDoklad[0]
        AutoDoklad()
    end)

    

    while true do
        if autoDokladActive then
            renderFontDrawText(Font, text, TimerPosX, TimerPosY, 0xFFffffff, false)
        end

        if isKeyDown(18) and isKeyJustPressed(88) then
            WinState[0] = not WinState[0]
        end

        
        wait(0)
    end
end

-- Определение копов в радиусе
function RunAutoShlagbaum()
    autoShlagbaumActive = not autoShlagbaumActive
    if autoShlagbaumActive then
        kppThread = lua_thread.create(function ()
            while true do
                if autoShlagbaumActive and isCharOnFoot(PLAYER_PED) then
                    if IsCopsInRadius(settings.MAIN.radius) then
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

        if settings.MAIN.passByNick then -- проверка на то, Друг ли это
            if sampGetPlayerIdByCharHandle(pedHandle) then 
                local _, pedID = sampGetPlayerIdByCharHandle(pedHandle)
                local pedNickName = sampGetPlayerNickname(pedID)
                for _, value in ipairs(friendsList) do
                    if pedNickName == value then
                        if isCharInAnyCar(pedHandle) and IsCarInRadius(pedCar, radius, settings.MAIN.depth) then
                            return true
                        end
                    end
                end
            end 
        end

        for _, value in ipairs(CopsSkins) do -- проверка на то, Коп ли это
            if getCharModel(pedHandle) == value then
                if isCharInAnyCar(pedHandle) and IsCarInRadius(pedCar, radius, settings.MAIN.depth) then
                    return true
                end
            end
        end

        if isCharInAnyCar(pedHandle) then
            if getCarModel(pedCar) == 433 and settings.MAIN.passBarracks then -- проверка на то, Barracks ли это
                if isCharInAnyCar(pedHandle) and IsCarInRadius(pedCar, radius, settings.MAIN.depth) then
                    return true
                end
            end
        end
    end

    return false
end

function IsCarInRadius(pedCarParameter, radius, depth)
    local x1, y1, z1 = getCharCoordinates(PLAYER_PED)
    local x2, y2, z2 = getCarCoordinates(pedCarParameter)
    if getDistanceBetweenCoords3d(x1, y1, z1, x2, y2, z2) <= radius and z1 - z2 <= depth and z2 - z1 <= 4 and getCarSpeed(pedCarParameter) >= 1 then
        return true
    end
end

-- АвтоДоклады
function AutoDoklad()
    autoDokladActive = not autoDokladActive
    if autoDokladActive then
        TimerPosX, TimerPosY = SetTimerAtTheBottom()
        sampSendChat('/r Пост: КПП. Состав: ' .. GetCopsInRadiusOnFoot(10) .. '. Состояние: Спокойное.')
        dokladThread = lua_thread.create(Timer)
    else
        dokladThread:terminate()
        second = math.random(20, 59)
        minute = 7
    end

    sampAddChatMessage(autoDokladActive and 'КОКОДЖАМБО' or 'НЕТ', 0xFFFF69B4)
end

function GetCopsInRadiusOnFoot(radius)
    local cops = 0
    for _, pedHandle in ipairs(getAllChars()) do -- посчитать копов в радиусе
        for _, value in ipairs(CopsSkins) do -- проверка на то, Коп ли это
            if getCharModel(pedHandle) == value and isCharOnFoot(pedHandle) then
                local x1, y1, z1 = getCharCoordinates(PLAYER_PED)
                local x2, y2, z2 = getCharCoordinates(pedHandle)
                if getDistanceBetweenCoords3d(x1, y1, z1, x2, y2, z2) <= radius and z1 - z2 <= 4 then
                    cops = cops + 1
                end
            end
        end
    end
    return cops
end

function Timer()
    while autoDokladActive do
        second = second - 1
        if second == -1 and minute == 0 then
            sampSendChat('/r Пост: КПП. Состав: ' .. GetCopsInRadiusOnFoot(10) .. '. Состояние: Спокойное.')
            minute = 7
            second = math.random(20, 59)
            if second >= 10 then
                text = minute .. '{FF8C00}:{FFFFFF}' .. second
            else
                text = minute .. '{FF8C00}:{FFFFFF}0' .. second
            end

        elseif second == -1 then
            second = 59
            minute = minute - 1
            text = minute .. '{FF8C00}:{FFFFFF}' .. second
        elseif second >= 10 then
            text = minute .. '{FF8C00}:{FFFFFF}' .. second
        else
            text = minute .. '{FF8C00}:{FFFFFF}0' .. second
        end
        wait(1000)
    end
end

function SetTimerAtTheBottom()
    local a, b
    a, b = getScreenResolution()
    a = a / 2 - renderGetFontDrawTextLength(Font, '0:00') / 2 -- выравнивание по горизонтали
    b = b * 0.95
    return a, b
end

-- Мимгуи
imgui.OnFrame(function() return WinState[0] end, function()
    imgui.SetNextWindowPos(imgui.ImVec2(screenX / 2, screenY / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.SetNextWindowSize(imgui.ImVec2(250, 280), imgui.Cond.Always)
    imgui.Begin('Police Shlagbaum Helper', WinState, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)

    if imgui.BeginTabBar('Tabs') then -- задаём начало вкладок
        -- ВКЛАДКА ШЛАГБАУМ
        if imgui.BeginTabItem(u8'Шлагбаум') then
        
            if imgui.Checkbox(u8'Вкл/выкл', checkboxShlagbaum) then
                sampAddChatMessage(checkboxShlagbaum[0] and 'включен!' or 'не убивай мен..', -1)
                RunAutoShlagbaum()
            end
            
            imgui.Text(u8'Радиус действия:')
            if imgui.SliderInt(u8'метров', SliderRadiusCars, 1, 100) then
                settings.MAIN.radius = SliderRadiusCars[0]
                inicfg.save(settings, "PoliceShlagbaumHelper.ini")
                sampAddChatMessage(SliderRadiusCars[0], -1)
            end

            imgui.Text(u8'Режим работы:')
            if imgui.RadioButtonIntPtr(u8'Стандартный', radioMode, 1) then
                settings.MAIN.mode = 1
                settings.MAIN.depth = 4
                inicfg.save(settings, "PoliceShlagbaumHelper.ini")
                sampAddChatMessage(radioMode[0], -1)
            end
        
            if imgui.RadioButtonIntPtr(u8'СФПД СЕВЕР', radioMode, 2) then
                settings.MAIN.mode = 2
                settings.MAIN.depth = 12
                inicfg.save(settings, "PoliceShlagbaumHelper.ini")
                sampAddChatMessage(radioMode[0], -1)
            end
            
            imgui.Text(u8'Дополнительно:')
            if imgui.Checkbox(u8'Пропускать грузовик вояк', checkboxBarracks) then
                settings.MAIN.passBarracks = not settings.MAIN.passBarracks
                inicfg.save(settings, "PoliceShlagbaumHelper.ini")
            end
            
            imgui.EndTabItem()
        end

        -- ВКЛАДКА ДОКЛАДЫ
        if imgui.BeginTabItem(u8'Доклады') then
            if imgui.Checkbox(u8'Вкл/выкл', checkboxDoklad) then
                sampAddChatMessage(checkboxDoklad[0] and 'АвтоДоклады включены!' or 'АвтоДоклады выключены', -1)
                AutoDoklad()
            end
            
            imgui.Separator()

            imgui.Text(u8'Настройки таймера')
            imgui.Button(u8'Изменить положение таймера')
            imgui.Button(u8'По умолчанию')
            imgui.EndTabItem() -- конец вкладки
        end
        
        -- ВКЛАДКА ДРУЗЬЯ
        if imgui.BeginTabItem(u8'Друзья') then
        
            if imgui.Checkbox(u8'Вкл/выкл', checkboxPassByNick) then
                settings.MAIN.passByNick = not settings.MAIN.passByNick
                inicfg.save(settings, "PoliceShlagbaumHelper.ini")
            end
            
            imgui.InputTextWithHint(u8'##', u8'Введите ник', inputField, 256)
            imgui.SameLine()
            if (imgui.Button(faicons('plus'))) then
                nickNameWithoutSpaces = noSpace(u8:decode(ffi.string(inputField)))
                
                if nickNameWithoutSpaces ~= '' then
                    inputField = new.char[256]()
                    file = io.open(getGameDirectory().."//moonloader//config//FriendsList.txt", "a")
                    file:write((nickNameWithoutSpaces) .. "\n")
                    file:close()
                    UpdateFriendsList()
                end
            end
            if imgui.IsItemHovered() then
                imgui.BeginTooltip()
                imgui.Text(u8'Нажмите чтобы добавить')
                imgui.EndTooltip()
            end
            
            -- imgui.Separator()

            if imgui.BeginChild('Name', imgui.ImVec2(0, 155), true) then
                for line in io.lines(getGameDirectory()..'//moonloader//config//FriendsList.txt') do
                    imgui.Text(u8(line))
                    if imgui.IsItemHovered() then
                        imgui.BeginTooltip()
                        imgui.Text(u8'Нажмите чтобы удалить')
                        imgui.EndTooltip()
                    end
                    if imgui.IsItemClicked() then
                        deleteNickName(line)
                        sampAddChatMessage('Вы удалили ' .. line, -1)
                    end
                 end
                imgui.EndChild() -- обязательно следите за тем, чтобы каждый чайлд был закрыт
            end
            
            

            imgui.EndTabItem() -- конец вкладки
        end
        imgui.EndTabBar()
    end

    
    imgui.End()
end)

-- addEventHandler('onWindowMessage', function(msg, wparam, lparam) -- закртыие окна мимгуи на Escape
--     if msg == wm.WM_KEYDOWN or msg == wm.WM_SYSKEYDOWN then
--         if wparam == vkeys.VK_ESCAPE and WinState[0] then 
--             consumeWindowMessage(true, false)
--             WinState[0] = not WinState[0]
--         end
--     end
-- end)

addEventHandler('onWindowMessage', function(msg, wparam, lparam) -- закрытие окна мимгуи на Escape
    if wparam == 27 then
        if WinState[0] then
            if msg == wm.WM_KEYDOWN then
                consumeWindowMessage(true, false)
            end
            if msg == wm.WM_KEYUP then
                WinState[0] = false
            end
        end
    end
end)

function UpdateFriendsList()
    for line in io.lines(getGameDirectory()..'//moonloader//config//FriendsList.txt') do
        if line ~= '' then
            table.insert(friendsList, line)
        end
    end
end

-- удаление пробелов в строке, нашел в инете
function noSpace(str)
    local normalisedString = string.gsub(str, "%s+", "")
    return normalisedString
end

function deleteNickName(nickname)
    local nicks = {}
    friendsList = {}
    for line in io.lines(getGameDirectory()..'//moonloader//config//FriendsList.txt') do
        if line ~= nickname then
            table.insert(nicks, line)
        end
    end

    file = io.open(getGameDirectory().."//moonloader//config//FriendsList.txt", "w")
    for _, value in ipairs(nicks) do
        file:write(value .. "\n")
    end
    file:close()
    UpdateFriendsList()
end

function blackorangetheme()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
    local ORANGE = ImVec4(1.00, 0.50, 0.00, 1.00)      
    local ORANGE_LIGHT = ImVec4(1.00, 0.60, 0.10, 1.00) 
    local ORANGE_DARK = ImVec4(0.90, 0.40, 0.00, 1.00)  
    style.WindowRounding = 5.0
    style.ChildRounding = 4.0
    style.FrameRounding = 4.0
    style.PopupRounding = 4.0
    style.ScrollbarRounding = 4.0
    style.GrabRounding = 4.0
    style.TabRounding = 4.0
    style.WindowTitleAlign = ImVec2(0.5, 0.5)
    style.ButtonTextAlign = ImVec2(0.5, 0.5)
    
    style.WindowPadding = ImVec2(15, 5)
    style.FramePadding = ImVec2(8, 4)
    style.ItemSpacing = ImVec2(10, 8)
    style.ItemInnerSpacing = ImVec2(6, 6)
    style.ScrollbarSize = 12
    style.GrabMinSize = 8
    colors[clr.Text] = ImVec4(1.00, 1.00, 1.00, 1.00)
    colors[clr.TextDisabled] = ImVec4(0.60, 0.60, 0.60, 1.00)
    colors[clr.WindowBg] = ImVec4(0.06, 0.06, 0.06, 0.90)
    colors[clr.ChildBg] = ImVec4(0.08, 0.08, 0.08, 1.00)
    colors[clr.PopupBg] = ImVec4(0.08, 0.08, 0.08, 0.94)
    colors[clr.Border] = ImVec4(ORANGE.x, ORANGE.y, ORANGE.z, 0.50)
    colors[clr.BorderShadow] = ImVec4(0.00, 0.00, 0.00, 0.00)
    
    colors[clr.FrameBg] = ImVec4(0.25, 0.25, 0.25, 1.00)
    colors[clr.FrameBgHovered] = ORANGE_DARK
    colors[clr.FrameBgActive] = ORANGE
    
    colors[clr.TitleBg] = ImVec4(0.06, 0.06, 0.06, 0.90)
    colors[clr.TitleBgActive] = ImVec4(0.06, 0.06, 0.06, 0.90)
    colors[clr.TitleBgCollapsed] = ImVec4(0.00, 0.00, 0.00, 0.51)
    
    colors[clr.Button] = ORANGE_DARK
    colors[clr.ButtonHovered] = ORANGE
    colors[clr.ButtonActive] = ORANGE_LIGHT
    
    colors[clr.Header] = ORANGE_DARK
    colors[clr.HeaderHovered] = ORANGE
    colors[clr.HeaderActive] = ORANGE_LIGHT
    
    colors[clr.Separator] = ImVec4(1.00, 0.50, 0.00, 0.50)  
    colors[clr.SeparatorHovered] = ORANGE_LIGHT
    colors[clr.SeparatorActive] = ORANGE_LIGHT
    
    colors[clr.ResizeGrip] = ORANGE_DARK
    colors[clr.ResizeGripHovered] = ORANGE
    colors[clr.ResizeGripActive] = ORANGE_LIGHT
    colors[clr.CheckMark] = ORANGE_LIGHT
    colors[clr.SliderGrab] = ORANGE
    colors[clr.SliderGrabActive] = ORANGE_LIGHT
    
    colors[clr.Tab] = ORANGE_DARK
    colors[clr.TabHovered] = ORANGE
    colors[clr.TabActive] = ORANGE_LIGHT
    colors[clr.TabUnfocused] = ImVec4(0.15, 0.15, 0.15, 1.00)
    colors[clr.TabUnfocusedActive] = ImVec4(0.20, 0.20, 0.20, 1.00)
    
    colors[clr.TextSelectedBg] = ImVec4(ORANGE.x, ORANGE.y, ORANGE.z, 0.35)
    colors[clr.DragDropTarget] = ORANGE
    colors[clr.NavHighlight] = ORANGE
    colors[clr.NavWindowingHighlight] = ImVec4(1.00, 1.00, 1.00, 0.70)
    colors[clr.NavWindowingDimBg] = ImVec4(0.80, 0.80, 0.80, 0.20)
    colors[clr.ModalWindowDimBg] = ImVec4(0.00, 0.00, 0.00, 0.70)
    
    colors[clr.PlotLines] = ORANGE
    colors[clr.PlotLinesHovered] = ORANGE_LIGHT
    colors[clr.PlotHistogram] = ORANGE
    colors[clr.PlotHistogramHovered] = ORANGE_LIGHT
end