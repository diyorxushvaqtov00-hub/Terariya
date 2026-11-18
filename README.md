# ETERNAL WORLD

An original 2D sandbox survival RPG built with Godot 4 and GDScript, targeting Android first.

## Current status

**Milestone 1 — foundation and player controller (initial implementation)**

Included in this first commit:
- Godot 4 project configuration using the mobile-compatible GL Compatibility renderer.
- Main scene and player scene.
- CharacterBody2D movement with acceleration, walking, running and jumping.
- Basic health, healing and fall-damage logic.
- Camera follow and a minimal health HUD.

Not yet implemented or verified:
- Original production pixel-art assets and animation set.
- Touchscreen joystick and action buttons.
- Double jump, swimming, climbing, death/respawn flow.
- World generation, mining, inventory, crafting, enemies and all later milestones.
- Android export and device performance testing.

## Run

1. Install a stable Godot 4.x build.
2. Clone this repository.
3. Import the folder containing `project.godot`.
4. Press **F6** to run the main scene, or **F5** to run the project.

## Controls

- A / Left Arrow: move left
- D / Right Arrow: move right
- Space: jump
- Shift: run

## Project structure

- `scenes/` — reusable Godot scenes
- `scripts/` — gameplay code
- `data/` — data-driven definitions (to be added)
- `assets/` — original art, audio and fonts (to be added)
- `tests/` — automated gameplay tests (to be added)
- `docs/` — architecture and development notes

## Development policy

Features are marked complete only after validation and gameplay testing. The project is being developed incrementally; this initial commit is a foundation, not a finished game.
