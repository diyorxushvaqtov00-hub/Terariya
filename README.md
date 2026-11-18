# ETERNAL WORLD

An original 2D sandbox survival RPG built with Godot 4 and GDScript, targeting Android first.

## Current status

**Milestone 3 — survival gameplay foundation (in progress; not yet runtime-verified)**

Implemented in source:
- Seeded 180 × 60 tile world with noise-based surface variation.
- Forest, desert and snow biomes with distinct surface materials; grass, dirt, sand, snow, stone, ore, wood and leaf tile types.
- Seeded procedural trees with harvestable trunks; leaf canopies are non-colliding.
- Deterministic underground cave pockets carved from seeded 2D noise, with ore deposits retained in the underground layers.
- Seeded shallow lakes with translucent water tiles that do not block movement or count as mineable terrain.
- Persistent day/night cycle with smooth world lighting, warm sunrise/sunset transitions, an on-screen clock and save/load support for the current world time.
- Slimes become faster and deal more damage at night; additional hostile slimes, durable zombies and ranged skeleton archers spawn at a distance during night and disappear at dawn, with a capped population.\n- Ancient Eye boss can be summoned using a crafted Eye Sigil, has 900 health, two combat phases, a timed charge attack, a boss health bar and a victory reward.\n- Three deterministic underground dungeon chambers generate across the forest, desert and snow biomes, each with a treasure chest. Chests can be opened nearby, grant ore, torches and healing potions, and remember their opened state in world saves.
- Each dungeon is guarded by a heavy skeleton warrior and a fast cave spider. Skeleton guards reward XP and silver ore; cave spiders reward XP and spider fangs.
- Dungeon hazards include six spike traps and three swinging blades, positioned deterministically in the three chambers and dealing contact damage to the player.
- A summonable Spider Queen boss has 1,400 HP and two phases; below half health she becomes faster and deals heavier damage. She fires poisonous web projectiles that damage, poison and slow the player. Defeating her grants gold ore, spider fangs, healing potions, 900 XP and the legendary Queen’s Fang (+80 base weapon damage). Queen’s Fang can be upgraded at an anvil using spider fangs.
- Healing potions restore 35 health and can be used from the inventory panel.
- Craftable torches can be placed in empty world cells, emit warm point light, and persist in world saves.
- Player swimming detection, reduced horizontal speed and gravity in water, buoyancy and a swim stroke on jump.
- Underwater head detection, a blue-tinted underwater screen effect, a 12-second oxygen reserve, oxygen recovery outside water, an on-screen air meter and periodic drowning damage after oxygen runs out.
- Step-based water simulation that moves water downward into open cells and spreads it sideways over supported ground; renewable lake sources feed downward flow, and a global water-tile cap prevents unbounded flooding.
- Water detection samples multiple real positions around the player, fixing the earlier issue where fractional tile offsets collapsed into the same grid cell.
- Water surfaces and falling columns have distinct highlights so lake tops and waterfall-like streams are easier to read.
- Craftable wooden buckets let the player collect a water tile and pour it into an empty nearby tile; the empty bucket returns after pouring.
- Runtime terrain collision generated from solid horizontal runs.
- Mining and block placement, including occupied-cell and player-overlap checks.
- Desktop Q/E/R and Android MINE/PLACE/BLOCK controls.
- Selectable dirt, stone, sand and snow placement with a live HUD selection indicator.
- Player movement, running, jumping, double jump, health, fall damage and timed respawn.
- XP and level progression up to level 50, with enemy and boss rewards, a HUD experience bar, +2 melee damage every two levels and +10 maximum health every five levels; progression is saved.
- Melee attack area, configurable damage/cooldown, a damageable training dummy and a chasing slime enemy with contact damage.
- Inventory and crafting panel with live item counts, recipe buttons and disabled recipes when materials are missing (I key or INVENTORY button).
- Inventory-based crafting recipes for wooden planks, a workbench, a stone sword and an Eye Sigil boss-summoning item, with ingredient checks and exact resource consumption.
- Crafted stone sword adds 15 melee damage while owned; copper sword adds 25 melee damage and takes priority when owned.
- Craftable wooden, silver and gold armor can be equipped, persists in save data, and reduces incoming damage by 6, 12 and 20 points per hit respectively.
- Silver and gold ore deposits generate deeper underground; silver/gold swords and armor can be crafted from their ores. Weapon priority is gold, silver, copper, then stone.
- An anvil is crafted from stone, ore and planks; silver/gold gear recipes require an anvil.
- Anvil upgrades improve the best owned weapon by +3 damage per level and equipped armor by +1 defense per level, up to level 10. Upgrade levels persist in inventory saves and require matching tier materials.
- Craftable wooden axe and pickaxe have persistent durability; axes double wood drops and pickaxes double stone drops.
- JSON world/player/inventory save-load with validation and automatic save every 30 seconds and on app pause/close.
- Smoke-test source covering forest/desert/snow biome generation, lakes, renewable water-source flow, falling-water simulation, renewable water-source persistence, water detection, bucket crafting/collection/pouring, swimming, underwater tint and oxygen/drowning behavior, seeded cave spaces and ore, world edits, save-data round trips, player health, combat and respawn.
- GitHub Actions workflow for headless Godot import and smoke tests.

Still required:
- Run Godot headless import and smoke tests; resolve any engine/parser errors.
- Add more night-only enemy species, more light-source types, and configurable day-length settings.
- Verify touch controls, terrain collision and combat on a physical Android device.
- Add item tooltips, multiple armor tiers and equipment slots, inventory capacity, and mining-speed progression for tools.
- Add pumps, drains, controllable source placement/removal tools and richer fluid interactions; improve biome transitions and chunk streaming, and expand cave variety and underground structures.
- Replace placeholder polygon visuals with original pixel-art assets and animations.
- Add more dungeon room variants, boss attack patterns, crafting stations and export/install a debug APK.

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
- Q: mine the block in front
- E: place the selected block in front
- R: switch between dirt and stone
- I: open or close inventory and crafting

Android:
- Left virtual joystick: move
- JUMP / RUN / HIT: movement and combat
- MINE / PLACE: edit terrain in front of the player
- BLOCK: switch the selected build material
- INVENTORY: open or close inventory and crafting

## Project structure

- `scenes/` — reusable player, world and target scenes
- `scripts/` — gameplay and procedural world code
- `tests/` — automated smoke tests
- `.github/workflows/` — automated Godot validation

## Development policy

Features are marked complete only after validation and gameplay testing. Source files and CI automation do not, by themselves, prove runtime correctness. This project is under active development and is not a finished game.
