-- Dive Shop window: sell catches for pearls and buy equipment. Opens when you talk to the shopkeeper.
-- Equipment rows come straight from Config.Equipment, so new items and tiers show up without UI changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shared = ReplicatedStorage:WaitForChild("DeepDive")
local Config = require(shared:WaitForChild("Config"))
local Ui = require(shared:WaitForChild("Ui"))
local Remotes = shared:WaitForChild("Remotes")
local player = Players.LocalPlayer
local shopDome = workspace:WaitForChild("Harbor"):WaitForChild("ShopDome")
local counter = shopDome:WaitForChild("Counter")
local prompt = shopDome:WaitForChild("Shopkeeper"):WaitForChild("HumanoidRootPart"):WaitForChild("ShopPrompt")

local CLOSE_DISTANCE = 20

local state = { pearls = 0, catches = {}, equipment = {} }
local tab = "sell"
local render

local gui = Ui.make("ScreenGui", { Name = "DeepDiveShop", ResetOnSpawn = false, Enabled = false })
local window = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.9, 0.8),
	BackgroundColor3 = Ui.PANEL,
	Parent = gui,
}, { Ui.corner(12), Ui.padding(14), Ui.make("UISizeConstraint", { MaxSize = Vector2.new(560, 460) }) })

Ui.label("DIVE SHOP", { Size = UDim2.new(0.5, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.None, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = window })
local pearlsLabel = Ui.label("", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -44, 0, 0),
	Size = UDim2.new(0.4, 0, 0, 28),
	AutomaticSize = Enum.AutomaticSize.None,
	TextColor3 = Ui.GOLD,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = window,
})
Ui.button("X", Ui.GREY, function()
	gui.Enabled = false
end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(32, 28), Parent = window })

local tabButtons = {}
for index, info in { { id = "sell", text = "Sell catches" }, { id = "equipment", text = "Equipment" } } do
	tabButtons[info.id] = Ui.button(info.text, Ui.GREY, function()
		tab = info.id
		render()
	end, { Position = UDim2.new((index - 1) * 0.5, index == 1 and 0 or 4, 0, 36), Size = UDim2.new(0.5, -4, 0, 34), TextSize = 16, Parent = window })
end

local list = Ui.make("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 80),
	Size = UDim2.new(1, 0, 1, -112),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	Parent = window,
}, { Ui.make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local status = Ui.label("", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 24),
	AutomaticSize = Enum.AutomaticSize.None,
	TextSize = 15,
	Parent = window,
})
gui.Parent = player:WaitForChild("PlayerGui")

local function request(action, ...)
	local result = Remotes.ShopRequest:InvokeServer(action, ...)
	if result.state then
		state = result.state
	end
	status.Text = result.message or ""
	status.TextColor3 = result.ok and Ui.GOLD or Ui.RED
	render()
end

-- One row: a title and subtitle on the left, buttons on the right.
local function row(order, title, subtitle, subtitleColor, buttons)
	local frame = Ui.make("Frame", { Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = Ui.ROW, LayoutOrder = order, Parent = list }, { Ui.corner(8) })
	local buttonsWidth = #buttons * 88
	Ui.label(title, { Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -buttonsWidth - 20, 0, 20), AutomaticSize = Enum.AutomaticSize.None, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	Ui.label(subtitle, { Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -buttonsWidth - 20, 0, 18), AutomaticSize = Enum.AutomaticSize.None, Font = Ui.BODY_FONT, TextSize = 14, TextColor3 = subtitleColor or Ui.SOFT_BLUE, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	for index, info in buttons do
		Ui.button(info.text, info.color, info.onClick, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8 - (#buttons - index) * 88, 0.5, 0),
			Size = UDim2.fromOffset(80, 36),
			TextSize = 14,
			Parent = frame,
		})
	end
end

local function renderSell()
	local owned = {}
	for id, count in state.catches do
		local creature = Config.getCreature(id)
		if creature and count > 0 then
			table.insert(owned, { creature = creature, count = count })
		end
	end
	table.sort(owned, function(a, b)
		return Config.Rarities[a.creature.rarity].order > Config.Rarities[b.creature.rarity].order
	end)
	if #owned == 0 then
		Ui.label("No catches to sell yet. Dive and bring some back!", { TextColor3 = Ui.SOFT_BLUE, Parent = list })
		return
	end
	for order, entry in owned do
		local creature, rarity = entry.creature, Config.Rarities[entry.creature.rarity]
		row(order, ("%s  x%d"):format(creature.name, entry.count), ("%s · %d pearls each"):format(creature.rarity, rarity.sellPrice), rarity.color, {
			{ text = "Sell 1", color = Ui.BLUE, onClick = function()
				request("sell", creature.id, 1)
			end },
			{ text = "Sell all", color = Ui.GREEN, onClick = function()
				request("sell", creature.id, entry.count)
			end },
		})
	end
end

local function renderEquipment()
	for order, item in Config.Equipment do
		local level = state.equipment[item.id] or 0
		local current, nextTier = item.tiers[level], item.tiers[level + 1]
		local title = ("%s: %s"):format(item.name, current and current.name or "none")
		if nextTier then
			local affordable = state.pearls >= nextTier.price
			row(order, title, ("Next: %s · %s"):format(nextTier.name, nextTier.desc), nil, {
				{ text = ("Buy %d"):format(nextTier.price), color = affordable and Ui.GREEN or Ui.GREY, onClick = function()
					request("buy", item.id)
				end },
			})
		else
			row(order, title, "Maxed out", Ui.GOLD, {})
		end
	end
end

function render()
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	pearlsLabel.Text = ("%d pearls"):format(state.pearls)
	for id, button in tabButtons do
		button.BackgroundColor3 = id == tab and Ui.BLUE or Ui.GREY
	end
	if tab == "sell" then
		renderSell()
	else
		renderEquipment()
	end
end

prompt.Triggered:Connect(function()
	tab = "sell"
	status.Text = ""
	gui.Enabled = true
	request("state")
end)

-- Close the window when you walk away from the counter.
task.spawn(function()
	while true do
		task.wait(0.5)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if gui.Enabled and (not root or (root.Position - counter.Position).Magnitude > CLOSE_DISTANCE) then
			gui.Enabled = false
		end
	end
end)
