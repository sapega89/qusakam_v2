---
type: cloud-report
branch: cloud/secrets
date: 2026-10-27
---
# Cloud report: secrets (D765, answers Q98)

**Summary.** Done: the invisible `SecretArea`, saved as room state (`found_<node>`), the World Map card's «Secrets c/d»
/ «Секрети c/d» counted from the nodes, a soft chime and a «Secret found» toast. Seven secrets are placed in six rooms.
Not done: nothing.
**D-ID text for the register (ROUTINE CALL, builds D765; integrate-28 numbered it D783):** «Secrets as built (`cloud/secrets`). `secret_area.tscn` +
`SecretArea.gd` (Area2D, layer 0, no art) in a room; found on the hero's first entry → room state `found_<node>` (saved
like a chest), event `secret_found` (bus SFX, the parry bell at pitch 2.4, −12 dB), and a text-only «Secret found» toast in the HUD
loot feed. The card reads «Explored N% · Chests a/b · Secrets c/d». Secrets get no level-2 map icon, which would give them
away. Placed: DragonMural, DesertRoad shop-roof rubble and tower-top stash, LizardCave shrine, ElderHouse attic, Mesa
top, Gatehouse Cellar. The Laboratory has none: its branches (drain, storeroom, Malik's stash) are not built.»
B rows fixed: none. Full suite: `SUITE: 1 FAIL`, which is `verify_city_gates_raid` «the hero falls after the teleport». It fails the same way on `origin/feature/backlog`, so this branch did not cause it (see Tests).

## What was built
- `SampleProject/Scripts/Gameplay/SecretArea.gd:15` `_ready`: skips watching once found. `:31` `_on_body_entered`:
  the player group only, once (disconnect + monitoring off), then `set_room_state`, `AudioManager.play(&"secret_found")`,
  `EventBus.secret_found`. `:27` `state_key()` is static, so LocationMap and the tests use the same key.
- `SampleProject/Scenes/Gameplay/Objects/secret_area.tscn`: Area2D, `collision_layer = 0`, `monitorable = false`, one
  `CollisionShape2D` (160×96 default). Each room overrides the shape with its own `RectangleShape2D` sub-resource.
- `SampleProject/Scripts/Systems/LocationMap.gd:49` `secrets_total / secrets_found`. `:177` counts every node with the
  SecretArea script in the location's rooms. They are read from the room scenes like chests, so there is no hand-written list.
- `SampleProject/Scripts/Menus/Game/metsys_map_component.gd:150`: the card line (spec order: explored, chests, secrets).
  Keys in `en.po`/`uk.po`: «Explored %d%% · Chests %d/%d · Secrets %d/%d» → «Досліджено %d%% · Скрині %d/%d ·
  Секрети %d/%d», «Secret found» → «Секрет знайдено». The old two-part key was replaced.
- `SampleProject/Scripts/Core/EventBus.gd:464` `secret_found(room, secret)`. `SampleProject/UI/Components/loot_feed.gd:41`
  `add_note(text)` adds a toast of the same template without an icon. It is never merged with an item toast.
- `SampleProject/Resources/Data/sound_events.json:63` `secret_found`. There is no chime file in the tree, so the
  existing `impactBell_heavy` (the parry bell) is pitched up and played quietly. **Routine call:** swap it for a real chime when audio art lands.

## Secrets placed (room, node, position, why)
Positions are in room coordinates and the shape is centred on them. Nothing else in the rooms was moved or changed.

| Room | Node | Position, size | Why it is a secret |
|---|---|---|---|
| DragonMural | `SecretArea_DragonMural` | (432, 376), 360×80 | The whole room is behind the Canyon's cracked wall (`Wall_Mural`). The zone is at the mural, past the arrival door at x 120. |
| DesertRoad | `SecretArea_ShopRoofRubble` | (1222, 125), 120×50 | Inside the `Rubble_ShopRoof` breakable wall on the shop roof, where `Pickup_ShopRoofRubble` lies. It can only be entered once the rubble is broken (the test checks the rect lies inside the rubble body). |
| DesertRoad | `SecretArea_TowerStash` | (2372, 140), 64×48 | The tower-top ledge (`Ledge_TowerTop`) with the caged `Chest_TowerStash`, a stash on a ledge up `Ladder_Tower`. The zone is between the ladder top and the cage. |
| LizardCave | `SecretArea_Shrine` | (1440, 376), 240×80 | The family shrine past `Gate_Shrine` (D562 branch, the grandfather's key). The zone is at `ShamanMural`. |
| ElderHouse | `Attic/SecretArea_Attic` | (560, 400), 240×88 | The grandfather's attic above `Hatch_Attic` (D562 branch, opened by a talk). The zone covers the notes and `Chest_Attic`, away from the hatch. |
| MesaClimb | `SecretArea_MesaTop` | (700, 150), 240×52 | The top ledge of the Mesa climb, with `Chest_Mesa` (a stash on a ledge at the end of the jump route). It sits above Ledge9's reach (y 124–176 against Ledge9 at 252). |
| GatehouseCellar | `SecretArea_Cellar` | (1560, 376), 240×80 | The cellar the guard lets you into (D562 branch). The zone is at `Chest_Cellar`, past the bats. |

Totals: Canyon of Whispers 6, City 1, Laboratory 0.
**Not marked:** the Bandit Camp (an open side path with a fight, not hidden), the guarded chests on the main road
(Old Vulture, Tower Guard), and the shop roof's open herb by the ladder. A breakable wall alone is not a secret (D765).

## Tests
- `verify_secrets` (new): `RESULT: ALL PASS`. It checks that each node draws nothing and is not a body, that the rubble
  secret lies inside the rubble, the per-location counts against `LocationMap`, that arriving does not count, that walking
  in counts once (event, room state, chime, an iconless toast), and that walking out and in again does not recount. The
  card reads «… Secrets 1/6». Save, load, and new game are covered too. It writes only to `user://verify_secrets/`.
- `verify_world_map`: `RESULT: ALL PASS`. The card check now includes «Secrets c/d», and the old «no secrets line»
  check now requires `secrets_total > 0`.
- `verify_save_load`: `RESULT: ALL PASS`. `verify_desert_road`: `RESULT: ALL PASS`.
- Full suite (`run_verify.sh`): `SUITE: 1 FAIL`, which is `verify_city_gates_raid`: `the hero falls after the teleport
  (y 360.0 -> 360.0)`. It still fails on a re-run and fails identically on a clean worktree of `origin/feature/backlog`.
  CityGates has no SecretArea and this branch does not touch it. It needs a B-ID from the orchestrator. It probably
  comes from the hero's arrival in CityGates (last changed in 67b9f428 / the city-life merge).
- Capture: `SampleProject/UI/capture_secrets.gd` writes `design/shots/secrets/card_vs_figma.png`, with Figma `539:6472`
  on top and the game below in en and uk. The third item sits on the stats line as in the frame. The font and the
  separator spacing differ by D715 (Cormorant Garamond, the game's only font), so there is no new B-ID.

## Housekeeping
The first commit also took four untracked `.uid` files made by the import (`capture_meditation_stones`,
`capture_quest_panel`, `verify_boss_hits`, `verify_masher`). The second commit removes them from the index again.
