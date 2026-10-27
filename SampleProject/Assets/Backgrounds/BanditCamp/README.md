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
- `gen_sacks.png` — the two sacks and the barrel that stood on the walk line, cut out as one prop. `Back/Props`, ×0.9,
  feet 4 px under the floor's edge.
- `gen_floor.png` — the camp's own sand below the walk line (45 rows, to the bottom of the frame); row 0 is the walk
  line y 416, a drawn light edge with a shadow row under it. `Back/Floor`, ×1.0, repeats.

`gen_back.png` is no longer in the scene; it is the source the planes are cut from.

`gen_gate.png` — the stockade gate (`Gate_Stockade`, a LockedDoor; the camp key): lashed poles, lizard skulls and a
brass lock, floor to ceiling. Candidate `gate_c` of `design/shots/candidates/cave_gate/cave_gate.py` (Qwen-Image,
Apache 2.0, AI-generated), picked by Sapega 2026-10-27. Its body spans the poles (184 px) so the hero stops at their
near face; the whole gate fades when it opens.
