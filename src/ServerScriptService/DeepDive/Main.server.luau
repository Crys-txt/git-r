-- Entry point: wires players, the trench, diving, the hub domes, the shop and autosave together.
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local Harbor = require(script.Parent.Harbor)
local Trench = require(script.Parent.Trench)
local Dive = require(script.Parent.Dive)
local Shop = require(script.Parent.Shop)

local AUTOSAVE_SECONDS = 120

Trench.onHazard = Dive.onHazard
Trench.onCatch = Dive.onCatch
Trench.onBubble = Dive.onBubble
Dive.homeCFrame = Harbor.homeCFrame
Shop.onPurchase = Dive.refreshStats

Dive.onZone = function(player, zone, meters)
	Harbor.post(("%s reached the %s (%d m)"):format(player.DisplayName, zone.name, meters))
end

Dive.onEnded = function(player, summary)
	Harbor.refresh(player)
	for _, name in summary.newSpecies do
		Harbor.post(("%s discovered the %s!"):format(player.DisplayName, name))
	end
	if summary.reason == "surfaced" and summary.depth >= 20 then
		Harbor.post(("%s surfaced from %d m"):format(player.DisplayName, summary.depth))
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.defer(Dive.refreshStats, player)
	end)
	if PlayerData.load(player) then
		Harbor.assignDome(player)
		Dive.refreshStats(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Dive.stop(player, "left")
	Harbor.releaseDome(player)
	PlayerData.release(player)
end)

game:BindToClose(PlayerData.saveAll)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		PlayerData.saveAll()
	end
end)
