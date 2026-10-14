-- Dive Shop in the shop dome: sell catches for pearls, buy equipment tiers.
-- The client calls ShopRequest(action, ...). To add a shop action, add a function to `handlers`.
-- Fish on display in your dome are not in `catches`, so they can never be sold.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.DeepDive.Config)
local PlayerData = require(script.Parent.PlayerData)
local Harbor = require(script.Parent.Harbor)

local Remotes = ReplicatedStorage.DeepDive.Remotes
local counter = workspace:WaitForChild("Harbor"):WaitForChild("ShopDome"):WaitForChild("Counter")

local MAX_DISTANCE = 25 -- studs from the counter; stops shopping from across the map

local Shop = {}
Shop.onPurchase = nil -- function(player), set by Main to re-apply equipment stats
local handlers = {}

-- Returns ok, message. `data` is the player's live profile.
function handlers.state()
	return true, nil
end

function handlers.sell(player, data, id, amount)
	local creature = type(id) == "string" and Config.getCreature(id)
	local owned = creature and data.catches[id] or 0
	if owned <= 0 then
		return false, "You don't have that catch"
	end
	amount = math.clamp(math.floor(tonumber(amount) or 1), 1, owned)
	data.catches[id] = owned - amount > 0 and owned - amount or nil
	local earned = amount * Config.Rarities[creature.rarity].sellPrice
	data.pearls += earned
	Harbor.refresh(player)
	return true, ("Sold %d %s for %d pearls"):format(amount, creature.name, earned)
end

function handlers.buy(player, data, itemId)
	local item = type(itemId) == "string" and Config.getEquipment(itemId)
	if not item then
		return false, "That item isn't sold here"
	end
	local nextTier = (data.equipment[itemId] or 0) + 1
	local tier = item.tiers[nextTier]
	if not tier then
		return false, item.name .. " is already maxed out"
	end
	if data.pearls < tier.price then
		return false, ("%s costs %d pearls (you have %d)"):format(tier.name, tier.price, data.pearls)
	end
	data.pearls -= tier.price
	data.equipment[itemId] = nextTier
	if Shop.onPurchase then
		Shop.onPurchase(player)
	end
	return true, ("Bought %s!"):format(tier.name)
end

local function snapshot(data)
	return { pearls = data.pearls, catches = data.catches, equipment = data.equipment }
end

Remotes.ShopRequest.OnServerInvoke = function(player, action, ...)
	local handler = handlers[action]
	local data = PlayerData.get(player)
	if not (handler and data) then
		return { ok = false, message = "The shop is closed" }
	end
	if player:GetAttribute("Diving") then
		return { ok = false, message = "Surface first", state = snapshot(data) }
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - counter.Position).Magnitude > MAX_DISTANCE then
		return { ok = false, message = "Walk up to the Dive Shop", state = snapshot(data) }
	end
	local ok, message = handler(player, data, ...)
	PlayerData.sync(player)
	return { ok = ok, message = message, state = snapshot(data) }
end

return Shop
