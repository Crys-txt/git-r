-- One dive per player: shuffled underwater floors, oxygen ticking, catches (by touch or harpoon), hazards
-- and the end of a run. Equipment and wings shape a dive only through Stats.compute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.DeepDive.Config)
local Stats = require(ReplicatedStorage.DeepDive.Stats)
local PlayerData = require(script.Parent.PlayerData)
local FloorMechanics = require(script.Parent.FloorMechanics)

local Remotes = ReplicatedStorage.DeepDive.Remotes
local templates = ServerStorage.DeepDive.FloorTemplates
local harborSpawn = workspace:WaitForChild("Harbor"):WaitForChild("HarborSpawn")

local HARPOON_TOLERANCE = 4 -- studs of slack for latency when checking harpoon range

local activeDives = Instance.new("Folder")
activeDives.Name = "ActiveDives"
activeDives.Parent = workspace

local Dive = {}
Dive.onFloorCleared = nil -- function(player, floor), set by Main
Dive.onEnded = nil -- function(player, summary), set by Main

local runs = {} -- [player] = run
local slotsTaken = {}
local rng = Random.new()

local function ownerOf(hit)
	return Players:GetPlayerFromCharacter(hit.Parent)
end

local function humanoidOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid, character
	end
end

local function shuffled(list)
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = rng:NextInteger(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

-- Random order within each difficulty, easier floors first (template attribute Difficulty, default 1).
local function floorOrder()
	local order = shuffled(templates:GetChildren())
	local position = {}
	for i, template in order do
		position[template] = i
	end
	table.sort(order, function(a, b)
		local da, db = a:GetAttribute("Difficulty") or 1, b:GetAttribute("Difficulty") or 1
		if da ~= db then
			return da < db
		end
		return position[a] < position[b]
	end)
	return order
end

-- Weighted by rarity; hard-to-reach spots never roll a Common.
local function rollCreature(hard)
	local perRarity = {}
	for _, creature in Config.Creatures do
		perRarity[creature.rarity] = (perRarity[creature.rarity] or 0) + 1
	end
	local pool, total = {}, 0
	for _, creature in Config.Creatures do
		if not (hard and creature.rarity == "Common") then
			local weight = Config.Rarities[creature.rarity].weight / perRarity[creature.rarity]
			total += weight
			table.insert(pool, { creature = creature, weight = weight })
		end
	end
	local roll = rng:NextNumber() * total
	for _, entry in pool do
		roll -= entry.weight
		if roll <= 0 then
			return entry.creature
		end
	end
	return pool[#pool].creature
end

local function setOxygen(run, value)
	run.oxygen = math.clamp(value, 0, run.maxOxygen)
	run.player:SetAttribute("Oxygen", run.oxygen)
end

local function teleportToStart(run)
	local _, character = humanoidOf(run.player)
	local start = run.floor and run.floor:FindFirstChild("Start")
	if not (character and start) then
		return
	end
	-- Floors run along +Z, so turn the character to face the course.
	character:PivotTo(start.CFrame * CFrame.new(0, 3, 0) * CFrame.Angles(0, math.pi, 0))
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local endDive, buildFloor

local function onHazard(run)
	if run.ended or run.awaitingChoice then
		return
	end
	local now = os.clock()
	if now - run.lastHit < 1 then
		return
	end
	run.lastHit = now
	setOxygen(run, run.oxygen - Config.HAZARD_OXYGEN_COST)
	Remotes.DiveEvent:FireClient(run.player, "Hit", { cost = Config.HAZARD_OXYGEN_COST })
	if run.oxygen <= 0 then
		endDive(run.player, "outOfAir")
	else
		teleportToStart(run)
	end
end

local function spawnCatch(run, spot)
	local creature = rollCreature(spot:GetAttribute("Hard") == true)
	local rarity = Config.Rarities[creature.rarity]

	local catch = Instance.new("Part")
	catch.Name = "Catch"
	catch.Shape = Enum.PartType.Ball
	catch.Size = Vector3.new(2.5, 2.5, 2.5)
	catch.Color = creature.color
	catch.Material = Enum.Material.Neon
	catch.Anchored = true
	catch.CanCollide = false
	catch.CFrame = spot.CFrame

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 36)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = rarity.color
	label.TextStrokeTransparency = 0
	label.Text = creature.name
	label.Parent = billboard
	billboard.Parent = catch
	catch.Parent = run.floor

	TweenService:Create(catch, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = spot.CFrame + Vector3.new(0, 1, 0) }):Play()

	local function collect()
		if run.ended or not run.catches[catch] then
			return
		end
		run.catches[catch] = nil
		table.insert(run.bag, creature.id)
		run.player:SetAttribute("BagCount", #run.bag)
		Remotes.DiveEvent:FireClient(run.player, "Caught", { name = creature.name, rarity = creature.rarity })
		catch:Destroy()
	end
	run.catches[catch] = collect
	catch.Touched:Connect(function(hit)
		if ownerOf(hit) == run.player then
			collect()
		end
	end)
end

local function onExit(run)
	if run.ended or run.awaitingChoice then
		return
	end
	run.awaitingChoice = true -- oxygen pauses while the player decides
	run.cleared = run.floorIndex
	setOxygen(run, run.oxygen + Config.OXYGEN_PER_FLOOR)
	if Dive.onFloorCleared then
		Dive.onFloorCleared(run.player, run.cleared)
	end
	if run.cleared >= Config.ZONE_FLOORS then
		endDive(run.player, "zoneCleared")
		return
	end
	Remotes.DiveEvent:FireClient(run.player, "FloorCleared", { floor = run.cleared, oxygenGain = Config.OXYGEN_PER_FLOOR })
end

function buildFloor(run)
	if run.floor then
		run.floor:Destroy()
	end
	run.floorIndex += 1
	run.awaitingChoice = false
	run.catches = {}

	local floor = run.order[(run.floorIndex - 1) % #run.order + 1]:Clone()
	floor.Name = ("%s_Floor%d"):format(run.player.Name, run.floorIndex)
	floor:SetAttribute("OwnerId", run.player.UserId)
	floor:PivotTo(CFrame.new(run.origin))
	floor.Parent = activeDives
	run.floor = floor

	for _, inst in floor:GetDescendants() do
		if not inst:IsA("BasePart") then
			continue
		end
		if inst.Name == "CatchSpot" then
			spawnCatch(run, inst)
		elseif inst.Name == "Exit" then
			inst.Touched:Connect(function(hit)
				if ownerOf(hit) == run.player then
					onExit(run)
				end
			end)
		elseif inst:GetAttribute("Hazard") then
			inst.Touched:Connect(function(hit)
				if ownerOf(hit) == run.player then
					onHazard(run)
				end
			end)
		end
	end
	FloorMechanics.start(floor)
	run.player:SetAttribute("Floor", run.floorIndex)
	teleportToStart(run)
end

function endDive(player, reason)
	local run = runs[player]
	if not run or run.ended then
		return
	end
	run.ended = true
	runs[player] = nil
	slotsTaken[run.slot] = nil
	if run.diedConnection then
		run.diedConnection:Disconnect()
	end
	if run.floor then
		run.floor:Destroy()
	end

	local kept = table.clone(run.bag)
	if reason ~= "surfaced" and reason ~= "zoneCleared" then
		-- Out of air (or left mid-dive): keep the rarest share, never zero.
		table.sort(kept, function(a, b)
			return Config.rarityOrder(a) > Config.rarityOrder(b)
		end)
		local keepCount = math.ceil(#kept * Config.KEEP_ON_FAIL)
		for i = #kept, keepCount + 1, -1 do
			table.remove(kept, i)
		end
	end

	-- Kept catches go into your inventory; pearls come from selling them at the Dive Shop.
	local data = PlayerData.get(player)
	local pearls = reason == "zoneCleared" and Config.ZONE_CLEAR_BONUS or 0
	local keptInfo = {}
	for _, id in kept do
		local creature = Config.getCreature(id)
		table.insert(keptInfo, { name = creature.name, rarity = creature.rarity })
		if data then
			data.catches[id] = (data.catches[id] or 0) + 1
			data.discovered[id] = true
		end
	end
	if data then
		data.pearls += pearls
		data.bestDepth = math.max(data.bestDepth, run.cleared)
		data.dives += 1
		PlayerData.sync(player)
	end

	player:SetAttribute("Diving", false)
	player:SetAttribute("Floor", 0)
	player:SetAttribute("BagCount", 0)
	player:SetAttribute("HarpoonRange", 0)

	local summary = {
		reason = reason,
		depth = run.cleared,
		best = data and data.bestDepth or run.cleared,
		kept = keptInfo,
		lost = #run.bag - #kept,
		pearls = pearls,
	}
	if reason ~= "left" then
		local humanoid, character = humanoidOf(player)
		if humanoid then
			humanoid.WalkSpeed = Config.WALK_SPEED
			character:PivotTo(harborSpawn.CFrame + Vector3.new(0, 4, 0))
		end
		Remotes.DiveEvent:FireClient(player, "DiveEnded", summary)
	end
	if Dive.onEnded then
		Dive.onEnded(player, summary)
	end
end

function Dive.start(player)
	local humanoid = humanoidOf(player)
	local data = PlayerData.get(player)
	if runs[player] or not (humanoid and data) then
		return
	end

	local slot = 1
	while slotsTaken[slot] do
		slot += 1
	end
	slotsTaken[slot] = true

	local stats = Stats.compute(data)
	local run = {
		player = player,
		slot = slot,
		origin = Config.DIVE_ORIGIN + Vector3.new((slot - 1) * Config.SLOT_SPACING, 0, 0),
		order = floorOrder(),
		stats = stats,
		maxOxygen = Config.OXYGEN_MAX + stats.oxygen,
		floorIndex = 0,
		cleared = 0,
		oxygen = 0,
		bag = {},
		catches = {}, -- [catch part] = collect function, for the current floor
		lastHit = 0,
		lastHarpoon = 0,
		awaitingChoice = false,
		ended = false,
	}
	runs[player] = run
	humanoid.WalkSpeed = Config.SWIM_SPEED + stats.swimSpeed
	player:SetAttribute("OxygenMax", run.maxOxygen)
	player:SetAttribute("HarpoonRange", stats.harpoonRange)
	setOxygen(run, Config.OXYGEN_START + stats.oxygen)
	player:SetAttribute("BagCount", 0)
	player:SetAttribute("Diving", true)
	run.diedConnection = humanoid.Died:Connect(function()
		endDive(player, "outOfAir")
	end)
	buildFloor(run)
	Remotes.DiveEvent:FireClient(player, "DiveStarted", {})
end

Dive.stop = function(player, reason)
	endDive(player, reason)
end

Remotes.DiveChoice.OnServerEvent:Connect(function(player, action)
	local run = runs[player]
	if not run or run.ended or not run.awaitingChoice then
		return
	end
	if action == "surface" then
		endDive(player, "surfaced")
	else
		buildFloor(run)
	end
end)

-- The client picks a target; the server checks it is this run's catch and within harpoon range.
Remotes.Harpoon.OnServerEvent:Connect(function(player, target)
	local run = runs[player]
	local _, character = humanoidOf(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (run and root and typeof(target) == "Instance") then
		return
	end
	local collect = run.catches[target]
	local range = run.stats.harpoonRange
	if not collect or range <= 0 or os.clock() - run.lastHarpoon < Config.HARPOON_COOLDOWN then
		return
	end
	if (target.Position - root.Position).Magnitude > range + HARPOON_TOLERANCE then
		return
	end
	run.lastHarpoon = os.clock()
	collect()
end)

task.spawn(function()
	while true do
		task.wait(1)
		for player, run in runs do
			if not run.awaitingChoice then
				setOxygen(run, run.oxygen - 1)
				if run.oxygen <= 0 then
					endDive(player, "outOfAir")
				end
			end
		end
	end
end)

return Dive
