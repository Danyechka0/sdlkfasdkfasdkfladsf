-- ============================================================
-- CASUAL HUB V1 [КРЯКНУТАЯ ВЕРСИЯ]
-- ESP + AUTOSELL + AUTOLOOT ДЛЯ BARIGA
-- БЕЗ КЛЮЧЕЙ И ОГРАНИЧЕНИЙ
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============================================================
-- НАСТРОЙКИ
-- ============================================================

local Config = {
    ESP_Enabled = true,
    ShowLegendary = true,
    ShowSuperRare = true,
    TracerLines = true,
    MaxDistance = 800,
    AutoSell_Enabled = false,
    AutoSell_Delay = 5,
    Sell_Filters = {
        Common = false,
        Uncommon = false,
        Rare = false,
        Epic = false,
        Legendary = false
    },
    InstantTake_Enabled = false,
    AutoBuy_Enabled = false
}

local TeleportPos = CFrame.new(-3616.0456542969, 327.11117553711, -234.45213317871)

-- ============================================================
-- ЗАГРУЗКА БИБЛИОТЕКИ UI
-- ============================================================

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/bigdanix/roblox-ui-libs/refs/heads/main/samet%20ui/source%20%2B%20example"))()

-- ============================================================
-- БАЗА ДАННЫХ ПРЕДМЕТОВ
-- ============================================================

local ItemDB = {}
local AccessoryDB = {}

-- Загрузка конфигов
pcall(function()
    local configs = require(ReplicatedStorage.Configs.AccessoryConfig)
    for category, items in pairs(configs) do
        if type(items) == "table" and category ~= "Categories" then
            for _, itemList in pairs(items) do
                for _, item in ipairs(itemList) do
                    local data = {
                        name = item.name or "Неизвестно",
                        chance = item.spawnChance or item.chance or 0,
                        rarity = item.economyProfile or item.rarity or "Common",
                        price = item.fairPrice or item.price or "?"
                    }
                    if item.id then AccessoryDB[tostring(item.id)] = data end
                    if item.customModelName then AccessoryDB[tostring(item.customModelName)] = data end
                    if item.assetId then AccessoryDB[tostring(item.assetId)] = data end
                    if item.bundleId then AccessoryDB[tostring(item.bundleId)] = data end
                    if item.assetIds then
                        for _, id in ipairs(item.assetIds) do
                            AccessoryDB[tostring(id)] = data
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- ФУНКЦИЯ ОПРЕДЕЛЕНИЯ ID ПРЕДМЕТА
-- ============================================================

local function GetItemIDs(obj)
    local meshId, textureId = "", ""
    
    local function scan(instance)
        if instance:IsA("MeshPart") and instance.MeshId ~= "" then
            meshId = instance.MeshId:match("%d+") or ""
        end
        if instance:IsA("SpecialMesh") and instance.MeshId ~= "" then
            meshId = instance.MeshId:match("%d+") or ""
        end
        if instance:IsA("Shirt") and instance.ShirtTemplate ~= "" then
            textureId = instance.ShirtTemplate:match("%d+") or ""
        end
        if instance:IsA("Pants") and instance.PantsTemplate ~= "" then
            textureId = instance.PantsTemplate:match("%d+") or ""
        end
        if instance:IsA("SurfaceAppearance") and instance.ColorMap ~= "" then
            textureId = instance.ColorMap:match("%d+") or ""
        end
    end
    
    if obj:IsA("Model") then
        for _, child in ipairs(obj:GetDescendants()) do
            scan(child)
        end
    else
        scan(obj)
    end
    
    if meshId ~= "" or textureId ~= "" then
        return meshId .. "_" .. textureId
    end
    return nil
end

-- ============================================================
-- ESP СИСТЕМА
-- ============================================================

local ESPObjects = {}
local ESPGui = Instance.new("ScreenGui")
ESPGui.Parent = CoreGui
ESPGui.Name = "CasualHubESP"

local function CreateESP(model, root, itemData)
    local text = Drawing.new("Text")
    text.Visible = false
    text.Center = true
    text.Outline = true
    text.Font = 2
    text.Size = 16
    text.ZIndex = 2
    
    local line = Drawing.new("Line")
    line.Visible = false
    line.Thickness = 1.5
    line.ZIndex = 1
    
    local isLegendary = itemData.rarity == "Legendary"
    local isSuperRare = (itemData.chance or 100) <= 0.09
    
    local baseText = string.format("[%s]\n%s\n%sШанс: %s%%", 
        (itemData.rarity or "Normal"):upper(),
        itemData.name or "Unknown",
        itemData.price and (itemData.price .. " R$ | ") or "",
        tostring(itemData.chance or 0)
    )
    
    table.insert(ESPObjects, {
        model = model,
        root = root,
        text = text,
        line = line,
        isSuper = isSuperRare,
        isLegendary = isLegendary,
        baseText = baseText,
        data = itemData
    })
end

local function FindItemData(obj)
    local ids = GetItemIDs(obj)
    if ids then
        local data = AccessoryDB[ids] or ItemDB[obj.Name]
        if data then return data end
    end
    return nil
end

local function ScanItem(obj)
    if not obj or not obj.Parent then return end
    if Players:GetPlayerFromCharacter(obj) then return end
    if obj:GetAttribute("ESP_Attached") then return end
    
    local root = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Torso") or obj:FindFirstChildWhichIsA("BasePart")
    if not root then return end
    
    local itemData = FindItemData(obj)
    if not itemData then return end
    
    local chance = tonumber(itemData.chance) or 100
    local isSuper = chance <= 0.09
    local isLegendary = chance <= 0.3 and chance > 0.09
    
    if Config.ESP_Enabled then
        CreateESP(obj, root, itemData)
        obj:SetAttribute("ESP_Attached", true)
    end
end

-- ============================================================
-- СКАНЕР ПРЕДМЕТОВ
-- ============================================================

task.spawn(function()
    while true do
        task.wait(1)
        for _, child in ipairs(Workspace:GetDescendants()) do
            if child:IsA("Model") or child:IsA("MeshPart") or child:IsA("Part") or child:IsA("Accessory") then
                if not child:GetAttribute("ESP_Attached") then
                    ScanItem(child)
                end
            end
        end
    end
end)

-- ============================================================
-- РЕНДЕР ESP
-- ============================================================

RunService.RenderStepped:Connect(function()
    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y)
    
    for i = #ESPObjects, 1, -1 do
        local obj = ESPObjects[i]
        if not obj.model or not obj.model.Parent or not obj.root or not obj.root.Parent then
            obj.text:Remove()
            obj.line:Remove()
            table.remove(ESPObjects, i)
            continue
        end
        
        local color = Color3.new(1, 1, 1)
        if obj.isSuper then
            color = Color3.fromRGB(0, 0, 0)
        elseif obj.isLegendary then
            color = Color3.fromRGB(255, 180, 0)
        end
        
        local pos, onScreen = Camera:WorldToViewportPoint(obj.root.Position)
        local dist = (Camera.CFrame.Position - obj.root.Position).Magnitude
        
        if Config.ESP_Enabled and onScreen and dist <= Config.MaxDistance then
            obj.text.Color = color
            obj.text.Text = obj.baseText .. string.format("\n[%.0fm]", dist * 0.28)
            obj.text.Position = Vector2.new(pos.X, pos.Y - 80)
            obj.text.Visible = true
            
            if Config.TracerLines then
                obj.line.From = Vector2.new(center.X, viewport.Y)
                obj.line.To = Vector2.new(pos.X, pos.Y)
                obj.line.Color = color
                obj.line.Visible = true
            else
                obj.line.Visible = false
            end
        else
            obj.text.Visible = false
            obj.line.Visible = false
        end
    end
end)

-- ============================================================
-- АВТО-ПРОДАЖА (БАРЫГА)
-- ============================================================

local function AutoSell()
    local remotes = ReplicatedStorage:FindFirstChild("BarigaRemotes")
    if not remotes then return end
    
    local getInv = remotes:FindFirstChild("GetBarigaInventory")
    local getOffer = remotes:FindFirstChild("GetBarigaOffer")
    local confirmSale = remotes:FindFirstChild("ConfirmBarigaSale")
    
    if not getInv or not getOffer then return end
    
    local success, inventory = pcall(function()
        return getInv:InvokeServer()
    end)
    
    if not success or type(inventory) ~= "table" then return end
    
    local toSell = {}
    for _, item in pairs(inventory) do
        if type(item) == "table" and item.uid and item.purchaseSource ~= "BERO" then
            if Config.Sell_Filters[item.rarity or "Unknown"] then
                table.insert(toSell, item.uid)
            end
        end
    end
    
    if #toSell == 0 then return end
    
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    local savedCF = rootPart.CFrame
    rootPart.CFrame = TeleportPos
    task.wait(0.5)
    
    if confirmSale then
        confirmSale:FireServer(true)
    end
    
    local success2, result = pcall(function()
        return getOffer:InvokeServer(toSell)
    end)
    
    task.wait(0.5)
    if success2 and type(result) == "table" and result.success then
        print("Продано! Получено: " .. (result.totalOffer or 0) .. " R$")
    end
    
    rootPart.CFrame = savedCF
end

-- ============================================================
-- АВТО-ПОДБОР (INSTANT TAKE)
-- ============================================================

local function FixProximityPrompt(prompt)
    if not prompt:GetAttribute("OriginalHoldDuration") then
        prompt:SetAttribute("OriginalHoldDuration", prompt.HoldDuration)
    end
    if Config.InstantTake_Enabled then
        prompt.HoldDuration = 0
    else
        prompt.HoldDuration = prompt:GetAttribute("OriginalHoldDuration") or 1
    end
end

local function ScanPrompts()
    for _, prompt in ipairs(Workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            FixProximityPrompt(prompt)
        end
    end
end

Workspace.DescendantAdded:Connect(function(child)
    if child:IsA("ProximityPrompt") then
        task.defer(function()
            if child.Parent then
                FixProximityPrompt(child)
            end
        end)
    end
end)

-- ============================================================
-- АВТО-ПОКУПКА
-- ============================================================

task.spawn(function()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local shopGui = playerGui:WaitForChild("ShopGUI", 10)
    if not shopGui then return end
    
    local dialog = shopGui:WaitForChild("DialogueFrame", 10)
    if not dialog then return end
    
    local buttons = dialog:FindFirstChild("Buttons")
    local buyBtn = buttons and buttons:FindFirstChild("BuyButton")
    
    if buyBtn then
        dialog:GetPropertyChangedSignal("Visible"):Connect(function()
            if Config.AutoBuy_Enabled and dialog.Visible and buyBtn.Visible then
                task.wait(0.05)
                if firesignal then
                    firesignal(buyBtn.MouseButton1Click)
                else
                    buyBtn.MouseButton1Click:Fire()
                end
            end
        end)
    end
end)

-- ============================================================
-- GUI (MENU)
-- ============================================================

local Window = Library:Window({
    Name = "Casual Hub",
    SubName = "V1",
    Logo = "0"
})

-- === ESP TAB ===
local espTab = Window:Page("ESP", "100050851789190")
local espSection = espTab:Section("Настройки ESP", 1)

espSection:Toggle("Включить ESP", "ESP_Enabled", Config.ESP_Enabled, function(v)
    Config.ESP_Enabled = v
end)

espSection:Toggle("Показывать Legendary", "ShowLegendary", Config.ShowLegendary, function(v)
    Config.ShowLegendary = v
end)

espSection:Toggle("Показывать Super Rare", "ShowSuperRare", Config.ShowSuperRare, function(v)
    Config.ShowSuperRare = v
end)

espSection:Toggle("Линии (Tracer)", "TracerLines", Config.TracerLines, function(v)
    Config.TracerLines = v
end)

espSection:Slider("Дистанция ESP", "MaxDistance", 50, 5000, Config.MaxDistance, function(v)
    Config.MaxDistance = v
end)

-- === FARM TAB ===
local farmTab = Window:Page("Farm", "100050851789190")
local sellSection = farmTab:Section("Авто-Продажа Барыге", 1)

sellSection:Toggle("Включить Авто-Продажу", "AutoSell_Enabled", Config.AutoSell_Enabled, function(v)
    Config.AutoSell_Enabled = v
end)

sellSection:Slider("Задержка продажи (сек)", "AutoSell_Delay", 1, 60, Config.AutoSell_Delay, function(v)
    Config.AutoSell_Delay = v
end)

local filterSection = farmTab:Section("Фильтры Продажи", 2)
for rarity in pairs(Config.Sell_Filters) do
    filterSection:Toggle(rarity, "Filter_" .. rarity, false, function(v)
        Config.Sell_Filters[rarity] = v
    end)
end

sellSection:Button("Продать сейчас", function()
    AutoSell()
end)

-- === MISC TAB ===
local miscSection = farmTab:Section("Разное", 1)

miscSection:Toggle("Instant Take (Auto Loot)", "InstantTake", Config.InstantTake_Enabled, function(v)
    Config.InstantTake_Enabled = v
    ScanPrompts()
end)

miscSection:Toggle("Моментальная покупка", "AutoBuy", Config.AutoBuy_Enabled, function(v)
    Config.AutoBuy_Enabled = v
end)

-- === SETTINGS TAB ===
local settingsTab = Window:Page("Настройки", "100050851789190")
local uiSection = settingsTab:Section("UI Настройки", 1)

uiSection:Keybind("Кнопка открытия меню", Enum.KeyCode.RightControl, "Toggle", function()
    Window:SetOpen(not Window.IsOpen)
end)

Window:Init()

-- ============================================================
-- ТАЙМЕР АВТО-ПРОДАЖИ
-- ============================================================

task.spawn(function()
    while true do
        if Config.AutoSell_Enabled then
            AutoSell()
        end
        local delay = tonumber(Config.AutoSell_Delay) or 5
        if delay < 1 then delay = 1 end
        task.wait(delay)
    end
end)

-- ============================================================
-- ХОТКЕЙ
-- ============================================================

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Z then
        Window:SetOpen(not Window.IsOpen)
    end
end)

print("[Casual Hub] Загружен!")