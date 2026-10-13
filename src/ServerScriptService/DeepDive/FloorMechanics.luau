-- Brings a cloned floor to life: terrain water, moving and spinning hazards, crumbling parts.
-- Behaviour is driven by part names and attributes set in tools/build_world.luau:
--   "Water" part          -> filled with terrain water while the floor exists
--   MoveOffset, MoveTime  -> moves back and forth (MovePhase 0..1 shifts the start of the cycle)
--   SpinSpeed, SpinAxis   -> spins in degrees per second around "X", "Y" (default) or "Z"
--   Crumble               -> fades out shortly after someone touches it, then comes back
--   Current               -> pushes swimmers; applied on the client (DeepDiveEquipment), not here
local RunService = game:GetService("RunService")

local FloorMechanics = {}

local CRUMBLE_WARNING = 0.6
local CRUMBLE_RESPAWN = 2.5
local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

local terrain = workspace.Terrain

local function fillWater(floor, volumes)
	local regions = {}
	for _, volume in volumes do
		terrain:FillBlock(volume.CFrame, volume.Size, Enum.Material.Water)
		table.insert(regions, { cframe = volume.CFrame, size = volume.Size })
	end
	floor.Destroying:Connect(function()
		for _, region in regions do
			terrain:FillBlock(region.cframe, region.size, Enum.Material.Air)
		end
	end)
end

local function hookCrumble(part)
	local originalColor, originalTransparency = part.Color, part.Transparency
	local busy = false
	part.Touched:Connect(function(hit)
		if busy or not hit.Parent:FindFirstChildOfClass("Humanoid") then
			return
		end
		busy = true
		part.Color = Color3.fromRGB(255, 140, 60)
		task.wait(CRUMBLE_WARNING)
		if not part.Parent then
			return
		end
		part.Transparency = 0.8
		part.CanCollide = false
		task.wait(CRUMBLE_RESPAWN)
		if not part.Parent then
			return
		end
		part.Color = originalColor
		part.Transparency = originalTransparency
		part.CanCollide = true
		busy = false
	end)
end

function FloorMechanics.start(floor)
	local movers, spinners, water = {}, {}, {}
	for _, part in floor:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Name == "Water" then
			table.insert(water, part)
		end
		local offset = part:GetAttribute("MoveOffset")
		if offset then
			table.insert(movers, {
				part = part,
				base = part.CFrame,
				offset = offset,
				period = 2 * (part:GetAttribute("MoveTime") or 3),
				phase = part:GetAttribute("MovePhase") or 0,
			})
		end
		local spin = part:GetAttribute("SpinSpeed")
		if spin then
			table.insert(spinners, { part = part, speed = math.rad(spin), axis = AXES[part:GetAttribute("SpinAxis") or "Y"] })
		end
		if part:GetAttribute("Crumble") then
			hookCrumble(part)
		end
	end
	fillWater(floor, water)
	if #movers == 0 and #spinners == 0 then
		return
	end

	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not floor.Parent then
			connection:Disconnect()
			return
		end
		local t = os.clock() - started
		for _, mover in movers do
			local angle = 2 * math.pi * (t / mover.period + mover.phase)
			mover.part.CFrame = mover.base + mover.offset * (0.5 - 0.5 * math.cos(angle))
			-- Matching velocity lets characters ride a moving platform instead of sliding off it.
			mover.part.AssemblyLinearVelocity = mover.offset * (math.pi / mover.period) * math.sin(angle)
		end
		for _, spinner in spinners do
			local cframe = spinner.part.CFrame
			spinner.part.CFrame = CFrame.fromAxisAngle(spinner.axis, spinner.speed * dt) * cframe.Rotation + cframe.Position
		end
	end)
end

return FloorMechanics
