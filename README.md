# ETERNAL WORLD

An original 2D sandbox survival RPG built with Godot 4 and GDScript, targeting Android first.

## Current status

**Milestone 2 — procedural terrain prototype (in progress; not yet runtime-verified)**

Implemented in source:
- Seeded 180 × 60 tile world with noise-based surface variation.
- Grass, dirt, stone and ore tile types.
- Runtime terrain collision generated from solid horizontal runs.
- Mining and block placement, including occupied-cell and player-overlap checks.
- Desktop Q/E/R and Android MINE/PLACE/BLOCK controls.
- Selectable dirt and stone placement with a live HUD selection indicator.
- Player movement, running, jumping, double jump, health, fall damage and timed respawn.
- Melee attack area, configurable damage/cooldown, a damageable training dummy and a chasing slime enemy with contact damage.
- JSON world/player/inventory save-load with validation and automatic save every 30 seconds and on app pause/close.
- Smoke-test source covering world edits, save-data round trips, player health, combat and respawn.
- GitHub Actions workflow for headless Godot import and smoke tests.

Still required:
- Run Godot headless import and smoke tests; resolve any engine/parser errors.
- Verify touch controls, terrain collision and combat on a physical Android device.
- Add block selection, inventory UI and richer progression systems.
- Add caves, trees, water, biome transitions and chunk streaming.
- Replace placeholder polygon visuals with original pixel-art assets and animations.
- Add more enemy species, boss encounters, crafting and export/install a debug APK.

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

Android:
- Left virtual joystick: move
- JUMP / RUN / HIT: movement and combat
- MINE / PLACE: edit terrain in front of the player
- BLOCK: switch the selected build material

## Project structure

- `scenes/` — reusable player, world and target scenes
- `scripts/` — gameplay and procedural world code
- `tests/` — automated smoke tests
- `.github/workflows/` — automated Godot validation

## Development policy

Features are marked complete only after validation and gameplay testing. Source files and CI automation do not, by themselves, prove runtime correctness. This project is under active development and is not a finished game.
