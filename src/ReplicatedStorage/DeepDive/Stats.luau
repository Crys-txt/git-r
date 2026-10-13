-- Turns a player's saved progress (wings, equipment tiers) into the numbers a dive uses.
-- To add a stat: give it a base value here, use it in a wing's or tier's `stats`, then read it where it matters.
local Config = require(script.Parent.Config)

local Stats = {}

Stats.BASE = {
	oxygen = 0, -- added to starting and maximum oxygen
	swimSpeed = 0, -- added to Config.SWIM_SPEED
	harpoonRange = 0, -- studs; 0 means no harpoon
}

function Stats.compute(data)
	local stats = table.clone(Stats.BASE)
	local function add(bonus)
		for stat, value in bonus or {} do
			stats[stat] = (stats[stat] or 0) + value
		end
	end
	for _, wing in Config.Wings do
		if data.wings[wing.id] then
			add(wing.stats)
		end
	end
	for _, item in Config.Equipment do
		local tier = item.tiers[data.equipment[item.id] or 0]
		if tier then
			add(tier.stats)
		end
	end
	return stats
end

return Stats
