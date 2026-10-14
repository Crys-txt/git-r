-- Diving: you start a dive by swimming down into the trench and end it by swimming back out of its top.
-- Oxygen only drains while diving. Sprinting is faster and drains oxygen by the same factor, so the oxygen
-- spent per stud travelled never changes. Equipment and wings shape a dive only through Stats.compute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.DeepDive.Config)
local Stats = require(ReplicatedStorage.DeepDive.Stats)
local PlayerData = require(script.Parent.PlayerData)
local Trench = require(script.Parent.Trench)

local Remotes = ReplicatedStorage.DeepDive.Remotes

local TICK = 0.1 -- seconds between dive checks
local HIT_COOLDOWN = 1
local HIT_PUSH = 6 -- studs a hazard knocks you upward
local DROWN_DELAY = 1.6 -- seconds of blackout before waking up at home
local MOVING_SPEED = 2 -- studs/s; slower than this, sprinting costs nothing extra
local HARPOON_TOLERANCE = 4 -- studs of slack for latency when checking harpoon range
local FALL_RESCUE_TIME = 0.5 -- seconds of free fall in the trench before we pull a diver back to safety
local FALL_SPEED = 80 -- studs/s downward; faster than any swimmer, so it means falling

local Dive = {}
Dive.onEnded = nil -- function(player, summary), set by Main
Dive.onZone = nil -- function(player, zone, meters), set by Main
Dive.homeCFrame = nil -- function(player) -> CFrame where you wake up after drowning, set by Main

local runs = {} -- [player] = run
local sprinting = {} -- [player] = true while the sprint key is held
local recovering = {} -- [player] = time until which a drowned player can't start a new dive

local function characterOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root, character
	end
end

local function setOxygen(run, value)
	run.oxygen = math.clamp(value, 0, run.maxOxygen)
	run.player:SetAttribute("Oxygen", run.oxygen)
end

-- Re-applies speed and lamp from saved progress; call after buying equipment or respawning.
function Dive.refreshStats(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local stats = Stats.compute(data)
	player:SetAttribute("LampRange", stats.lampRange)
	local humanoid = characterOf(player)
	if humanoid then
		local speed = Config.SWIM_SPEED + stats.swimSpeed
		humanoid.WalkSpeed = sprinting[player] and speed * Config.SPRINT_MULTIPLIER or speed
	end
end

local function startDive(player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local stats = Stats.compute(data)
	local run = {
		player = player,
		stats = stats,
		maxOxygen = Config.OXYGEN_MAX + stats.oxygen,
		oxygen = 0,
		bag = {},
		maxMeters = 0,
		zone = 1,
		lastHit = 0,
		lastHarpoon = 0,
		ended = false,
	}
	runs[player] = run
	player:SetAttribute("OxygenMax", run.maxOxygen)
	player:SetAttribute("HarpoonRange", stats.harpoonRange)
	player:SetAttribute("BagCount", 0)
	player:SetAttribute("Depth", 0)
	setOxygen(run, Config.OXYGEN_START + stats.oxygen)
	player:SetAttribute("Diving", true)
	Remotes.DiveEvent:FireClient(player, "DiveStarted", {})
end

local function endDive(player, reason)
	local run = runs[player]
	if not run or run.ended then
		return
	end
	run.ended = true
	runs[player] = nil

	local kept = table.clone(run.bag)
	if reason ~= "surfaced" then
		-- Drowned (or left mid-dive): keep the rarest share, never zero.
		table.sort(kept, function(a, b)
			return Config.rarityOrder(a) > Config.rarityOrder(b)
		end)
		local keepCount = math.ceil(#kept * Config.KEEP_ON_FAIL)
		for i = #kept, keepCount + 1, -1 do
			table.remove(kept, i)
		end
	end

	-- The first catch of a species goes into your dome's tank for good; the rest can be sold.
	local data = PlayerData.get(player)
	local keptInfo, newSpecies = {}, {}
	for _, id in kept do
		local creature = Config.getCreature(id)
		table.insert(keptInfo, { name = creature.name, rarity = creature.rarity })
		if data and not data.discovered[id] then
			data.discovered[id] = true
			table.insert(newSpecies, creature.name)
		elseif data then
			data.catches[id] = (data.catches[id] or 0) + 1
		end
	end
	local pearls = reason == "surfaced" and math.floor(run.maxMeters / 10) * Config.DEPTH_PEARLS_PER_10M or 0
	if data then
		data.pearls += pearls
		data.bestDepth = math.max(data.bestDepth, run.maxMeters)
		data.dives += 1
		PlayerData.sync(player)
	end

	player:SetAttribute("Diving", false)
	player:SetAttribute("BagCount", 0)
	player:SetAttribute("HarpoonRange", 0)

	local summary = {
		reason = reason,
		depth = run.maxMeters,
		best = data and data.bestDepth or run.maxMeters,
		kept = keptInfo,
		lost = #run.bag - #kept,
		pearls = pearls,
		newSpecies = newSpecies,
	}
	if reason == "outOfAir" then
		-- The body is still in the trench during the blackout; don't let that count as a new dive.
		recovering[player] = os.clock() + DROWN_DELAY + 1
		Remotes.DiveEvent:FireClient(player, "Drowned", {})
		task.delay(DROWN_DELAY, function()
			local _, _, character = characterOf(player)
			if character and Dive.homeCFrame then
				local home = Dive.homeCFrame(player)
				-- Make sure the client has the dome loaded before we put the character in it.
				pcall(player.RequestStreamAroundAsync, player, home.Position)
				character:PivotTo(home)
			end
			Remotes.DiveEvent:FireClient(player, "DiveEnded", summary)
		end)
	elseif reason == "surfaced" then
		Remotes.DiveEvent:FireClient(player, "DiveEnded", summary)
	end
	if Dive.onEnded then
		Dive.onEnded(player, summary)
	end
end

Dive.stop = endDive

-- Called by the trench when a player touches things in it.
function Dive.onHazard(player, _part)
	local run = runs[player]
	local _, root, character = characterOf(player)
	if not (run and root) or os.clock() - run.lastHit < HIT_COOLDOWN then
		return
	end
	run.lastHit = os.clock()
	setOxygen(run, run.oxygen - Config.HAZARD_OXYGEN_COST)
	character:PivotTo(root.CFrame + Vector3.new(0, HIT_PUSH, 0))
	Remotes.DiveEvent:FireClient(player, "Hit", { cost = Config.HAZARD_OXYGEN_COST })
	if run.oxygen <= 0 then
		endDive(player, "outOfAir")
	end
end

function Dive.onCatch(player, creature)
	local run = runs[player]
	if not run then
		return false
	end
	table.insert(run.bag, creature.id)
	player:SetAttribute("BagCount", #run.bag)
	Remotes.DiveEvent:FireClient(player, "Caught", { name = creature.name, rarity = creature.rarity })
	return true
end

function Dive.onBubble(player)
	local run = runs[player]
	if not run or run.oxygen >= run.maxOxygen then
		return false
	end
	setOxygen(run, run.oxygen + Config.AIR_BUBBLE_OXYGEN)
	Remotes.DiveEvent:FireClient(player, "Bubble", { amount = Config.AIR_BUBBLE_OXYGEN })
	return true
end

Remotes.Sprint.OnServerEvent:Connect(function(player, on)
	sprinting[player] = on == true or nil
	player:SetAttribute("Sprinting", sprinting[player] == true)
	Dive.refreshStats(player)
end)

-- The client picks a target; the server checks it is a catch and within harpoon range.
Remotes.Harpoon.OnServerEvent:Connect(function(player, target)
	local run = runs[player]
	local _, root = characterOf(player)
	if not (run and root and typeof(target) == "Instance" and target:IsA("BasePart")) then
		return
	end
	local range = run.stats.harpoonRange
	if range <= 0 or os.clock() - run.lastHarpoon < Config.HARPOON_COOLDOWN then
		return
	end
	if (target.Position - root.Position).Magnitude > range + HARPOON_TOLERANCE then
		return
	end
	run.lastHarpoon = os.clock()
	Trench.harpoon(player, target)
end)

Players.PlayerRemoving:Connect(function(player)
	sprinting[player] = nil
	recovering[player] = nil
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < TICK then
		return
	end
	local step = elapsed
	elapsed = 0

	local diverYs = {}
	for _, player in Players:GetPlayers() do
		local _, root = characterOf(player)
		local run = runs[player]
		if not root then
			continue
		end
		local position = root.Position
		local inTrench = Vector2.new(position.X, position.Z).Magnitude < Config.TRENCH_RADIUS + 4
		local canStart = os.clock() > (recovering[player] or 0)
		if not run and canStart and inTrench and position.Y < Config.DIVE_START_Y then
			startDive(player)
			run = runs[player]
		end
		if not run then
			continue
		end
		if position.Y > Config.SURFACE_Y then
			endDive(player, "surfaced")
			continue
		end
		table.insert(diverYs, position.Y)

		-- Falling fast in a water-filled trench means the client lost the terrain (streaming) or glitched
		-- through a wall: put the diver back where they last swam. (Swimming down never gets this fast.)
		if root.AssemblyLinearVelocity.Y < -FALL_SPEED then
			run.fallingFor = (run.fallingFor or 0) + step
			if run.fallingFor > FALL_RESCUE_TIME and run.safeCFrame then
				run.fallingFor = 0
				root.AssemblyLinearVelocity = Vector3.zero
				root.Parent:PivotTo(run.safeCFrame)
				continue
			end
		else
			run.fallingFor = 0
			run.safeCFrame = root.CFrame
		end

		local meters = Config.toMeters(-position.Y)
		run.maxMeters = math.max(run.maxMeters, meters)
		player:SetAttribute("Depth", meters)
		local zone = Config.zoneAt(meters)
		local zoneIndex = table.find(Config.Zones, zone)
		if zoneIndex > run.zone then
			run.zone = zoneIndex
			if Dive.onZone then
				Dive.onZone(player, zone, meters)
			end
		end

		local moving = root.AssemblyLinearVelocity.Magnitude > MOVING_SPEED
		local drain = (sprinting[player] and moving) and Config.SPRINT_MULTIPLIER or 1
		setOxygen(run, run.oxygen - step * drain)
		if run.oxygen <= 0 then
			endDive(player, "outOfAir")
		end
	end
	Trench.update(diverYs)
end)

return Dive
