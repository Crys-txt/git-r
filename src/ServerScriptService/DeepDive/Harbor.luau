-- The hub on the seafloor: player domes with display tanks, wing unlocks, the shopkeeper NPC and the live feed.
-- Each tank shows one of every species you have caught (your collection); those fish can't be sold.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.DeepDive.Config)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.DeepDive.Remotes
local models = ReplicatedStorage.DeepDive.Models
local harbor = workspace:WaitForChild("Harbor")
local spawnDome = harbor:WaitForChild("SpawnDome")
local shopDome = harbor:WaitForChild("ShopDome")
local feedLabel = spawnDome:WaitForChild("DiveFeed"):WaitForChild("SurfaceGui"):WaitForChild("FeedLabel")

local Harbor = {}

local FEED_LINES = 6
local FISH_SIZE = 2.2 -- studs, largest side of a displayed fish
local LEGENDARY_SIZE = 3.6
local LOCKED_COLOR = Color3.fromRGB(120, 130, 140)
local OPEN_COLOR = Color3.fromRGB(120, 220, 255)
local IDLE_ANIMATION = "rbxassetid://507766666" -- Roblox's default R15 idle
local WAVE_ANIMATION = "rbxassetid://507770239" -- Roblox's default R15 wave

local owners = {} -- [dome] = player
local feed = {}

local domes = harbor:WaitForChild("Domes"):GetChildren()
table.sort(domes, function(a, b)
	return a.Name < b.Name
end)

local function domeOf(player)
	for dome, owner in owners do
		if owner == player then
			return dome
		end
	end
end

function Harbor.post(text)
	table.insert(feed, 1, text)
	if #feed > FEED_LINES then
		table.remove(feed)
	end
	feedLabel.Text = table.concat(feed, "\n")
end

-- Where you wake up after drowning: your own dome, or the spawn dome.
function Harbor.homeCFrame(player)
	local dome = domeOf(player)
	local spot = dome and dome:FindFirstChild("HomeSpot") or spawnDome:FindFirstChild("HarborSpawn")
	return spot.CFrame + Vector3.new(0, 4, 0)
end

local function fishVisual(creature)
	local source = models:FindFirstChild(creature.model)
	local fish
	if source and source:IsA("BasePart") then
		fish = source:Clone()
		local size = creature.rarity == "Legendary" and LEGENDARY_SIZE or FISH_SIZE
		fish.Size *= size / math.max(fish.Size.X, fish.Size.Y, fish.Size.Z)
	else
		-- No mesh yet: a coloured blob in the rarity colour.
		fish = Instance.new("Part")
		fish.Size = Vector3.new(0.6, 0.9, 1.6)
		fish.Color = Config.Rarities[creature.rarity].color
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = fish
	end
	fish.Name = creature.id
	fish.Anchored = true
	fish.CanCollide = false
	fish.CanQuery = false
	fish.CanTouch = false
	return fish
end

local function addFish(creature, tank, parent)
	local fish = fishVisual(creature)
	local half = tank.Size / 2 - Vector3.new(1.5, 1.5, 1.5)
	local function randomPoint()
		return tank.CFrame:PointToWorldSpace(Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * half)
	end
	local from, to = randomPoint(), randomPoint()
	fish.CFrame = CFrame.lookAt(from, to)
	fish.Parent = parent
	local swim = TweenInfo.new(3 + math.random() * 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(fish, swim, { CFrame = CFrame.lookAt(to, to + (to - from)) }):Play()
end

function Harbor.refresh(player)
	local dome, data = domeOf(player), PlayerData.get(player)
	if not (dome and data) then
		return
	end
	dome.Fish:ClearAllChildren()

	local species = {}
	for _, creature in Config.Creatures do
		if data.discovered[creature.id] then
			table.insert(species, creature)
		end
	end
	-- Rarest first, so the best catches are always on show.
	table.sort(species, function(a, b)
		return Config.Rarities[a.rarity].order > Config.Rarities[b.rarity].order
	end)

	local shown = 0
	for _, wing in Config.Wings do
		local tank = dome.Tanks[wing.id]
		local unlocked = data.wings[wing.id] == true
		tank.Color = unlocked and OPEN_COLOR or LOCKED_COLOR
		tank.Transparency = unlocked and 0.65 or 0.85
		tank.ProximityPrompt.Enabled = not unlocked
		if unlocked then
			for _ = 1, Config.SPECIES_PER_TANK do
				local creature = species[shown + 1]
				if not creature then
					break
				end
				addFish(creature, tank, dome.Fish)
				shown += 1
			end
		end
	end

	local lines = { ("%s's Dome"):format(player.DisplayName), ("%d / %d species"):format(#species, #Config.Creatures) }
	if #species > shown then
		table.insert(lines, ("%d waiting for a new tank"):format(#species - shown))
	end
	dome.Sign.BillboardGui.TextLabel.Text = table.concat(lines, "\n")
end

function Harbor.assignDome(player)
	for _, dome in domes do
		if not owners[dome] then
			owners[dome] = player
			dome:SetAttribute("OwnerId", player.UserId)
			Harbor.refresh(player)
			return dome
		end
	end
	warn("[DeepDive] No free dome for", player.Name)
end

function Harbor.releaseDome(player)
	local dome = domeOf(player)
	if not dome then
		return
	end
	owners[dome] = nil
	dome:SetAttribute("OwnerId", nil)
	dome.Fish:ClearAllChildren()
	dome.Sign.BillboardGui.TextLabel.Text = "Free dome"
	for _, tank in dome.Tanks:GetChildren() do
		tank.Color = LOCKED_COLOR
		tank.Transparency = 0.85
		tank.ProximityPrompt.Enabled = false
	end
end

local function tryUnlock(player, dome, index)
	local wing = Config.Wings[index]
	local data = PlayerData.get(player)
	if owners[dome] ~= player or not data or data.wings[wing.id] then
		return
	end
	local previous = Config.Wings[index - 1]
	if previous and not data.wings[previous.id] then
		Remotes.DiveEvent:FireClient(player, "Notice", { text = "Open the " .. previous.name .. " first" })
		return
	end
	if data.pearls < wing.cost then
		Remotes.DiveEvent:FireClient(player, "Notice", { text = ("Need %d pearls (you have %d)"):format(wing.cost, data.pearls) })
		return
	end
	data.pearls -= wing.cost
	data.wings[wing.id] = true
	PlayerData.sync(player)
	Harbor.refresh(player)
	Harbor.post(("%s opened the %s!"):format(player.DisplayName, wing.name))
end

for _, dome in domes do
	for index, wing in Config.Wings do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = ("Unlock (%d pearls)"):format(wing.cost)
		prompt.ObjectText = wing.name
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = dome.Tanks[wing.id]
		prompt.Triggered:Connect(function(player)
			tryUnlock(player, dome, index)
		end)
	end
end

-- The shopkeeper: a Roblox avatar standing behind the counter. Talking to her opens the shop (client side).
local function createShopkeeper()
	local look = Config.Shopkeeper
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = look.skin
	description.LeftArmColor = look.skin
	description.RightArmColor = look.skin
	description.TorsoColor = look.shirt
	description.LeftLegColor = look.pants
	description.RightLegColor = look.pants
	local ok, npc = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if not ok then
		warn("[DeepDive] Could not create the shopkeeper:", npc)
		return
	end
	npc.Name = "Shopkeeper"
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local root = npc:FindFirstChild("HumanoidRootPart")
	humanoid.DisplayName = look.name
	humanoid.NameDisplayDistance = 40
	root.Anchored = true
	local spot = shopDome:WaitForChild("ShopkeeperSpot")
	npc:PivotTo(spot.CFrame * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = look.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	npc.Parent = shopDome

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local function load(id)
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		return animator:LoadAnimation(animation)
	end
	local idle, wave = load(IDLE_ANIMATION), load(WAVE_ANIMATION)
	idle.Looped = true
	idle:Play()
	prompt.Triggered:Connect(function()
		wave:Play()
	end)
end

createShopkeeper()
Harbor.post("Welcome! Swim into the trench to dive.")

return Harbor
