-- ============================================
-- ЧИТ-СКРИПТ ДЛЯ ROBLOX (Casual Hub V1)
-- Разработан для игры с системой "Барыга"
-- ============================================

-- Подключение UI библиотеки с GitHub
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/bigdanix/roblox-ui-libs/refs/heads/main/samet%20ui/source%20%2B%20example"))()

-- ============================================
-- 1. ПОЛУЧЕНИЕ СЕРВИСОВ ИГРЫ
-- ============================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

-- Для обхода защиты
local CurrentCamera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ============================================
-- 2. НАСТРОЙКИ (по умолчанию)
-- ============================================
local Settings = {
    ESP_Enabled = true,              -- Включить ESP
    ShowLegendary = true,            -- Показывать легендарные предметы
    ShowSuperRare = true,            -- Показывать супер-редкие
    TracerLines = true,              -- Линии к предметам
    MaxDistance = 800,               -- Максимальная дистанция ESP
    
    AutoSell_Enabled = false,        -- Авто-продажа
    AutoSell_Delay = 5,              -- Задержка между продажами (сек)
    Sell_Filters = {                 -- Фильтры редкости для продажи
        Common = false,
        Uncommon = false,
        Rare = false,
        Epic = false,
        Legendary = false
    },
    
    InstantTake_Enabled = false,     -- Мгновенный подбор
    AutoBuy_Enabled = false          -- Авто-покупка
}

-- Позиция для телепортации к барыге
local BarigaTeleportPos = CFrame.new(-3616.0456542969, 327.11117553711, -234.45213317871)

-- ============================================
-- 3. СБОР ДАННЫХ О ПРЕДМЕТАХ
-- ============================================

-- Кэши данных о предметах
local ItemCache = {}
local ItemCache2 = {}

-- Рекурсивный сбор данных из конфигов
local function collectItemData(data, depth, seen)
    if depth > 5 then return end
    
    if seen then
        if seen[data] then return end
        seen[data] = true
    end
    
    for key, value in pairs(data) do
        if type(value) == "table" then
            if value.id and value.name then
                ItemCache[tostring(value.id)] = value
            else
                collectItemData(value, depth + 1, seen)
            end
        end
    end
end

-- Поиск конфигов в ReplicatedStorage
for _, module in ipairs(ReplicatedStorage:GetDescendants()) do
    if module:IsA("ModuleScript") then
        local name = string.lower(module.Name)
        if name:match("config") or name:match("clothing") or name:match("item") or name:match("ticket") then
            pcall(function()
                collectItemData(require(module), 0)
            end)
        end
    end
end

-- Дополнительный сбор данных из AccessoryConfig
local AccessoryData = {}
pcall(function()
    local config = require(ReplicatedStorage.Configs.AccessoryConfig)
    for category, items in pairs(config) do
        if type(items) == "table" and category ~= "Categories" then
            for _, itemGroup in pairs(items) do
                if type(itemGroup) == "table" then
                    for _, item in ipairs(itemGroup) do
                        local itemInfo = {
                            name = item.name or "Неизвестно",
                            chance = item.spawnChance or item.chance or 0,
                            economyProfile = item.economyProfile or item.rarity or "Common",
                            price = item.fairPrice or item.price or "?"
                        }
                        
                        if item.id then
                            AccessoryData[tostring(item.id)] = itemInfo
                        end
                        if item.customModelName then
                            AccessoryData[tostring(item.customModelName)] = itemInfo
                        end
                        if item.assetId then
                            AccessoryData[tostring(item.assetId)] = itemInfo
                        end
                        if item.bundleId then
                            AccessoryData[tostring(item.bundleId)] = itemInfo
                        end
                        if item.assetIds and type(item.assetIds) == "table" then
                            for _, assetId in ipairs(item.assetIds) do
                                AccessoryData[tostring(assetId)] = {
                                    name = item.name or "Неизвестно",
                                    chance = item.spawnChance or item.chance or 0,
                                    economyProfile = item.economyProfile or item.rarity or "Common",
                                    price = item.price or "?"
                                }
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================
-- 4. ФУНКЦИИ ДЛЯ РАБОТЫ С ПРЕДМЕТАМИ
-- ============================================

-- Получение ID предмета из MeshId/TextureId
local function getItemIdFromMesh(obj)
    local meshId = ""
    local textureId = ""
    
    local function checkMesh(mesh)
        if mesh:IsA("MeshPart") then
            if mesh.MeshId ~= "" then
                local id = mesh.MeshId:match("%d+")
                if id then
                    meshId = id
                    if mesh.TextureID ~= "" then
                        local texId = mesh.TextureID:match("%d+")
                        if texId then
                            textureId = texId
                            -- Проверяем SurfaceAppearance
                            local surface = mesh:FindFirstChildWhichIsA("SurfaceAppearance")
                            if surface then
                                pcall(function()
                                    if surface.ColorMap ~= "" then
                                        local colorId = surface.ColorMap:match("%d+")
                                        if colorId then
                                            textureId = colorId
                                        end
                                    end
                                end)
                            end
                            return meshId ~= "" or textureId ~= ""
                        end
                    end
                end
            end
        end
        
        if mesh:IsA("SpecialMesh") then
            if mesh.MeshId ~= "" then
                local id = mesh.MeshId:match("%d+")
                if id then
                    meshId = id
                    if mesh.TextureId ~= "" then
                        local texId = mesh.TextureId:match("%d+")
                        if texId then
                            textureId = texId
                            return meshId ~= "" or textureId ~= ""
                        end
                    end
                end
            end
        end
        return false
    end
    
    if checkMesh(obj) then
        return meshId .. "_" .. textureId
    end
    
    for _, descendant in ipairs(obj:GetDescendants()) do
        if checkMesh(descendant) then
            return meshId .. "_" .. textureId
        end
    end
    
    return nil
end

-- Кэш для аксессуаров
local AccessoryCache = {}

-- Сбор аксессуаров из ReplicatedStorage
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("Accessory") or obj:IsA("Model") or obj:IsA("MeshPart") then
        local id = getItemIdFromMesh(obj)
        if id then
            local name = obj.Name:gsub("^ACC_", "")
            local data = AccessoryData[name] or AccessoryData[name:gsub("^CUSTOM_", "")]
            if data then
                AccessoryCache[obj] = data
            end
        end
    end
end

-- ============================================
-- 5. ESP (ВИЗУАЛЬНЫЙ ПОИСК ПРЕДМЕТОВ)
-- ============================================

-- Проверка, находится ли предмет вне карты
local function isItemInVoid(item)
    if item.Parent == Workspace then
        return true
    end
    
    if item:IsA("Model") and item.PrimaryPart then
        local pos = item.PrimaryPart.Position
    elseif item:IsA("BasePart") then
        local pos = item.Position
        if pos.Y > 1000 or pos.Y < -500 then
            return true
        end
    end
    return false
end

local ESPObjects = {}

-- Получение ID одежды
local function getClothingId(item)
    local shirt = item:FindFirstChildOfClass("Shirt")
    local pants = item:FindFirstChildOfClass("Pants")
    
    if shirt then
        return shirt.ShirtTemplate:match("%d+")
    end
    if pants then
        return pants.PantsTemplate:match("%d+")
    end
    return nil
end

-- Проверка на игрока
local function isPlayer(item)
    local parent = item.Parent
    while parent do
        if parent:FindFirstChildOfClass("Humanoid") then
            return true
        end
        parent = parent.Parent
    end
    return false
end

-- Создание ESP для предмета
local function createESP(model, rootPart, itemName, price, chance, rarity, isSuper, isLegendary, textureId, isAccessory)
    if not model:IsA("BasePart") then
        return
    end
    
    local parent = model.Parent
    while parent do
        if model:GetAttribute("ESP_Attached_Top") then
            return
        end
        model:SetAttribute("ESP_Attached_Top", true)
        
        if model:GetAttribute("ESP_Attached") then
            return
        end
        
        if rootPart then
            if rootPart:GetAttribute("ESP_Root_Attached") then
                return
            end
        end
        
        model:SetAttribute("ESP_Attached", true)
        if rootPart then
            rootPart:SetAttribute("ESP_Root_Attached", true)
        end
        
        -- Создание текста
        local text = Drawing.new("Text")
        text.Visible = false
        text.Center = true
        text.Outline = true
        text.Font = 2
        text.Size = 16
        text.ZIndex = 2
        
        -- Создание линии
        local line = Drawing.new("Line")
        line.Visible = false
        line.Thickness = 1.5
        line.ZIndex = 1
        
        -- Формирование базового текста
        local rarityText = isSuper and "SUPER RARE" or (isLegendary and "LEGENDARY" or "")
        local baseText = string.format(
            "[%s]\n%s\n%sШанс: %s%%",
            rarityText:upper(),
            tostring(itemName),
            price and price .. " R$ | " or "",
            tostring(chance)
        )
        
        table.insert(ESPObjects, {
            model = model,
            root = rootPart,
            savedTex = textureId,
            text = text,
            line = line,
            isSuper = isSuper,
            isLegendary = isLegendary,
            baseText = baseText,
            isAccessory = isAccessory
        })
        return
    end
end

-- Обработка модели для ESP
local function processModelForESP(model)
    if not model or not model:IsA("Model") then
        return
    end
    
    -- Игнорируем игроков
    if Players:GetPlayerFromCharacter(model) then
        return
    end
    
    -- Игнорируем предметы в пустоте
    if isItemInVoid(model) then
        return
    end
    
    -- Уже обработано
    if model:GetAttribute("ESP_Attached") then
        return
    end
    
    -- Проверяем наличие частей
    if not (model:FindFirstChild("HumanoidRootPart") or 
            model:FindFirstChild("Torso") or 
            model:FindFirstChildWhichIsA("BasePart")) then
        return
    end
    
    -- Получаем данные об одежде
    local clothingId = getClothingId(model)
    if clothingId then
        local data = ItemCache2[clothingId]
        if data then
            local chance = tonumber(data.spawnChance or data.chance or "100") or 100
            local isSuper = chance <= 0.09
            local isLegendary = chance <= 0.3 and chance > 0.09
            
            if isSuper or isLegendary then
                createESP(
                    model,
                    model:FindFirstChild("HumanoidRootPart") or 
                    model:FindFirstChild("Torso") or 
                    model:FindFirstChildWhichIsA("BasePart"),
                    data.name or "Unknown",
                    tostring(data.fairPrice or data.price or "?"),
                    tostring(data.chance or "100"),
                    data.economyProfile or data.rarity,
                    isSuper,
                    isLegendary,
                    clothingId,
                    false
                )
            end
        end
    end
end

-- Проверка наличия ESP
local function hasESP(item)
    local parent = item.Parent
    while parent do
        if parent:GetAttribute("ESP_Attached") then
            return true
        end
        parent = parent.Parent
    end
    return false
end

-- Обработка аксессуара для ESP
local function processAccessoryForESP(item)
    if isPlayer(item) then
        return false
    end
    
    if isItemInVoid(item) then
        return false
    end
    
    if item:GetAttribute("ESP_Attached") then
        return false
    end
    
    if hasESP(item) then
        return false
    end
    
    local id = getItemIdFromMesh(item)
    if id then
        local data = AccessoryData[id]
        if data then
            local chance = tonumber(data.chance) or 100
            local isSuper = chance <= 2
            local isLegendary = chance <= 5 and chance > 2
            
            if isSuper or isLegendary then
                createESP(
                    item,
                    item,
                    data.name,
                    tostring(data.price) or nil,
                    tostring(data.chance),
                    data.economyProfile or data.rarity,
                    isSuper,
                    isLegendary,
                    nil,
                    true
                )
                return true
            end
        end
    end
    return false
end

-- Обработка специальных предметов
local function processSpecialItemForESP(item)
    if isPlayer(item) then
        return
    end
    
    if isItemInVoid(item) then
        return
    end
    
    if item:GetAttribute("ESP_Attached") then
        return
    end
    
    if hasESP(item) then
        return
    end
    
    local id = getItemIdFromMesh(item)
    if id then
        local data = AccessoryCache[id]
        if data then
            local chance = tonumber(data.chance) or 100
            local isSuper = chance <= 0.09
            local isLegendary = chance <= 0.3 and chance > 0.09
            
            if isSuper or isLegendary then
                createESP(
                    item,
                    item,
                    data.name or "Unknown",
                    tostring(data.price) or nil,
                    tostring(data.chance),
                    data.economyProfile or data.rarity,
                    isSuper,
                    isLegendary,
                    nil,
                    true
                )
            end
        end
    end
end

-- ============================================
-- 6. ОБНОВЛЕНИЕ ESP В РЕАЛЬНОМ ВРЕМЕНИ
-- ============================================

-- Фоновый поток очистки старых ESP
task.spawn(function()
    while true do
        task.wait(1)
        for i = #ESPObjects, 1, -1 do
            local esp = ESPObjects[i]
            local model = esp.model
            
            if model then
                if esp.isAccessory then
                    -- Проверяем аксессуар
                    if isPlayer(model) then
                        esp.text.Visible = false
                        esp.text:Remove()
                        esp.line.Visible = false
                        esp.line:Remove()
                        model:SetAttribute("ESP_Attached", nil)
                        table.remove(ESPObjects, i)
                    end
                else
                    -- Проверяем одежду
                    local newId = getClothingId(model)
                    if newId and newId ~= esp.savedTex then
                        esp.text.Visible = false
                        esp.text:Remove()
                        esp.line.Visible = false
                        esp.line:Remove()
                        model:SetAttribute("ESP_Attached", nil)
                        table.remove(ESPObjects, i)
                        processModelForESP(model)
                    end
                end
            else
                -- Объект удален
                esp.text.Visible = false
                esp.text:Remove()
                esp.line.Visible = false
                esp.line:Remove()
                table.remove(ESPObjects, i)
            end
        end
    end
end)

-- Первоначальное сканирование мира
task.spawn(function()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        local className = obj.ClassName
        
        if className == "Shirt" or className == "Pants" then
            if obj.Parent and obj.Parent.ClassName == "Model" then
                processModelForESP(obj.Parent)
            end
        elseif className == "Model" or className == "MeshPart" or 
               className == "Part" or className == "Accessory" or className == "Tool" then
            if not processAccessoryForESP(obj) then
                processSpecialItemForESP(obj)
            end
        end
    end
end)

-- Обновление ESP каждый кадр
RunService.RenderStepped:Connect(function()
    local viewportSize = CurrentCamera.ViewportSize
    local screenCenter = Vector2.new(viewportSize.X / 2, viewportSize.Y)
    
    for i = #ESPObjects, 1, -1 do
        local esp = ESPObjects[i]
        local model = esp.model
        
        -- Проверка валидности
        if not model or not model.Parent or not esp.root or not esp.root.Parent then
            esp.text.Visible = false
            esp.text:Remove()
            esp.line.Visible = false
            esp.line:Remove()
            table.remove(ESPObjects, i)
        end
        
        local color = Color3.new(1, 1, 1)
        local show = Settings.ESP_Enabled
        
        if show then
            if Settings.ShowSuperRare and esp.isSuper then
                color = Color3.fromRGB(0, 0, 0)
            elseif Settings.ShowLegendary and esp.isLegendary then
                color = Color3.fromRGB(255, 180, 0)
            else
                show = false
            end
        end
        
        -- Проверка дистанции
        local inRange = false
        if show then
            inRange = (CurrentCamera.CFrame.Position - esp.root.Position).Magnitude <= Settings.MaxDistance
        end
        
        if inRange then
            local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(esp.root.Position)
            
            if onScreen then
                esp.text.Color = color
                esp.line.Color = color
                esp.text.Text = esp.baseText .. string.format("\n[%.0fm]", (CurrentCamera.CFrame.Position - esp.root.Position).Magnitude)
                esp.text.Position = Vector2.new(screenPos.X, screenPos.Y - 80)
                esp.text.Visible = true
                
                if Settings.TracerLines then
                    esp.line.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                    esp.line.To = Vector2.new(screenPos.X, screenPos.Y)
                    esp.line.Visible = true
                else
                    esp.line.Visible = false
                end
            else
                esp.text.Visible = false
                esp.line.Visible = false
            end
        else
            esp.text.Visible = false
            esp.line.Visible = false
        end
    end
end)

-- ============================================
-- 7. АВТО-ПРОДАЖА (БАРЫГА)
-- ============================================

local function autoSell(silent)
    local barigaRemotes = ReplicatedStorage:FindFirstChild("BarigaRemotes")
    if not barigaRemotes then
        if not silent then
            showNotification("Ошибка", "Ремоты Барыги не найдены!")
        end
        return
    end
    
    local getInventory = barigaRemotes:FindFirstChild("GetBarigaInventory")
    local getOffer = barigaRemotes:FindFirstChild("GetBarigaOffer")
    local confirmSale = barigaRemotes:FindFirstChild("ConfirmBarigaSale")
    local triggerBariga = barigaRemotes:FindFirstChild("TriggerBariga")
    local sellItems = barigaRemotes:FindFirstChild("SellItems")
    
    if not getInventory or not getOffer or not confirmSale or not triggerBariga then
        if not silent then
            showNotification("Ошибка", "Ремоты продажи не найдены!")
        end
        return
    end
    
    -- Получаем инвентарь
    local success, inventory = pcall(function()
        return getInventory:InvokeServer()
    end)
    
    if not success or type(inventory) ~= "table" then
        if not silent then
            showNotification("Ошибка", "Не удалось получить инвентарь.")
        end
        return
    end
    
    -- Фильтруем предметы
    local itemsToSell = {}
    for _, item in pairs(inventory) do
        if type(item) == "table" and item.uid and item.purchaseSource ~= "BERO" then
            if Settings.Sell_Filters[item.rarity or "Unknown"] then
                table.insert(itemsToSell, item.uid)
            end
        end
    end
    
    if #itemsToSell == 0 then
        if not silent then
            showNotification("Барыга: Пусто", "В инвентаре нет предметов выбранной редкости.")
        end
        return
    end
    
    -- Телепортируемся к барыге
    local character = LocalPlayer.Character
    if not character then
        if not silent then
            showNotification("Ошибка", "Нет RootPart для телепорта")
        end
        return
    end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        if not silent then
            showNotification("Ошибка", "Нет RootPart для телепорта")
        end
        return
    end
    
    local originalCFrame = rootPart.CFrame
    rootPart.CFrame = BarigaTeleportPos
    task.wait(0.5)
    
    -- Триггерим барыгу
    triggerBariga:FireServer()
    task.wait(0.5)
    
    -- Получаем предложение
    local offerSuccess, offerResult = pcall(function()
        return getOffer:InvokeServer(itemsToSell)
    end)
    
    if offerSuccess then
        task.wait(0.5)
        confirmSale:FireServer(true)
        
        local totalPrice = math.floor(offerResult.totalOffer or 0)
        local formattedPrice = tostring(totalPrice):reverse():gsub("(%d%d%d)", "%1,"):reverse()
        if formattedPrice:sub(1, 1) == "," then
            formattedPrice = formattedPrice:sub(2)
        end
        
        task.wait(0.5)
    else
        if not silent then
            showNotification("Ошибка Барыги", "Сервер отклонил сделку")
        end
        rootPart.CFrame = originalCFrame
    end
end

-- Фоновый поток авто-продажи
task.spawn(function()
    while true do
        if Settings.AutoSell_Enabled then
            autoSell(true)
        end
        
        local delay = Settings.AutoSell_Delay
        if type(delay) ~= "number" or delay < 1 then
            delay = 5
        end
        task.wait(delay)
    end
end)

-- ============================================
-- 8. INSTANT TAKE (МГНОВЕННЫЙ ПОДБОР)
-- ============================================

local function setupInstantTake(prompt)
    if not prompt:GetAttribute("OriginalHoldDuration") then
        prompt:SetAttribute("OriginalHoldDuration", prompt.HoldDuration)
    end
    
    if Settings.InstantTake_Enabled then
        prompt.HoldDuration = 0
    else
        prompt.HoldDuration = prompt:GetAttribute("OriginalHoldDuration") or 1
    end
end

local function applyInstantTakeToAll()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            setupInstantTake(obj)
        end
    end
end

-- Применяем Instant Take
applyInstantTakeToAll()

-- Следим за новыми промптами
Workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("ProximityPrompt") then
        task.defer(function()
            if obj.Parent then
                setupInstantTake(obj)
            end
        end)
    end
end)

-- Перехват сетевых вызовов для Instant Take
if hookmetamethod and getnamecallmethod then
    local oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        if getnamecallmethod() == "FireServer" and Settings.InstantTake_Enabled then
            if self.Name == "TakeItemHoldStart" or self.Name == "RequestTakeItem" then
                local parent = self.Parent
                if parent and parent.Name == "ShopRemotes" then
                    local args = {...}
                    task.spawn(function()
                        local takeItem = parent:FindFirstChild("TakeItem")
                        if takeItem then
                            takeItem:FireServer(unpack(args))
                        end
                    end)
                end
            end
        end
        return oldNamecall(self, ...)
    end)
end

-- ============================================
-- 9. АВТО-ПОКУПКА
-- ============================================

task.spawn(function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local shopGUI = playerGui:WaitForChild("ShopGUI", 10)
    if not shopGUI then
        return
    end
    
    local dialogueFrame = shopGUI:WaitForChild("DialogueFrame", 10)
    if dialogueFrame then
        local buttons = dialogueFrame:WaitForChild("Buttons", 5)
        if buttons then
            local buyButton = buttons:WaitForChild("BuyButton", 5)
            if buyButton then
                dialogueFrame:GetPropertyChangedSignal("Visible"):Connect(function()
                    if Settings.AutoBuy_Enabled and dialogueFrame.Visible then
                        task.wait(0.05)
                        if buyButton.Visible then
                            if firesignal then
                                firesignal(buyButton.MouseButton1Click)
                            elseif getconnections then
                                for _, conn in pairs(getconnections(buyButton.MouseButton1Click)) do
                                    conn:Fire()
                                end
                                dialogueFrame.Visible = false
                            end
                        end
                    end
                end)
            end
        end
    end
end)

-- ============================================
-- 10. СОЗДАНИЕ GUI МЕНЮ
-- ============================================

local Window = Library:Window({
    Name = "Casual Hub",
    SubName = "V1",
    Logo = "0"
})

-- Клавиша для открытия меню (по умолчанию Z)
local userInputService = game:GetService("UserInputService")
userInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.KeyCode == Enum.KeyCode.Z then
        if Window and type(Window.SetOpen) == "function" then
            Window:SetOpen(not Window.IsOpen)
        end
    end
end)

-- ============================================
-- 10.1 ВКЛАДКА "ESP"
-- ============================================
Window:Category("Visuals")
local espPage = Window:Page({
    Name = "ESP",
    Icon = "100050851789190"
})

local espSection = espPage:Section({
    Name = "Настройки ESP",
    Side = 1
})

espSection:Toggle({
    Name = "Включить ESP",
    Flag = "ESP_Enabled",
    Default = Settings.ESP_Enabled,
    Callback = function(value)
        Settings.ESP_Enabled = value
    end
})

espSection:Toggle({
    Name = "Показывать Legendary",
    Flag = "ShowLegendary",
    Default = Settings.ShowLegendary,
    Callback = function(value)
        Settings.ShowLegendary = value
    end
})

espSection:Toggle({
    Name = "Показывать Super Rare",
    Flag = "ShowSuperRare",
    Default = Settings.ShowSuperRare,
    Callback = function(value)
        Settings.ShowSuperRare = value
    end
})

espSection:Toggle({
    Name = "Линии (Tracer)",
    Flag = "TracerLines",
    Default = Settings.TracerLines,
    Callback = function(value)
        Settings.TracerLines = value
    end
})

espSection:Slider({
    Name = "Дистанция ESP",
    Flag = "MaxDistance",
    Min = 50,
    Max = 5000,
    Default = Settings.MaxDistance,
    Callback = function(value)
        Settings.MaxDistance = value
    end
})

-- ============================================
-- 10.2 ВКЛАДКА "FARM"
-- ============================================
Window:Category("Main")
local farmPage = Window:Page({
    Name = "Farm",
    Icon = "100050851789190"
})

-- Секция авто-продажи
local autoSellSection = farmPage:Section({
    Name = "Авто-Продажа Барыге",
    Side = 1
})

autoSellSection:Toggle({
    Name = "Включить Авто-Продажу",
    Flag = "AutoSell_Enabled",
    Default = Settings.AutoSell_Enabled,
    Callback = function(value)
        Settings.AutoSell_Enabled = value
    end
})

autoSellSection:Slider({
    Name = "Задержка продажи (сек)",
    Flag = "AutoSell_Delay",
    Min = 1,
    Max = 60,
    Default = Settings.AutoSell_Delay,
    Callback = function(value)
        Settings.AutoSell_Delay = value
    end
})

-- Секция фильтров продажи
local filtersSection = farmPage:Section({
    Name = "Фильтры Продажи",
    Side = 2
})

for rarity in pairs(Settings.Sell_Filters) do
    filtersSection:Toggle({
        Name = rarity,
        Flag = "Filter_" .. rarity,
        Default = false,
        Callback = function(value)
            Settings.Sell_Filters[rarity] = value
        end
    })
end

autoSellSection:Button({
    Name = "Продать сейчас",
    Callback = function()
        autoSell(false)
    end
})

-- Секция разное
local miscSection = farmPage:Section({
    Name = "Разное",
    Side = 1
})

miscSection:Toggle({
    Name = "Instant Take (Auto Loot)",
    Flag = "InstantTake",
    Default = Settings.InstantTake_Enabled,
    Callback = function(value)
        Settings.InstantTake_Enabled = value
        applyInstantTakeToAll()
    end
})

miscSection:Toggle({
    Name = "Моментальная покупка",
    Flag = "AutoBuy",
    Default = Settings.AutoBuy_Enabled,
    Callback = function(value)
        Settings.AutoBuy_Enabled = value
    end
})

-- ============================================
-- 10.3 ВКЛАДКА "SETTINGS"
-- ============================================
Window:Category("Settings")
local settingsPage = Window:Page({
    Name = "Настройки",
    Icon = "100050851789190"
})

local uiSettingsSection = settingsPage:Section({
    Name = "UI Настройки",
    Side = 1
})

uiSettingsSection:Keybind({
    Name = "Кнопка открытия меню",
    Default = Enum.KeyCode.RightControl,
    Mode = "Toggle",
    Callback = function()
        if Window and type(Window.SetOpen) == "function" then
            Window:SetOpen(not Window.IsOpen)
        end
    end
})

Window:Init()

-- ============================================
-- КОНЕЦ СКРИПТА
-- ============================================
