-- The trench: an endless shaft under the hub, built chunk by chunk as divers go down and shared by everyone.
-- Rock walls are terrain and stay once built. The hazards, catches and air bubbles inside a chunk are cloned
-- from ServerStorage.DeepDive.ChunkTemplates and removed again when no diver is near.
--
-- Template parts can use (see tools/build_world.luau):
--   attribute Terrain = "Rock", "Basalt"...   -> becomes terrain of that material (shelves, pillars), part removed
--   attribute Model = "Urchin"...             -> a mesh from ReplicatedStorage.DeepDive.Models is welded on
--   attribute Hazard                          -> touching it calls Trench.onHazard
--   part named CatchSpot (attribute Hard)     -> holds a shared catch that refills after Config.CATCH_RESPAWN
--   part named BubbleSpot                     -> holds an air bubble that refills after Config.BUBBLE_RESPAWN
--   MoveOffset/MoveTime/MovePhase, SpinSpeed/SpinAxis, Current, Crumble -> see Mechanics
-- The template model's Difficulty (1-3) is matched against the depth zone's difficulty.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.DeepDive.Config)
local Mechanics = require(script.Parent.Mechanics)

local Trench = {}
Trench.onHazard = nil -- function(player, part), set by Main
Trench.onCatch = nil -- function(player, creature) -> true if the player took it, set by Main
Trench.onBubble = nil -- function(player) -> true if the player took it, set by Main

local models = ReplicatedStorage.DeepDive.Models
local terrain = workspace.Terrain
local seed = Config.TRENCH_SEED or Random.new():NextInteger(1, 1e9)

local templates = ServerStorage.DeepDive.ChunkTemplates:GetChildren()
table.sort(templates, function(a, b)
	return a.Name < b.Name -- stable order so a fixed seed gives the same trench on every server
end)

local folder = Instance.new("Folder")
folder.Name = "Trench"
folder.Parent = workspace

local loaded = {} -- [chunk index] = model
local walled = {} -- [chunk index] = true once its rock shell exists
local catchTakers = {} -- [catch hitbox] = function(player) -> boolean

local function chunkTopY(index)
	return Config.TRENCH_TOP_Y - index * Config.CHUNK_HEIGHT
end

local function chunkMeters(index)
	return Config.toMeters(-(chunkTopY(index) - Config.CHUNK_HEIGHT / 2))
end

function Trench.indexAt(y)
	return math.floor((Config.TRENCH_TOP_Y - y) / Config.CHUNK_HEIGHT)
end

local function playerOf(hit)
	return Players:GetPlayerFromCharacter(hit.Parent)
end

-- Weighted by rarity, shifted toward rare catches with depth; hard spots never hold a Common.
function Trench.rollCreature(meters, hard, rng)
	local eligible, perRarity = {}, {}
	for _, creature in Config.Creatures do
		if meters >= (creature.minDepth or 0) and not (hard and creature.rarity == "Common") then
			table.insert(eligible, creature)
			perRarity[creature.rarity] = (perRarity[creature.rarity] or 0) + 1
		end
	end
	if #eligible == 0 then
		return Config.Creatures[1]
	end
	local total, weights = 0, {}
	for i, creature in eligible do
		local rarity = Config.Rarities[creature.rarity]
		weights[i] = rarity.weight * (1 + rarity.depthBonus * meters / 100) / perRarity[creature.rarity]
		total += weights[i]
	end
	local roll = rng:NextNumber() * total
	for i, creature in eligible do
		roll -= weights[i]
		if roll <= 0 then
			return creature
		end
	end
	return eligible[#eligible]
end

-- Welds a mesh from the Models folder onto `part`, scaled to its largest side; the part becomes invisible.
function Trench.attachVisual(part, modelName)
	local source = models:FindFirstChild(modelName)
	if not (source and source:IsA("BasePart")) then
		return nil
	end
	local visual = source:Clone()
	local scale = math.max(part.Size.X, part.Size.Y, part.Size.Z) / math.max(visual.Size.X, visual.Size.Y, visual.Size.Z)
	visual.Size *= scale
	visual.CFrame = part.CFrame
	visual.Anchored = false
	visual.Massless = true
	visual.CanCollide = false
	visual.CanTouch = false
	visual.CanQuery = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = visual
	weld.Parent = visual
	visual.Parent = part
	part.Transparency = 1
	return visual
end

local function label(parent, text, color)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 32)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.MaxDistance = 60
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0
	textLabel.Text = text
	textLabel.Parent = billboard
	billboard.Parent = parent
end

local function bob(part)
	TweenService:Create(part, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = part.CFrame * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(40), 0) }):Play()
end

local function spawnCatch(spot, meters, rng)
	local hard = spot:GetAttribute("Hard") == true
	local function fill()
		if not spot.Parent then
			return
		end
		local creature = Trench.rollCreature(meters, hard, rng)
		local rarity = Config.Rarities[creature.rarity]
		local hitbox = Instance.new("Part")
		hitbox.Name = "Catch"
		hitbox.Shape = Enum.PartType.Ball
		hitbox.Size = Vector3.new(3, 3, 3)
		hitbox.Anchored = true
		hitbox.CanCollide = false
		hitbox.Material = Enum.Material.Neon
		hitbox.Color = rarity.color
		hitbox.CFrame = spot.CFrame
		hitbox:SetAttribute("Creature", creature.id)
		Trench.attachVisual(hitbox, creature.model)
		local glow = Instance.new("PointLight")
		glow.Color = rarity.color
		glow.Range = 10
		glow.Brightness = 1.5
		glow.Parent = hitbox
		label(hitbox, creature.name, rarity.color)
		hitbox.Parent = spot.Parent
		bob(hitbox)

		local taken = false
		local function take(player)
			if taken or not Trench.onCatch(player, creature) then
				return false
			end
			taken = true
			hitbox:Destroy()
			task.delay(Config.CATCH_RESPAWN, fill)
			return true
		end
		catchTakers[hitbox] = take
		hitbox.Destroying:Connect(function()
			catchTakers[hitbox] = nil
		end)
		hitbox.Touched:Connect(function(hit)
			local player = playerOf(hit)
			if player then
				take(player)
			end
		end)
	end
	fill()
end

local function spawnBubble(spot)
	local hitbox = Instance.new("Part")
	hitbox.Name = "AirBubble"
	hitbox.Shape = Enum.PartType.Ball
	hitbox.Size = Vector3.new(3.5, 3.5, 3.5)
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.Material = Enum.Material.Glass
	hitbox.Color = Color3.fromRGB(170, 230, 255)
	hitbox.Transparency = 0.4
	hitbox.CFrame = spot.CFrame
	local visual = Trench.attachVisual(hitbox, "AirBubble")
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(150, 220, 255)
	glow.Range = 8
	glow.Parent = hitbox
	hitbox.Parent = spot.Parent
	bob(hitbox)

	local ready = true
	local function setReady(value)
		ready = value
		glow.Enabled = value
		if visual then
			visual.Transparency = value and 0 or 1
		else
			hitbox.Transparency = value and 0.4 or 1
		end
	end
	hitbox.Touched:Connect(function(hit)
		local player = playerOf(hit)
		if ready and player and Trench.onBubble(player) then
			setReady(false)
			task.delay(Config.BUBBLE_RESPAWN, function()
				if hitbox.Parent then
					setReady(true)
				end
			end)
		end
	end)
end

local function buildWalls(index)
	if walled[index] then
		return
	end
	walled[index] = true
	local center = CFrame.new(0, chunkTopY(index) - Config.CHUNK_HEIGHT / 2, 0)
	terrain:FillCylinder(center, Config.CHUNK_HEIGHT, Config.TRENCH_WALL_RADIUS, Enum.Material.Rock)
	-- Water only fills empty space, so carve the shaft to air first.
	terrain:FillCylinder(center, Config.CHUNK_HEIGHT, Config.TRENCH_RADIUS, Enum.Material.Air)
	terrain:FillCylinder(center, Config.CHUNK_HEIGHT, Config.TRENCH_RADIUS, Enum.Material.Water)
end

local function pickTemplate(index, rng)
	local difficulty = Config.zoneAt(chunkMeters(index)).difficulty
	local pool = {}
	for _, template in templates do
		local level = template:GetAttribute("Difficulty") or 1
		if level <= difficulty then
			-- Templates matching the zone come up three times as often as easier ones.
			for _ = 1, level == difficulty and 3 or 1 do
				table.insert(pool, template)
			end
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function toTerrain(part)
	local material = Enum.Material[part:GetAttribute("Terrain")]
	if part.Shape == Enum.PartType.Ball then
		terrain:FillBall(part.Position, part.Size.X / 2, material)
	elseif part.Shape == Enum.PartType.Cylinder then
		-- A cylinder part's axis is its X axis; FillCylinder's is Y.
		terrain:FillCylinder(part.CFrame * CFrame.Angles(0, 0, math.rad(90)), part.Size.X, part.Size.Y / 2, material)
	else
		terrain:FillBlock(part.CFrame, part.Size, material)
	end
	part:Destroy()
end

local function loadChunk(index)
	if loaded[index] then
		return
	end
	buildWalls(index)
	local rng = Random.new(seed + index * 7919)
	local template = pickTemplate(index, rng)
	local chunk = template:Clone()
	chunk.Name = ("Chunk%d_%s"):format(index, template.Name)
	chunk:PivotTo(CFrame.new(0, chunkTopY(index), 0) * CFrame.Angles(0, math.rad(90 * rng:NextInteger(0, 3)), 0))
	for _, part in chunk:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Terrain") then
			toTerrain(part)
		end
	end
	chunk.Parent = folder
	loaded[index] = chunk

	local meters = chunkMeters(index)
	for _, part in chunk:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local modelName = part:GetAttribute("Model")
		if modelName then
			Trench.attachVisual(part, modelName)
		end
		if part.Name == "CatchSpot" then
			spawnCatch(part, meters, rng)
		elseif part.Name == "BubbleSpot" then
			spawnBubble(part)
		elseif part:GetAttribute("Hazard") then
			part.Touched:Connect(function(hit)
				local player = playerOf(hit)
				if player then
					Trench.onHazard(player, part)
				end
			end)
		end
	end
	Mechanics.start(chunk)
end

-- Keeps chunks loaded around every diver (given as world Y positions) and unloads the rest.
function Trench.update(diverYs)
	local wanted = { [0] = true } -- the entrance always looks alive
	for _, y in diverYs do
		local index = math.max(0, Trench.indexAt(y))
		for i = math.max(0, index - 1), index + Config.CHUNKS_AHEAD do
			wanted[i] = true
		end
	end
	for index in wanted do
		loadChunk(index)
	end
	for index, chunk in loaded do
		if not wanted[index] then
			chunk:Destroy()
			loaded[index] = nil
		end
	end
end

-- Harpoon hit on a catch hitbox; returns true if the player took it.
function Trench.harpoon(player, hitbox)
	local take = catchTakers[hitbox]
	return take ~= nil and take(player)
end

return Trench
