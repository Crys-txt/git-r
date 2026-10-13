-- Harbor lobby: plot ownership, aquarium tanks with swimming catches, wing unlocks and the live dive feed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.DeepDive.Config)
local PlayerData = require(script.Parent.PlayerData)

local Remotes = ReplicatedStorage.DeepDive.Remotes
local harbor = workspace:WaitForChild("Harbor")
local plotsFolder = harbor:WaitForChild("Plots")
local feedLabel = harbor:WaitForChild("DiveFeed"):WaitForChild("SurfaceGui"):WaitForChild("FeedLabel")

local Harbor = {}

local FEED_LINES = 5
local LOCKED_COLOR = Color3.fromRGB(120, 130, 140)
local OPEN_COLOR = Color3.fromRGB(120, 220, 255)

local owners = {} -- [plot] = player
local feed = {}

local plots = plotsFolder:GetChildren()
table.sort(plots, function(a, b)
	return a.Name < b.Name
end)

local function plotOf(player)
	for plot, owner in owners do
		if owner == player then
			return plot
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

local function addFish(creature, tank, parent)
	local fish = Instance.new("Part")
	fish.Name = creature.id
	fish.Anchored = true
	fish.CanCollide = false
	fish.CanQuery = false
	fish.CanTouch = false
	fish.Size = Vector3.new(0.5, 0.8, 1.4) * (creature.rarity == "Legendary" and 1.8 or 1)
	fish.Color = creature.color
	fish.Material = creature.rarity == "Common" and Enum.Material.SmoothPlastic or Enum.Material.Neon
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = fish

	local half = tank.Size / 2 - Vector3.new(1, 1, 1)
	local function randomPoint()
		return tank.CFrame:PointToWorldSpace(Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * half)
	end
	local from, to = randomPoint(), randomPoint()
	fish.CFrame = CFrame.lookAt(from, to)
	fish.Parent = parent
	local swim = TweenInfo.new(2 + math.random() * 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(fish, swim, { CFrame = CFrame.lookAt(to, to + (to - from)) }):Play()
end

function Harbor.refresh(player)
	local plot, data = plotOf(player), PlayerData.get(player)
	if not (plot and data) then
		return
	end
	plot.Fish:ClearAllChildren()

	-- Rarest catches first, so the best ones are always on display.
	local catches = {}
	for id, count in data.catches do
		local creature = Config.getCreature(id)
		if creature then
			for _ = 1, math.min(count, Config.FISH_PER_TANK) do
				table.insert(catches, creature)
			end
		end
	end
	table.sort(catches, function(a, b)
		return Config.Rarities[a.rarity].order > Config.Rarities[b.rarity].order
	end)

	local nextCatch = 1
	for _, wing in Config.Wings do
		local tank = plot.Tanks[wing.id]
		local unlocked = data.wings[wing.id] == true
		tank.Color = unlocked and OPEN_COLOR or LOCKED_COLOR
		tank.Transparency = unlocked and 0.6 or 0.85
		tank.ProximityPrompt.Enabled = not unlocked
		if unlocked then
			for _ = 1, Config.FISH_PER_TANK do
				local creature = catches[nextCatch]
				if not creature then
					break
				end
				addFish(creature, tank, plot.Fish)
				nextCatch += 1
			end
		end
	end
end

function Harbor.assignPlot(player)
	for _, plot in plots do
		if not owners[plot] then
			owners[plot] = player
			plot:SetAttribute("OwnerId", player.UserId)
			plot.Sign.SurfaceGui.TextLabel.Text = player.DisplayName .. "'s Aquarium"
			Harbor.refresh(player)
			return plot
		end
	end
	warn("[DeepDive] No free plot for", player.Name)
end

function Harbor.releasePlot(player)
	local plot = plotOf(player)
	if not plot then
		return
	end
	owners[plot] = nil
	plot:SetAttribute("OwnerId", nil)
	plot.Fish:ClearAllChildren()
	plot.Sign.SurfaceGui.TextLabel.Text = "Free plot"
	for _, tank in plot.Tanks:GetChildren() do
		tank.Color = LOCKED_COLOR
		tank.Transparency = 0.85
		tank.ProximityPrompt.Enabled = false
	end
end

local function tryUnlock(player, plot, index)
	local wing = Config.Wings[index]
	local data = PlayerData.get(player)
	if owners[plot] ~= player or not data or data.wings[wing.id] then
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

for _, plot in plots do
	for index, wing in Config.Wings do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = ("Unlock (%d pearls)"):format(wing.cost)
		prompt.ObjectText = wing.name
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = plot.Tanks[wing.id]
		prompt.Triggered:Connect(function(player)
			tryUnlock(player, plot, index)
		end)
	end
end

Harbor.post("Welcome to the harbor! Take the diving bell down.")

return Harbor
