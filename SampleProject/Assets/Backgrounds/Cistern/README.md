# Cistern planes (M6c-3)

**AI-generated.** Made with `design/shots/candidates/m6c3/m6c3.py` on top of `Scripts/Tools/comfy_backdrop.py`, using
**Qwen-Image** (Alibaba Qwen, Apache 2.0) with the Qwen-Image-Lightning LoRA (lightx2v, Apache 2.0). Brought down ×3 to
the game's pixel and a few colours (octree); the depths, the columns and the dragon are darkened toward violet for
depth. Reused from the Aqueduct (the same old waterworks): the vault strip, the walkway floor, the cellar arch and its
grate, the rockfall and the vault-pier front. A Steam release has to disclose AI-generated content. Review:
`design/shots/m6c3_archive_cistern.png` (frames 2–6).

The room (`Maps/Cistern.tscn`): underground, 3 cells (1728 × 320 art = 2592 × 480 world) at [22,7], under the market;
floor y 384 world (art row 256), camera x 0…1152 art, y fixed. The City's old cistern, fed by the aqueduct (D773): a
forest of columns with carved capitals standing in still **green water**, low half-empty («Water's dearer than oil these
days», the market crowd) — the old water lines run high on the columns; a walkway along the edge; one column stands on a
**carved stone dragon head** (dragons «like deities», as the Aqueduct's spout and the Old Ruins' relief). Its passages,
all painted (D747):

- **`CellarDoor`** (x 140, gate `cistern_cellar`) — the gatehouse cellar's barred arch: the Aqueduct's arch and grate
  (`../Aqueduct/gen_cellar.png` + `gen_grate.png`, 128 art), the same cellar on its other side. Hide the grate once
  `cistern_cellar_open` is set; `CellarLever` (x 290, `lever.tscn`) stands right of the arch.
- **`WellDoor`** (x 1700, the Arrival) — the **well shaft**: a pillar of fitted blocks with a narrow shaft, iron rungs
  set in its back wall (world_structure_plan: «iron rungs in stone for the city cellars»), a rope with a bucket; it
  rises into the vault (the vault strip is drawn over its top). No hole in the floor (B201). The market end is a hatch
  (D836/Q-d), so this is the shaft that hatch drops down.
- **`StashDoor`** (x 2300, behind `Wall_Stash`) — the **end wall** of the cistern (`gen_end.png`) has an old breach,
  walled up with smaller blocks and cracked: that patch is `Wall_Stash`'s picture (`gen_cracked.png`, 124 art); a heavy
  hit breaks it and the dark breach behind (opening 112) leads down into the stash.
- **East edge** — the end wall, its corner closed by the Aqueduct's rockfall.

## Planes, back to front

Art px, room-local; every sprite `texture_filter = 1`, `scale = (1.5, 1.5)`, `centered = false`. A Parallax2D plane
with factor f is drawn at anchor − f × camera (camera = view left edge), so the positions below hold with the camera at
the room's left end. Tiles: `repeat_size = (864, 0)`, `repeat_times` 5.

| node (replaces) | file | size | factor | position (world) | what |
|---|---|---|---|---|---|
| `Back/Far` (Cellar far ×0.4, `repeat_size` 1728 → 864) | `gen_far.png` | 576×324 | 0.45 | (0, 0); tile, opaque | the cistern's depths: rows of columns with capitals and brick arches over green water, thin light from holes in the vault |
| `Back/Mid` (Cellar mid ×0.8) → `Back/Columns` ×0.75 | `gen_columns.png` | 576×256 | 0.75 | (0, 3); tile | thick columns with carved capitals, old water lines high on them, their feet in a strip of green water just above the walk line |
| `Back/Dragon` (new Parallax2D ×0.85, one Sprite2D) | `gen_dragon.png` | 166×200 | 0.85 | (843, 87) | a column standing on a carved dragon head lying on its side, slime and water stains; the head about a man's height; its capital under the vault strip; mid-screen at camera 420 art (630 world) |
| `CellarDoorEntrance` → `CellarArch` (Sprite2D, `z_index = -2`) | `../Aqueduct/gen_cellar.png` | 181×163 | 1.0 | (4.5, 142.5) | the cellar arch, opening empty and dark, centred on x 140 world, threshold on the walk line |
| `CellarGrate` (Sprite2D, `z_index = -2`, after `CellarArch`) | `../Aqueduct/gen_grate.png` | 181×163 | 1.0 | (4.5, 142.5) | the rusted grate alone, 128 art; visible while `cistern_cellar_open` is unset |
| `WellDoorEntrance` → `Well` (Sprite2D, `z_index = -2`) | `gen_well.png` | 88×258 | 1.0 | (1632, 0) | the well shaft with iron rungs, rope and bucket; the shaft centred on x 1700 world, foot on the walk line |
| `EndWall` (new Sprite2D, `z_index = -2`) | `gen_end.png` | 220×258 | 1.0 | (2137.5, 0) | the cistern's end wall of big blocks with moss and water stains; the **breach** (112 art) centred on x 2300 world, fallen blocks at its left foot |
| `Rubble` (new Sprite2D, `z_index = -2`) | `../Aqueduct/gen_rubble.png` | 102×258 | 1.0 | (2454, 0) | fallen vault blocks in the east corner, past the edge by 15 world |
| `Ceiling` (new Sprite2D, `z_index = -2`, **after** `Well` and `EndWall`; `region_enabled`, `region_rect = Rect2(576, 0, 1728, 110)`) | `../Aqueduct/gen_ceiling.png` | 1728×110 | 1.0 | (0, 0) | the vault's band of fitted blocks with roots and stains — the Aqueduct strip without its breach tile; the shaft and the end wall run up behind it |
| `Ground/Floor1` (Cellar floor → this, `region_rect = Rect2(0, 0, 1728, 64)`, `texture_repeat = 2`) | `../Aqueduct/gen_floor.png` | 576×64 | 1.0 | (0, 384) | the walkway over the conduit, green water in its channels; opaque to the room's bottom (`Fill1` may go) |
| `Wall_Stash/Sprite` (its placeholder offset) | `gen_cracked.png` | 88×124 | 1.0 | `Wall_Stash` stays at (2300, 384); Sprite: `texture` this file, `scale = (1.5, 1.5)`, `offset = (0, -60)`, `centered` true, `z_index = -1` as now | the walled-up breach: smaller blocks split by one jagged crack, a few loose; covers the breach whole, bottom 2 art under the walk line |
| `FrontDark` = `foreground_dark.tscn` (new) + Sprite2Ds `Pier1`, `Pier2` | `../Aqueduct/gen_front.png` | 135×340 | 1.3 | (819, −66) and (1500, −66) | the Aqueduct's vault pier with a ring and a broken chain, darkened (D750); mid-screen at camera 250 and 600 art; at the Arrival (camera 845) only Pier2's edge shows at the left; off screen at the grate (camera 0) and the end wall (camera 1152) |

**The doors are painted.** Delete `WellDoorEntrance`, `CellarDoorEntrance` and `StashDoorEntrance` (the `cave_mouth`
placeholders); `WellDoor` → (1700, 330), `CellarDoor` → (140, 330), `StashDoor` → (2300, 330) (`cover` stays
`Wall_Stash`). Add to `PAINTED` in `verify_room_entrances.gd`: `"Cistern/WellDoor": "the well shaft with iron rungs"`,
`"Cistern/CellarDoor": "the barred cellar arch"`, `"Cistern/StashDoor": "the cracked breach in the end wall"`.

**The scene is generated.** `Scripts/Tools/build_world_rooms.py` rewrites the new rooms (D833): wire these planes there
(the three doors' art becomes `None`), or take `Cistern` out of its list once wired by hand. `python -B
design/shots/candidates/m6c3/m6c3.py wiring` prints the positions.

Atmosphere for the room routine: a pale light column with dust down the well shaft at the Arrival, drips glinting into
the green water at the columns' feet, ripples, a bat on the vault (`critter_bat`); sound: drips, a hollow echo, the
market's murmur faint through the shaft.
