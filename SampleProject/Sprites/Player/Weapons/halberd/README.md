# Kusakam with a two-handed halberd (BACKLOG 42, art A3, D267)

**AI-generated** (a Steam release has to disclose it). Made by `Scripts/Tools/comfy_sprite.py hero_weapon_halberd`
with the local ComfyUI, model **Qwen-Image-Edit-2511** (unsloth GGUF Q5_K_M, licence **Apache 2.0**) + the
Lightning 4-step LoRA. The first frame is the sword set's `sword/CombatIdle/1.png` with the sword replaced by a
halberd; the attacks, block and hurt are made from that frame or from already good frames of this set (`FROM:`);
run and air from the artist's own frames (`Run/N`, `Jump/2–3`, `Fall/2`) with only the halberd added. The artist's
colours only.

Not wired into `Player.tscn` yet.

- Cell **96×96**, the same as the sword set: the hero's body sits where it does in the sword frames, feet on row
  **88** (= row 56 of the 64×64 frames + 32). Faces right; flip for the left.
- The halberd head (axe blade, back spike, spear tip) is drawn in the sword's metal key colours on a brown wooden
  pole — the colours a palette-swap shader recolours per item (BACKLOG 42). The pole is about the hero's height.
- Two-handed in the combat poses (D267: thrusts and a low sweep). Air carries it in one hand, slanted back over the
  shoulder with the head behind the hero (the model kept a helmet on him when asked for the head forward).
- **One halberd head in every attack frame.** Level or low, the model drew a big symmetric double axe, so
  `Scripts/Tools/halberd_fixups.py` (run it after every `comfy_sprite.py hero_weapon_halberd`, which overwrites the
  frames) replaces the model's head in `Attack1–3` and `Heavy` with the small single-blade head of `CombatIdle/1`,
  turned to each frame's pole angle with RotSprite (Scale2x ×8, nearest rotation, centre sampling). Facing forward
  the blade hangs below the pole.
- **Run** is built by the same script, not by the model (the model changed the head size and the slant every frame):
  the artist's run frames with one fixed halberd behind his back — the same head, the pole 29° off vertical, head up
  and behind; it moves only with his bounce.
- The pole reaches the cell edges in the low poses (`Attack1`, `Attack2`, `Attack3`, `Heavy/3`: x 0–92).

| Folder | Frames | Pose |
|---|---|---|
| `CombatIdle/1–4` | 4 | stance, both hands on the pole, head up and forward; 2–3 = breathing (`BOB:76`) |
| `Run/1–7` | 7 | the artist's run (no `Run/2`, as for the sword) + the fixed halberd behind him; feet follow his bounce (rows 88–90) |
| `Air/1–3` | 3 | jump rise, apex, fall (from `Jump/2`, `Jump/3`, `Fall/2`) |
| `Attack1/1–3` | 3 | thrust with the pole level at chest height: pull back, lunging thrust (tip at x 89), recover |
| `Attack2/1–3` | 3 | low sweep arc: head low behind his back foot, head sweeping past the front foot, follow-through at knee height |
| `Attack3/1–3` | 3 | finisher: coiled with the pole at the belly, long low lunge (pole below the chin), recover with the head low |
| `Heavy/1–3` | 3 | overhead arc: wind-up (head high behind his head), chop (head in front at head height), head on the ground in front |
| `Block/1` | 1 | pole upright before the chest, head above his head |
| `Hurt/1` | 1 | recoil, head tipped back, halberd tilted over the shoulder |
