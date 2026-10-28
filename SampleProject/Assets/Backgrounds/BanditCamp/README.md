# Bandit Camp planes

**AI-generated.** `gen_back.png` came from `Scripts/Tools/comfy_backdrop.py` (layer `BanditCamp/gen_back`, D643) with
**Qwen-Image** (Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). It was cut into
planes like the Lizard Cave (B162) with `design/shots/candidates/camp_planes/camp_planes.py`: **Qwen-Image-Edit-2511**
(Apache 2.0, GGUF Q5 by unsloth) painted the far view, made the sky masks and repainted the sand behind the sacks; the
pixels are the original's, in its 16 colours. A Steam release has to disclose AI-generated content.

Placed in `SampleProject/Maps/BanditCamp.tscn` → `Back` (z −10), back to front:

- `gen_far.png` — the sky and the big dunes with the camp removed; mirrored twice (1152 px, seamless). `Back/Far`, ×0.4.
- `gen_mid.png` — the palisade, the weapon racks, the tents, the crates, the pots and the sand up to the walk line; the
  sky and the dune are transparent. `Back/Mid`, ×0.8.
- `Back/Props`, ×0.9: the two sacks and the barrel on the walk line — `prop_sack_near.png` / `prop_barrel_near.png`
  since A13 (the old one-piece `gen_sacks.png` is deleted).
- `gen_floor.png` — the sand below the walk line (45 rows, to the bottom of the frame); row 0 is the walk line y 416, a
  drawn light edge with a shadow row under it. `Back/Floor`, ×1.0, repeats; also the floor of the other desert rooms
  (`build_world_rooms.py` «desert»: CanyonFloor, Chasm, Dunes, GateApproach, MesaTop, ZahraRest).
  **A8** (2026-10-28, `camp_planes.py fix`): it was the camp picture's own rows under the walk line — a rock and a bush
  sliced flat by the walk line, a straight vertical cut at x 397 (the edge of the patch under the removed sacks) and half
  the strip one violet slab. Now sand seen from above at a low angle, from the terrain painter's AI-generated
  `sand_floor` texture (Qwen-Image), in the camp's 16 colours: light sand at the far edge, violet shadow patches that
  thicken toward the near edge, pebbles; seamless.
- `gen_mid.png` A8: the pink horizon scraps left on the stake tips and the pink cloud at the palisade's right end
  (sky remnants of the cut) are transparent now.

`gen_back.png` is no longer in the scene; it is the source the planes are cut from.

`gen_gate.png` — the stockade gate (`Gate_Stockade`, a LockedDoor; the camp key): lashed poles, lizard skulls and a
brass lock, floor to ceiling. Candidate `gate_c` of `design/shots/candidates/cave_gate/cave_gate.py` (Qwen-Image,
Apache 2.0, AI-generated), picked by Sapega 2026-10-27. Its body spans the poles (184 px) so the hero stops at their
near face; the whole gate fades when it opens.

## A13 (B189, D814), 2026-10-28 — props out of the planes, at chart size

`gen_mid.png` had a barrel, a stack of crates and a sack painted in at 1.3–2× the chart; `gen_sacks.png` is a sack, a
barrel and a sack at 2.5–3.9× (its barrel 80 art px). `Scripts/Tools/unbake_props.py` (Qwen-Image-Edit-2511, Apache
2.0, AI-generated) repainted `gen_mid.png` without them — only the pixels the props covered change (the sand, the
palisade and the striped tent's foot continue; a second pass took the sack the first left), in the plane's own colours;
the original is `design/shots/candidates/a13/camp_orig.png`. `gen_sacks.png` was swapped for the sprites below
when they were wired (D813).

The props are separate sprites from `Scripts/Tools/comfy_backdrop.py` (layers `BanditCamp/prop_*`, **Qwen-Image**,
Apache 2.0, AI-generated), exactly `round(chart art px × the plane's scroll_scale)` tall (barrel 32, crate 32, sack 24
art; world px = art × 1.5), trimmed, in the camp's 16-colour palette (`unbake_props.py props`). To wire: a `Sprite2D`
child of the named plane, `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`,
`offset = (−width / 2, −height)` — so `position` is the prop's feet (bottom centre) in that plane's local coordinates:

| File | Size (art) | Plane | Feet `position` | Was |
|---|---|---|---|---|
| `prop_barrel.png` | 21×26 | `Back/Mid` (×0.8) | (114, 297) | the barrel by the palisade |
| `prop_crate.png` | 27×26 | `Back/Mid` | (499.5, 315) | crate stack, front left |
| `prop_crate.png` | 27×26 | `Back/Mid` | (609, 331.5) | crate stack, front right |
| `prop_crate.png` | 27×26 | `Back/Mid` | (570, 283.5) | crate stack, on top of the two |
| `prop_sack.png` | 14×19 | `Back/Mid` | (678, 324) | the sack at the tent's foot |
| `prop_sack_near.png` | 17×21 | `Back/Props` (×0.9) | (340.5, 420.5) | `gen_sacks` left sack |
| `prop_barrel_near.png` | 24×29 | `Back/Props` | (427.5, 420.5) | `gen_sacks` barrel |
| `prop_sack_near.png` | 17×21 | `Back/Props` | (511.5, 420.5) | `gen_sacks` right sack (flip_h for variety) |

**Wired 2026-10-28** (B189): the eight sprites above are `Back/Mid/{Barrel,CrateL,CrateR,CrateTop,Sack}` and
`Back/Props/{SackL,Barrel,SackR}`; `Back/Props/Sprite` and `gen_sacks.png` are gone. `Back/Mid` repeats every 864 px, so its props repeat with it.
