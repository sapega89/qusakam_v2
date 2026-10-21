# NPCs (D239)

**AI-generated** by `Scripts/Tools/comfy_sprite.py <npc>`: the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba Qwen,
Apache 2.0; GGUF Q5_K_M by unsloth) and its Lightning LoRA (lightx2v, Apache 2.0). The first frame is made from the
hero's own sprite (`SampleProject/Sprites/Player/Walk/1.png`) as the style reference, the second from the first.
64×96 cells at the hero's pixel (×1.5 in the game) — adults stand 1.5× the hero's height (D172). A Steam release has
to disclose AI-generated content. Replaces the Figma NPC art of D107 and the old man's 48 px sheet.

| Folder | Used by | Frames |
|---|---|---|
| `blacksmith/sheet.png` | `Scenes/Gameplay/Objects/NPCs/blacksmith.tscn` | row 0 three-quarter `talk` 0–1, row 1 profile `walk` 4–7, row 2 front `idle` 8–9 (D292); feet row 91 |
| `merchant/sheet.png` | `Scenes/Gameplay/Objects/NPCs/merchant.tscn` | row 0 three-quarter `talk` 0–1, row 1 profile `walk` 4–7, row 2 front `idle` 8–9 (D292); feet row 89 |
| `old_man/sheet.png` | `Maps/Village.tscn` → OldMan (flipped, faces left) | idle 0–1, feet row 89 |
| `gate_guard/sheet.png` | `Scenes/Gameplay/Objects/NPCs/gate_guard.tscn` → CityGates GuardLeft/GuardRight (flipped, face the road; D258) | idle 0–1, feet row 91 |
| `priest/sheet.png` | `Scenes/Gameplay/Objects/NPCs/oath_priest.tscn` → City OathPriest (D281) | row 0 profile (faces **left**), row 1 front; feet row 90 |
| `witch/sheet.png` | `Scenes/Gameplay/Objects/NPCs/oath_witch.tscn` → City OathWitch (D281) | row 0 profile (faces right), row 1 front; feet row 90 |
| `dervish/sheet.png` | `Scenes/Gameplay/Objects/NPCs/oath_dervish.tscn` → City OathDervish (D281) | row 0 profile (faces right), row 1 front; feet row 91 |
| `malik/sheet.png` | `Scenes/Gameplay/Objects/NPCs/lab_malik.tscn` → LabCells Malik (D303) | row 0 idle profile (faces right), row 1 walk, row 2 front; feet row 91 |
| `prisoner/sheet.png` | `Scenes/Gameplay/Objects/NPCs/lab_prisoner.tscn` → LabCells Prisoner (D303) | idle, walk, shout, collapse, front; feet row 91 |
| `alchemist/sheet.png` | `Scenes/Gameplay/Objects/NPCs/lab_alchemist.tscn` → LabCells Scientist (D303) | idle, walk, inject, front; feet row 91 |
