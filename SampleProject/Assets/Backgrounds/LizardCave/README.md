# Lizard Cave planes (B162)

**AI-generated.** `gen_back.png` came from `Scripts/Tools/comfy_backdrop.py` (layer `LizardCave/gen_back`, D643) with
**Qwen-Image** (Alibaba Qwen, Apache 2.0) and the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). B162 cut it into
planes with `design/shots/candidates/cave_planes/cave_planes.py`: **Qwen-Image-Edit-2511** (Apache 2.0, GGUF Q5 by
unsloth) made the masks and repainted the wall behind the shrines; the pixels are the original's, in its 16 colours.
A Steam release has to disclose AI-generated content.

Placed in `SampleProject/Maps/LizardCave.tscn` → `Back` (z −10), back to front:

- `gen_far.png` — sky, the stone bridge, the far canyon; mirrored twice (1152 px, seamless). `Back/Far`, ×0.4.
- `gen_wall.png` — the orange walls, the tunnel with its lit end (the exit, D729), the ceiling and the far floor; the
  opening is transparent. `Back/Wall`, ×0.8.
- `gen_shrine_a.png`, `gen_shrine_b.png` — the lizard idol shrines (b holds the bowl on the floor and the tail; its
  painted text is gone). `Back/Shrines`, ×0.9, where they stood in `gen_back.png`.
- `gen_floor.png` — the flagstone floor strip (comfy_backdrop `LizardCave/gen_floor`, Qwen-Image, in the same
  palette); row 0 is the walk line y 416. `Back/Floor`, ×1.0, repeats.

`gen_back.png` is no longer in the scene; it is the source the planes are cut from. The planes' `scroll_offset` puts
them where `gen_back.png` was when the camera is at the room's left end (Parallax2D counts from a camera centre of
960, the viewport's half width, not from the room).
- `gen_gate.png` — the shrine gate (`Gate_Shrine`, a LockedDoor; Grandfather's Old Key): a brass portcullis in a carved
  arch, floor to ceiling. Candidate `gate_b` of `design/shots/candidates/cave_gate/cave_gate.py` (Qwen-Image, Apache
  2.0, in the cave's 16 colours), picked by Sapega 2026-10-27. Its body spans the arch (210 px) so the hero stops at
  its near face; the whole gate fades when it opens.
