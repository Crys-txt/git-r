-- Helpers for building UI in code, shared by the client scripts so every window looks the same.
local Ui = {}

Ui.FONT = Enum.Font.GothamBold
Ui.BODY_FONT = Enum.Font.Gotham
Ui.WHITE = Color3.new(1, 1, 1)
Ui.SOFT_BLUE = Color3.fromRGB(180, 220, 255)
Ui.PANEL = Color3.fromRGB(15, 35, 55)
Ui.ROW = Color3.fromRGB(30, 55, 80)
Ui.BLUE = Color3.fromRGB(30, 120, 200)
Ui.GREEN = Color3.fromRGB(40, 150, 90)
Ui.GREY = Color3.fromRGB(70, 80, 90)
Ui.RED = Color3.fromRGB(255, 130, 130)
Ui.GOLD = Color3.fromRGB(255, 230, 120)

function Ui.make(className, props, children)
	local inst = Instance.new(className)
	for key, value in props or {} do
		inst[key] = value
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	return inst
end

function Ui.corner(radius)
	return Ui.make("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

function Ui.padding(pixels)
	local offset = UDim.new(0, pixels)
	return Ui.make("UIPadding", { PaddingTop = offset, PaddingBottom = offset, PaddingLeft = offset, PaddingRight = offset })
end

-- Full-width text that grows to fit; override anything through props.
function Ui.label(text, props)
	local label = Ui.make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.FONT,
		TextSize = 16,
		TextColor3 = Ui.WHITE,
		TextWrapped = true,
		Text = text,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	for key, value in props or {} do
		label[key] = value
	end
	return label
end

function Ui.button(text, color, onClick, props)
	local button = Ui.make("TextButton", {
		BackgroundColor3 = color,
		Font = Ui.FONT,
		TextSize = 18,
		TextColor3 = Ui.WHITE,
		Text = text,
		Size = UDim2.new(1, 0, 0, 44),
	}, { Ui.corner(8) })
	for key, value in props or {} do
		button[key] = value
	end
	button.Activated:Connect(onClick)
	return button
end

return Ui
