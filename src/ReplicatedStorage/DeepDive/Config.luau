-- Tuning values for the Deep Dive prototype (see docs/game-design.md).
local Config = {}

Config.OXYGEN_START = 60
Config.OXYGEN_PER_FLOOR = 8
Config.OXYGEN_MAX = 120
Config.HAZARD_OXYGEN_COST = 10
Config.KEEP_ON_FAIL = 0.5 -- share of catches kept when you run out of air, rarest first
Config.ZONE_FLOORS = 8 -- clearing this many floors clears the Sunlit Reef
Config.ZONE_CLEAR_BONUS = 10 -- pearls
Config.GADGET_PICK_FLOORS = { [1] = true, [3] = true, [5] = true }
Config.AIR_TANK_BONUS = 25
Config.DIVE_ORIGIN = Vector3.new(0, 200, 1500)
Config.SLOT_SPACING = 500
Config.FISH_PER_TANK = 12

Config.Rarities = {
	Common = { weight = 70, pearls = 1, order = 1, color = Color3.fromRGB(220, 220, 220) },
	Rare = { weight = 22, pearls = 3, order = 2, color = Color3.fromRGB(80, 150, 255) },
	Epic = { weight = 7, pearls = 8, order = 3, color = Color3.fromRGB(190, 90, 255) },
	Legendary = { weight = 1, pearls = 25, order = 4, color = Color3.fromRGB(255, 190, 40) },
}

Config.Creatures = {
	{ id = "Clownfish", name = "Clownfish", rarity = "Common", color = Color3.fromRGB(255, 120, 30) },
	{ id = "BlueTang", name = "Blue Tang", rarity = "Common", color = Color3.fromRGB(40, 90, 255) },
	{ id = "Starfish", name = "Starfish", rarity = "Common", color = Color3.fromRGB(255, 90, 120) },
	{ id = "Seahorse", name = "Seahorse", rarity = "Rare", color = Color3.fromRGB(255, 220, 80) },
	{ id = "Pufferfish", name = "Pufferfish", rarity = "Rare", color = Color3.fromRGB(230, 200, 140) },
	{ id = "SeaTurtle", name = "Sea Turtle", rarity = "Epic", color = Color3.fromRGB(60, 170, 90) },
	{ id = "GoldenOyster", name = "Golden Oyster", rarity = "Epic", color = Color3.fromRGB(255, 215, 0) },
	{ id = "RainbowManta", name = "Rainbow Manta", rarity = "Legendary", color = Color3.fromRGB(255, 255, 255) },
}

Config.Gadgets = {
	BubbleJump = { name = "Bubble Jump", desc = "Jump again in mid-air" },
	JetFins = { name = "Jet Fins", desc = "Press Q (or the Dash button) to dash" },
	AirTank = { name = "Spare Air Tank", desc = "+25 oxygen right now" },
}

-- Unlocked in order; each adds a tank to your aquarium and oxygen to every dive.
Config.Wings = {
	{ id = "ReefTank", name = "Reef Tank", cost = 0, bonusOxygen = 0 },
	{ id = "ShipwreckHall", name = "Shipwreck Hall", cost = 25, bonusOxygen = 10 },
	{ id = "JellyfishDome", name = "Jellyfish Dome", cost = 75, bonusOxygen = 20 },
}

local creaturesById = {}
for _, creature in Config.Creatures do
	creaturesById[creature.id] = creature
end

function Config.getCreature(id)
	return creaturesById[id]
end

function Config.rarityOrder(id)
	local creature = creaturesById[id]
	return creature and Config.Rarities[creature.rarity].order or 0
end

return Config
