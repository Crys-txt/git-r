-- Client side of run gadgets: Bubble Jump (double jump) and Jet Fins (dash).
-- The server decides which gadgets you own through the "Gadgets" player attribute.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local DASH_ACTION = "DeepDiveDash"
local DASH_SPEED = 70
local DASH_TIME = 0.18
local DASH_COOLDOWN = 1.5
local BUBBLE_JUMP_SPEED = 50
local BUBBLE_JUMP_DELAY = 0.15 -- ignore the jump press that started the first jump

local owned = {}
local bubbleUsed = false
local airborneSince = 0
local lastDash = 0

local function humanoidAndRoot()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return humanoid, root
	end
end

local function onCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.StateChanged:Connect(function(_, state)
		if state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running then
			bubbleUsed = false
		elseif state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
			if airborneSince == 0 then
				airborneSince = os.clock()
			end
			return
		end
		airborneSince = 0
	end)
end

UserInputService.JumpRequest:Connect(function()
	if not owned.BubbleJump or bubbleUsed then
		return
	end
	local humanoid, root = humanoidAndRoot()
	if not humanoid or humanoid.FloorMaterial ~= Enum.Material.Air then
		return
	end
	if airborneSince == 0 or os.clock() - airborneSince < BUBBLE_JUMP_DELAY then
		return
	end
	bubbleUsed = true
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, BUBBLE_JUMP_SPEED, velocity.Z)
end)

local function dash(_, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local humanoid, root = humanoidAndRoot()
	if not humanoid or os.clock() - lastDash < DASH_COOLDOWN then
		return Enum.ContextActionResult.Sink
	end
	lastDash = os.clock()
	local direction = humanoid.MoveDirection.Magnitude > 0.1 and humanoid.MoveDirection or root.CFrame.LookVector
	local push = Instance.new("LinearVelocity")
	push.Attachment0 = root:FindFirstChild("RootAttachment")
	push.MaxForce = math.huge
	push.VectorVelocity = Vector3.new(direction.X, 0, direction.Z).Unit * DASH_SPEED
	push.Parent = root
	Debris:AddItem(push, DASH_TIME)
	return Enum.ContextActionResult.Sink
end

local function refreshGadgets()
	owned = {}
	for id in string.gmatch(player:GetAttribute("Gadgets") or "", "[^,]+") do
		owned[id] = true
	end
	ContextActionService:UnbindAction(DASH_ACTION)
	if owned.JetFins then
		ContextActionService:BindAction(DASH_ACTION, dash, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle(DASH_ACTION, "Dash")
	end
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end
player:GetAttributeChangedSignal("Gadgets"):Connect(refreshGadgets)
refreshGadgets()
