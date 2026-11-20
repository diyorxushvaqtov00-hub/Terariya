# ETERNAL WORLD

An original 2D sandbox survival RPG built with Godot 4 and GDScript, targeting Android first.

## Current status

**Milestone 3 — survival gameplay foundation (in progress; not yet runtime-verified)**

Implemented in source:
- Seeded 180 × 60 tile world with noise-based surface variation.
- Forest, desert and snow biomes with distinct surface materials and smooth material/height blending across biome borders; grass, dirt, sand, snow, stone, ore, wood and leaf tile types.
- Seeded procedural trees with harvestable trunks; leaf canopies are non-colliding.
- Deterministic underground cave pockets and narrow branching passages carved from two seeded noise layers, with ore deposits retained in the underground layers. Two abandoned mine shafts with timber supports connect underground passages.
- A glowing mushroom cavern in the western underground with harvestable glow mushrooms and fungal soil.
- A deep desert magma chamber with lava pools and solid magma-rock borders; lava is non-solid, cannot be mined as a block, and burns the player for 12 damage every 0.8 seconds while touched.
- A summonable Magma Golem boss with 2,200 HP, two phases and a telegraphed area-of-effect magma slam; victory grants magma cores, gold ore, healing potions and 1,400 XP.
- Obsidian sword and armor are crafted from magma cores at an anvil; the sword adds 105 base melee damage, armor grants 28 defense, and both can be upgraded up to level 10 with magma cores.
- A summonable Mushroom Guardian has 1,750 HP, two phases and a spreading spore volley that poisons the player; victory grants glow mushrooms, fungal soil, healing potions and 1,100 XP.
- Mushroom Blade and Fungal Armor are crafted with an anvil from glowing mushrooms and underground materials; the blade adds 75 base melee damage and armor grants 22 defense, with upgrades saved up to level 10.
- Seeded shallow lakes with translucent water tiles that do not block movement or count as mineable terrain.
- Persistent day/night cycle with smooth world lighting, warm sunrise/sunset transitions, an on-screen clock and save/load support for the current world time.
- Slimes become faster and deal more damage at night; hostile slimes, durable zombies, ranged skeleton archers and flying night bats spawn at a distance during night and disappear at dawn, with a capped population.
- Day length is configurable in the Godot Inspector on the main game node (120–1,800 seconds); the selected duration is used consistently by the clock and day/night cycle.
- Ancient Eye boss can be summoned using a crafted Eye Sigil, has 900 health, two combat phases, a timed charge attack, a boss health bar and a victory reward.
- Three deterministic underground dungeon chambers generate across the forest, desert and snow biomes, each with a treasure chest. The chambers have three layouts: Pillar Hall, High Gallery and Flooded Vault. Chests can be opened nearby, grant ore, torches and healing potions, and remember their opened state in world saves.
- Each dungeon is guarded by a heavy skeleton warrior and a fast cave spider. Skeleton guards reward XP and silver ore; cave spiders reward XP and spider fangs.
- Dungeon hazards include six spike traps and three swinging blades, positioned deterministically in the three chambers and dealing contact damage to the player.
- A summonable Spider Queen boss has 1,400 HP and two phases; below half health she becomes faster and deals heavier damage. She fires poisonous web projectiles that damage, poison and slow the player, periodically summons up to two cave-spider minions, and has a pulsing/rotating idle animation. Minions become tougher and summon in pairs during phase two; defeating them grants 35 XP each. Defeating the Queen grants gold ore, spider fangs, healing potions, 900 XP and the legendary Queen’s Fang (+80 base weapon damage). Queen’s Fang can be upgraded at an anvil using spider fangs.
- Healing potions restore 35 health and can be used from the inventory panel.
- A travelling merchant stands near the forest starting area; players can buy healing potions, torches, silver ore and spider fangs, or sell wood and copper ore. Coins persist in inventory saves and are earned from defeated enemies and dungeon guards.
- Craftable torches and brighter lanterns can be placed in empty world cells; both emit warm point light and persist in world saves.
- Player swimming detection, reduced horizontal speed and gravity in water, buoyancy and a swim stroke on jump.
- Underwater head detection, a blue-tinted underwater screen effect, a 12-second oxygen reserve, oxygen recovery outside water, an on-screen air meter and periodic drowning damage after oxygen runs out.
- Step-based water simulation that moves water downward into open cells and spreads it sideways over supported ground; renewable lake sources feed downward flow, and a global water-tile cap prevents unbounded flooding.
- Water detection samples multiple real positions around the player, fixing the earlier issue where fractional tile offsets collapsed into the same grid cell.
- Water surfaces and falling columns have distinct highlights so lake tops and waterfall-like streams are easier to read.
- Craftable wooden buckets let the player collect a water tile and pour it into an empty nearby tile; the empty bucket returns after pouring. Craftable pumps convert water tiles into renewable sources, while drain charges remove water tiles and disable their source status.
- Runtime terrain collision generated from solid horizontal runs. Terrain draw calls are culled to the camera-visible tile bounds; collision is streamed in 16×16 tile chunks with a one-chunk preload radius around the player. Mining and block placement now rebuild only the edited loaded chunk instead of clearing and recreating every loaded collision chunk.
- Mining and block placement, including occupied-cell and player-overlap checks.
- Desktop Q/E/R and Android MINE/PLACE/BLOCK controls.
- Selectable dirt, stone, sand and snow placement with a live HUD selection indicator.
- Player movement, running, jumping, double jump, health, fall damage and timed respawn; original animated pixel-art sprites now cover the player, slime, night bat, zombie, skeleton archer, cave spider, dungeon skeleton and all six major bosses; the training dummy also has a dedicated pixel-art sprite.
- XP and level progression up to level 50, with enemy and boss rewards, a HUD experience bar, +2 melee damage every two levels and +10 maximum health every five levels; progression is saved.
- Melee attack area, configurable damage/cooldown, a damageable training dummy and a chasing slime enemy with contact damage.
- Shared enemy hit reactions: damage flash, directional knockback and a brief defeat animation are applied to the common enemy base, including bosses that inherit its damage handling.
- All six major bosses now play a distinct color-tinted transition effect when entering phase two, layered over their existing phase-specific attacks and movement changes.
- Player combat feedback: melee attacks use a short directional swing animation, incoming hits trigger a red damage flash and recoil, and the walking cycle continues while airborne.
- Inventory and crafting panel with live item counts, recipe buttons, item tooltips and disabled recipes when materials are missing; inventory supports 40 distinct item stacks (I key or INVENTORY button).
- Inventory-based crafting recipes for wooden planks, a workbench, a stone sword and an Eye Sigil boss-summoning item, with ingredient checks and exact resource consumption.
- Crafted stone sword adds 15 melee damage while owned; copper sword adds 25 melee damage and takes priority when owned.
- Craftable wooden, silver and gold body armor, helmets and boots can be equipped in separate equipment slots; all equipped defense values and equipment selections persist in save data.
- Silver and gold ore deposits generate deeper underground; silver/gold swords and armor can be crafted from their ores. Weapon priority is Obsidian Sword, Queen’s Fang, Mushroom Blade, gold, silver, copper, then stone. Armor priority is obsidian, fungal, gold, silver, then wooden.
- A Workbench is now the first crafting progression gate: after basic planks, tools, weapons, armor, utility stations and advanced recipes require the crafted Workbench. Silver/gold and endgame gear also require an Anvil; the Alchemy Table unlocks healing potions, and the Tinkering Bench unlocks the Double Jump Charm and tool repair kits. Locked recipe buttons explain which station is missing.
- Anvil upgrades improve the best owned weapon by +3 damage per level and equipped armor by +1 defense per level, up to level 10. Upgrade levels persist in inventory saves and require matching tier materials.
- Craftable wooden axe and pickaxe have persistent durability; axes double wood drops and pickaxes double stone drops. Pickaxes can be upgraded at an anvil up to level 10, increasing held-to-mine speed by 15% per level.
- JSON world/player/inventory save-load with validation and automatic save every 30 seconds and on app pause/close.
- Smoke-test source covering forest/desert/snow biome generation, lakes, renewable water-source flow, falling-water simulation, renewable water-source persistence, water detection, bucket crafting/collection/pouring, swimming, underwater tint and oxygen/drowning behavior, seeded cave spaces and ore, world edits, save-data round trips, player health, combat and respawn.
- GitHub Actions workflow for headless Godot import and smoke tests.

Still required:
1. Run the final Godot headless import and smoke-test suite; resolve any engine/parser errors.
2. Verify touch controls, terrain collision, mining, water, combat and sustained frame rate on a physical Android device.
3. Profile and tune chunk streaming on larger maps; collision now loads nearby 16×16 chunks and unloads distant chunks, with camera-aware render culling.
4. Finish hit/reaction animation polish; player attack/damage feedback and shared enemy flash, knockback and defeat feedback are implemented, while richer boss-specific reactions remain.
5. Balance station recipes and equipment progression; the anvil, alchemy table and tinkering bench now gate metal gear, potions, the Double Jump Charm and tool repair kits.
6. Complete a successful Android debug APK export, install it on a phone and fix any device-specific issues.

## Run

1. Install Godot 4.3 or a compatible Godot 4.x version.
2. Clone this repository.
3. Import the folder containing `project.godot`.
4. Press **F5** to run the project.

## Controls

Desktop:
- A / Left Arrow: move left
- D / Right Arrow: move right
- Space: jump
- Shift: run
- F: melee attack
- G: cast a Void Bolt (requires a crafted Void Staff and mana)
- Q: mine the block in front
- E: place the selected block in front
- R: switch between dirt and stone
- I: open or close inventory and crafting

Android:
- Landscape layout with responsive touch-button sizing for compact phone screens.
- Left virtual joystick: move
- VOID: cast a Void Bolt (requires a crafted Void Staff and mana)
- JUMP / RUN / HIT: movement and combat
- MINE / PLACE: edit terrain in front of the player
- BLOCK: switch the selected build material
- INV: open or close inventory and crafting


## Android debug build

- The repository includes an Android export preset targeting 64-bit ARM devices.
- After the Godot validation workflow succeeds on `main`, the Android debug workflow exports `build/eternal-world-debug.apk` and uploads it as the `eternal-world-android-debug` workflow artifact.
- Open GitHub Actions, select the latest successful **Android debug APK** run, and download the artifact. The APK is debug-signed and is for testing, not Play Store release.
- Install with `adb install -r eternal-world-debug.apk`, or transfer the APK to the Android device and open it to install.
- Physical-device QA is still required: verify joystick movement, simultaneous touch controls, mining/placement, combat, collision, inventory scrolling, water, lighting and sustained frame rate.

## Project structure

- `scenes/` — reusable player, world and target scenes
- `scripts/` — gameplay and procedural world code
- `tests/` — automated smoke tests
- `.github/workflows/` — automated Godot validation

## Development policy

Features are marked complete only after validation and gameplay testing. Source files and CI automation do not, by themselves, prove runtime correctness. This project is under active development and is not a finished game.

## Quests and progression

The quest log currently includes three persistent objectives: collect 10 wood, defeat 3 enemies, and open a dungeon chest. Completing them grants coins and progression materials. Quest progress and completion flags are saved with the world and restored when the save is loaded. The quest log is displayed inside the inventory and crafting panel.

## Elder guide NPC

An Elder NPC now appears beside the starting camp. Open the inventory panel and choose **TALK TO THE ELDER** while nearby to receive contextual guidance for the current objective, basic survival and exploration. The dialogue adapts to the three quest milestones and points players toward later biomes after the starter quests are complete.

## Locked dungeon vaults

The three underground dungeon chests are now locked. Craft three **Dungeon Keys** using 6 silver ore, 3 gold ore and 2 spider fangs, then spend one key per vault. Each vault has its own saved opened state and grants base supplies plus increasing metal rewards; the final vault also grants gold ore. The inventory panel displays the key count and explains why a chest could not be opened.

## Dungeon Warden boss

The third dungeon vault awards a unique Dungeon Relic. Combine one relic with 20 gold ore, 10 silver ore and 6 spider fangs to craft a Dungeon Warden Sigil. Use it from the inventory panel to summon the two-phase Dungeon Warden. Its charged vault slam is telegraphed before impact, has a larger radius and heavier damage in phase two; phase two also fires a three-projectile fan volley. It rewards 3 Dungeon Relics, 28 gold ore, 8 healing potions and 1,800 XP. Only one major boss encounter can be active at a time.


### Dungeon Warden Arena Update
- Dungeon Warden summoning now places the boss in the center of the nearest generated dungeon chamber instead of spawning beside the player anywhere in the world.
- The arena locator uses each chamber's generated chest anchor and floor height, so it follows the generated dungeon layout and works across all three biome vaults.


### Ancient Secret Vaults
- Each of the three dungeon chambers now contains a concealed side room behind a two-tile sealed gate.
- Craft two Ancient Keys from 1 Dungeon Relic, 8 Gold Ore and 4 Spider Fangs; each gate consumes one key.
- Open the sealed gate beside the dungeon, enter the side room and claim its one-time cache for a Dungeon Relic, Gold Ore, Silver Ore and Healing Potions.
- Gate tiles and cache claim state are saved with the world, preventing duplicate loot after reloading.

## Voidbreaker — endgame weapon

- Craft the Voidbreaker at an anvil using 2 Dungeon Relics, 16 Gold Ore, 8 Magma Cores and 12 Spider Fangs.
- It adds 145 base melee damage and has the highest weapon priority.
- Upgrade it up to level 10 using additional Dungeon Relics; each upgrade adds the existing +3 weapon damage bonus.

## Void Guardian encounter

- Craft a Void Guardian Sigil from 1 Dungeon Relic, 12 Gold Ore, 6 Magma Cores and 6 Spider Fangs.
- Travel to an opened secret vault to summon the Void Guardian there; the sigil cannot be used far from a secret vault.
- The boss has 1,350 HP, a telegraphed void pulse, and a faster second phase below half health.
- Defeating it awards 3 Void Shards, 2 Dungeon Relics, 5 Healing Potions and 1,600 XP.

## Void Armor

- Craft Void Armor at an anvil using 8 Void Shards, 3 Dungeon Relics and 20 Gold Ore.
- It provides 38 defense, currently the strongest armor set, and upgrades up to level 10 using Void Shards.
- Its Void Ward passive reduces incoming damage by a further 15% before flat defense is applied.
- The best-armor button prioritizes Void Armor; its equipped state and upgrade level persist in saves.

## Void Staff and ranged magic

- Craft the Void Staff at an anvil using 6 Void Shards, 2 Dungeon Relics and 12 Glow Mushrooms.
- With the staff in your inventory, press **G** on desktop or **VOID** on Android to fire a fast Void Bolt.
- Each bolt deals 92 damage, costs 20 mana and has a 0.62-second cast cooldown. Mana regenerates at 8 points per second and is saved with the player.
- The projectile travels horizontally in the direction the player is facing and damages enemies on contact.
