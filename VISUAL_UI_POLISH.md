# Veldara — Caldra Visual and UI Polish

Branch: `feature/caldra-visual-ui-polish`

This iteration is based on `feature/capture-training-evolution` and keeps all work isolated from `main`. No deployment or merge was performed.

## Visual changes
- Warmer volcanic lighting, softer directional shadows, adjusted fog density, and a darker atmospheric camera background.
- A custom low-poly Tamer assembled from a coat/body, face, hair, ember scarf, and shoulder satchel instead of a single plain capsule.
- A more expressive partner model with eye whites, pupils, side ears, a glowing crest, and a visible ember core.
- Wild monsters now have pupils, horns, and species-specific details; the Concord Siphon has a distinct core.
- Added emissive-looking lava fissures, obsidian shards, and warm point-light ember lanterns around Caldra.
- Updated material smoothness/metallic settings to make surfaces less uniformly flat.

## UI changes
- Darker translucent panels with warm amber titles and brighter text contrast.
- Custom button normal, hover, and active states.
- Monster HUD continues to show the active partner's HP, Bond Gauge, level, power, EXP, bits, and roster count.
- Capture, training, evolution, and partner-switch controls remain available.

## Test in Unity
1. Use Unity `6000.6.5f1`.
2. Check out `feature/caldra-visual-ui-polish`.
3. Open `Assets/Scenes/SampleScene.unity` and press Play.
4. Inspect the Tamer and partner from the default camera angle; move and rotate the Tamer to check the child meshes.
5. Visit the village forge and verify the lanterns, lava emissive materials, and NPC details.
6. Check that HUD buttons still invoke their actions and dialogue/status text remains readable at the target resolution.
7. Check the Console for shader/material warnings and runtime exceptions.

## Notes and limitations
- Art is still procedural low-poly greybox content made from Unity primitives; these are visual improvements, not final production assets.
- The HUD still uses IMGUI, not a responsive Canvas/UI Toolkit layout. Very small window sizes should be checked manually.
- This environment can edit and statically inspect repository files but cannot launch the Unity Editor or run a player build. Runtime compilation, lighting, and layout remain to be verified locally.
- No merge, deployment, or changes to `main` were made.
