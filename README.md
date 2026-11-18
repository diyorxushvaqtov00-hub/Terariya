# ETERNAL WORLD

An original 2D sandbox survival RPG built with Godot 4 and GDScript, targeting Android first.

## Current status

**Milestone 1 — foundation and player controller (in progress; not yet runtime-verified)**

Implemented in source:
- Godot 4 project configuration using the mobile-compatible GL Compatibility renderer.
- Main scene, reusable player scene and follow camera.
- CharacterBody2D movement with acceleration, walking, running and jumping.
- Basic health, healing and fall-damage logic.
- Unlockable double-jump state.
- Android virtual joystick and jump, run and attack touch controls.
- Melee attack area with configurable damage, active window and cooldown.
- Training dummy target with health and defeat behavior.
- Player smoke-test script and GitHub Actions validation workflow.

Still required before Milestone 1 can be marked complete:
- Run Godot headless import and smoke tests; resolve any engine/parser errors.
- Verify touch controls and melee combat on physical Android devices.
- Replace temporary polygon visuals with original pixel-art sprites and animations.
- Implement death/respawn flow and real enemy AI.
- Export and install a debug APK for device testing.

Later milestones:
- Procedural chunked world, biomes, mining and building.
- Inventory, chests, item data and crafting.
- Enemy AI, bosses, NPCs, quests and progression.
- Survival systems, persistent world saves, audio, polish and release builds.

## Run

1. Install a stable Godot 4.x build.
2. Clone this repository.
3. Import the folder containing `project.godot`.
4. Press **F6** to run the main scene, or **F5** to run the project.

## Controls

Desktop:
- A / Left Arrow: move left
- D / Right Arrow: move right
- Space: jump
- Shift: run
- F: melee attack

Android:
- Left virtual joystick: move
- JUMP: jump
- RUN: run while held
- HIT: melee attack

## Project structure

- `scenes/` — reusable Godot scenes
- `scripts/` — gameplay code
- `data/` — data-driven definitions (to be added)
- `assets/` — original art, audio and fonts (to be added)
- `tests/` — automated gameplay tests
- `.github/workflows/` — automated Godot validation

## Development policy

Features are marked complete only after validation and gameplay testing. Source files and CI automation do not, by themselves, prove runtime correctness. This project is under active development and is not a finished game.
