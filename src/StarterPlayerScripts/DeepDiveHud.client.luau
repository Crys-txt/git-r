-- Dive HUD and feel: oxygen bar, depth and zone, toasts, end-of-dive summary, depth lighting, head lamp,
-- breathing bubbles, underwater ambience, and the low-oxygen / drowning effects (darkening, blur, heartbeat,
-- bubble burst, blackout).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local shared = ReplicatedStorage:WaitForChild("DeepDive")
local Config = require(shared:WaitForChild("Config"))
local Ui = require(shared:WaitForChild("Ui"))
local Remotes = shared:WaitForChild("Remotes")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local OXYGEN_COLOR = Color3.fromRGB(80, 210, 255)
local LOW_OXYGEN_COLOR = Color3.fromRGB(255, 80, 80)
local DANGER_SHARE = 0.3 -- below this share of max oxygen the screen starts closing in
local BREATH_INTERVAL = { 3.5, 5.5 } -- seconds between breathing bubbles while diving

local function attr(name, default)
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

---------------------------------------------------------------- sounds
-- Everything plays through one group so being underwater can muffle it all.
local ocean = Ui.make("SoundGroup", { Name = "DeepDiveOcean", Parent = SoundService })
local muffle = Ui.make("EqualizerSoundEffect", { HighGain = -20, MidGain = -6, LowGain = 2, Enabled = false, Parent = ocean })
local function sound(id, volume, looped)
	return Ui.make("Sound", { SoundId = id, Volume = volume, Looped = looped or false, SoundGroup = ocean, Parent = SoundService })
end
local ambience = sound(Config.Sounds.Ambience, 0.35, true)
local heartbeat = sound(Config.Sounds.Heartbeat, 0, true)
local bubbles = sound(Config.Sounds.Bubbles, 0.5)
local drownBubbles = sound(Config.Sounds.DrownBubbles, 0.9)
local gasp = sound(Config.Sounds.Gasp, 0.7)
ambience:Play()

local function playOnce(source, pitch)
	local copy = source:Clone()
	copy.PlaybackSpeed = pitch or (0.9 + math.random() * 0.2)
	copy.Parent = SoundService
	copy:Play()
	copy.Ended:Once(function()
		copy:Destroy()
	end)
end

---------------------------------------------------------------- screen effects
local depthTint = Ui.make("ColorCorrectionEffect", { Name = "DeepDiveDepth", Parent = Lighting })
local danger = Ui.make("ColorCorrectionEffect", { Name = "DeepDiveDanger", Parent = Lighting })
local blur = Ui.make("BlurEffect", { Name = "DeepDiveBlur", Size = 0, Parent = Lighting })

local gui = Ui.make("ScreenGui", { Name = "DeepDiveHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 })
-- Dark overlay used for low oxygen and the drowning blackout.
local darkness = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 0, Parent = gui })
local blackoutText = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(500, 40), AutomaticSize = Enum.AutomaticSize.None, TextSize = 28, TextTransparency = 1, ZIndex = 1, Parent = darkness })

---------------------------------------------------------------- HUD
local oxygenFill = Ui.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = OXYGEN_COLOR, BorderSizePixel = 0 }, { Ui.corner(6) })
local oxygenText = Ui.label("", { Size = UDim2.fromScale(1, 1), AutomaticSize = Enum.AutomaticSize.None, TextStrokeTransparency = 0.5, ZIndex = 3 })
local oxygenBar = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.fromOffset(320, 26),
	BackgroundColor3 = Color3.fromRGB(20, 40, 60),
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 2,
	Parent = gui,
}, { Ui.corner(6), oxygenFill, oxygenText })
oxygenFill.ZIndex = 2
local infoText = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(420, 22), AutomaticSize = Enum.AutomaticSize.None, TextStrokeTransparency = 0.5, Visible = false, ZIndex = 2, Parent = gui })
local toast = Ui.label("", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(500, 30), AutomaticSize = Enum.AutomaticSize.None, TextSize = 22, TextStrokeTransparency = 1, TextTransparency = 1, ZIndex = 2, Parent = gui })

local toastId = 0
local function showToast(text, color)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = color or Ui.WHITE
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.3
	task.delay(2.5, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

local panel = Ui.make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(440, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = Ui.PANEL,
	Visible = false,
	ZIndex = 4,
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
		row.ZIndex = 5
		row.Parent = panel
	end
	panel.Visible = true
end

local SUMMARY_TITLES = { surfaced = "You surfaced safely!", outOfAir = "You blacked out..." }

local function showSummary(summary)
	local names = {}
	for _, catch in summary.kept do
		table.insert(names, ("%s (%s)"):format(catch.name, catch.rarity))
	end
	local rows = {
		Ui.label(SUMMARY_TITLES[summary.reason] or "Dive over", { TextSize = 26 }),
		Ui.label(("Deepest point: %d m  ·  Record: %d m"):format(summary.depth, summary.best), { TextColor3 = Ui.SOFT_BLUE }),
		Ui.label(#names > 0 and "Brought back: " .. table.concat(names, ", ") or "No catches this time.", { TextSize = 15 }),
	}
	if summary.lost > 0 then
		table.insert(rows, Ui.label(("Lost %d catch(es) when you blacked out."):format(summary.lost), { TextSize = 15, TextColor3 = Ui.RED }))
	end
	if #summary.newSpecies > 0 then
		table.insert(rows, Ui.label("New in your aquarium: " .. table.concat(summary.newSpecies, ", "), { TextSize = 16, TextColor3 = Ui.GOLD }))
	end
	if summary.pearls > 0 then
		table.insert(rows, Ui.label(("+%d pearls depth bonus"):format(summary.pearls), { TextSize = 20, TextColor3 = Ui.GOLD }))
	end
	table.insert(rows, Ui.label("Sell extra catches to Marina at the Dive Shop.", { TextSize = 14, TextColor3 = Ui.SOFT_BLUE }))
	table.insert(rows, Ui.button("Continue", Ui.BLUE, function()
		panel.Visible = false
	end))
	showPanel(rows)
end

local function updateHud()
	local diving = attr("Diving", false)
	oxygenBar.Visible = diving
	infoText.Visible = diving
	if not diving then
		return
	end
	local oxygen, max = attr("Oxygen", 0), attr("OxygenMax", Config.OXYGEN_MAX)
	local share = math.clamp(oxygen / max, 0, 1)
	oxygenFill.Size = UDim2.fromScale(share, 1)
	oxygenFill.BackgroundColor3 = share <= DANGER_SHARE and LOW_OXYGEN_COLOR or OXYGEN_COLOR
	oxygenText.Text = ("Oxygen %d%s"):format(math.ceil(oxygen), attr("Sprinting", false) and "  (sprinting)" or "")
	local meters = attr("Depth", 0)
	local hints = (attr("HarpoonRange", 0) > 0) and "  ·  F harpoon" or ""
	infoText.Text = ("%d m  ·  %s  ·  Catches %d  ·  Shift sprint%s"):format(meters, Config.zoneAt(meters).name, attr("BagCount", 0), hints)
end

for _, name in { "Diving", "Oxygen", "OxygenMax", "Depth", "BagCount", "HarpoonRange", "Sprinting" } do
	player:GetAttributeChangedSignal(name):Connect(updateHud)
end
updateHud()

---------------------------------------------------------------- character effects (lamp, bubbles)
local lamp, breath
local function onCharacter(character)
	local head = character:WaitForChild("Head")
	lamp = Ui.make("PointLight", { Name = "DiveLamp", Color = Color3.fromRGB(220, 240, 255), Brightness = 1.6, Shadows = true, Enabled = false, Parent = head })
	breath = Ui.make("ParticleEmitter", {
		Name = "Breath",
		Texture = Config.BUBBLE_TEXTURE,
		Rate = 0,
		Lifetime = NumberRange.new(1.2, 2),
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 6, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.45) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 0.3,
		Parent = head,
	})
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

local function cameraInWater()
	local position = camera.CFrame.Position
	local region = Region3.new(position - Vector3.new(2, 2, 2), position + Vector3.new(2, 2, 2)):ExpandToGrid(4)
	local materials = workspace.Terrain:ReadVoxels(region, 4)
	return materials[1][1][1] == Enum.Material.Water
end

local blackedOut = false
local nextBreath = 0
local waterCheck = 0
local underwater = true

RunService.RenderStepped:Connect(function(dt)
	local diving = attr("Diving", false)
	local meters = attr("Depth", 0)

	-- Light fades with depth; the zone sets how dark it gets.
	local zone = Config.zoneAt(diving and meters or 0)
	local darknessLevel = diving and zone.darkness or 0
	depthTint.TintColor = Color3.fromRGB(235, 245, 255):Lerp(Color3.fromRGB(110, 140, 210), darknessLevel)
	depthTint.Brightness = -0.3 * darknessLevel
	depthTint.Contrast = 0.1 * darknessLevel
	if lamp then
		lamp.Enabled = diving and meters > 15
		lamp.Range = attr("LampRange", 24)
	end

	-- Low oxygen: the screen darkens, blurs and loses colour while the heartbeat gets louder.
	local share = diving and math.clamp(attr("Oxygen", 0) / attr("OxygenMax", 1), 0, 1) or 1
	local fear = math.clamp(1 - share / DANGER_SHARE, 0, 1)
	local pulse = fear > 0 and (0.5 + 0.5 * math.sin(os.clock() * (4 + fear * 6))) or 0
	danger.Saturation = -0.7 * fear
	danger.Brightness = -0.15 * fear
	blur.Size = 10 * fear + 4 * fear * pulse
	if not blackedOut then
		darkness.BackgroundTransparency = 1 - (0.45 * fear + 0.1 * fear * pulse)
	end
	heartbeat.Volume = 0.8 * fear
	if fear > 0 and not heartbeat.IsPlaying then
		heartbeat:Play()
	elseif fear == 0 and heartbeat.IsPlaying then
		heartbeat:Stop()
	end

	-- Breathing bubbles: more often when sprinting or short of air.
	if breath then
		breath.Rate = diving and (2 + (attr("Sprinting", false) and 4 or 0) + fear * 8) or 0
	end
	if diving and os.clock() > nextBreath then
		local interval = BREATH_INTERVAL[1] + (BREATH_INTERVAL[2] - BREATH_INTERVAL[1]) * math.random()
		nextBreath = os.clock() + interval * (1 - 0.6 * fear)
		local quiet = bubbles:Clone()
		quiet.Volume = 0.25 + 0.3 * fear
		quiet.Parent = SoundService
		quiet:Play()
		quiet.Ended:Once(function()
			quiet:Destroy()
		end)
		if breath then
			breath:Emit(6)
		end
	end

	-- Inside an air dome the ocean is quieter and clearer.
	waterCheck -= dt
	if waterCheck <= 0 then
		waterCheck = 0.4
		underwater = cameraInWater()
		muffle.Enabled = underwater
		ambience.Volume = underwater and 0.35 or 0.1
	end
end)

---------------------------------------------------------------- events
local function blackout(text)
	blackedOut = true
	blackoutText.Text = text
	TweenService:Create(darkness, TweenInfo.new(1.2), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(blackoutText, TweenInfo.new(1.2), { TextTransparency = 0 }):Play()
end

local function wakeUp()
	if not blackedOut then
		return
	end
	blackedOut = false
	TweenService:Create(darkness, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(blackoutText, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	playOnce(gasp)
end

Remotes.DiveEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "Caught" then
		showToast(("Caught a %s! (%s)"):format(info.name, info.rarity), Config.Rarities[info.rarity].color)
		playOnce(bubbles, 1.3)
	elseif kind == "Bubble" then
		showToast(("+%d oxygen"):format(info.amount), OXYGEN_COLOR)
		playOnce(bubbles, 0.8)
	elseif kind == "Hit" then
		showToast(("Ouch! -%d oxygen"):format(info.cost), Color3.fromRGB(255, 120, 120))
		playOnce(bubbles, 0.7)
		if breath then
			breath:Emit(20)
		end
	elseif kind == "Notice" then
		showToast(info.text)
	elseif kind == "DiveStarted" then
		panel.Visible = false
		showToast("Diving! Swim back up out of the trench to bank your catches.")
	elseif kind == "Drowned" then
		playOnce(drownBubbles, 1)
		if breath then
			breath:Emit(60)
		end
		blackout("You ran out of air...")
	elseif kind == "DiveEnded" then
		if info.reason == "surfaced" then
			playOnce(gasp)
		end
		wakeUp()
		showSummary(info)
	end
end)
