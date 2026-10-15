# Veldara — Godot 2.5D rebuild

This folder is a new Godot 4 project scaffold on a separate feature branch. The existing Unity project files are intentionally left untouched; this is a migration foundation, not a claim that Unity assets have already been converted.

## Open and run
1. Install Godot 4.4 or newer.
2. Open `godot/project.godot` in the Godot Project Manager.
3. Press **F6** to run the main scene, or **F5** to run the project.

## Prototype controls
- **WASD / Arrow keys** — move the tamer
- **E** — catch the wild Cinderling when nearby
- **T** — train the companion and gain EXP
- **V** — evolve after reaching level 3

## Current scope
- Fixed angled 3D camera for a 2.5D presentation
- Runtime-generated placeholder terrain, tamer, companion, and wild creature
- Basic catch / training / level-up / evolution loop
- Lightweight GL Compatibility renderer as a baseline

## Next migration stages
1. Replace placeholder meshes with reviewed reusable assets.
2. Add data-driven monster definitions, stats, elements, skills, and evolution requirements.
3. Add animation state machines, combat, quests, inventory, saving, and real environment art.
4. Run Godot headless parse/import checks and gameplay tests before considering the prototype validated.

No deployment, merge, or changes to `main` are part of this work.
