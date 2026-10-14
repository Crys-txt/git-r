-- Moves AI-generated meshes from the Workspace into ReplicatedStorage.DeepDive.Models under the names the
-- game uses (Config.Creatures[].model, the Model attribute on trench parts, Coral/Kelp/ShopCounter decor).
-- Generated models are named after their prompt, so they are matched by keyword. Run in Studio's command
-- bar after generating; then re-run tools/build_world.luau so the hub decorations pick the meshes up.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KEYWORDS = {
	{ "clownfish", "Clownfish" },
	{ "blue tang", "BlueTang" },
	{ "starfish", "Starfish" },
	{ "seahorse", "Seahorse" },
	{ "pufferfish", "Pufferfish" },
	{ "sea turtle", "SeaTurtle" },
	{ "oyster", "GoldenOyster" },
	{ "manta", "RainbowManta" },
	{ "urchin", "Urchin" },
	{ "jellyfish", "Jellyfish" },
	{ "eel", "Eel" },
	{ "coral", "Coral" },
	{ "kelp", "Kelp" },
	{ "counter", "ShopCounter" },
	{ "air bubble", "AirBubble" },
}

local models = ReplicatedStorage:WaitForChild("DeepDive"):FindFirstChild("Models") or Instance.new("Folder")
models.Name = "Models"
models.Parent = ReplicatedStorage.DeepDive

local imported = {}
for _, item in workspace:GetChildren() do
	local lowered = item.Name:lower()
	for _, entry in KEYWORDS do
		if lowered:find(entry[1], 1, true) then
			-- Keep a single MeshPart: that is what the game scales and welds.
			local meshPart = item:IsA("MeshPart") and item or item:FindFirstChildWhichIsA("MeshPart", true)
			if meshPart then
				local old = models:FindFirstChild(entry[2])
				if old then
					old:Destroy()
				end
				meshPart.Name = entry[2]
				meshPart.Anchored = true
				meshPart.CanCollide = false
				meshPart.Parent = models
				if item ~= meshPart then
					item:Destroy()
				end
				table.insert(imported, entry[2])
			end
			break
		end
	end
end
return "Imported: " .. table.concat(imported, ", ")
