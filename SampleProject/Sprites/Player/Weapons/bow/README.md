# Kusakam with a bow (BACKLOG 40, art A4)

**AI-generated** (a Steam release has to disclose it). Made by `Scripts/Tools/comfy_sprite.py hero_weapon_bow` with
the local ComfyUI, model **Qwen-Image-Edit-2511** (unsloth GGUF Q5_K_M, licence **Apache 2.0**) + the Lightning 4-step
LoRA (Apache 2.0). Reference: the artist's frame `SampleProject/Sprites/Player/Walk/1.png`; the first frame (bow up,
arrow nocked) is made from it, the other draw / shoot / charged frames from that first frame (`FROM:`), the run is the
artist's `Run/1,3,4,5,7,8` with only the bow added (`ON:`). The artist's 28 colours only.

Not wired into `Player.tscn` yet.

- Cell **96×96**, the same as the sword set: feet on row **88** (= row 56 of the 64×64 frames + 32); the run keeps
  the artist's bounce (feet rows 89, 88, 89, 89, 89, 90). Faces right; flip for the left.
- Bow in the far hand, held upright in front of him; the near hand draws the string.
- Arrow spawn point (nocked arrowhead tip): about **(76, 61)** in the cell for `Draw/1–3` and `Charged/1`,
  **(82, 62)** for `Charged/2` (the glow reaches further). The projectile is `Assets/FX/Projectiles/arrow*.png`.

| Folder | Frames | Pose |
|---|---|---|
| `Draw/1–3` | 3 | bow raised, arrow nocked, string slack → half drawn → fully drawn (the change is mostly the string and the hand) |
| `Shoot/1–2` | 2 | the release (string straight, drawing hand flung back) → the bow lowered to the hip |
| `Charged/1–2` | 2 | full draw held, the arrowhead glowing cream-yellow → a bigger glow with sparks; loop the two |
| `Run/1–6` | 6 | the artist's run with the bow upright in the far hand |
