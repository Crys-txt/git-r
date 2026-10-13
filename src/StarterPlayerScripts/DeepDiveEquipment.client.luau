-- Client side of diving: the harpoon (F / Harpoon button catches the nearest creature in range and in sight)
-- and water currents that push you while you swim through a floor's "Current" zones.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("DeepDive")
local Config = require(shared:WaitForChild("Config"))
local Remotes = shared:WaitForChild("Remotes")
local player = Players.LocalPlayer
local activeDives = workspace:WaitForChild("ActiveDives")

local HARPOON_ACTION = "DeepDiveHarpoon"

local lastShot = 0

local diveParams = OverlapParams.new()
diveParams.FilterType = Enum.RaycastFilterType.Include
diveParams.FilterDescendantsInstances = { activeDives }

local function rootPart()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return character:FindFirstChild("HumanoidRootPart"), character
	end
end

local function inSight(root, character, target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, target }
	params.IgnoreWater = true
	return workspace:Raycast(root.Position, target.Position - root.Position, params) == nil
end

local function nearestCatch(root, character, range)
	local best, bestDistance = nil, range
	for _, part in workspace:GetPartBoundsInRadius(root.Position, range, diveParams) do
		local floor = part:FindFirstAncestorOfClass("Model")
		if part.Name == "Catch" and floor and floor:GetAttribute("OwnerId") == player.UserId then
			local distance = (part.Position - root.Position).Magnitude
			if distance < bestDistance and inSight(root, character, part) then
				best, bestDistance = part, distance
			end
		end
	end
	return best
end

local function drawLine(from, to)
	local line = Instance.new("Part")
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.Material = Enum.Material.Neon
	line.Color = Color3.fromRGB(230, 240, 255)
	line.Size = Vector3.new(0.2, 0.2, (to - from).Magnitude)
	line.CFrame = CFrame.lookAt((from + to) / 2, to)
	line.Parent = workspace
	Debris:AddItem(line, 0.25)
end

local function fireHarpoon(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local root, character = rootPart()
	local range = player:GetAttribute("HarpoonRange") or 0
	if not root or range <= 0 or os.clock() - lastShot < Config.HARPOON_COOLDOWN then
		return Enum.ContextActionResult.Sink
	end
	lastShot = os.clock()
	local target = nearestCatch(root, character, range)
	if target then
		drawLine(root.Position, target.Position)
		Remotes.Harpoon:FireServer(target)
	end
	return Enum.ContextActionResult.Sink
end

local function refreshHarpoon()
	ContextActionService:UnbindAction(HARPOON_ACTION)
	if player:GetAttribute("Diving") and (player:GetAttribute("HarpoonRange") or 0) > 0 then
		ContextActionService:BindAction(HARPOON_ACTION, fireHarpoon, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle(HARPOON_ACTION, "Harpoon")
	end
end

local function insidePart(part, position)
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- Currents carry you along at their speed while you are inside the zone. This moves the character directly
-- because the swim controller overrides any velocity added to it every frame.
RunService.Heartbeat:Connect(function(dt)
	if not player:GetAttribute("Diving") then
		return
	end
	local root = rootPart()
	if not root then
		return
	end
	for _, part in workspace:GetPartBoundsInRadius(root.Position, 1, diveParams) do
		local current = part:GetAttribute("Current")
		if current and insidePart(part, root.Position) then
			root.CFrame += current * dt
		end
	end
end)

player:GetAttributeChangedSignal("Diving"):Connect(refreshHarpoon)
player:GetAttributeChangedSignal("HarpoonRange"):Connect(refreshHarpoon)
refreshHarpoon()
