# Veldara — Monster Capture, Training & Evolution

This iteration extends the Caldra greybox prototype on `feature/capture-training-evolution`. It is an offline PC prototype and does not require a server.

## Controls
- **WASD / Arrow keys** — move.
- **Space** — attack the nearest enemy.
- **E** — talk to NPCs, inspect nearby enemies, or rest at the forge.
- **C** — attempt to capture a nearby wild monster.
- **T** — train the active monster.
- **U** — evolve the active monster when eligible.
- **Tab** — switch active partner.
- **Q** — Embit's story-gated Bond Shift.
- **H** — restore Tamer and active monster HP for testing.
- The right-side roster panel also exposes Capture, Train, Evolve, and Switch buttons.

## Capture rules
- Capture range is 3.2 world units.
- Each attempt costs 5 bits.
- The roster limit is six monsters.
- Capture chance starts at 35%, increases by up to 45 percentage points as the target loses HP, and loses 8 percentage points per level the target exceeds the active monster; the final chance is clamped to 10–90%.
- A failed attempt still consumes the 5 bits. Weaken the target and try again.
- The Concord Siphon boss cannot be captured.

## Training and progression
- Training costs 3 bits, grants 12 EXP, restores up to 8 HP, and records a training session.
- Defeating an enemy grants EXP to the active monster.
- EXP required for each level is the current level multiplied by 25.
- Level-ups increase maximum HP by 8 and Power by 2, and restore HP.
- Captured Ashlings can evolve into **Cindermaw** at Lv.5 and **Pyroclast** at Lv.10.
- Captured Cinder Mites can evolve into **Emberwing** at Lv.5 and **Solwing** at Lv.10.
- Each evolution adds 20 maximum HP and 5 Power, restores HP, and updates the partner's color.
- Embit keeps its quest/Bond-gated Sprout ↔ Bloom transformation and does not use the ordinary evolution command.

## Testing checklist
1. Open the project with Unity 6000.6.5f1 and open `Assets/Scenes/SampleScene.unity`.
2. Press Play and approach an Ashling or Cinder Mite.
3. Weaken it with Space, then press C. Confirm bits are spent and the roster count changes on success.
4. Capture a second monster, then press Tab to switch partners.
5. Press T to train; confirm bits, EXP, HP, and levels change.
6. Raise a captured Ashling or Cinder Mite to Lv.5, press U, then reach Lv.10 for its second stage.
7. Confirm Embit's Q Bond Shift still requires the Kaelen quest and a full Bond Gauge.

## Limitations
- The roster and progression are runtime-only and reset when the application restarts; save/load is a follow-up task.
- This environment cannot launch Unity Editor or run a Windows player build, so compile and gameplay validation must be performed in Unity.
- No deployment, merge, or change to `main` was performed.
