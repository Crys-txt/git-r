# Deep Dive

Roblox obby × roguelite × tycoon. You ride a diving bell down an ocean trench, clear one shuffled obby floor at a time before your oxygen runs out, and show off your catches in an aquarium on the shared harbor.

- Design: [docs/game-design.md](docs/game-design.md)
- Game scripts: [src/](src/), mirroring where each script lives in Studio
- World builder: [tools/build_world.luau](tools/build_world.luau) builds the harbor and the 8 Sunlit Reef floor templates. Run it in Studio's command bar; it is safe to re-run.

## Where things live in Studio

| Repo file | Studio location | Type |
| --- | --- | --- |
| `src/ReplicatedStorage/DeepDive/Config.luau` | `ReplicatedStorage.DeepDive.Config` | ModuleScript |
| `src/ServerScriptService/DeepDive/Main.server.luau` | `ServerScriptService.DeepDive.Main` | Script |
| `src/ServerScriptService/DeepDive/*.luau` (others) | `ServerScriptService.DeepDive.<name>` | ModuleScript |
| `src/StarterPlayerScripts/*.client.luau` | `StarterPlayer.StarterPlayerScripts.<name>` | LocalScript |

Floor templates live in `ServerStorage.DeepDive.FloorTemplates`. Each one is a model with a `Start` pad at its origin, an `Exit` gate, `CatchSpot` parts (attribute `Hard` = rare-only), and parts with the attributes `Hazard`, `MoveOffset`/`MoveTime`, `Current`, `Crumble` or `SpinSpeed`.

## Saving

Progress uses DataStores, which only work once the place is published and "Enable Studio Access to API Services" is on. Until then, the game runs but nothing is saved.
