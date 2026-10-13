-- Dive HUD: oxygen bar, floor and catch count, floor-cleared choice, end-of-dive summary and underwater tint.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("DeepDive")
local Config = require(shared:WaitForChild("Config"))
local Ui = require(shared:WaitForChild("Ui"))
local Remotes = shared:WaitForChild("Remotes")
local player = Players.LocalPlayer

local OXYGEN_COLOR = Color3.fromRGB(80, 210, 255)
local LOW_OXYGEN_COLOR = Color3.fromRGB(255, 80, 80)
local LOW_OXYGEN = 15

local gui = Ui.make("ScreenGui", { Name = "DeepDiveHud", ResetOnSpawn = false })

-- Oxygen bar and dive info (top centre, only while diving)
local oxygenFill = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = OXYGEN_COLOR, BorderSizePixel = 0 }, { Ui.corner(6) })
local oxygenText = Ui.label("", { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, TextStrokeTransparency = 0.5, ZIndex = 2 })
local oxygenBar = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(320, 26),
	BackgroundColor3 = Color3.fromRGB(20, 40, 60),
	BorderSizePixel = 0,
	Visible = false,
	Parent = gui,
}, { Ui.corner(6), oxygenFill, oxygenText })

local infoText = Ui.label("", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 42),
	Size = UDim2.fromOffset(320, 22),
	AutomaticSize = Enum.AutomaticSize.None,
	TextStrokeTransparency = 0.5,
	Visible = false,
	Parent = gui,
})

-- Short messages (catches, hits, notices)
local toast = Ui.label("", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.fromOffset(460, 30),
	AutomaticSize = Enum.AutomaticSize.None,
	TextSize = 22,
	TextStrokeTransparency = 1,
	TextTransparency = 1,
	Parent = gui,
})

local toastId = 0
local function showToast(text, color)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or Ui.WHITE
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(2, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

-- Centre panel, reused for the floor-cleared choice and the dive summary
local panel = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Ui.PANEL,
	Visible = false,
	Parent = gui,
}, {
	Ui.corner(12),
	Ui.padding(16),
	Ui.make("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
gui.Parent = player:WaitForChild("PlayerGui")

local function showPanel(rows)
	for _, child in panel:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, row in rows do
		row.LayoutOrder = order
		row.Parent = panel
	end
	panel.Visible = true
end

local function hidePanel()
	panel.Visible = false
end

local function showFloorCleared(info)
	showPanel({
		Ui.label(("Floor %d cleared!"):format(info.floor), { TextSize = 26 }),
		Ui.label(("+%d oxygen. Dive deeper, or surface and keep every catch?"):format(info.oxygenGain), { TextSize = 15, TextColor3 = Ui.SOFT_BLUE }),
		Ui.button("Dive deeper", Ui.BLUE, function()
			hidePanel()
			Remotes.DiveChoice:FireServer("deeper")
		end),
		Ui.button("Surface (keep every catch)", Ui.GREEN, function()
			hidePanel()
			Remotes.DiveChoice:FireServer("surface")
		end),
	})
end

local SUMMARY_TITLES = {
	surfaced = "You surfaced safely!",
	outOfAir = "Out of air!",
	zoneCleared = "Sunlit Reef cleared!",
}

local function showSummary(summary)
	local names = {}
	for _, catch in summary.kept do
		table.insert(names, ("%s (%s)"):format(catch.name, catch.rarity))
	end
	local rows = {
		Ui.label(SUMMARY_TITLES[summary.reason] or "Dive over", { TextSize = 26 }),
		Ui.label(("Reached floor %d  ·  Best: %d"):format(summary.depth, summary.best), { TextColor3 = Ui.SOFT_BLUE }),
		Ui.label(#names > 0 and "Kept: " .. table.concat(names, ", ") or "No catches this time.", { TextSize = 15 }),
	}
	if summary.lost > 0 then
		table.insert(rows, Ui.label(("Lost %d catch(es) when your air ran out."):format(summary.lost), { TextSize = 15, TextColor3 = Ui.RED }))
	end
	if summary.pearls > 0 then
		table.insert(rows, Ui.label(("+%d pearls reef bonus"):format(summary.pearls), { TextSize = 20, TextColor3 = Ui.GOLD }))
	end
	if #names > 0 then
		table.insert(rows, Ui.label("Sell catches for pearls at the Dive Shop by the spawn.", { TextSize = 15, TextColor3 = Ui.GOLD }))
	end
	table.insert(rows, Ui.button("Back to the harbor", Ui.BLUE, hidePanel))
	showPanel(rows)
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
	local hint = (player:GetAttribute("HarpoonRange") or 0) > 0 and "  ·  F: harpoon" or ""
	infoText.Text = ("Floor %d  ·  Catches %d%s"):format(player:GetAttribute("Floor") or 0, player:GetAttribute("BagCount") or 0, hint)
end

-- Deeper floors get darker. Terrain water already adds the underwater fog.
local tint = Ui.make("ColorCorrectionEffect", { Name = "DeepDiveTint", Enabled = false, Parent = Lighting })
local function updateTint()
	local depth = math.clamp((player:GetAttribute("Floor") or 1) / Config.ZONE_FLOORS, 0, 1)
	tint.Enabled = player:GetAttribute("Diving") == true
	tint.TintColor = Color3.fromRGB(200, 230, 255):Lerp(Color3.fromRGB(120, 160, 220), depth)
	tint.Brightness = -0.1 * depth
end

for _, attribute in { "Diving", "Oxygen", "OxygenMax", "Floor", "BagCount", "HarpoonRange" } do
	player:GetAttributeChangedSignal(attribute):Connect(updateHud)
end
player:GetAttributeChangedSignal("Diving"):Connect(updateTint)
player:GetAttributeChangedSignal("Floor"):Connect(updateTint)
updateHud()

Remotes.DiveEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "Caught" then
		showToast(("Caught a %s! (%s)"):format(info.name, info.rarity), Config.Rarities[info.rarity].color)
	elseif kind == "Hit" then
		showToast(("Ouch! -%d oxygen"):format(info.cost), Color3.fromRGB(255, 120, 120))
	elseif kind == "Notice" then
		showToast(info.text)
	elseif kind == "DiveStarted" then
		hidePanel()
		showToast("Swim to the glowing gate before your air runs out!")
	elseif kind == "FloorCleared" then
		showFloorCleared(info)
	elseif kind == "DiveEnded" then
		showSummary(info)
	end
end)
