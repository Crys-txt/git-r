-- Builds the Deep Dive grey-box world in Edit mode (run once through Studio's command bar or the MCP).
-- Safe to re-run: it rebuilds the Harbor and the floor templates it owns.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

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

local function textGui(parent, text, size, face)
	local gui
	if face then
		gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
	else
		gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(220, 50)
		gui.StudsOffset = Vector3.new(0, size, 0)
		gui.MaxDistance = 120
	end
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = text
	label.Parent = gui
	gui.Parent = parent
	return label
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
local REMOTES = { DiveEvent = "RemoteEvent", DiveChoice = "RemoteEvent", Harpoon = "RemoteEvent", ShopRequest = "RemoteFunction" }
for name, className in REMOTES do
	if not remotes:FindFirstChild(name) then
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = remotes
	end
end
folder(ServerScriptService, "DeepDive")
local serverAssets = folder(ServerStorage, "DeepDive")
if serverAssets:FindFirstChild("FloorTemplates") then
	serverAssets.FloorTemplates:Destroy()
end
local templates = folder(serverAssets, "FloorTemplates")

-- 2. Harbor lobby: pier, spawn, diving bell, live feed board and six aquarium plots.
if workspace:FindFirstChild("Harbor") then
	workspace.Harbor:Destroy()
end
local harbor = Instance.new("Model")
harbor.Name = "Harbor"
local SAND = Color3.fromRGB(230, 210, 160)

-- Real swimmable sea around the pier (terrain water over a sand floor).
local terrain = workspace.Terrain
terrain.WaterColor = Color3.fromRGB(20, 120, 170)
terrain.WaterTransparency = 0.6
terrain.WaterWaveSize = 0.1
terrain:FillBlock(CFrame.new(0, -12.5, 0), Vector3.new(600, 24, 600), Enum.Material.Water)
terrain:FillBlock(CFrame.new(0, -26.5, 0), Vector3.new(600, 4, 600), Enum.Material.Sand)
part(harbor, "Pier", Vector3.new(40, 1, 170), Vector3.new(0, 0, 0), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "HarborSpawn"
spawn.Size = Vector3.new(10, 1, 10)
spawn.CFrame = CFrame.new(0, 1, -70) * CFrame.Angles(0, math.pi, 0)
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.Color = Color3.fromRGB(80, 200, 255)
spawn.Parent = harbor

local bell = Instance.new("Model")
bell.Name = "DivingBell"
part(bell, "Base", Vector3.new(14, 1, 14), Vector3.new(0, 1, 72), Color3.fromRGB(90, 90, 100), Enum.Material.DiamondPlate)
local dome = part(bell, "Dome", Vector3.new(10, 10, 10), Vector3.new(0, 6.5, 72), Color3.fromRGB(205, 160, 60), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
part(bell, "Window", Vector3.new(4, 4, 1), Vector3.new(0, 7, 66.6), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
textGui(dome, "DIVE", 8)
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Start dive"
prompt.ObjectText = "Diving Bell"
prompt.HoldDuration = 0
prompt.MaxActivationDistance = 14
prompt.RequiresLineOfSight = false
prompt.Parent = dome
bell.Parent = harbor

local board = part(harbor, "DiveFeed", Vector3.new(22, 9, 1), Vector3.new(0, 11, -40), Color3.fromRGB(20, 35, 50), Enum.Material.SmoothPlastic, { CanCollide = false })
local feedGui = Instance.new("SurfaceGui")
feedGui.Face = Enum.NormalId.Front
feedGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
feedGui.PixelsPerStud = 40
local feedTitle = Instance.new("TextLabel")
feedTitle.Name = "Title"
feedTitle.Size = UDim2.new(1, 0, 0.2, 0)
feedTitle.BackgroundTransparency = 1
feedTitle.Font = Enum.Font.GothamBlack
feedTitle.TextScaled = true
feedTitle.TextColor3 = Color3.fromRGB(120, 220, 255)
feedTitle.Text = "LIVE DIVE FEED"
feedTitle.Parent = feedGui
local feedLabel = Instance.new("TextLabel")
feedLabel.Name = "FeedLabel"
feedLabel.Position = UDim2.fromScale(0.04, 0.22)
feedLabel.Size = UDim2.fromScale(0.92, 0.75)
feedLabel.BackgroundTransparency = 1
feedLabel.Font = Enum.Font.GothamMedium
feedLabel.TextSize = 30
feedLabel.TextWrapped = true
feedLabel.TextXAlignment = Enum.TextXAlignment.Left
feedLabel.TextYAlignment = Enum.TextYAlignment.Top
feedLabel.TextColor3 = Color3.new(1, 1, 1)
feedLabel.Text = ""
feedLabel.Parent = feedGui
feedGui.Parent = board
for _, x in { -10, 10 } do
	part(harbor, "Pole", Vector3.new(1, 11, 1), Vector3.new(x, 5.5, -39), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
end

-- Dive Shop stall next to the spawn: sell catches, buy equipment.
local shop = Instance.new("Model")
shop.Name = "DiveShop"
local counter = part(shop, "Counter", Vector3.new(9, 3, 3), Vector3.new(13, 2, -57), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks)
for _, offset in { Vector3.new(-4.5, 0, -6), Vector3.new(4.5, 0, -6), Vector3.new(-4.5, 0, 1), Vector3.new(4.5, 0, 1) } do
	part(shop, "Post", Vector3.new(0.8, 8, 0.8), Vector3.new(13, 4.5, -57) + offset, Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
end
part(shop, "Roof", Vector3.new(11, 0.6, 9), Vector3.new(13, 8.8, -59.5), Color3.fromRGB(230, 90, 70), Enum.Material.Fabric)
textGui(counter, "DIVE SHOP", 7)
local shopPrompt = Instance.new("ProximityPrompt")
shopPrompt.ActionText = "Open shop"
shopPrompt.ObjectText = "Dive Shop"
shopPrompt.HoldDuration = 0
shopPrompt.MaxActivationDistance = 10
shopPrompt.RequiresLineOfSight = false
shopPrompt.Parent = counter
shop.Parent = harbor

-- Wing ids must match Config.Wings.
local WING_IDS = { "ReefTank", "ShipwreckHall", "JellyfishDome" }
local WING_NAMES = { "Reef Tank", "Shipwreck Hall", "Jellyfish Dome" }
local plots = Instance.new("Folder")
plots.Name = "Plots"
plots.Parent = harbor
for i, spot in { { -33, -40 }, { 33, -40 }, { -33, 5 }, { 33, 5 }, { -33, 50 }, { 33, 50 } } do
	local x, z = spot[1], spot[2]
	local side = x > 0 and 1 or -1
	local plot = Instance.new("Model")
	plot.Name = ("Plot%d"):format(i)
	part(plot, "Base", Vector3.new(26, 1, 36), Vector3.new(x, 0, z), SAND, Enum.Material.Sand)
	local signPosition = Vector3.new(x - side * 12, 4, z)
	local sign = part(plot, "Sign", Vector3.new(14, 3, 0.5), CFrame.lookAt(signPosition, signPosition - Vector3.new(side, 0, 0)), Color3.fromRGB(40, 60, 80), Enum.Material.SmoothPlastic, { CanCollide = false })
	textGui(sign, "Free plot", 0, Enum.NormalId.Front)
	local tanks = Instance.new("Folder")
	tanks.Name = "Tanks"
	tanks.Parent = plot
	for w, wingId in WING_IDS do
		local tank = part(tanks, wingId, Vector3.new(14, 7, 9), Vector3.new(x + side * 3, 4, z + (w - 2) * 12), Color3.fromRGB(120, 130, 140), Enum.Material.Glass, { Transparency = 0.85 })
		textGui(tank, WING_NAMES[w], 5)
	end
	local fish = Instance.new("Folder")
	fish.Name = "Fish"
	fish.Parent = plot
	plot.Parent = plots
end
harbor.Parent = workspace

-- 3. Sunlit Reef floor templates: enclosed underwater caves you swim through.
-- Each cave has a Start pad (the model's pivot), an Exit gate, a "Water" volume the server fills with
-- terrain water when the floor is built, and CatchSpot parts (attribute Hard = rare-only).
-- Mechanics come from attributes: Hazard, MoveOffset/MoveTime/MovePhase, SpinSpeed/SpinAxis, Current, Crumble.
-- Difficulty (1-3) on the cave model orders floors in a dive: random within a difficulty, easy ones first.
local ROCK = Color3.fromRGB(75, 85, 100)
local HAZARD = Color3.fromRGB(150, 20, 60)

local function newCave(name, opts)
	local W, H, L = opts.width or 40, opts.height or 24, opts.length
	local y0 = opts.bottom or -2
	local y1 = y0 + H
	local z0, z1 = -8, L + 8
	local cz, len, T = (z0 + z1) / 2, z1 - z0, 4
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Difficulty", opts.difficulty or 1)
	m.PrimaryPart = part(m, "Start", Vector3.new(8, 1, 8), opts.start or Vector3.new(0, y0 + 0.5, 0), Color3.fromRGB(80, 200, 255), Enum.Material.Neon, { Transparency = 0.4 })
	part(m, "Bed", Vector3.new(W + 2 * T, T, len + 2 * T), Vector3.new(0, y0 - T / 2, cz), SAND, Enum.Material.Sand)
	-- Opaque on purpose: the camera passes through see-through parts and would end up outside the cave.
	part(m, "Ceiling", Vector3.new(W + 2 * T, T, len + 2 * T), Vector3.new(0, y1 + T / 2, cz), Color3.fromRGB(45, 60, 80), Enum.Material.Rock)
	for _, side in { -1, 1 } do
		part(m, "Wall", Vector3.new(T, H, len), Vector3.new(side * (W / 2 + T / 2), (y0 + y1) / 2, cz), ROCK, Enum.Material.Rock)
	end
	for _, z in { z0 - T / 2, z1 + T / 2 } do
		part(m, "Wall", Vector3.new(W, H, T), Vector3.new(0, (y0 + y1) / 2, z), ROCK, Enum.Material.Rock)
	end
	part(m, "Water", Vector3.new(W, H, len), Vector3.new(0, (y0 + y1) / 2, cz), Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local exit = part(m, "Exit", Vector3.new(10, 10, 1), opts.exit or Vector3.new(0, y0 + 6, L), Color3.fromRGB(120, 255, 220), Enum.Material.Neon, { Transparency = 0.4, CanCollide = false })
	local exitLight = Instance.new("PointLight")
	exitLight.Range = 30
	exitLight.Brightness = 2
	exitLight.Color = exit.Color
	exitLight.Parent = exit
	-- Glowing coral along the walls so the cave stays readable.
	for z = 8, L, 20 do
		for _, side in { -1, 1 } do
			local glow = part(m, "Glow", Vector3.new(1.5, 1.5, 1.5), Vector3.new(side * (W / 2 - 1), y0 + H * 0.6, z), Color3.fromRGB(255, 150, 200), Enum.Material.Neon, { CanCollide = false, CanQuery = false, CanTouch = false })
			local light = Instance.new("PointLight")
			light.Range = 22
			light.Brightness = 1.2
			light.Color = glow.Color
			light.Parent = glow
		end
	end
	m.Parent = templates
	return m, { W = W, y0 = y0, y1 = y1, z0 = z0, z1 = z1 }
end

local function rock(m, x0, x1, y0, y1, z0, z1)
	if x1 - x0 > 0.1 and y1 - y0 > 0.1 and z1 - z0 > 0.1 then
		part(m, "Rock", Vector3.new(x1 - x0, y1 - y0, z1 - z0), Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), ROCK, Enum.Material.Rock)
	end
end

-- A rock wall across the cave at z with one opening (centre hx, hy; size hw x hh).
local function wallWithHole(m, d, z, hx, hy, hw, hh)
	local za, zb = z - 1.5, z + 1.5
	local xa, xb, ya, yb = hx - hw / 2, hx + hw / 2, hy - hh / 2, hy + hh / 2
	rock(m, -d.W / 2, xa, d.y0, d.y1, za, zb)
	rock(m, xb, d.W / 2, d.y0, d.y1, za, zb)
	rock(m, xa, xb, d.y0, ya, za, zb)
	rock(m, xa, xb, yb, d.y1, za, zb)
end

-- A rock shelf across a vertical shaft at height y with one opening (centre hx, hz; size hw x hd).
local function shelfWithHole(m, d, y, hx, hz, hw, hd)
	local ya, yb = y - 1.5, y + 1.5
	local xa, xb, za, zb = hx - hw / 2, hx + hw / 2, hz - hd / 2, hz + hd / 2
	rock(m, -d.W / 2, xa, ya, yb, d.z0, d.z1)
	rock(m, xb, d.W / 2, ya, yb, d.z0, d.z1)
	rock(m, xa, xb, ya, yb, d.z0, za)
	rock(m, xa, xb, ya, yb, zb, d.z1)
end

local function hazardBall(m, name, size, pos, color, material, attributes)
	attributes = attributes or {}
	attributes.Hazard = true
	return part(m, name, Vector3.new(size, size, size), pos, color, material, { Shape = Enum.PartType.Ball, Attributes = attributes })
end

local function urchin(m, pos, attributes)
	return hazardBall(m, "Urchin", 4, pos, HAZARD, Enum.Material.Slate, attributes)
end

local function hazardBar(m, name, size, at, attributes)
	attributes = attributes or {}
	attributes.Hazard = true
	return part(m, name, size, at, HAZARD, Enum.Material.Slate, { Attributes = attributes })
end

local function catchSpot(m, pos, hard)
	part(m, "CatchSpot", Vector3.new(1, 1, 1), pos, Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, Attributes = { Hard = hard } })
end

do -- 1. Coral Maze: walls with one opening each, alternating side and height
	local m, d = newCave("CoralMaze", { length = 90, difficulty = 1 })
	wallWithHole(m, d, 18, -12, 3, 10, 9)
	wallWithHole(m, d, 36, 12, 15, 10, 9)
	wallWithHole(m, d, 54, -12, 15, 10, 9)
	wallWithHole(m, d, 72, 12, 3, 10, 9)
	urchin(m, Vector3.new(12, 2, 42))
	urchin(m, Vector3.new(12, 2, 48))
	catchSpot(m, Vector3.new(-12, 4, 27), false)
	catchSpot(m, Vector3.new(12, 15, 63), false)
	catchSpot(m, Vector3.new(16, 1, 45), true)
end

do -- 2. Urchin Garden: drift between floating urchins, three of them patrol
	local m = newCave("UrchinGarden", { length = 80, difficulty = 2 })
	for _, p in { { -12, 4, 14 }, { 4, 12, 14 }, { 14, 18, 18 }, { -4, 18, 24 }, { 10, 4, 26 }, { -14, 10, 30 }, { 2, 6, 36 }, { 14, 12, 38 }, { -8, 16, 42 }, { 6, 18, 48 }, { -14, 4, 50 }, { 0, 10, 54 }, { 12, 4, 58 }, { -6, 6, 64 }, { 8, 14, 66 } } do
		urchin(m, Vector3.new(p[1], p[2], p[3]))
	end
	urchin(m, Vector3.new(-16, 8, 20), { MoveOffset = Vector3.new(32, 0, 0), MoveTime = 3 })
	urchin(m, Vector3.new(0, 0, 45), { MoveOffset = Vector3.new(0, 18, 0), MoveTime = 2 })
	urchin(m, Vector3.new(16, 10, 60), { MoveOffset = Vector3.new(-32, 0, 0), MoveTime = 2.5 })
	-- The rare catch sits in a ring of urchins; reach it from the front or back.
	for _, o in { { -5, 0 }, { 5, 0 }, { 0, -5 }, { 0, 5 } } do
		urchin(m, Vector3.new(-12 + o[1], 15 + o[2], 72))
	end
	catchSpot(m, Vector3.new(0, 14, 30), false)
	catchSpot(m, Vector3.new(6, 6, 62), false)
	catchSpot(m, Vector3.new(-12, 15, 72), true)
end

do -- 3. Kelp Forest: weave between kelp stalks while two eels patrol
	local m, d = newCave("KelpForest", { length = 90, difficulty = 1 })
	local rng = Random.new(7)
	for z = 12, 78, 8 do
		for x = -16, 16, 8 do
			if rng:NextNumber() > 0.3 then
				part(m, "Kelp", Vector3.new(2.5, d.y1 - d.y0, 2.5), Vector3.new(x + rng:NextNumber(-2, 2), (d.y0 + d.y1) / 2, z + rng:NextNumber(-2, 2)), Color3.fromRGB(60, 150, 70), Enum.Material.Grass)
			end
		end
	end
	hazardBar(m, "Eel", Vector3.new(1.5, 1.5, 6), Vector3.new(-16, 8, 36), { MoveOffset = Vector3.new(32, 0, 0), MoveTime = 2.5 })
	hazardBar(m, "Eel", Vector3.new(1.5, 1.5, 6), Vector3.new(16, 15, 60), { MoveOffset = Vector3.new(-32, 0, 0), MoveTime = 3 })
	catchSpot(m, Vector3.new(-4, 4, 24), false)
	catchSpot(m, Vector3.new(12, 12, 48), false)
	catchSpot(m, Vector3.new(4, 18, 68), true)
end

do -- 4. Jelly Drift: rows of jellyfish bobbing up and down out of sync
	local m = newCave("JellyDrift", { length = 80, difficulty = 2 })
	for row, z in { 15, 27, 39, 51, 63 } do
		for col, x in { -15, -7.5, 0, 7.5, 15 } do
			local jelly = hazardBall(m, "Jelly", 5, Vector3.new(x, 1, z), Color3.fromRGB(255, 120, 200), Enum.Material.Neon, {
				MoveOffset = Vector3.new(0, 17, 0),
				MoveTime = 1.6 + row * 0.15,
				MovePhase = (row * 0.2 + col * 0.35) % 1,
			})
			jelly.Transparency = 0.3
		end
	end
	catchSpot(m, Vector3.new(0, 10, 21), false)
	catchSpot(m, Vector3.new(-11, 10, 45), false)
	catchSpot(m, Vector3.new(15, 18, 57), true)
end

do -- 5. Current Tunnel: currents push you back, into a spiky wall, then up into a spiky roof
	local m = newCave("CurrentTunnel", { length = 100, width = 24, height = 20, difficulty = 2 })
	local function current(za, zb, velocity)
		part(m, "Current", Vector3.new(24, 20, zb - za), Vector3.new(0, 8, (za + zb) / 2), Color3.fromRGB(170, 230, 255), Enum.Material.Glass, {
			Transparency = 0.9,
			CanCollide = false,
			CanQuery = true, -- the client finds current zones with a spatial query
			CanTouch = false,
			CastShadow = false,
			Attributes = { Current = velocity },
		})
	end
	current(14, 36, Vector3.new(0, 0, -12))
	current(46, 66, Vector3.new(14, 0, 0))
	current(74, 94, Vector3.new(0, 12, 0))
	hazardBar(m, "SpikeWall", Vector3.new(2, 20, 20), Vector3.new(11, 8, 56))
	hazardBar(m, "SpikeRoof", Vector3.new(24, 2, 20), Vector3.new(0, 17, 84))
	catchSpot(m, Vector3.new(0, 1, 25), false)
	catchSpot(m, Vector3.new(-8, 8, 56), false)
	catchSpot(m, Vector3.new(6, 13, 84), true)
end

do -- 6. Spike Roof: you float upward and the whole roof is spiked, so stay low under the arches
	local m, d = newCave("SpikeRoof", { length = 80, difficulty = 3 })
	hazardBar(m, "SpikeRoof", Vector3.new(40, 2, 96), Vector3.new(0, d.y1 - 1, 40))
	wallWithHole(m, d, 20, -8, 3, 14, 9)
	wallWithHole(m, d, 40, 8, 3, 14, 9)
	wallWithHole(m, d, 60, 0, 3, 14, 9)
	urchin(m, Vector3.new(0, 0, 30))
	urchin(m, Vector3.new(-10, 0, 50))
	catchSpot(m, Vector3.new(6, 3, 30), false)
	catchSpot(m, Vector3.new(-4, 3, 50), false)
	catchSpot(m, Vector3.new(12, 16, 70), true)
end

do -- 7. Deep Shaft: swim down against your own buoyancy through shelves with offset holes
	local m, d = newCave("DeepShaft", { length = 24, width = 28, height = 64, bottom = -56, start = Vector3.new(0, 0, 0), exit = Vector3.new(0, -51, 24), difficulty = 3 })
	shelfWithHole(m, d, -10, 8, 4, 9, 9)
	shelfWithHole(m, d, -22, -8, 20, 9, 9)
	shelfWithHole(m, d, -34, 8, 20, 9, 9)
	shelfWithHole(m, d, -44, -8, 4, 9, 9)
	urchin(m, Vector3.new(-6, -28, 8))
	urchin(m, Vector3.new(6, -40, 12))
	urchin(m, Vector3.new(0, -16, 14), { MoveOffset = Vector3.new(0, 0, -12), MoveTime = 2 })
	urchin(m, Vector3.new(6, -51, 6))
	catchSpot(m, Vector3.new(-8, -16, 4), false)
	catchSpot(m, Vector3.new(8, -28, 12), false)
	catchSpot(m, Vector3.new(11, -53, 2), true)
end

do -- 8. Windmills: spinning blades across the tunnel; time your swim or squeeze through a corner
	local m = newCave("Windmills", { length = 70, difficulty = 3 })
	for i, z in { 20, 40, 58 } do
		local speed = i % 2 == 0 and -70 or 55
		for _, angle in { 0, 90 } do
			hazardBar(m, "Blade", Vector3.new(36, 2, 2), CFrame.new(0, 10, z) * CFrame.Angles(0, 0, math.rad(angle)), { SpinSpeed = speed, SpinAxis = "Z" })
		end
	end
	catchSpot(m, Vector3.new(-15, 0, 30), false)
	catchSpot(m, Vector3.new(15, 18, 50), false)
	catchSpot(m, Vector3.new(0, 10, 49), true)
end

return ("Built harbor with %d plots and %d floor templates"):format(#plots:GetChildren(), #templates:GetChildren())
