# ETERNAL WORLD

An original 2D sandbox survival RPG built with Godot 4 and GDScript, targeting Android first.

## Current status

**Milestone 1 — foundation and player controller (in progress; not yet runtime-verified)**

Implemented in source:
- Godot 4 project configuration using the mobile-compatible GL Compatibility renderer.
- Main scene, reusable player scene and follow camera.
- CharacterBody2D movement with acceleration, walking, running and jumping.
- Basic health, healing and fall-damage logic.
- Unlockable double-jump state and attack input signal.
- Responsive on-screen virtual joystick, jump, run and attack touch zones for Android.
- Player smoke-test script and GitHub Actions validation workflow.

Still required before Milestome 1 can be marked complete:
- Run Godot headless import and smoke tests; resolve any engine/parser errors.
- Verify touch controls on physical Android devices and adjust layout for aspect ratios.
- Replace temporary polygon player/ground visuals with original pixel-art sprites and animations.
- Implement attack hitboxes/weapon handling and death/respawn flow.
- Export and install a debug APK for device testing.

Later milestones:
- Procedural chunked world, biomes, mining and building.
- Inventory, chests, item data and crafting.
- Enemy AI, combat, bosses, NPCs, quests and progression.
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
- F: attack input signal

Android:
- Left virtual joystick: move
- JUMP: jump
- RUN: run while held
- HIT: emits the attack input signal (weapon combat is not implemented yet)

## Project structure

- `scenes/` — reusable Godot scenes
- `scripts/` — gameplay code
- `data/` — data-driven definitions (to be added)
- `assets/` — original art, audio and fonts (to be added)
- `tests/` — automated gameplay tests
- `.github/workflows/` — automated Godot validation

## Development policy

Features are marked complete only after validation and gameplay testing. Source files and CI automation do not, by themselves, prove runtime correctness. This project is under active development and is not a finished game.
