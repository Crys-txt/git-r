-- Builds the Deep Dive world in Edit mode (run through Studio's command bar or the MCP). Safe to re-run:
-- it clears the terrain and rebuilds the hub, the domes, the decorations and the trench chunk templates.
-- Meshes are taken from ReplicatedStorage.DeepDive.Models when present (see tools/import_models.luau).
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local terrain = workspace.Terrain
local SAND = Color3.fromRGB(230, 210, 160)
local GLASS = Color3.fromRGB(170, 220, 255)
local METAL = Color3.fromRGB(120, 130, 145)
local HUB_RADIUS = 120 -- domes sit on a circle this far from the trench
local TRENCH_RADIUS = 22 -- must match Config.TRENCH_RADIUS
local TRENCH_TOP_Y = -16 -- must match Config.TRENCH_TOP_Y
local SEA_SIZE = 640
local SEA_DEPTH = 140 -- water from the seafloor (y = 0) up to here

local function part(parent, name, size, at, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(at) == "Vector3" and CFrame.new(at) or at
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props or {} do
		if key == "Attributes" then
			for attribute, attributeValue in value do
				p:SetAttribute(attribute, attributeValue)
			end
		else
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function folder(parent, name)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function billboard(parent, text, offset, size)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromOffset(240, 60)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = 250
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
end

local models = folder(folder(ReplicatedStorage, "DeepDive"), "Models")
local function mesh(name, parent, cframe, largestSide)
	local source = models:FindFirstChild(name)
	if not (source and source:IsA("BasePart")) then
		return nil
	end
	local copy = source:Clone()
	copy.Size *= largestSide / math.max(copy.Size.X, copy.Size.Y, copy.Size.Z)
	copy.CFrame = cframe
	copy.Anchored = true
	copy.Parent = parent
	return copy
end

-- 0. Move the old obby out of the way (kept in ServerStorage so it can be restored).
if not ServerStorage:FindFirstChild("OldObbyBackup") then
	local backup = folder(ServerStorage, "OldObbyBackup")
	for _, name in { "Checkpoints", "TrapParts", "StartSpawn", "Conveyors", "ObbyStructure", "BouncePad" } do
		local item = workspace:FindFirstChild(name)
		if item then
			item.Parent = backup
		end
	end
	for _, name in { "CheckpointManager", "ConveyorManager", "TrapManager" } do
		local item = ServerScriptService:FindFirstChild(name)
		if item then
			item.Parent = backup
		end
	end
	local bouncePad = StarterPlayer.StarterPlayerScripts:FindFirstChild("BouncePadManager")
	if bouncePad then
		bouncePad.Parent = backup
	end
end

-- 1. Containers and remotes.
local shared = folder(ReplicatedStorage, "DeepDive")
local remotes = folder(shared, "Remotes")
local REMOTES = { DiveEvent = "RemoteEvent", Harpoon = "RemoteEvent", Sprint = "RemoteEvent", ShopRequest = "RemoteFunction" }
for name, className in REMOTES do
	if not remotes:FindFirstChild(name) then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
end
folder(ServerScriptService, "DeepDive")
local serverAssets = folder(ServerStorage, "DeepDive")
for _, old in { "FloorTemplates", "ChunkTemplates" } do
	if serverAssets:FindFirstChild(old) then
		serverAssets[old]:Destroy()
	end
end
local templates = folder(serverAssets, "ChunkTemplates")
workspace.FallenPartsDestroyHeight = -50000 -- the trench is (practically) endless

-- 2. The ocean: a sandy seafloor at y = 0 under deep water, with the trench opening in the middle.
terrain:Clear()
terrain.WaterColor = Color3.fromRGB(20, 110, 160)
terrain.WaterTransparency = 0.3 -- murky enough that the domes feel deep underwater
terrain.WaterWaveSize = 0.1
terrain.WaterReflectance = 0.2
terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(176, 160, 118))
terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(82, 88, 98))
terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(45, 45, 55))
terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(SEA_SIZE, 16, SEA_SIZE), Enum.Material.Sand)
terrain:FillBlock(CFrame.new(0, SEA_DEPTH / 2, 0), Vector3.new(SEA_SIZE, SEA_DEPTH, SEA_SIZE), Enum.Material.Water)
-- Trench mouth: a rocky rim and an opening down to where the runtime chunks begin.
terrain:FillCylinder(CFrame.new(0, 1, 0), 6, TRENCH_RADIUS + 10, Enum.Material.Rock)
terrain:FillCylinder(CFrame.new(0, TRENCH_TOP_Y / 2, 0), -TRENCH_TOP_Y + 12, TRENCH_RADIUS + 12, Enum.Material.Rock)
-- Water only fills empty space, so carve the opening to air first.
terrain:FillCylinder(CFrame.new(0, TRENCH_TOP_Y / 2 + 2, 0), -TRENCH_TOP_Y + 12, TRENCH_RADIUS, Enum.Material.Air)
terrain:FillCylinder(CFrame.new(0, TRENCH_TOP_Y / 2 + 2, 0), -TRENCH_TOP_Y + 12, TRENCH_RADIUS, Enum.Material.Water)

Lighting.Ambient = Color3.fromRGB(70, 90, 110)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 150, 180)
Lighting.Brightness = 2.5

-- 3. The hub: glass domes full of air on the seafloor, around the trench.
if workspace:FindFirstChild("Harbor") then
	workspace.Harbor:Destroy()
end
local harbor = Instance.new("Model")
harbor.Name = "Harbor"

local function slot(index)
	local angle = math.rad(index * 45)
	local center = Vector3.new(math.sin(angle) * HUB_RADIUS, 0, -math.cos(angle) * HUB_RADIUS)
	-- Each dome faces the trench: local -Z points at the centre of the hub.
	return CFrame.lookAt(center, Vector3.new(0, 0, 0))
end

local function dome(name, frame, radius)
	local model = Instance.new("Model")
	model.Name = name
	-- Air inside: carve the water out, then put the sand back under the floor.
	terrain:FillBall(frame.Position, radius - 0.5, Enum.Material.Air)
	-- Stop 2 studs under the floor so the sand never pokes through it.
	terrain:FillBlock(frame * CFrame.new(0, -9, 0), Vector3.new(radius * 2 + 4, 14, radius * 2 + 4), Enum.Material.Sand)
	part(model, "Glass", Vector3.new(radius * 2, radius * 2, radius * 2), frame, GLASS, Enum.Material.Glass, {
		Shape = Enum.PartType.Ball,
		Transparency = 0.82,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	part(model, "Floor", Vector3.new(1, radius * 2 - 1, radius * 2 - 1), frame * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), METAL, Enum.Material.DiamondPlate, { Shape = Enum.PartType.Cylinder })
	part(model, "Rug", Vector3.new(0.2, radius, radius), frame * CFrame.new(0, 1.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 90, 130), Enum.Material.Fabric, { Shape = Enum.PartType.Cylinder, CanCollide = false })
	local lampPart = part(model, "Lamp", Vector3.new(2, 1, 2), frame * CFrame.new(0, radius - 2, 0), Color3.fromRGB(255, 240, 200), Enum.Material.Neon, { CanCollide = false, Shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Range = radius * 1.8
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 240, 210)
	light.Parent = lampPart
	model.Parent = harbor
	return model
end

-- Spawn dome with the live dive feed.
do
	local frame = slot(0)
	local spawnDome = dome("SpawnDome", frame, 24)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HarborSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = frame * CFrame.new(0, 1.5, 4)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(80, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.Parent = spawnDome
	local board = part(spawnDome, "DiveFeed", Vector3.new(20, 9, 1), frame * CFrame.new(0, 8, 14), Color3.fromRGB(20, 35, 50), Enum.Material.SmoothPlastic)
	local feedGui = Instance.new("SurfaceGui")
	feedGui.Face = Enum.NormalId.Front
	feedGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	feedGui.PixelsPerStud = 40
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.2, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(120, 220, 255)
	title.Text = "LIVE DIVE FEED"
	title.Parent = feedGui
	local feedLabel = Instance.new("TextLabel")
	feedLabel.Name = "FeedLabel"
	feedLabel.Position = UDim2.fromScale(0.04, 0.22)
	feedLabel.Size = UDim2.fromScale(0.92, 0.75)
	feedLabel.BackgroundTransparency = 1
	feedLabel.Font = Enum.Font.GothamMedium
	feedLabel.TextSize = 28
	feedLabel.TextWrapped = true
	feedLabel.TextXAlignment = Enum.TextXAlignment.Left
	feedLabel.TextYAlignment = Enum.TextYAlignment.Top
	feedLabel.TextColor3 = Color3.new(1, 1, 1)
	feedLabel.Text = ""
	feedLabel.Parent = feedGui
	feedGui.Parent = board
	billboard(part(spawnDome, "SignAnchor", Vector3.new(1, 1, 1), frame * CFrame.new(0, 27, 0), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }), "HUB\nWalk out and swim to the trench to dive", 0)
end

-- Shop dome: a counter with the shopkeeper NPC (created at runtime by Harbor.luau) behind it.
do
	local frame = slot(1)
	local shopDome = dome("ShopDome", frame, 22)
	local counterFrame = frame * CFrame.new(0, 2.5, 3)
	local counter = part(shopDome, "Counter", Vector3.new(12, 3, 3), counterFrame, Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks)
	local counterMesh = mesh("ShopCounter", shopDome, counterFrame * CFrame.new(0, 0.2, 0), 9)
	if counterMesh then
		counterMesh.CanCollide = false
		counter.Transparency = 1 -- keep the box as the solid, invisible collider
	end
	part(shopDome, "ShopkeeperSpot", Vector3.new(2, 0.2, 2), frame * CFrame.new(0, 1.1, 7), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	billboard(part(shopDome, "SignAnchor", Vector3.new(1, 1, 1), frame * CFrame.new(0, 25, 0), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }), "DIVE SHOP\nSell catches · Buy gear", 0)
end

-- Six player domes, each with three display tanks (ids must match Config.Wings).
local WINGS = { { "ReefTank", "Reef Tank" }, { "ShipwreckHall", "Shipwreck Hall" }, { "JellyfishDome", "Jellyfish Dome" } }
local domes = Instance.new("Folder")
domes.Name = "Domes"
domes.Parent = harbor
for i = 1, 6 do
	local frame = slot(i + 1)
	local playerDome = dome(("Dome%d"):format(i), frame, 24)
	playerDome.Parent = domes
	part(playerDome, "HomeSpot", Vector3.new(2, 0.2, 2), frame * CFrame.new(0, 1.1, 0), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local sign = part(playerDome, "Sign", Vector3.new(1, 1, 1), frame * CFrame.new(0, 28, 0), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	billboard(sign, "Free dome", 0, UDim2.fromOffset(260, 80))
	local tanks = folder(playerDome, "Tanks")
	for w, wing in WINGS do
		local x = (w - 2) * 12
		local tank = part(tanks, wing[1], Vector3.new(10, 7, 6), frame * CFrame.new(x, 4.5, 10 + math.abs(x) * -0.2) * CFrame.Angles(0, math.rad(-x * 1.5), 0), Color3.fromRGB(120, 130, 140), Enum.Material.Glass, { Transparency = 0.85 })
		part(playerDome, wing[1] .. "Base", Vector3.new(10.4, 1, 6.4), tank.CFrame * CFrame.new(0, -4, 0), METAL, Enum.Material.Metal, { CanQuery = false })
		billboard(tank, wing[2], 5.5, UDim2.fromOffset(200, 40))
	end
	folder(playerDome, "Fish")
end

-- The trench mouth: a ring of lights and a sign.
do
	local rim = Instance.new("Model")
	rim.Name = "TrenchRim"
	for i = 0, 11 do
		local angle = math.rad(i * 30)
		local position = Vector3.new(math.cos(angle) * (TRENCH_RADIUS + 15), 1.5, math.sin(angle) * (TRENCH_RADIUS + 15))
		local post = part(rim, "Light", Vector3.new(1, 3, 1), position, Color3.fromRGB(120, 255, 220), Enum.Material.Neon, { CanCollide = false })
		local light = Instance.new("PointLight")
		light.Range = 14
		light.Color = post.Color
		light.Parent = post
	end
	billboard(part(rim, "SignAnchor", Vector3.new(1, 1, 1), Vector3.new(0, 16, 0), Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false }), "THE TRENCH\nSwim down to dive · Swim up to bank your catches", 0, UDim2.fromOffset(420, 80))
	rim.Parent = harbor
end

-- Decorations: coral, kelp and rocks scattered over the seafloor, away from the domes and the trench.
do
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = harbor
	local rng = Random.new(42)
	local placed = 0
	while placed < 70 do
		local angle, distance = rng:NextNumber(0, math.pi * 2), rng:NextNumber(TRENCH_RADIUS + 16, 280)
		local position = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local clear = true
		for s = 0, 7 do
			if (position - slot(s).Position).Magnitude < 30 then
				clear = false
			end
		end
		if clear then
			placed += 1
			local kind = rng:NextInteger(1, 3)
			local facing = CFrame.new(position) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			if kind == 1 then
				local size = rng:NextNumber(4, 8)
				if not mesh("Coral", decor, facing * CFrame.new(0, size * 0.35, 0), size) then
					part(decor, "Coral", Vector3.new(size, size * 0.6, size), facing * CFrame.new(0, size * 0.3, 0), Color3.fromHSV(rng:NextNumber(0.85, 1.05) % 1, 0.6, 1), Enum.Material.Pebble, { Shape = Enum.PartType.Ball })
				end
			elseif kind == 2 then
				local height = rng:NextNumber(10, 22)
				if not mesh("Kelp", decor, facing * CFrame.new(0, height / 2, 0), height) then
					part(decor, "Kelp", Vector3.new(1.2, height, 1.2), facing * CFrame.new(0, height / 2, 0), Color3.fromRGB(60, 150, 70), Enum.Material.Grass, { CanCollide = false })
				end
			else
				terrain:FillBall(position + Vector3.new(0, -1, 0), rng:NextNumber(3, 8), Enum.Material.Rock)
			end
		end
	end
end
harbor.Parent = workspace

-- 4. Trench chunk templates. Local origin = top centre of an 80-stud slice of the shaft (y goes down to -80);
-- open water within 22 studs of the axis. See Trench.luau for the attributes.
local CHUNK_HEIGHT = 80
local INNER = 18 -- keep things within this radius so they never sit inside the walls

local function newChunk(name, difficulty)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Difficulty", difficulty)
	m.PrimaryPart = part(m, "Origin", Vector3.new(1, 1, 1), Vector3.zero, Color3.new(), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	m.Parent = templates
	return m
end

local function marker(m, name, pos, attributes)
	return part(m, name, Vector3.new(1, 1, 1), pos, Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, Attributes = attributes })
end

local function catchSpot(m, pos, hard)
	marker(m, "CatchSpot", pos, { Hard = hard })
end

local function bubbleSpot(m, pos)
	marker(m, "BubbleSpot", pos)
end

local function rockBlock(m, size, at, material)
	return part(m, "TerrainRock", size, at, Color3.fromRGB(90, 90, 100), Enum.Material.Rock, { Transparency = 0.5, Attributes = { Terrain = material or "Rock" } })
end

local function rockBall(m, pos, radius, material)
	return part(m, "TerrainRock", Vector3.new(radius * 2, radius * 2, radius * 2), pos, Color3.fromRGB(90, 90, 100), Enum.Material.Rock, { Shape = Enum.PartType.Ball, Transparency = 0.5, Attributes = { Terrain = material or "Rock" } })
end

-- A rock shelf across the whole shaft at height y with one square hole (centre hx, hz; side hs).
local function shelf(m, y, hx, hz, hs, material)
	local W = 76
	local xa, xb, za, zb = hx - hs / 2, hx + hs / 2, hz - hs / 2, hz + hs / 2
	rockBlock(m, Vector3.new(xa + W / 2, 4, W), Vector3.new((xa - W / 2) / 2, y, 0), material)
	rockBlock(m, Vector3.new(W / 2 - xb, 4, W), Vector3.new((xb + W / 2) / 2, y, 0), material)
	rockBlock(m, Vector3.new(hs, 4, za + W / 2), Vector3.new(hx, y, (za - W / 2) / 2), material)
	rockBlock(m, Vector3.new(hs, 4, W / 2 - zb), Vector3.new(hx, y, (zb + W / 2) / 2), material)
end

local function hazard(m, name, size, at, modelName, attributes, ball)
	attributes = attributes or {}
	attributes.Hazard = true
	attributes.Model = modelName
	return part(m, name, size, at, Color3.fromRGB(150, 20, 60), Enum.Material.Slate, {
		Shape = ball and Enum.PartType.Ball or Enum.PartType.Block,
		CanCollide = attributes.MoveOffset == nil and attributes.SpinSpeed == nil,
		Attributes = attributes,
	})
end

local function urchin(m, pos, attributes)
	return hazard(m, "Urchin", Vector3.new(4, 4, 4), pos, "Urchin", attributes, true)
end

local function jelly(m, pos, attributes)
	return hazard(m, "Jelly", Vector3.new(5, 5, 5), pos, "Jellyfish", attributes, true)
end

local function eel(m, pos, attributes)
	return hazard(m, "Eel", Vector3.new(5, 5, 5), pos, "Eel", attributes, true)
end

-- A kelp stalk made of stacked 12-stud pieces, so the kelp mesh keeps its proportions.
local function kelp(m, pos, height)
	local pieces = math.max(1, math.floor(height / 12))
	for i = 0, pieces - 1 do
		local y = pos.Y + height / 2 - 6 - i * 12
		part(m, "Kelp", Vector3.new(2, 12, 2), CFrame.new(pos.X, y, pos.Z) * CFrame.Angles(0, math.rad(i * 70), 0), Color3.fromRGB(60, 150, 70), Enum.Material.Grass, { Attributes = { Model = "Kelp" } })
	end
end

local function coral(m, pos, size)
	part(m, "Coral", Vector3.new(size, size * 0.7, size), pos, Color3.fromRGB(255, 120, 150), Enum.Material.Pebble, { CanCollide = false, CanQuery = false, CanTouch = false, Attributes = { Model = "Coral" } })
end

local function current(m, size, at, velocity)
	part(m, "Current", size, at, Color3.fromRGB(170, 230, 255), Enum.Material.Glass, {
		Transparency = 0.92,
		CanCollide = false,
		CanQuery = true, -- the client finds current zones with a spatial query
		CanTouch = false,
		CastShadow = false,
		Attributes = { Current = velocity },
	})
end

local function randomInDisc(rng, radius)
	local angle, distance = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * radius
	return math.cos(angle) * distance, math.sin(angle) * distance
end

do -- Open Reef (1): a gentle start with coral on the walls
	local m = newChunk("OpenReef", 1)
	rockBall(m, Vector3.new(19, -25, 0), 7)
	rockBall(m, Vector3.new(-17, -55, 9), 8)
	coral(m, Vector3.new(14, -20, 0), 5)
	coral(m, Vector3.new(-12, -50, 7), 6)
	urchin(m, Vector3.new(6, -35, -10))
	urchin(m, Vector3.new(-10, -62, -4))
	urchin(m, Vector3.new(12, -70, 8))
	catchSpot(m, Vector3.new(-6, -30, 6), false)
	catchSpot(m, Vector3.new(8, -58, -6), false)
	catchSpot(m, Vector3.new(-16, -63, 13), true)
	bubbleSpot(m, Vector3.new(0, -45, 12))
end

do -- Ledge Steps (1): three shelves, each with one hole in a different place
	local m = newChunk("LedgeSteps", 1)
	shelf(m, -15, 10, 0, 12)
	shelf(m, -40, -10, 6, 12)
	shelf(m, -65, 4, -10, 12)
	coral(m, Vector3.new(-10, -11, -8), 5)
	urchin(m, Vector3.new(-12, -36, -12))
	catchSpot(m, Vector3.new(-12, -10, 10), false)
	catchSpot(m, Vector3.new(14, -35, 10), false)
	catchSpot(m, Vector3.new(-15, -60, -14), true)
	bubbleSpot(m, Vector3.new(4, -52, -10))
end

do -- Kelp Forest (1): weave through tall kelp
	local m = newChunk("KelpForest", 1)
	local rng = Random.new(3)
	for _ = 1, 16 do
		local x, z = randomInDisc(rng, INNER)
		kelp(m, Vector3.new(x, -40, z), 74)
	end
	catchSpot(m, Vector3.new(5, -25, -5), false)
	catchSpot(m, Vector3.new(-8, -55, 4), false)
	catchSpot(m, Vector3.new(0, -70, 0), true)
	bubbleSpot(m, Vector3.new(-6, -40, -10))
end

do -- Urchin Field (2): urchins everywhere, three of them patrolling
	local m = newChunk("UrchinField", 2)
	local rng = Random.new(5)
	for _ = 1, 16 do
		local x, z = randomInDisc(rng, INNER)
		urchin(m, Vector3.new(x, rng:NextNumber(-74, -6), z))
	end
	urchin(m, Vector3.new(-18, -25, 0), { MoveOffset = Vector3.new(36, 0, 0), MoveTime = 2.5 })
	urchin(m, Vector3.new(0, -45, -18), { MoveOffset = Vector3.new(0, 0, 36), MoveTime = 3 })
	urchin(m, Vector3.new(18, -65, 0), { MoveOffset = Vector3.new(-36, 0, 0), MoveTime = 2 })
	catchSpot(m, Vector3.new(10, -18, 10), false)
	catchSpot(m, Vector3.new(-10, -48, -10), false)
	catchSpot(m, Vector3.new(0, -66, 0), true)
	bubbleSpot(m, Vector3.new(-12, -32, 12))
end

do -- Jelly Column (2): jellyfish bobbing up and down out of sync
	local m = newChunk("JellyColumn", 2)
	local index = 0
	for ring = 1, 2 do
		for i = 1, 6 do
			index += 1
			local angle = math.rad(i * 60 + ring * 30)
			local radius = ring * 8
			jelly(m, Vector3.new(math.cos(angle) * radius, -70, math.sin(angle) * radius), {
				MoveOffset = Vector3.new(0, 55, 0),
				MoveTime = 2.4 + (index % 3) * 0.4,
				MovePhase = (index * 0.17) % 1,
			})
		end
	end
	catchSpot(m, Vector3.new(0, -40, 0), false)
	catchSpot(m, Vector3.new(14, -25, -6), false)
	catchSpot(m, Vector3.new(-12, -62, 10), true)
	bubbleSpot(m, Vector3.new(4, -52, 16))
end

do -- Current Shaft (2): an updraft on one side, a downdraft lined with urchins on the other
	local m = newChunk("CurrentShaft", 2)
	current(m, Vector3.new(22, 76, 44), CFrame.new(-11, -40, 0), Vector3.new(0, 14, 0))
	current(m, Vector3.new(22, 76, 44), CFrame.new(11, -40, 0), Vector3.new(0, -12, 0))
	for y = -15, -70, -14 do
		urchin(m, Vector3.new(16, y, (y % 28 == 0) and 6 or -6))
	end
	catchSpot(m, Vector3.new(-12, -30, 0), false)
	catchSpot(m, Vector3.new(8, -50, 0), false)
	catchSpot(m, Vector3.new(-14, -68, -8), true)
	bubbleSpot(m, Vector3.new(-8, -55, 10))
end

do -- Windmills (3): spinning blades sweep the whole shaft; slip through between them
	local m = newChunk("Windmills", 3)
	for i, y in { -22, -56 } do
		for _, angle in { 0, 90 } do
			hazard(m, "Blade", Vector3.new(46, 2, 3), CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(angle), 0), nil, { SpinSpeed = i == 1 and 55 or -70, SpinAxis = "Y" })
		end
	end
	catchSpot(m, Vector3.new(10, -38, 10), false)
	catchSpot(m, Vector3.new(-12, -70, -6), false)
	catchSpot(m, Vector3.new(0, -12, 0), true)
	bubbleSpot(m, Vector3.new(-10, -40, -10))
end

do -- Eel Den (3): eels patrol across the shaft between two shelves
	local m = newChunk("EelDen", 3)
	shelf(m, -10, -8, -8, 12)
	shelf(m, -70, 8, 8, 12)
	eel(m, Vector3.new(-18, -25, 6), { MoveOffset = Vector3.new(36, 0, 0), MoveTime = 2 })
	eel(m, Vector3.new(18, -40, -6), { MoveOffset = Vector3.new(-36, 0, 0), MoveTime = 2.4 })
	eel(m, Vector3.new(-18, -55, 0), { MoveOffset = Vector3.new(36, 0, 0), MoveTime = 1.8, MovePhase = 0.5 })
	catchSpot(m, Vector3.new(14, -18, 14), false)
	catchSpot(m, Vector3.new(-14, -48, -12), false)
	catchSpot(m, Vector3.new(0, -64, 0), true)
	bubbleSpot(m, Vector3.new(10, -32, -12))
	bubbleSpot(m, Vector3.new(-10, -62, 12))
end

do -- The Choke (3): a narrow hole ringed with urchins, rare catches beside it
	local m = newChunk("TheChoke", 3)
	shelf(m, -40, 0, 0, 9, "Basalt")
	for i = 0, 5 do
		local angle = math.rad(i * 60)
		urchin(m, Vector3.new(math.cos(angle) * 8, -35, math.sin(angle) * 8))
	end
	urchin(m, Vector3.new(0, -20, 0), { MoveOffset = Vector3.new(0, -12, 0), MoveTime = 1.6 })
	catchSpot(m, Vector3.new(14, -30, 10), true)
	catchSpot(m, Vector3.new(-12, -55, -12), false)
	catchSpot(m, Vector3.new(10, -70, -10), true)
	bubbleSpot(m, Vector3.new(-14, -25, 8))
	bubbleSpot(m, Vector3.new(12, -50, 12))
end

return ("Built the hub (%d domes) and %d trench chunk templates"):format(#domes:GetChildren(), #templates:GetChildren())
