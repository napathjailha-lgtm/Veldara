# Veldara — Demo 0: Caldra Arc

This branch now targets the original Veldara v1.4 direction: a monster-bonding action RPG set in the volcanic Caldra region. This is a playable greybox direction using Unity primitive geometry, not final art.

## Included
- Ash field, basalt ridge, glowing lava fissures, and landmarks for Caldra Village, the Old Forge, Old Mine, Volcano Crater, and Cold Anvil.
- Player movement and a following Embit partner.
- Prototype real-time combat: Space attacks the nearest enemy; enemies pursue and damage the player; defeated enemies reward bits.
- Bond Gauge grows from attacks and defeats. After Kaelen's quest, Q toggles Embit's Sprout/Bloom forms when Bond is full.
- Story NPCs Kaelen Vorr, Tessa, and Pip with contextual dialogue.
- Quest loop: talk to Kaelen, defeat the Concord Siphon at the crater, return to Kaelen, and finish the quest.
- UI for HP, Bond Gauge, bits, quest state, field notes, and dialogue.

## Controls
- WASD / Arrow keys: move
- Space: attack
- E: talk, inspect, interact
- Q: Bond Shift (after quest completion and 100 Bond)
- H: restore HP for testing
- Escape: toggle dialogue panel

## Run
Open with Unity 6000.6.5f1, wait for package resolution, open Assets/Scenes/SampleScene.unity, and press Play. The runtime bootstrap builds the greybox.

## Limitations
- Geometry uses Unity primitives. No final Blender models, authored animation, VFX, audio, save/load, mobile controls, elemental reactions, four-monster party, egg care/box, or complete branching story yet.
- Unity Editor/build cannot be launched from this environment. Compilation and gameplay must be verified in the Editor.
- Changes are on feature/monster-taming-prototype only. Do not merge to main or deploy without explicit approval.
