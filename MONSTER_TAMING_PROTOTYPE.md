# Veldara — Monster Taming Prototype (PC)

This branch adds a first playable prototype loop to the existing Unity 6 URP starter project.

## Included
- Procedural low-poly meadow test arena, tamer, and roaming wild monsters.
- Capture attempts with level-based success odds and coin reward/penalty.
- Monster collection and active partner switching.
- Training: every three training actions grant one level and increase power.
- Evolution at level 5 with three original lines: Mossling → Thornback → Verdantaur; Embercub → Flarefang → Solwyrm; Pebblit → Cragolem → Mountainox.
- On-screen controls and status feedback; no imported art required.

## Controls
- **WASD / Arrow keys** — move
- **E** — capture nearest wild monster in range
- **T** — train active partner
- **U** — evolve at level 5
- **Tab** — switch active partner

## How it works
Assets/Scripts/VeldaraPrototype.cs initializes after the first scene loads and builds the test arena at runtime. Existing SampleScene.unity and main are left untouched.

## Known limitations
- Prototype visuals use primitive shapes and Unity IMGUI, not final art or production UI.
- Progress resets when the game restarts; no save system, battle AI, items, quests, audio, or authored animations yet.
- This task could not launch Unity Editor or run a player build, so compilation and in-editor behavior still need verification on a PC with Unity 6000.6.5f1.

## Try it
1. Open the project in Unity 6000.6.5f1.
2. Wait for package resolution and script compilation.
3. Open Assets/Scenes/SampleScene.unity and press Play.
4. Capture with E, train with T, and evolve with U once the partner reaches level 5.
