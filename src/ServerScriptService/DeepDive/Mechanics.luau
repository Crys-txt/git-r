-- Brings a trench chunk to life. Driven by part attributes set in tools/build_world.luau, all in the
-- chunk's own space (so a rotated chunk still moves things the way it was built):
--   MoveOffset, MoveTime  -> moves back and forth (MovePhase 0..1 shifts the start of the cycle)
--   SpinSpeed, SpinAxis   -> spins in degrees per second around "X", "Y" (default) or "Z"
--   Crumble               -> fades out shortly after someone touches it, then comes back
--   Current               -> pushes swimmers; applied on the client (DeepDiveEquipment), not here
local RunService = game:GetService("RunService")

local Mechanics = {}

local CRUMBLE_WARNING = 0.6
local CRUMBLE_RESPAWN = 2.5
local AXES = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }

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

function Mechanics.start(model)
	local pivot = model:GetPivot()
	local movers, spinners = {}, {}
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local offset = part:GetAttribute("MoveOffset")
		if offset then
			table.insert(movers, {
				part = part,
				base = part.CFrame,
				offset = pivot:VectorToWorldSpace(offset),
				period = 2 * (part:GetAttribute("MoveTime") or 3),
				phase = part:GetAttribute("MovePhase") or 0,
			})
		end
		local spin = part:GetAttribute("SpinSpeed")
		if spin then
			local axis = pivot:VectorToWorldSpace(AXES[part:GetAttribute("SpinAxis") or "Y"])
			table.insert(spinners, { part = part, speed = math.rad(spin), axis = axis })
		end
		if part:GetAttribute("Crumble") then
			hookCrumble(part)
		end
	end
	if #movers == 0 and #spinners == 0 then
		return
	end

	local started = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not model.Parent then
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

return Mechanics
