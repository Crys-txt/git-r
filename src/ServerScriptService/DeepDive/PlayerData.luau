-- Loads, holds and saves each player's permanent progress (pearls, catches, wings, best depth).
local DataStoreService = game:GetService("DataStoreService")

local PlayerData = {}

local STORE_NAME = "DeepDive_v1"
local profiles = {} -- [player] = { data = table, canSave = boolean }

local storeOk, store = pcall(DataStoreService.GetDataStore, DataStoreService, STORE_NAME)
if not storeOk then
	warn("[DeepDive] DataStore unavailable, progress will not save:", store)
	store = nil
end

local function newProfile()
	return { pearls = 0, catches = {}, wings = { ReefTank = true }, bestDepth = 0, dives = 0 }
end

local function keyFor(player)
	return "player_" .. player.UserId
end

function PlayerData.load(player)
	local profile = newProfile()
	local canSave = store ~= nil
	if store then
		local ok, saved = pcall(store.GetAsync, store, keyFor(player))
		if not ok then
			-- Never overwrite real progress with a blank profile after a failed load.
			canSave = false
			warn("[DeepDive] Could not load data for", player.Name, "- progress will not save this session:", saved)
		elseif type(saved) == "table" then
			for field, value in saved do
				profile[field] = value
			end
		end
	end
	if not player.Parent then
		return nil -- left while loading
	end
	profiles[player] = { data = profile, canSave = canSave }
	PlayerData.sync(player)
	return profile
end

function PlayerData.get(player)
	local entry = profiles[player]
	return entry and entry.data
end

-- Pushes the numbers other players can see (leaderboard) and the HUD reads.
function PlayerData.sync(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		for _, name in { "Deepest", "Pearls" } do
			local value = Instance.new("IntValue")
			value.Name = name
			value.Parent = stats
		end
		stats.Parent = player
	end
	stats.Deepest.Value = data.bestDepth
	stats.Pearls.Value = data.pearls
	player:SetAttribute("Pearls", data.pearls)
end

function PlayerData.save(player)
	local entry = profiles[player]
	if not (entry and entry.canSave and store) then
		return
	end
	local ok, err = pcall(store.SetAsync, store, keyFor(player), entry.data)
	if not ok then
		warn("[DeepDive] Save failed for", player.Name, err)
	end
end

function PlayerData.release(player)
	PlayerData.save(player)
	profiles[player] = nil
end

function PlayerData.saveAll()
	for player in profiles do
		PlayerData.save(player)
	end
end

return PlayerData
