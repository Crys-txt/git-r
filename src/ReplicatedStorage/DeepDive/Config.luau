-- Tuning values for the Deep Dive prototype (see docs/game-design.md).
-- Content lives in plain tables so new creatures, equipment, tiers or wings are a data change, not a code change.
local Config = {}

Config.OXYGEN_START = 60
Config.OXYGEN_MAX = 120
Config.OXYGEN_PER_FLOOR = 8
Config.HAZARD_OXYGEN_COST = 10
Config.KEEP_ON_FAIL = 0.5 -- share of catches kept when you run out of air, rarest first
Config.ZONE_FLOORS = 8 -- clearing this many floors clears the Sunlit Reef
Config.ZONE_CLEAR_BONUS = 10 -- pearls
Config.WALK_SPEED = 16 -- on land
Config.SWIM_SPEED = 16 -- base Humanoid.WalkSpeed during a dive; fins add to it
Config.HARPOON_COOLDOWN = 0.8
Config.DIVE_ORIGIN = Vector3.new(0, 200, 1500)
Config.SLOT_SPACING = 500
Config.FISH_PER_TANK = 12

Config.Rarities = {
	Common = { weight = 70, sellPrice = 2, order = 1, color = Color3.fromRGB(220, 220, 220) },
	Rare = { weight = 22, sellPrice = 6, order = 2, color = Color3.fromRGB(80, 150, 255) },
	Epic = { weight = 7, sellPrice = 15, order = 3, color = Color3.fromRGB(190, 90, 255) },
	Legendary = { weight = 1, sellPrice = 60, order = 4, color = Color3.fromRGB(255, 190, 40) },
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

-- Equipment sold at the Dive Shop. Each purchase moves you to the next tier; only your current tier's
-- `stats` apply. Stat names are defined in Stats.BASE.
Config.Equipment = {
	{
		id = "Tank",
		name = "Air Tank",
		tiers = {
			{ name = "Steel Tank", price = 20, desc = "+20 oxygen per dive", stats = { oxygen = 20 } },
			{ name = "Twin Tanks", price = 60, desc = "+40 oxygen per dive", stats = { oxygen = 40 } },
			{ name = "Rebreather", price = 150, desc = "+70 oxygen per dive", stats = { oxygen = 70 } },
		},
	},
	{
		id = "Fins",
		name = "Fins",
		tiers = {
			{ name = "Rubber Fins", price = 25, desc = "Swim 25% faster", stats = { swimSpeed = 4 } },
			{ name = "Pro Fins", price = 70, desc = "Swim 50% faster", stats = { swimSpeed = 8 } },
			{ name = "Mermaid Fins", price = 160, desc = "Swim 80% faster", stats = { swimSpeed = 13 } },
		},
	},
	{
		id = "Harpoon",
		name = "Harpoon",
		tiers = {
			{ name = "Hand Spear", price = 30, desc = "Catch from 12 studs away (F)", stats = { harpoonRange = 12 } },
			{ name = "Spear Gun", price = 80, desc = "Catch from 22 studs away (F)", stats = { harpoonRange = 22 } },
			{ name = "Pneumatic Harpoon", price = 180, desc = "Catch from 35 studs away (F)", stats = { harpoonRange = 35 } },
		},
	},
}

-- Unlocked in order; each adds a tank to your aquarium and its `stats` to every dive.
Config.Wings = {
	{ id = "ReefTank", name = "Reef Tank", cost = 0, stats = {} },
	{ id = "ShipwreckHall", name = "Shipwreck Hall", cost = 25, stats = { oxygen = 10 } },
	{ id = "JellyfishDome", name = "Jellyfish Dome", cost = 75, stats = { oxygen = 20 } },
}

local creaturesById = {}
for _, creature in Config.Creatures do
	creaturesById[creature.id] = creature
end

local equipmentById = {}
for _, item in Config.Equipment do
	equipmentById[item.id] = item
end

function Config.getCreature(id)
	return creaturesById[id]
end

function Config.getEquipment(id)
	return equipmentById[id]
end

function Config.rarityOrder(id)
	local creature = creaturesById[id]
	return creature and Config.Rarities[creature.rarity].order or 0
end

return Config
