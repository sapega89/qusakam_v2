# Grandfather's attic planes (M6b-1)

**AI-generated.** Made with `design/shots/candidates/m6b1/m6b1.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0), and
**Qwen-Image-Edit-2511** (Apache 2.0) to clear the floors and walls the model painted behind the props and to turn the
figurine into a plain robed clay figure. The floor is `../ElderHouse/gen_floor.png` (the same house) with the hatch cut
in. A Steam release has to disclose AI-generated content. Review: `design/shots/m6b1_cave_attic.png`.

The room: interior, 1 screen (576 × 324 art = 864 × 486 world), above the grandfather's house (`ElderHouse`). The
hero climbs up the ladder through the **hatch** in the floor. Lore: his prayer corner with the statuette of the Maiden
nobody prays to any more and his notes on the barrier (journal story `grandfather_notes`), his stored things (chest,
carpets, baskets, jars, a shaman's hand drum), dried herbs under the roof. The camera does not move; parallax is
moot, the planes are kept separate so props sit in front of the wall and the foreground in front of the hero.

Walk line row 277 art = y 416 world. Hatch opening: art x 300–344 (world 450–516), dark through the floor's whole
depth; the ladder's top sticks 40 art above the floor.

## Planes, back to front (art px, room-local; scale 1.5)

| file | size | factor | anchor (x, y) | what |
|---|---|---|---|---|
| `gen_wall.png` | 576×324 | 1.0 | (0, 0) | rafters and reed matting under the pitched roof, the adobe gable with a round window and a beam of dusty light, cobwebs |
| `gen_floor.png` | 576×64 | 1.0 | (0, 277) | plank floor (row 0 = walk line) with the hatch opening at x 300–344 |
| `gen_clutter.png` | 160×70 | 1.0 | (30, 210) | his belongings: iron-bound chest, rolled carpets, baskets, jars, the drum |
| `gen_shrine.png` | 56×54 | 1.0 | (440, 226) | the prayer corner: low table, the clay statuette, candle, prayer beads, his notes, ink pot — the notes pickup goes here |
| `gen_hatch.png` | 22×60 | 1.0 | (311, 237) | the ladder's top, rising out of the hatch (its foot 20 art down in the hole); over the floor |
| `gen_front.png` | 102×120 | 1.3 | (520, −4) | foreground (D774): a beam end with hanging dried herbs and peppers, shaded dark, top right corner |

Atmosphere for the room routine: dust motes in the window beam, a candle flicker on the shrine.
