---
type: cloud-report
branch: cloud/wire-leftovers
date: 2026-10-28
---
# Cloud report: wire-leftovers

**Summary**
- **Done:** H3 weapon variants of LungeCut / ShieldCharge / LeapSlam are in the sword (`Player.tscn`), dagger, mace and polearm (halberd) libraries; `Player.body_animation` now picks them, dual keeps the base poses. Unused kit icons and the old Roll frames are deleted.
- **Nothing to do:** `Assets/FX/Smear`: all five cards (arc, dash, punch, slam_ring, thrust) are already played on this branch, none is unused.
- **Not done:** dual and bow H3 variants (no art yet, per the prompt). Room backdrops and props: left to the room chain (list below).
- **D-IDs:** D-wl1, D-wl2, D-wl3 below (placeholders, the orchestrator numbers them).
- **B rows fixed:** none.
- **Full suite:** FULL_SUITE_LINE

## Decisions (D-ID text)
| ID | Kind | Text |
|---|---|---|
| D-wl1 | ROUTINE CALL (`cloud/wire-leftovers`) | **Movement-skill poses from the weapon sets** (H3, D812). `<weapon>/LungeCut\|ShieldCharge\|LeapSlam{Windup,Move,Strike}` play `Sprites/Player/Weapons/<set>/<Skill>/1–3` in the libraries `sword` (inside `Player.tscn`), `dagger`, `mace`, `polearm` (set `halberd`). Same timing as the base poses (one frame, 0.3 s each), offset (0, −16) like the rest of each 96×96 library; the feet of every frame sit on row 88 (= base row 56 + 32), so no per-frame foot offset is needed. The WeaponView overlay hides itself over them through `_drawn_in_frame()` (the weapon is drawn in the frame), so the base fist points stay only for weapons without the set (dual, bow, or a hidden weapon). Added by `Scripts/Tools/weapon_skill_poses.py`, which only inserts and is idempotent: re-running `weapon_libraries.py` would wipe the hand-set per-frame foot offsets already in the four .tres files (it no longer reproduces them), so the new poses are not added through it. |
| D-wl2 | ROUTINE CALL | **Smear cards: nothing left.** The prompt's "2 unused Smear cards" were wired before this branch (catalog after the merge: arc → SlashTrail/wind_arc, dash and slam_ring → MoveSkill, punch → SlashTrail, thrust → SlashTrail/arrow). Nothing deleted. |
| D-wl3 | ROUTINE CALL, follows D813 | **Unused leftovers deleted:** `Assets/UI/Icons/kit/hand_palm.png`, `kit/shield.png` (no scene, script or tool reads them; D603 redoes them as silhouettes anyway; the rows in `skill_icons_brief.md` point to git `e06dd5b2`) and `Sprites/Player/Roll/1–6` (the old roll; Roll plays the `Dash/` frames since round 14, Sapega: no rolling; README row removed). This reverses the "kept" part of D854 under D813. |

## Details
- `Scripts/Tools/weapon_skill_poses.py`: new; inserts textures, animations and `_data` keys.
- `SampleProject/Player.tscn`: 9 textures `sw_*`, 9 animations `Animation_sword_<Pose>`, keys in `AnimationLibrary_sword`.
- `SampleProject/Resources/Player/WeaponAnimations/{dagger,mace,polearm}.tres`: 9 animations each.
- Test: `verify_weapon_animations.gd` → `_skill_poses(library)`, run for each library in combat: `body_animation(<Pose>)` == `<library>/<Pose>`, its texture is `<set>/<Skill>/<n>`, length == base pose, offset (0, −16), and while it plays the overlay (`pivot`, `off_pivot`) is hidden and the sprite shows the weapon frame; for dual it resolves to the base pose. Section [0] also checks that each new animation has key-colour metal (palette swap).

```
verify_scripts_compile   RESULT: ALL PASS
verify_weapon_animations RESULT: ALL PASS
  OK  skill poses: own sword frames, base timing, overlay hidden ([])
  OK  skill poses: own dagger frames, base timing, overlay hidden ([])
  OK  skill poses: own mace frames, base timing, overlay hidden ([])
  OK  skill poses: own halberd frames, base timing, overlay hidden ([])
  OK  skill poses: the base poses, no H3 frames ([])
verify_skill_moves       RESULT: ALL PASS
```

## Unused room backdrops and props, after merging `origin/cloud/wire-backdrops-2` (5c38a28b)
`asset_catalog.py` on a scratch merge of this branch + wire-backdrops-2 (not committed here): 136 unused cards, all of them room art below (the merge only conflicts in `design/MASTER_PLAN.md`). For the next room routine:

| Folder | n | Files |
|---|---|---|
| AlchemistCorridor | 7 | gen_cages.png, gen_desk.png, gen_door.png, gen_front.png, gen_stairs.png, gen_vessel.png, gen_wall.png |
| AlchemistStore | 3 | gen_barrels.png, gen_parts.png, gen_wall.png |
| Aqueduct | 11 | gen_arcade.png, gen_ceiling.png, gen_cellar.png, gen_far.png, gen_floor.png, gen_front.png, gen_grate.png, gen_rubble.png, gen_spout.png, gen_stair.png, gen_wheel.png |
| BanditCamp | 5 | prop_barrel.png, prop_barrel_near.png, prop_crate.png, prop_sack.png, prop_sack_near.png |
| BridgeCave | 1 | gen_ladder.png |
| CanyonFloor | 7 | gen_cart.png, gen_cliff.png, gen_cracked.png, gen_far.png, gen_ground.png, gen_mid.png, gen_mouth.png |
| CaveExit | 3 | gen_far.png, gen_rubble.png, gen_wall.png |
| Cellar | 2 | prop_barrel.png, prop_crate.png |
| Chasm | 5 | gen_bridge.png, gen_city.png, gen_front.png, gen_ground.png, gen_winch.png |
| Cistern | 6 | gen_columns.png, gen_cracked.png, gen_dragon.png, gen_end.png, gen_far.png, gen_well.png |
| CisternStash | 4 | gen_goods.png, gen_hole.png, gen_jars.png, gen_wall.png |
| City | 2 | gen_attic_stall.png, gen_rooftops_ladder.png |
| CollapsedDrain | 6 | gen_collapse.png, gen_far.png, gen_grate.png, gen_hatch.png, gen_mid.png, gen_pipe.png |
| CraftQuarter | 5 | gen_copper.png, gen_front.png, gen_mid.png, gen_potter.png, gen_weaver.png |
| Decor | 1 | lab_grate_sheet.png |
| DryRiverbed | 5 | gen_banks.png, gen_boat.png, gen_far.png, gen_front.png, gen_ground.png |
| Dunes | 8 | gen_colossus.png, gen_dunes.png, gen_front.png, gen_ground.png, gen_near.png, gen_slope.png, gen_stake.png, gen_trailhead.png |
| ElderHouse | 2 | prop_amphora.png, prop_pot.png |
| GateApproach | 6 | gen_city.png, gen_front.png, gen_ground.png, gen_lever.png, gen_pump.png, gen_ruins.png |
| Gates | 1 | gen_rooftops_rope.png |
| MalikStash | 5 | gen_hoard.png, gen_lamp.png, gen_post.png, gen_slab.png, gen_wall.png |
| MayorArchive | 5 | gen_door.png, gen_front.png, gen_lectern.png, gen_map.png, gen_wall.png |
| MesaClimb | 1 | gen_back.png |
| OldRuins | 9 | gen_arcade.png, gen_arch.png, gen_ceiling.png, gen_far.png, gen_floor.png, gen_front.png, gen_relief.png, gen_statue.png, gen_well.png |
| PalaceSquare | 3 | gen_fountain.png, gen_mid.png, gen_palace.png |
| PigeonLoft | 4 | gen_door.png, gen_front.png, gen_keeper.png, gen_wall.png |
| RockLedges | 1 | gen_ledges.png |
| Rooftops | 8 | gen_boards.png, gen_front.png, gen_ladder.png, gen_laundry.png, gen_loft.png, gen_mid.png, gen_roof.png, gen_rope.png |
| SmugglersStash | 2 | gen_goods.png, gen_wall.png |
| TavernAttic | 4 | gen_barrels.png, gen_front.png, gen_sacks.png, gen_wall.png |
| Village | 4 | gen_back.png, gen_elder_house.png, gen_grandpa_house.png, gen_houses.png |

Notes: `Village/gen_{back,elder_house,grandpa_house,houses}.png` are the unburnt planes that the burnt ones replaced in wire-backdrops (whether the village needs an unburnt state, e.g. a flashback, is the room chain's call; if not, they go under D813). `BridgeCave/gen_ladder.png` waits for an end-game flag (wire-backdrops report). `RockLedges/gen_ledges.png` is superseded by `gen_ledges_ramp.png` on wire-backdrops-2.
