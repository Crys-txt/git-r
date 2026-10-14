-- Client side of moving and diving: sprint swimming (Shift / Sprint button), the harpoon (F / Harpoon button
-- catches the nearest creature in range and in sight) and trench currents that push you while you swim.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("DeepDive")
local Config = require(shared:WaitForChild("Config"))
local Remotes = shared:WaitForChild("Remotes")
local player = Players.LocalPlayer
local trench = workspace:WaitForChild("Trench")

local HARPOON_ACTION = "DeepDiveHarpoon"
local SPRINT_ACTION = "DeepDiveSprint"

local lastShot = 0

local trenchParams = OverlapParams.new()
trenchParams.FilterType = Enum.RaycastFilterType.Include
trenchParams.FilterDescendantsInstances = { trench }

local function rootPart()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return character:FindFirstChild("HumanoidRootPart"), character
	end
end

---------------------------------------------------------------- sprint
-- The server applies the speed and drains oxygen faster by the same factor.
local function sprint(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		Remotes.Sprint:FireServer(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		Remotes.Sprint:FireServer(false)
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction(SPRINT_ACTION, sprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle(SPRINT_ACTION, "Sprint")

---------------------------------------------------------------- harpoon
local function inSight(root, character, target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, target }
	params.IgnoreWater = true
	return workspace:Raycast(root.Position, target.Position - root.Position, params) == nil
end

local function nearestCatch(root, character, range)
	local best, bestDistance = nil, range
	for _, part in workspace:GetPartBoundsInRadius(root.Position, range, trenchParams) do
		if part.Name == "Catch" then
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

---------------------------------------------------------------- currents
local function insidePart(part, position)
	local p = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- Currents carry you along at their speed while you are inside the zone. This moves the character directly
-- because the swim controller overrides any velocity added to it every frame. A current's direction is in
-- its chunk's own space, so rotated chunks still push the way they were built.
RunService.Heartbeat:Connect(function(dt)
	if not player:GetAttribute("Diving") then
		return
	end
	local root = rootPart()
	if not root then
		return
	end
	for _, part in workspace:GetPartBoundsInRadius(root.Position, 1, trenchParams) do
		local current = part:GetAttribute("Current")
		local chunk = part:FindFirstAncestorOfClass("Model")
		if current and chunk and insidePart(part, root.Position) then
			root.CFrame += chunk:GetPivot():VectorToWorldSpace(current) * dt
		end
	end
end)

player:GetAttributeChangedSignal("Diving"):Connect(refreshHarpoon)
player:GetAttributeChangedSignal("HarpoonRange"):Connect(refreshHarpoon)
refreshHarpoon()
