# Deep Dive

Roblox obby × roguelite × tycoon, entirely underwater. You live in a glass dome on the seafloor and dive into an endless trench in the middle of the hub: the deeper you go the rarer the catches, but your oxygen only lasts so long and you have to swim back out of the top to keep everything. Sell spare catches to Marina at the Dive Shop for better gear; the first of every species goes on display in your dome's tanks for good.

- Design: [docs/game-design.md](docs/game-design.md)
- Game scripts: [src/](src/), mirroring where each script lives in Studio
- World builder: [tools/build_world.luau](tools/build_world.luau) builds the seafloor, the domes, the decorations and the trench chunk templates. Run it in Studio's command bar; it is safe to re-run.
- Model import: [tools/import_models.luau](tools/import_models.luau) files AI-generated meshes under `ReplicatedStorage.DeepDive.Models` by name.

## Where things live in Studio

| Repo file | Studio location | Type |
| --- | --- | --- |
| `src/ReplicatedStorage/DeepDive/*.luau` (Config, Stats, Ui) | `ReplicatedStorage.DeepDive.<name>` | ModuleScript |
| `src/ServerScriptService/DeepDive/Main.server.luau` | `ServerScriptService.DeepDive.Main` | Script |
| `src/ServerScriptService/DeepDive/*.luau` (others) | `ServerScriptService.DeepDive.<name>` | ModuleScript |
| `src/StarterPlayerScripts/*.client.luau` | `StarterPlayer.StarterPlayerScripts.<name>` | LocalScript |

Meshes (creatures, urchin, jellyfish, eel, coral, kelp, shop counter, air bubble) live in `ReplicatedStorage.DeepDive.Models`. Trench chunk templates live in `ServerStorage.DeepDive.ChunkTemplates`; the attributes they use are listed at the top of `Trench.luau`.

## How the trench works

The trench is a vertical shaft under the hub, built in 80-stud chunks while divers go down (`Trench.luau`). Each chunk's rock walls become terrain; its contents are cloned from a random template that suits the depth zone (`Config.Zones`), rotated by a random quarter turn, and removed again when nobody is near. A fixed `Config.TRENCH_SEED` gives every server the same trench (for a weekly challenge). Diving starts when you swim below the seafloor inside the shaft and ends when you swim back out, so there are no levels or teleports.

## Extending the game

| To add… | Change |
| --- | --- |
| A creature | One line in `Config.Creatures` (with `minDepth`), plus its mesh in `Models` |
| An equipment tier | One entry in that item's `tiers` in `Config.Equipment`; the shop shows it automatically |
| A new equipment line (sonar, scooter…) | A new `Config.Equipment` entry whose tiers use a stat; add the stat to `Stats.BASE`, then read `run.stats.<stat>` in `Dive.luau` (or a player attribute set in `Dive.refreshStats`) |
| A depth zone | An entry in `Config.Zones` (name, start depth, difficulty, darkness) |
| A trench chunk | A `do … end` block in `tools/build_world.luau` using `newChunk` and the helpers, then re-run the builder |
| A chunk mechanic | Read a new attribute in `Mechanics.start` (server) or `DeepDiveEquipment` (client, for things that move the player) |
| A dome tank | An entry in `Config.Wings` plus a tank part with the same id in `tools/build_world.luau` |
| A shop action | A function in `handlers` in `Shop.luau`, called from the client with `ShopRequest:InvokeServer(action, ...)` |
| A sound | An id in `Config.Sounds`, played from `DeepDiveHud` |

## Saving

Progress uses DataStores. The place is published, so saving works in live servers; in Studio it also needs "Enable Studio Access to API Services" (Game Settings → Security). Without it the game runs but nothing is saved.
