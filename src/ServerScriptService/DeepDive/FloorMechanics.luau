-- Moving platforms, currents, crumbling sand and spinning hazards for a cloned floor.
-- Behaviour is driven by attributes set in tools/build_world.luau.
local RunService = game:GetService("RunService")

local FloorMechanics = {}

local CRUMBLE_WARNING = 0.6
local CRUMBLE_RESPAWN = 2.5

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
	local movers, spinners = {}, {}
	for _, part in floor:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local offset = part:GetAttribute("MoveOffset")
		if offset then
			table.insert(movers, { part = part, base = part.CFrame, offset = offset, period = 2 * (part:GetAttribute("MoveTime") or 3) })
		end
		if part:GetAttribute("SpinSpeed") then
			table.insert(spinners, part)
		end
		if part:GetAttribute("Crumble") then
			hookCrumble(part)
		end
		local current = part:GetAttribute("Current")
		if current then
			-- An anchored part with velocity pushes whatever stands on it, like a conveyor.
			part.AssemblyLinearVelocity = current
		end
	end
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
			local phase = 2 * math.pi * t / mover.period
			mover.part.CFrame = mover.base + mover.offset * (0.5 - 0.5 * math.cos(phase))
			-- Matching velocity lets characters ride the platform instead of sliding off it.
			mover.part.AssemblyLinearVelocity = mover.offset * (math.pi / mover.period) * math.sin(phase)
		end
		for _, part in spinners do
			part.CFrame *= CFrame.Angles(0, math.rad(part:GetAttribute("SpinSpeed")) * dt, 0)
		end
	end)
end

return FloorMechanics
