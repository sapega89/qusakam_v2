# Ambient critters — birds (A21 slice 2, [[ambient_critters_plan]], D774)

`bird.png` (a desert lark: outdoors, the Village) and `pigeon.png` (the City) — **AI-generated** (a Steam release has
to disclose it) by `python -I -B Scripts/Tools/comfy_sprite.py critter_bird` / `critter_pigeon` with the local
ComfyUI, **Qwen-Image-Edit-2511** (Alibaba Qwen, licence **Apache 2.0**; GGUF Q5_K_M by unsloth) + Lightning LoRA.
Reference: the hero's artist frame (`Sprites/Player/Walk/1.png`), for the style and the pixel size (not the vulture
sheet: it is drawn at enemy size). Seeds 111 / 112, no picks by Sapega yet.

Facing right, the feet (lowest pixel) on the bottom row of the cell; scenes flip for the left.

| File | Cell | Row 0 | Row 1 |
|---|---|---|---|
| `bird.png` | 48×48 | `perch` 2 (frame 2: head and body 1 px lower, `BOB`) | `fly` 4: wings up, level, downstroke, level |
| `pigeon.png` | 56×56 (bigger bird, wings up are 50 px) | `perch` 2 (`BOB`) | `fly` 4: wings up, level, downstroke, level (feet down — a take-off) |
| `butterfly.png` | 40×40 (in flight ~25 px, perched ~10×14 — smaller than the lark) | `perch` 2: wings closed, wings open | `fly` 4: wings up, open, downstroke, open |
| `butterfly_blue.png` | 40×40 | the same frames, hue turned to an oasis blue | |
| `moth.png` | 40×40 | the same frames, dusty grey-brown (caves, night interiors) | |
| `mouse.png` | 16×16 (sitting exactly 12 art px tall, running 10–11 × 14) | `idle` 2: sitting up, frame 2 head and shoulders 1 px lower (`BOB:56`, the sniff / whisker twitch) | `run` 4: stretched, mid, gathered (tail up), mid (frame 2 repeated) |

**Atmosphere (A23, slice 2b).** `butterfly.png` — `comfy_sprite.py critter_butterfly` (Qwen-Image-Edit-2511, as the
birds), seed 121; the perched "wings open" frame is the flight's open-wing frame (the model kept the wings shut when
sitting). `butterfly_blue.png` and `moth.png` are its frames recoloured by `Scripts/Tools/draw_atmosphere.py` (a
generated moth came out lark-sized with wings that did not move between frames). The same script draws the particle
textures, not AI-generated: `glow_firefly.png` (9×9, warm core, 3 alpha steps), `glow_spore.png` (7×7, pale core, cold
halo), `glow_dust.png` (3×3 mote), `glow_shaft.png` (16×96 light streak, low alpha), colours from the Lizard Cave
palette. Sheet: `design/shots/atmosphere_sprites.png`. Placement is the room routine's (`m6_backdrops`).

The bat critter uses the enemy sheet `Enemies/bat/sheet.png` (`critter_bat.tscn`). Sound: `critter_flap`.

**Mouse (R2).** `mouse.png` — a desert mouse that runs along the floor into a hole when the hero comes near; `comfy_sprite.py critter_mouse` (Qwen-Image-Edit-2511, as the birds), seed 131, the run frames from the first run frame (`FROM:run:0`). The model drew it about 45 art px tall whatever the prompt asked, so the `height=12` option scales every generated frame by one factor (0.245) until the sitting frame is exactly 12 art px with its outline ([[world_scale_plan]]: butterfly, moth, mouse); the silhouette is thickened by a quarter block first, or the 1-px tail vanished. Sheet next to the hero: `design/shots/critters_mouse.png`. The hole and the placement are the room routine's.
