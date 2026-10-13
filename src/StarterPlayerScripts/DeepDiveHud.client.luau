-- Dive HUD: oxygen bar, floor and catch count, floor-cleared choices, end-of-dive summary and underwater lighting.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("DeepDive")
local Config = require(shared:WaitForChild("Config"))
local Remotes = shared:WaitForChild("Remotes")
local player = Players.LocalPlayer

local FONT = Enum.Font.GothamBold
local WHITE = Color3.new(1, 1, 1)
local SOFT_BLUE = Color3.fromRGB(180, 220, 255)
local OXYGEN_COLOR = Color3.fromRGB(80, 210, 255)
local LOW_OXYGEN_COLOR = Color3.fromRGB(255, 80, 80)
local LOW_OXYGEN = 15

local function make(className, props, children)
	local inst = Instance.new(className)
	for key, value in props do
		inst[key] = value
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

local function corner(radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local gui = make("ScreenGui", { Name = "DeepDiveHud", ResetOnSpawn = false })

-- Oxygen bar and dive info (top centre, only while diving)
local oxygenFill = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = OXYGEN_COLOR, BorderSizePixel = 0 }, { corner(6) })
local oxygenText = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = FONT, TextSize = 16, TextColor3 = WHITE, TextStrokeTransparency = 0.5, ZIndex = 2 })
local oxygenBar = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(320, 26),
	BackgroundColor3 = Color3.fromRGB(20, 40, 60),
	BorderSizePixel = 0,
	Visible = false,
}, { corner(6), oxygenFill, oxygenText })
oxygenBar.Parent = gui

local infoText = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 42),
	Size = UDim2.fromOffset(320, 22),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 16,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.5,
	Visible = false,
})
infoText.Parent = gui

-- Short messages (catches, hits, notices)
local toast = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.fromOffset(460, 30),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 22,
	TextColor3 = WHITE,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
})
toast.Parent = gui

local toastId = 0
local function showToast(text, color)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or WHITE
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(2, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- Centre panel, reused for the floor-cleared choice and the dive summary
local panel = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Color3.fromRGB(15, 35, 55),
	Visible = false,
}, {
	corner(12),
	make("UIPadding", { PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
	make("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
panel.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local function clearPanel()
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function addLabel(text, size, color, order)
	make("TextLabel", {
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = size,
		TextColor3 = color or WHITE,
		TextWrapped = true,
		Text = text,
		LayoutOrder = order,
	}).Parent = panel
end

local function addButton(text, color, order, onClick)
	local button = make("TextButton", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = color,
		Font = FONT,
		TextSize = 18,
		TextColor3 = WHITE,
		Text = text,
		LayoutOrder = order,
	}, { corner(8) })
	button.Activated:Connect(onClick)
	button.Parent = panel
end

local function showFloorCleared(info)
	clearPanel()
	local selected = nil
	addLabel(("Floor %d cleared!"):format(info.floor), 26, nil, 1)
	addLabel(("+%d oxygen. Dive deeper, or surface and keep every catch?"):format(info.oxygenGain), 15, SOFT_BLUE, 2)
	if #info.choices > 0 then
		addLabel("Pick a gadget for this dive:", 16, nil, 3)
		local row = make("Frame", { Size = UDim2.new(1, 0, 0, 92), BackgroundTransparency = 1, LayoutOrder = 4 }, {
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
		})
		local strokes = {}
		for _, choice in info.choices do
			local stroke = make("UIStroke", { Color = Color3.fromRGB(255, 220, 90), Thickness = 3, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
			strokes[choice.id] = stroke
			local card = make("TextButton", {
				Size = UDim2.new(1 / #info.choices, -8, 1, 0),
				BackgroundColor3 = Color3.fromRGB(40, 70, 100),
				Font = Enum.Font.Gotham,
				TextSize = 14,
				TextColor3 = WHITE,
				TextWrapped = true,
				Text = ("<b>%s</b>\n%s"):format(choice.name, choice.desc),
				RichText = true,
			}, { corner(8), stroke })
			card.Activated:Connect(function()
				selected = choice.id
				for id, s in strokes do
					s.Enabled = id == choice.id
				end
			end)
			card.Parent = row
		end
		row.Parent = panel
	end
	addButton("Dive deeper", Color3.fromRGB(30, 120, 200), 5, function()
		panel.Visible = false
		Remotes.DiveChoice:FireServer("deeper", selected)
	end)
	addButton("Surface (keep every catch)", Color3.fromRGB(40, 150, 90), 6, function()
		panel.Visible = false
		Remotes.DiveChoice:FireServer("surface", selected)
	end)
	panel.Visible = true
end

local SUMMARY_TITLES = {
	surfaced = "You surfaced safely!",
	outOfAir = "Out of air!",
	zoneCleared = "Sunlit Reef cleared!",
}

local function showSummary(summary)
	clearPanel()
	addLabel(SUMMARY_TITLES[summary.reason] or "Dive over", 26, nil, 1)
	addLabel(("Reached floor %d  ·  Best: %d"):format(summary.depth, summary.best), 16, SOFT_BLUE, 2)
	local names = {}
	for _, catch in summary.kept do
		table.insert(names, ("%s (%s)"):format(catch.name, catch.rarity))
	end
	addLabel(#names > 0 and "Kept: " .. table.concat(names, ", ") or "No catches this time.", 15, nil, 3)
	if summary.lost > 0 then
		addLabel(("Lost %d catch(es) when your air ran out."):format(summary.lost), 15, Color3.fromRGB(255, 150, 150), 4)
	end
	addLabel(("+%d pearls"):format(summary.pearls), 22, Color3.fromRGB(255, 230, 120), 5)
	addButton("Back to the harbor", Color3.fromRGB(30, 120, 200), 6, function()
		panel.Visible = false
	end)
	panel.Visible = true
end

local function updateHud()
	local diving = player:GetAttribute("Diving") == true
	oxygenBar.Visible = diving
	infoText.Visible = diving
	if not diving then
		return
	end
	local oxygen = player:GetAttribute("Oxygen") or 0
	local max = player:GetAttribute("OxygenMax") or Config.OXYGEN_MAX
	oxygenFill.Size = UDim2.fromScale(math.clamp(oxygen / max, 0, 1), 1)
	oxygenFill.BackgroundColor3 = oxygen <= LOW_OXYGEN and LOW_OXYGEN_COLOR or OXYGEN_COLOR
	oxygenText.Text = ("Oxygen %d"):format(oxygen)
	infoText.Text = ("Floor %d  ·  Catches %d"):format(player:GetAttribute("Floor") or 0, player:GetAttribute("BagCount") or 0)
end

-- Underwater look: the place uses an Atmosphere, so tint that (fog settings are ignored while one exists).
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local surfaceAtmosphere = atmosphere and { Density = atmosphere.Density, Color = atmosphere.Color, Decay = atmosphere.Decay, Haze = atmosphere.Haze, Glare = atmosphere.Glare }
local tint = make("ColorCorrectionEffect", { Name = "DeepDiveTint", Enabled = false })
tint.Parent = Lighting

local function updateWater()
	local diving = player:GetAttribute("Diving") == true
	local depth = math.clamp((player:GetAttribute("Floor") or 1) / Config.ZONE_FLOORS, 0, 1)
	tint.Enabled = diving
	tint.TintColor = Color3.fromRGB(170, 220, 255):Lerp(Color3.fromRGB(110, 150, 220), depth)
	tint.Brightness = -0.08 * depth
	if not atmosphere then
		return
	end
	if diving then
		atmosphere.Density = 0.45 + 0.25 * depth
		atmosphere.Color = Color3.fromRGB(40, 140, 200):Lerp(Color3.fromRGB(10, 40, 80), depth)
		atmosphere.Decay = Color3.fromRGB(20, 80, 130):Lerp(Color3.fromRGB(5, 20, 45), depth)
		atmosphere.Haze = 2
		atmosphere.Glare = 0
	else
		for key, value in surfaceAtmosphere do
			atmosphere[key] = value
		end
	end
end

for _, attribute in { "Diving", "Oxygen", "OxygenMax", "Floor", "BagCount" } do
	player:GetAttributeChangedSignal(attribute):Connect(updateHud)
end
player:GetAttributeChangedSignal("Diving"):Connect(updateWater)
player:GetAttributeChangedSignal("Floor"):Connect(updateWater)
updateHud()

Remotes.DiveEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "Caught" then
		showToast(("Caught a %s! (%s)"):format(info.name, info.rarity), Config.Rarities[info.rarity].color)
	elseif kind == "Hit" then
		showToast(("Ouch! -%d oxygen"):format(info.cost), Color3.fromRGB(255, 120, 120))
	elseif kind == "Notice" then
		showToast(info.text)
	elseif kind == "DiveStarted" then
		panel.Visible = false
		showToast("Dive! Reach the glowing gate before your air runs out.")
	elseif kind == "FloorCleared" then
		showFloorCleared(info)
	elseif kind == "DiveEnded" then
		showSummary(info)
	end
end)
