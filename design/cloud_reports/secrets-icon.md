---
type: cloud-report
branch: cloud/secrets-icon
date: 2026-10-27
---
# Cloud report: secrets-icon (extends D765, answers Sapega 2026-10-27)

**Summary.** Done: a found SecretArea now shows its own icon on the level-2 map at its position: a violet circle with a white keyhole. An unfound one shows nothing. The legend has a new row, «секрет (знайдений)» / «secret (found)». Every icon kind in the spec is drawn for the real rooms, and opened chests do dim (now tested). Nothing was missing, so nothing else needed fixing.
Not done: nothing. One finding on what was already built (B-row candidate below): the legend's «бачив вхід» swatch can't be seen on the dark plate.
**D-ID text (ROUTINE CALL, extends D765; integrate-28 numbered it D784):** «Found secrets on the map (`cloud/secrets-icon`). Sapega 2026-10-27: «В нас на карті будуть відмічатись знайдені секрети…?» → yes. D765's "no level-2 icon" is replaced: a *found* SecretArea is drawn at its node's position on level 2, in the 26 px circle style. The fill is `UITokens.MAP_ICON_SECRET` (violet `#7A4FB3`, kept well away from the blue meditation fill) and the glyph is a white keyhole (a circle over a trapezoid). It is not ✦, which is the meditation star, and not the padlock bow used for locked. An unfound secret draws nothing, so the map never gives one away. Like every other non-door icon, it appears only in an explored cell. The legend row reads «секрет (знайдений)» / «secret (found)».»
B rows fixed: none. Full suite: 132 PASS, 1 FAIL (`verify_masher`, flaky balance sim: ALL PASS on re-run here, and it fails on the untouched `cloud/secrets` base too).

## What was built
- `SampleProject/Scripts/Systems/LocationMap.gd`: `KIND_SECRET := &"secret"`. In `_classify`, a SecretArea whose room state `found_<node>` is true goes through `_mark(KIND_SECRET, pos, …)`. The position is the node's, which is also the centre of its shape.
- `SampleProject/UI/Components/map_icon.gd`: `FILL[&"secret"]` and the keyhole glyph, drawn in the 26-unit grid like the other icons.
- `SampleProject/UI/Tokens/UITokens.gd`: `MAP_ICON_SECRET := Color("7a4fb3")`. There was no teal or violet token before, so this one is new.
- `SampleProject/Scenes/Menus/Game/metsys_map_component.tscn`: `Legend/Rows/Secret` (Icon `kind = &"secret"` + Text). The plate grows down by one row, and it still fits (see the shot).
- `en.po` / `uk.po`: `"secret (found)"` → «secret (found)» / «секрет (знайдений)».
- `metsys_map_component.gd` needed no change: `_add_icons` draws any marker kind. A secret is not in `SEEN_KINDS`, so it shows only in an explored cell.

## Audit: spec icon kinds against the real rooms (new game, every location)
| Location | chests | markers |
|---|---|---|
| Canyon of Whispers | 7 | chest 7, locked 6, quest 2, save 1, exit 1, hero 1 |
| City | 1 | chest 1, locked 1, quest 1, save 1, exit 1 |
| Laboratory | 1 | chest 1, save 2 |

- Every Chest node has an icon, and so does every SavePoint, including the meditation stones under them (DesertRoad, City, Laboratory ×2). Locked doors and gated RoomDoors are marked. Quest givers depend on game state.
- No `_mark` "outside the room's MetSys cells" warning comes from any room.
- The Laboratory has no exit icon, and that is correct. The hero is carried into LabCells by the story (`MayorHall.gd:23`, D303), and LaboratoryOutside ends the demo. No door or MetSys border leads out. (The comments at `CityGates.gd:100/205` still say a MetSys connection leads to the Laboratory. They are stale, but I didn't change them.)
- Opened chests dim: `opened_<name>` → `KIND_CHEST_OPEN` → `MapIcon.dimmed` (alpha `MAP_ICON_OPENED_ALPHA` 0.4). This is now covered by verify_world_map [6b] and shown in the shot.

## Visual triage
- **B169** (filed by integrate-28; pre-existing, not fixed): the legend's «saw the entrance, not entered yet» swatch is invisible. It is drawn as a 45 % ink dashed square on the dark `MapCard` plate (`map_icon.gd` `room_seen`), so ink on near-black. See `design/shots/secrets/map_legend.png`. Proposed fix: draw the legend swatch in `MAP_ROOM_FILL` or a light token. That needs a look from someone who knows Figma 539:6615, so I left it alone.
- MesaClimb: the secret's icon sits on top of `Chest_Mesa`'s icon, because the secret zone covers the chest. Both stay readable (shot, right). This is accepted as is: the zone is where the stash is.

## Tests
- `verify_secrets`: `RESULT: ALL PASS`. New checks: no secret marker in any location while none is found; after the mural is found, exactly one marker, in DragonMural, at the node's position (432, 376); level 2 draws it as `kind secret`, not dimmed, 26 px; the legend row is present.
- `verify_world_map`: `RESULT: ALL PASS`. New section [6b]: every location has a chest icon for each chest (7/7, 1/1, 1/1). The real rooms give hero, save, chest, locked, quest and exit icons. The ElderHouse chest icon is bright while closed, and after `opened_Chest_Attic` it shows as `chest_open`, dimmed to 0.4. The game state is restored afterwards.
- Capture `SampleProject/UI/capture_secrets_icon.gd` → `design/shots/secrets/map_icon_before_after.png` (left: all cells explored in memory, chests closed, no secrets; right: every Canyon chest opened and dimmed, DragonMural and MesaTop secrets found) and `map_legend.png` (legend at 1:1).
- Full suite (`Scripts/Tools/run_verify.sh`): 132 PASS, `SUITE: 1 FAIL`. The failure is `verify_masher` «road's first fight: 2 bandits, 2 jackals (2nd try), SKILLS: wins (enemy HP left 0%)». It is a random balance simulation that this change does not touch. Re-run on this branch: `RESULT: ALL PASS`. On `origin/cloud/secrets` without this change, the same check fails, so it is a flake, not a regression.
- Also committed: Godot-generated `.uid` files for scripts that had none (SecretArea, verify_secrets, capture_secrets, …). The import created them.
