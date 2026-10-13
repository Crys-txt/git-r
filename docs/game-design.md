# Roblox Game Concept: Obby × Roguelite × Tycoon

Exported from the [Claude Doc](https://claude.ai/code/artifact/5e00f392-8176-4c9e-bba9-aaa22cedd997) on 2026-10-14. The doc is the live version; this file is the snapshot the prototype is built from.

## Brief

One game, three layers: short **obby runs** that are **randomized like a roguelite**, feeding a **tycoon-style home** you grow between runs. Roguelite, not roguelike: each run's layout resets, but catches, equipment, home and unlocks are kept forever, so a death never sends you back to zero. The inspiration ([1+ Wings Obby Escape](https://www.roblox.com/games/73768006371986/1-Wings-Obby-Escape)) proves the run-and-upgrade loop works; this concept fixes its three gaps:

| Gap | Fix in this concept |
| --- | --- |
| No real theme | A world where the obby, the loot and the home all make sense together |
| Grind is invisible | Progress you can *see*: a home others visit, a collection book, titles over your head |
| No sense of competition | Shared lobby, live run leaderboards, ghost racers, weekly seeds |

Design goal: the first 10 minutes feel fast and rewarding, the first hour feels hard enough to matter, and every session ends with something new on display.

## Theme: Deep Dive

You ride a diving bell down an ocean trench, one floor at a time. Each floor is an enclosed underwater cave you **swim** through (real Roblox water: you float upward, look down and swim to dive); an **oxygen meter** is the run's clock and tension. Surface with your catches, or run out of air and keep only part of them.

| Depth zone | Floors | Look | Threats | Signature catches |
| --- | --- | --- | --- | --- |
| Sunlit Reef | 1–10 | Bright coral, kelp swings, turtle-shell platforms | Currents, sea urchins | Clownfish, starfish, pearls |
| Shipwreck Graveyard | 11–25 | Broken decks, cannons, cargo nets | Collapsing planks, eels | Pirate coins, octopus, compass |
| Twilight Zone | 26–50 | Dim blue, jellyfish fields, glowing plankton | Stinging jellies, patrolling sharks | Glow jellyfish, nautilus |
| Midnight Trench | 51+ | Pitch dark, only your lamp and creature lights | Anglerfish lures, pressure cracks | Anglerfish, giant squid, abyss relics |

**Equipment** (bought at the Dive Shop with pearls from selling catches, kept forever, 3 tiers each): air tanks (more oxygen), fins (swim faster), harpoon (catch creatures from a distance with F). Later: lamp, sonar, scooter.

**Home:** an aquarium whose wings unlock as you go deeper. **Currency:** pearls.

## Core loop

A session is 3–5 minute runs chained by quick trips home, so there is always a natural "one more run".

1. **Get ready at the harbor** – see rivals' aquariums and the live dive feed; pick a zone, join a race or go solo.
2. **Dive floor by floor** – each floor is an underwater cave, shuffled every dive with easier caves first.
3. **The dive ends** – surface: keep every catch. Out of air: keep part, never zero.
4. **Sell, upgrade, display** – sell catches at the Dive Shop for pearls, buy better equipment, or keep rare fish in your aquarium (selling removes them). Then back to 1, stronger, so you go deeper.

The run is the challenge; the home and lobby are where the grind becomes visible and where rivals see it.

## Showing the grind

Every hour played should leave a mark someone else can see. Four layers, from private to public:

| Layer | What the player sees | What others see |
| --- | --- | --- |
| **Home (tycoon)** | Aquarium wings unlock in order: reef tank → shipwreck hall → jellyfish dome → twilight tunnel → abyss gallery. Each wing boosts dives (more oxygen per dive) | Aquariums line the shared harbor in the lobby; visitors walk through and "like" them |
| **Collection book** | Every creature and treasure has a page: silhouette until found, rarity stars, "found at floor X". Completing a page = permanent bonus | Rarest creatures get a spotlight tank at the aquarium entrance |
| **Achievements & titles** | 3 tiers per achievement (bronze/silver/gold), e.g. "Clear the Sunlit Reef without a hit" | Equipped title floats above your head: *Shark Whisperer*, *Depth 50*, *No-Hit Reef* |
| **Cosmetics** | Trails, equipment skins, diving bell skins earned from milestones, not only bought | Visible every run and in the lobby |

Rule of thumb: each session should unlock at least one thing in one of these layers.

## Competition and social

Players should feel others racing them even when playing solo.

- **Shared harbor:** every player's aquarium docks along the pier; the biggest one sits at the front with a crown.
- **Live run feed:** a lobby billboard shows "Alex just reached the Twilight Zone (floor 30)" in real time.
- **Ghost racers:** during a run, faint ghosts of server players (or your own best run) move alongside you.
- **Weekly seed:** one fixed floor order for everyone; global leaderboard by depth and time; top 100 get a unique title.
- **Server race event:** every 30-60 minutes, everyone drops into the same short run; deepest diver wins a rare item/lootbox.
- **Leaderboards:** deepest floor, fastest reef clear, home value, collection %. Show the player's own rank and the next name above them, not just the top 10.
- **Co-op revive:** in multiplayer runs, a friend can revive you once by reaching your spot; builds teamwork without needing parties.

## Early retention

The first session decides everything: make the first win easy, the second win earned, and the third one visibly close.

**First 10 minutes**

1. **0–1 min:** step into the diving bell at the dock; one-button tutorial floor; first catch (a clownfish) in 30 seconds.
2. **1–3 min:** first real dive, 3 floors, almost impossible to fail. Surface and drop the fish in your tank: home "levels up" with a big effect.
3. **3–6 min:** sell the first catches and buy a first piece of equipment (fins or a tank). Second dive is 5 floors and introduces the oxygen meter and a patrolling shark.
4. **6–10 min:** first fail. Show what you kept (loot, XP) and what's next ("2 more pearls for the shipwreck hall"). Prompt a third run.

**Smooth but challenging**

- **Death keeps something:** you always bank part of the loot, so failing never feels like wasted time.
- **Difficulty by depth, not by time played:** floors 1–5 are easy forever; the challenge lives deeper. Skilled players dive, casual players farm.
- **Checkpoint gates:** beating a zone (Sunlit Reef, Shipwreck Graveyard, Twilight Zone) once lets you start runs there later.
- **Always show the next goal:** a small tracker with the next aquarium wing, next achievement tier and next rank above you.
- **Daily quests (3/day):** short and varied ("use the harpoon grapple 5 times") to bring players back.
- **Pity timer:** guaranteed rare after N runs without one.

## Loot boxes and rare items

Loot boxes are earned only by playing; Robux can buy luck, but never the boxes themselves. Rares get less rare mostly through effort (depth, streaks, pity, crafting); paid luck speeds that up without replacing it.

**Box tiers** (themed as things you pull off the seabed)

| Box | How you earn it | Odds: Common / Rare / Epic / Legendary |
| --- | --- | --- |
| Clam shell | Every finished run, even a failed one | 80 / 17 / 3 / 0 % |
| Barnacle crate | Reach floor 10+, or complete a daily quest | 60 / 30 / 9 / 1 % |
| Sunken chest | Win a server race, top 25% on the weekly seed, beat a zone for the first time | 35 / 40 / 20 / 5 % |

Odds are starting values to tune in playtests. Show them on every box: players trust visible odds, and Roblox requires them on any paid random item.

**Making rares less rare, without Robux**

| Lever | How it works |
| --- | --- |
| Pity bar | Visible bar on the box screen: guaranteed Epic every 20 boxes, Legendary every 60 |
| Scrap crafting | Duplicates break into scrap; scrap crafts any item already seen in the collection book (Legendaries cost the most) |
| Lucky charms | Aquarium wings add small, capped luck bonuses, so growing the aquarium pays off in drops |
| Depth bonus | Each floor past 10 adds a little luck to boxes earned on that run; skill = better loot |
| Daily streak | 5 days in a row upgrades your next box one tier |
| Hunt target | Pick one item each week to "hunt"; it gets double drop weight |

**Robux luck:** a 30-minute luck potion (+25%) and a Lucky gamepass (+10%, permanent). Paid and earned luck share one cap, so a free player with a fully built aquarium can reach the same odds as a paying one. Boosted odds show on the box while active. Robux still never buys boxes, keys or pity skips; it can also buy box style (opening effects, a display tank).

## Monetization, MVP and next steps

**Fair monetization:** sell convenience and style, never wins on the leaderboard.

- Game passes: extra aquarium wing slot, 2x pearls, a VIP trail.
- Cosmetics: equipment skins, diving bell skins, emotes.
- One emergency air tank per dive (Robux), disabled on the weekly seed leaderboard.

**MVP scope (first playable)**

- [ ] One zone (Sunlit Reef) with 8 floor templates and the oxygen meter, randomized order
- [ ] Dive Shop: sell catches, buy 3 equipment lines (tank, fins, harpoon)
- [ ] Aquarium with 3 unlockable wings where catches swim
- [ ] Collection book with 20 creatures and treasures
- [ ] Harbor lobby showing every player's aquarium
- [ ] Depth leaderboard + equipped titles
- [ ] Clam shell and barnacle crate with visible odds and a pity bar

**Next steps**

- [ ] Lock the Deep Dive art direction: 4 depth zones, color palette, first 20 creatures
- [ ] Grey-box 3 Sunlit Reef floors in Studio and test the run length (target 3–5 min)
- [ ] Test the first 10 minutes with 3–5 players and note where they quit

## Prototype defaults (decided 2026-10-14)

- **Catching:** touch a creature to catch it (or harpoon it); rarer ones sit in harder spots.
- **Oxygen:** ~60 s of air, plus a few seconds back per floor cleared.
- **Out of air:** keep 50% of catches, rarest first.
- **Dives:** solo per player; lobby and harbor are shared.
- **Floors:** one enclosed underwater cave per floor, 15–40 s to clear, tagged Difficulty 1–3.
- **Look:** grey-box with color-coded hazards; art later.
- **Swimming:** real terrain water in caves and around the harbor; idle swimmers float up at about 5 studs/s, so spiked roofs and vertical shafts use buoyancy as a hazard.
- **Economy:** catches are an inventory. Selling at the Dive Shop is the main pearl source (Common 2, Rare 6, Epic 15, Legendary 60); clearing the reef adds a 10-pearl bonus.
