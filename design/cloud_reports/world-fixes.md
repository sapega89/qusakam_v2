---
type: report
status: done
tags: [cloud, world, rooms, camera]
---

# Cloud report: `cloud/world-fixes` (2026-10-23)

**Summary.** All four of Sapega's 2026-10-23 world calls are built and checked in in-game captures of every outdoor room.
- **D446:** an `ItemPickup` is now an animated pixel sparkle (SVG). The item is named only in the pickup modal.
- **D448:** the stray earth column and the floating ledge were in **CityGates**, not the Desert Road. Both are removed from collision and from the painted terrain. Nothing lay on that ledge, so `Chest_CaravanLedge` stays where it is (D545).
- **D451:** the CityGates gate is now drawn under the road. The City's copy of the gate is removed, as the gate where no gate belongs (D546, which amends D314).
- **D483:** outdoor rooms now put the floor at 85 % of the screen. The view goes 24 units above the room's top edge, and a sky strip in the backdrop covers that area (D547).
- Not done: indoor rooms keep their old camera limits (D547). The `room-content` skill is not in this checkout, because `.claude/` is gitignored, so I worked without it.
- D-ID text for D545–D548 is below (renumbered from D523–D526 at merge). No B rows were fixed. Full suite: 97 PASS and 1 FAIL (`verify_living_world`, "City: has banner decor", fixed afterwards and re-run as ALL PASS).

## D-ID text (the orchestrator applies it to the register)

| ID | Kind | Text |
|---|---|---|
| D545 | GAP (`cloud/world-fixes`) | **Where D448's pieces were.** The column and the ledge from Sapega's screenshot are at the west end of **CityGates**: Foreground tiles x 0–2 × y 0–8 (world 0–96 × 0–288, the column) and x 12–14 × y 7 (world 384–480 × 224–256, the ledge in front of the walls). Both are erased from `TileMap/Foreground`, and their two separate pieces of `CityGates_Terrain.png` are cleared. The floor tiles are unchanged. Nothing lay on that ledge. `Chest_CaravanLedge` (DesertRoad x 4144) stands on a solid stepped mesa that is joined to the ground, not on a floating ledge, so it stays there. The out-of-room tiles at x ≥ 1792 are never on screen and are left as they are. Agent call, Sapega to confirm. |
| D546 | OVERRIDE of part of D314 (`cloud/world-fixes`) | **One gate, and the road over its feet.** In CityGates, `GatePassage` now comes before `Terrain` in the scene tree, so the road draws over the feet of the towers. The hero still draws in front of every gate layer (z 1 over 0 / −1). The City's own `GatePassage` instance at (−407, 127) is removed. It was the gate standing behind the market awnings in Sapega's shot («ворота наче тут не мають бути»): the hero has just walked through the same gate in CityGates. The room change still happens inside the CityGates passage. The removed gate carried the City's only banners (D392, checked by `verify_living_world`), so two existing `Decor/banner.tscn` instances now hang in a new `City/Decor`: one on the Forge chimney (1060, 215) and one on the Chapel wall (1560, 230). The other outdoor rooms already had their buildings under `Terrain`, so nothing changed there. `verify_city_gates_raid` [8] asserts the new order and that the City has no gate. Agent call: the choice of *which* gate is mine, so Sapega should confirm. |
| D547 | GAP (`cloud/world-fixes`) | **How D483 is built.** Each outdoor room (Village, Canyon, DesertRoad, CityGates, City, LaboratoryOutside) has `metadata/camera_floor_y = 384` on its root. After `adjust_camera_limits`, `Game._raise_camera_bottom()` sets `limit_bottom = floor + 15 % of the view height` (456 at 480 units) and lowers `limit_top` so that one full view fits (−24). The floor then sits at 85 % of the screen. In the 2-cell-high rooms (Village, Canyon, Laboratory Outside) the camera used to follow the hero down and showed about 45 % ground. Now it shows 15 %. Both desert backdrops have a new `Plan5/SkyTop` strip (the top 4 px row of the sky, stretched to 96 units above y 0), so the view above the room shows sky with no blank. The Canyon exit cut-scene sets the bottom limit back to the room's full height before the climb down, so the hero stays in view below the floor. Indoor rooms have no metadata and keep the MetSys cell limits: they have no backdrop above their top edge, so raising their camera would show blank. That needs art or a separate call. |
| D548 | GAP (`cloud/world-fixes`) | **The D446 sparkle.** `Assets/World/pickup_sparkle.svg`: four 11 × 11 pixel frames (a dot, a cross, a peak with a long 4-point cross, a fading ring) in ACCENT gold `#D4AF37`, warm white `#FFF8E0` and a dark gold. The scale is ×3 (two pixels of the hero's ×1.5). At ×1.5 it was too faint to notice in a full frame. The `glint` animation in the scene loops every 1.6 s and mostly rests on the dot. `ItemPickup.gd` no longer sets the item icon. An unknown `item_id` still disables the pickup. |

## Details

- **D446:** `Objects/ItemPickup.tscn` has a Sprite2D (sparkle, hframes 4, nearest filter, ×3) and an AnimationPlayer `glint` that autoplays. `Scripts/Gameplay/ItemPickup.gd` no longer has the `_sprite` icon line. `verify_interaction` [6] asserts the sparkle texture, that it is not the item icon, and that `glint` is playing. Shot: `design/shots/world_fixes/sparkle.png` (4 frames, full size, Pickup_DuneLedge).
- **D448:** `Maps/CityGates.tscn` has the new `TileMap/Foreground` data. In `Assets/Backgrounds/Terrain/CityGates_Terrain.png`, pixel rects (0,0)–(63,190) and (256,146)–(319,170) are cleared. These were separate pieces of the image, not joined to the floor.
- **D451:** `Maps/CityGates.tscn` has `GatePassage` moved before `Terrain`. In `Maps/City.tscn`, `GatePassage` and its `ext_resource` are removed, and a new `Decor` holds `Banner1` and `Banner2`.
- **D483:** `Scripts/Game.gd` gets `CAMERA_GROUND_SHARE` and `_raise_camera_bottom()`, called in `init_room()` right after `adjust_camera_limits`. The six outdoor room roots get `metadata/camera_floor_y`. `Scenes/Backgrounds/desert_backdrop_{open,canyon}.tscn` get `Plan5/SkyTop`. `Scripts/Gameplay/Scenes/Canyon.gd` (exit cut-scene) restores the bottom limit before the climb.
- **Tools:** `SampleProject/UI/capture_world_fixes.gd` puts the hero in the middle of each MetSys column of each outdoor room, plus the sparkle frames. Run it as `-- <out_dir> [room … | sparkle]`. `Scripts/Tools/world_fixes_sheet.py` builds one before | after sheet per room.
- **Shots:** `design/shots/world_fixes/{Village,Canyon,DesertRoad,CityGates,City,LaboratoryOutside}.png` (left is before, right is after; one row per column of the room) and `sparkle.png`. The LaboratoryOutside shots drop the demo-end screen that this room opens on arrival.
- **Seen, not fixed (possible B row):** in LaboratoryOutside the hero stands at y 304, about 56 units above the painted grass line. This shows in both before and after, so something invisible there has collision. Not in this task's scope.

### RESULT lines (touched tests)

```
verify_canyon_exit       RESULT:ALL PASS
verify_city_gates_raid   RESULT: ALL PASS
verify_interaction       RESULT: ALL PASS
verify_laboratory        RESULT: ALL PASS
verify_map_geometry      RESULT: ALL PASS
verify_village_house     RESULT: ALL PASS
verify_chests            RESULT: ALL PASS
```

### Full suite

`Scripts/Tools/run_verify.sh` ran once at the end, before the City banners were added: 97 PASS and 1 FAIL.

```
FAIL  verify_living_world — RESULT: 1 FAIL, 0 SCRIPT ERROR   (  FAIL City: has banner decor)
SUITE: 1 FAIL
```

This FAIL came from removing the City gate, whose two banners were the City's banner decor. After `City/Decor` got its two banners:
`verify_living_world RESULT: ALL PASS` and `verify_city_gates_raid RESULT: ALL PASS`.
