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
for _, name in { "DiveEvent", "DiveChoice" } do
	if not remotes:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
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

part(harbor, "Sea", Vector3.new(600, 2, 600), Vector3.new(0, -3, 0), Color3.fromRGB(35, 120, 190), Enum.Material.Glass, { Transparency = 0.15 })
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

-- 3. Sunlit Reef floor templates. Each runs along +Z from a Start pad at the origin to an Exit gate.
local REEF = { Color3.fromRGB(255, 127, 80), Color3.fromRGB(255, 170, 200), Color3.fromRGB(250, 210, 90), Color3.fromRGB(120, 200, 170) }
local reefIndex = 0
local function reefColor()
	reefIndex = reefIndex % #REEF + 1
	return REEF[reefIndex]
end

local function newFloor(name, length, exitY)
	exitY = exitY or 0
	local m = Instance.new("Model")
	m.Name = name
	m.PrimaryPart = part(m, "Start", Vector3.new(12, 1, 12), Vector3.new(0, 0, 0), Color3.fromRGB(80, 200, 255))
	part(m, "ExitPad", Vector3.new(12, 1, 12), Vector3.new(0, exitY, length), Color3.fromRGB(80, 200, 255))
	part(m, "Exit", Vector3.new(10, 8, 1), Vector3.new(0, exitY + 4.5, length + 3), Color3.fromRGB(120, 255, 220), Enum.Material.Neon, { Transparency = 0.5, CanCollide = false })
	part(m, "Seabed", Vector3.new(160, 2, length + 80), Vector3.new(0, -24, length / 2), SAND, Enum.Material.Sand, { Attributes = { Hazard = true } })
	for z = 0, length, 16 do
		for _, x in { -30, 30 } do
			part(m, "Kelp", Vector3.new(1, 18 + (z % 3) * 4, 1), Vector3.new(x + z % 5, -14, z), Color3.fromRGB(60, 140, 70), Enum.Material.Grass, { CanCollide = false, CanQuery = false, CanTouch = false })
		end
	end
	m.Parent = templates
	return m
end

local function platform(m, size, pos, props)
	return part(m, "Platform", size, pos, reefColor(), Enum.Material.SmoothPlastic, props)
end

local function catchSpot(m, pos, hard)
	part(m, "CatchSpot", Vector3.new(1, 1, 1), pos, Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false, CanTouch = false, Attributes = { Hard = hard } })
end

local function urchin(m, pos, props)
	return part(m, "Urchin", Vector3.new(3, 3, 3), pos, Color3.fromRGB(150, 20, 60), Enum.Material.Slate, props or {})
end

local function hazardous(props)
	props = props or {}
	props.Shape = Enum.PartType.Ball
	props.Attributes = props.Attributes or {}
	props.Attributes.Hazard = true
	return props
end

do -- 1. Coral Steps: staggered climb with a detour for the hard catch
	local m = newFloor("CoralSteps", 67)
	for _, p in { { -3, 0, 12 }, { 3, 2, 23 }, { -3, 4, 34 }, { 3, 4, 45 }, { -3, 2, 56 } } do
		platform(m, Vector3.new(6, 1, 6), Vector3.new(p[1], p[2], p[3]))
	end
	platform(m, Vector3.new(4, 1, 4), Vector3.new(13, 6, 45))
	catchSpot(m, Vector3.new(3, 5, 23), false)
	catchSpot(m, Vector3.new(-3, 5, 56), false)
	catchSpot(m, Vector3.new(13, 9, 45), true)
end

do -- 2. Kelp Beams: narrow zigzag beams
	local m = newFloor("KelpBeams", 70)
	for _, p in { { 0, 14 }, { 4, 28 }, { -1, 42 }, { 3, 56 } } do
		part(m, "Beam", Vector3.new(2.5, 1, 12), Vector3.new(p[1], 0, p[2]), Color3.fromRGB(70, 160, 80), Enum.Material.Grass)
	end
	platform(m, Vector3.new(3, 1, 3), Vector3.new(-8, 1, 42))
	catchSpot(m, Vector3.new(4, 3, 28), false)
	catchSpot(m, Vector3.new(3, 3, 56), false)
	catchSpot(m, Vector3.new(-8, 4, 42), true)
end

do -- 3. Urchin Field: open floor, dodge the urchins (two of them patrol)
	local m = newFloor("UrchinField", 72)
	part(m, "Floor", Vector3.new(24, 1, 58), Vector3.new(0, 0, 36), Color3.fromRGB(240, 220, 170), Enum.Material.Sand)
	for _, p in { { -8, 15 }, { 8, 15 }, { -4, 28 }, { 6, 32 }, { 2, 44 }, { 9, 48 }, { -5, 54 }, { 4, 60 } } do
		urchin(m, Vector3.new(p[1], 2, p[2]), hazardous())
	end
	urchin(m, Vector3.new(-6, 2, 21), hazardous({ Attributes = { MoveOffset = Vector3.new(12, 0, 0), MoveTime = 2 } }))
	urchin(m, Vector3.new(6, 2, 40), hazardous({ Attributes = { MoveOffset = Vector3.new(-14, 0, 0), MoveTime = 2.4 } }))
	catchSpot(m, Vector3.new(-2, 3, 36), false)
	catchSpot(m, Vector3.new(-9, 3, 28), false)
	catchSpot(m, Vector3.new(9, 3, 41), true)
end

do -- 4. Turtle Shells: moving platforms
	local m = newFloor("TurtleShells", 73)
	local moves = {
		{ -5, 13, Vector3.new(10, 0, 0) },
		{ 5, 25, Vector3.new(-10, 0, 0) },
		{ 0, 37, Vector3.new(0, 4, 0) },
		{ -5, 49, Vector3.new(10, 0, 0) },
		{ 5, 61, Vector3.new(-10, 0, 0) },
	}
	for _, mv in moves do
		part(m, "Shell", Vector3.new(7, 1.5, 7), Vector3.new(mv[1], 0, mv[2]), Color3.fromRGB(90, 140, 70), Enum.Material.Slate, { Attributes = { MoveOffset = mv[3], MoveTime = 2.5 } })
	end
	catchSpot(m, Vector3.new(0, 4, 25), false)
	catchSpot(m, Vector3.new(0, 4, 49), false)
	catchSpot(m, Vector3.new(0, 9, 37), true)
end

do -- 5. Current Corridor: slabs with sideways currents
	local m = newFloor("CurrentCorridor", 63)
	for i, z in { 14, 32, 50 } do
		local push = i % 2 == 1 and 10 or -10
		part(m, "Current", Vector3.new(12, 1, 14), Vector3.new(0, 0, z), Color3.fromRGB(90, 190, 230), Enum.Material.Glacier, { Attributes = { Current = Vector3.new(push, 0, 0) } })
	end
	catchSpot(m, Vector3.new(-4, 3, 14), false)
	catchSpot(m, Vector3.new(0, 3, 32), false)
	catchSpot(m, Vector3.new(5, 3, 50), true)
end

do -- 6. Sinking Sand: platforms crumble shortly after you land
	local m = newFloor("SinkingSand", 64)
	for i, z in { 12, 22, 32, 42, 52 } do
		platform(m, Vector3.new(6, 1, 6), Vector3.new(i % 2 == 0 and 2 or -2, 0, z), { Material = Enum.Material.Sand, Attributes = { Crumble = true } })
	end
	platform(m, Vector3.new(4, 1, 4), Vector3.new(9, 0, 32), { Material = Enum.Material.Sand, Attributes = { Crumble = true } })
	catchSpot(m, Vector3.new(2, 3, 22), false)
	catchSpot(m, Vector3.new(2, 3, 42), false)
	catchSpot(m, Vector3.new(9, 3, 32), true)
end

do -- 7. Bubble Climb: zigzag up to a high exit
	local m = newFloor("BubbleClimb", 58, 24)
	for _, p in { { 0, 3, 12 }, { 6, 6, 18 }, { 0, 9, 24 }, { -6, 12, 30 }, { 0, 15, 36 }, { 6, 18, 42 }, { 0, 21, 48 } } do
		part(m, "Bubble", Vector3.new(5, 1, 5), Vector3.new(p[1], p[2], p[3]), Color3.fromRGB(170, 230, 255), Enum.Material.SmoothPlastic, { Transparency = 0.2 })
	end
	part(m, "Bubble", Vector3.new(3, 1, 3), Vector3.new(13, 21, 46), Color3.fromRGB(170, 230, 255), Enum.Material.SmoothPlastic, { Transparency = 0.2 })
	catchSpot(m, Vector3.new(6, 9, 18), false)
	catchSpot(m, Vector3.new(-6, 15, 30), false)
	catchSpot(m, Vector3.new(13, 24, 46), true)
end

do -- 8. Urchin Sweeper: jump the spinning bar, or hug the corners
	local m = newFloor("UrchinSweeper", 48)
	part(m, "Floor", Vector3.new(32, 1, 32), Vector3.new(0, 0, 24), Color3.fromRGB(240, 220, 170), Enum.Material.Sand)
	part(m, "Sweeper", Vector3.new(30, 1.5, 1.5), Vector3.new(0, 1.25, 24), Color3.fromRGB(150, 20, 60), Enum.Material.Slate, { Attributes = { Hazard = true, SpinSpeed = 70 } })
	catchSpot(m, Vector3.new(12, 3, 12), false)
	catchSpot(m, Vector3.new(-12, 3, 36), false)
	catchSpot(m, Vector3.new(0, 4.5, 24), true)
end

return ("Built harbor with %d plots and %d floor templates"):format(#plots:GetChildren(), #templates:GetChildren())
