# Deep Dive

Roblox obby × roguelite × tycoon. You ride a diving bell down an ocean trench and swim through one shuffled underwater cave at a time before your oxygen runs out. Back at the harbor you sell catches at the Dive Shop for better equipment, or keep the rare ones swimming in your aquarium.

- Design: [docs/game-design.md](docs/game-design.md)
- Game scripts: [src/](src/), mirroring where each script lives in Studio
- World builder: [tools/build_world.luau](tools/build_world.luau) builds the harbor and the 8 Sunlit Reef floor templates. Run it in Studio's command bar; it is safe to re-run.

## Where things live in Studio

| Repo file | Studio location | Type |
| --- | --- | --- |
| `src/ReplicatedStorage/DeepDive/*.luau` (Config, Stats, Ui) | `ReplicatedStorage.DeepDive.<name>` | ModuleScript |
| `src/ServerScriptService/DeepDive/Main.server.luau` | `ServerScriptService.DeepDive.Main` | Script |
| `src/ServerScriptService/DeepDive/*.luau` (others) | `ServerScriptService.DeepDive.<name>` | ModuleScript |
| `src/StarterPlayerScripts/*.client.luau` | `StarterPlayer.StarterPlayerScripts.<name>` | LocalScript |

Floor templates live in `ServerStorage.DeepDive.FloorTemplates`. Each one is an underwater cave model with a `Start` pad (its pivot), an `Exit` gate, a `Water` part the server fills with terrain water, `CatchSpot` parts (attribute `Hard` = rare-only), and parts with the attributes `Hazard`, `MoveOffset`/`MoveTime`/`MovePhase`, `SpinSpeed`/`SpinAxis`, `Current` or `Crumble`. The model's `Difficulty` (1–3) puts easy caves first in a dive.

## Extending the game

| To add… | Change |
| --- | --- |
| A creature | One line in `Config.Creatures` |
| An equipment tier | One entry in that item's `tiers` in `Config.Equipment`; the shop shows it automatically |
| A new equipment line (lamp, sonar…) | A new `Config.Equipment` entry whose tiers use a stat; add the stat to `Stats.BASE`, then read `run.stats.<stat>` in `Dive.luau` (or the matching player attribute on the client) |
| An aquarium wing | An entry in `Config.Wings` plus a tank part with the same id in `tools/build_world.luau` |
| A cave | A `do … end` block in `tools/build_world.luau` using `newCave` and the helpers, then re-run the builder |
| A floor mechanic | Read a new attribute in `FloorMechanics.start` (server) or `DeepDiveEquipment` (client, for things that move the player) |
| A shop action | A function in `handlers` in `Shop.luau`, called from the client with `ShopRequest:InvokeServer(action, ...)` |

## Saving

Progress uses DataStores, which only work once the place is published and "Enable Studio Access to API Services" is on. Until then, the game runs but nothing is saved.
