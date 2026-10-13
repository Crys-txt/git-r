-- Entry point: wires player join/leave, the diving bell, the harbor and autosave together.
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)
local Harbor = require(script.Parent.Harbor)
local Dive = require(script.Parent.Dive)

local AUTOSAVE_SECONDS = 120
local FEED_FROM_FLOOR = 3 -- floors below this are too common to announce

local bellPrompt = workspace.Harbor.DivingBell.Dome.ProximityPrompt
bellPrompt.Triggered:Connect(Dive.start)

Dive.onFloorCleared = function(player, floor)
	if floor >= FEED_FROM_FLOOR then
		Harbor.post(("%s reached floor %d"):format(player.DisplayName, floor))
	end
end

Dive.onEnded = function(player, summary)
	Harbor.refresh(player)
	if summary.reason == "zoneCleared" then
		Harbor.post(("%s cleared the Sunlit Reef!"):format(player.DisplayName))
	elseif summary.reason == "surfaced" and #summary.kept > 0 then
		Harbor.post(("%s surfaced with %d catches"):format(player.DisplayName, #summary.kept))
	end
end

local function onPlayerAdded(player)
	if PlayerData.load(player) then
		Harbor.assignPlot(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Dive.stop(player, "left")
	Harbor.releasePlot(player)
	PlayerData.release(player)
end)

game:BindToClose(PlayerData.saveAll)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		PlayerData.saveAll()
	end
end)
