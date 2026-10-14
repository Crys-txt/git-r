-- Tuning values for Deep Dive (see docs/game-design.md).
-- Content lives in plain tables so new creatures, equipment, tiers, wings, zones or sounds are a data change.
local Config = {}

-- Oxygen (only drains while diving)
Config.OXYGEN_START = 60
Config.OXYGEN_MAX = 120
Config.HAZARD_OXYGEN_COST = 10
Config.AIR_BUBBLE_OXYGEN = 12
Config.KEEP_ON_FAIL = 0.5 -- share of catches kept when you drown, rarest first

-- Movement
Config.SWIM_SPEED = 16 -- Humanoid.WalkSpeed in the hub and the trench; fins add to it
Config.SPRINT_MULTIPLIER = 1.6 -- sprinting is this much faster AND drains oxygen this much faster,
-- so oxygen spent per stud travelled stays the same
Config.HARPOON_COOLDOWN = 0.8

-- The trench: an endless vertical shaft under the hub, built in chunks as divers go down
Config.TRENCH_RADIUS = 22 -- open water radius
Config.TRENCH_WALL_RADIUS = 34 -- rock shell around it
Config.TRENCH_TOP_Y = -16 -- bottom of the seafloor sand, where chunk 0 starts
Config.CHUNK_HEIGHT = 80
Config.CHUNKS_AHEAD = 2 -- chunks kept loaded below (and above) every diver
Config.DIVE_START_Y = -12 -- below this, inside the trench, you are diving
Config.SURFACE_Y = -4 -- back above this, you have surfaced
Config.STUDS_PER_METER = 3
Config.TRENCH_SEED = nil -- set a number for a fixed layout (e.g. a weekly seed); nil = random per server
Config.CATCH_RESPAWN = 60 -- seconds before a caught spot refills (catches are shared)
Config.BUBBLE_RESPAWN = 25 -- seconds before an air bubble refills, per player
Config.DEPTH_PEARLS_PER_10M = 1 -- surfacing pays 1 pearl per 10 m of your deepest point

-- Depth zones: shown in the HUD, set the light level and how hard the trench chunks get.
Config.Zones = {
	{ name = "Sunlit Reef", fromMeters = 0, difficulty = 1, darkness = 0 },
	{ name = "Shipwreck Graveyard", fromMeters = 100, difficulty = 2, darkness = 0.25 },
	{ name = "Twilight Zone", fromMeters = 250, difficulty = 3, darkness = 0.55 },
	{ name = "Midnight Trench", fromMeters = 500, difficulty = 3, darkness = 0.8 },
}

-- weight: base chance; depthBonus: extra weight per 100 m of depth (deeper = rarer catches)
Config.Rarities = {
	Common = { weight = 70, depthBonus = 0, sellPrice = 2, order = 1, color = Color3.fromRGB(220, 220, 220) },
	Rare = { weight = 22, depthBonus = 0.6, sellPrice = 6, order = 2, color = Color3.fromRGB(80, 150, 255) },
	Epic = { weight = 7, depthBonus = 1.5, sellPrice = 15, order = 3, color = Color3.fromRGB(190, 90, 255) },
	Legendary = { weight = 1, depthBonus = 3, sellPrice = 60, order = 4, color = Color3.fromRGB(255, 190, 40) },
}

-- model = name of the mesh in ReplicatedStorage.DeepDive.Models; minDepth in meters
Config.Creatures = {
	{ id = "Clownfish", name = "Clownfish", rarity = "Common", model = "Clownfish", minDepth = 0 },
	{ id = "BlueTang", name = "Blue Tang", rarity = "Common", model = "BlueTang", minDepth = 0 },
	{ id = "Starfish", name = "Starfish", rarity = "Common", model = "Starfish", minDepth = 0 },
	{ id = "Seahorse", name = "Seahorse", rarity = "Rare", model = "Seahorse", minDepth = 0 },
	{ id = "Pufferfish", name = "Pufferfish", rarity = "Rare", model = "Pufferfish", minDepth = 20 },
	{ id = "SeaTurtle", name = "Sea Turtle", rarity = "Epic", model = "SeaTurtle", minDepth = 60 },
	{ id = "GoldenOyster", name = "Golden Oyster", rarity = "Epic", model = "GoldenOyster", minDepth = 100 },
	{ id = "RainbowManta", name = "Rainbow Manta", rarity = "Legendary", model = "RainbowManta", minDepth = 150 },
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
	{
		id = "Lamp",
		name = "Head Lamp",
		tiers = {
			{ name = "Glow Stick", price = 15, desc = "Light up 40 studs around you", stats = { lampRange = 16 } },
			{ name = "Dive Torch", price = 50, desc = "Light up 52 studs around you", stats = { lampRange = 28 } },
			{ name = "Floodlight", price = 120, desc = "Light up 60 studs around you", stats = { lampRange = 36 } },
		},
	},
}

-- Unlocked in order; each adds a display tank to your dome and its `stats` to every dive.
Config.Wings = {
	{ id = "ReefTank", name = "Reef Tank", cost = 0, stats = {} },
	{ id = "ShipwreckHall", name = "Shipwreck Hall", cost = 25, stats = { oxygen = 10 } },
	{ id = "JellyfishDome", name = "Jellyfish Dome", cost = 75, stats = { oxygen = 20 } },
}
Config.SPECIES_PER_TANK = 6 -- each tank shows one of every species you have caught

Config.Shopkeeper = {
	name = "Marina",
	skin = Color3.fromRGB(234, 184, 146),
	shirt = Color3.fromRGB(30, 60, 110),
	pants = Color3.fromRGB(230, 200, 140),
}

-- Licensed sound effects (ProSoundEffects / APM on the Creator Store)
Config.Sounds = {
	Ambience = "rbxassetid://9112889907",
	Bubbles = "rbxassetid://9120310416",
	DrownBubbles = "rbxassetid://9120311209",
	Gasp = "rbxassetid://9125572450",
	Heartbeat = "rbxassetid://1839998022",
}
Config.BUBBLE_TEXTURE = "rbxassetid://3113298352"

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

function Config.toMeters(depthStuds)
	return math.max(0, math.floor(depthStuds / Config.STUDS_PER_METER))
end

function Config.zoneAt(meters)
	local zone = Config.Zones[1]
	for _, candidate in Config.Zones do
		if meters >= candidate.fromMeters then
			zone = candidate
		end
	end
	return zone
end

return Config
