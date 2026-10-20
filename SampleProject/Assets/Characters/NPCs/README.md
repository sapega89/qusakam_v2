# NPCs (D239)

**AI-generated** by `Scripts/Tools/comfy_sprite.py <npc>`: the local ComfyUI with **Qwen-Image-Edit-2511** (Alibaba Qwen,
Apache 2.0; GGUF Q5_K_M by unsloth) and its Lightning LoRA (lightx2v, Apache 2.0). The first frame is made from the
hero's own sprite (`SampleProject/Sprites/Player/Walk/1.png`) as the style reference, the second from the first.
64×96 cells at the hero's pixel (×1.5 in the game) — adults stand 1.5× the hero's height (D172). A Steam release has
to disclose AI-generated content. Replaces the Figma NPC art of D107 and the old man's 48 px sheet.

| Folder | Used by | Frames |
|---|---|---|
| `blacksmith/sheet.png` | `Scenes/Gameplay/Objects/NPCs/blacksmith.tscn` | idle 0–1, feet row 91 |
| `merchant/sheet.png` | `Scenes/Gameplay/Objects/NPCs/merchant.tscn` | idle 0–1, feet row 89 |
| `old_man/sheet.png` | `Maps/Village.tscn` → OldMan (flipped, faces left) | idle 0–1, feet row 89 |
| `gate_guard/sheet.png` | `Scenes/Gameplay/Objects/NPCs/gate_guard.tscn` → CityGates GuardLeft/GuardRight (flipped, face the road; D258) | idle 0–1, feet row 91 |
