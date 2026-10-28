---
type: report
branch: cloud/integrate-32
base: feature/backlog @ origin 2026-10-28 09:5x
date: 2026-10-28
---

# integrate-32

- **Merged (7):** elite-reach, enemy-sizes, ui-bugs-205-206, critter-tweaks, yellow-sky, skill-art-wire, wire-backdrops (to its report `b53f4862`). Not merged, as briefed: wire-backdrops-2+, lab-main-path, rooms-city, rooms-lab.
- **B203:** one root fix kept, **enemy-sizes'** `DefaultEnemy._grown_range`. Its test `verify_hit_areas` [1b] covers every live melee kind (ordinaries and elites, small and medium) at its grown scale, B187's `kinds.<kind>.scale` included. elite-reach's [10] covers only the elites, and its `grow = elite.scale` was wrong once B187 landed. elite-reach's [10] is kept as an extra test, now with `grow = kind.scale × elite.scale`, and it passes on enemy-sizes' fix (a strike started at `attack_range` lands).
- **IDs:** D866 enemy sizes + B203 rule, D867 M map grid only, D868 critter tweaks (D-ct1), D869 movement-skill art (D-SAW), D870–D873 wire-backdrops (were D864–D867). D864 (yellow sky) is marked Built. B207 City pigeons (B-ct1), B208 empty `verify_combat_flow` [2e] check, B209 painted road skies stay blue. Q125 ledges ramp vs steps (non-blocking, default the bent ramp). `world_scale.json` row `elite_human` (144 art = 216 world, D859).
- **Fixed:** B187, B203, B205, B206; B186 partly.
- **Task B:** verify_archer, verify_mayor_hall and verify_combat_player now run on game time (`Kit.until` / `Kit.wait` in physics steps; archer has a game clock with `time_scale`). verify_camera_transitions [7] gets a defined start (a new game's Canyon, the camp fight switched off). Both camera tests are `## SERIAL`. A shader error from yellow-sky is fixed (`TEXTURE` passed to a function).
- **Full suite:** `SUITE: 6 FAIL in 28 min 27 s, J=4` (nproc 4). After fixes, the failures re-run alone: verify_map_geometry and verify_quiet_transitions PASS (my `--import` predated wire-backdrops' new textures, so `gen_ledges_ramp.png` was missing); verify_yellow_sky PASS (B209-like merge gap fixed, below); verify_city_gates_raid PASS (a J=4 flake in [7], see Left). verify_camera_transitions and verify_camera_rooms PASS in their serial slot (386 s, 289 s).
- **Still red, balance (waits on Q114/Q116–Q118):** verify_difficulty 17 FAIL and verify_lab_boss 2 FAIL. Both are row for row identical to `origin/feature/backlog` (diffed).

## Per branch

| branch | conflicts | IDs | tests |
|---|---|---|---|
| elite-reach | none (first) | its D-ID not registered: the fix it describes was replaced by enemy-sizes' (above) | — |
| enemy-sizes | `DefaultEnemy.gd` (took enemy-sizes'), `verify_enemy_variety.gd` [1] small-size hunk (took enemy-sizes'), [10] grow adapted | D866 (its «D862») | verify_enemy_variety, verify_hit_areas, verify_combat_enemies ALL PASS after the merge |
| ui-bugs-205-206 | none | D867 | in the suite |
| critter-tweaks | none | D868 ← D-ct1, B207 ← B-ct1 (report rewritten) | in the suite |
| yellow-sky | none | D864 Built | in the suite; see the shader fix |
| skill-art-wire | none | D869 ← D-SAW (report rewritten) | in the suite |
| wire-backdrops | none | D870–D873 ← D864–D867 (report rewritten; no code refers to them) | in the suite |

Room fix not done here (the room chain owns `Maps/*.tscn`): B207.

## Task B

- **verify_archer** (5 FAIL under J=4 on feature/backlog, ALL PASS alone on both): its deadlines and «arrow 380–560 ms after the glint» read `Time.get_ticks_msec()`, and its pauses were process timers. Now `clock_ms` adds `1000 × Engine.time_scale / ticks` on every `physics_frame`, the clock the game's own timers run on (hitstop drops time_scale to 0.05), and pauses are `Kit.wait` (a physics-step timer). No bound changed.
- **verify_mayor_hall** (hung): a wall-clock `_until` gave up early under load. `_snap()` then read a null hall, and the SCRIPT ERROR killed the coroutine before `quit()`, so the test hung until the 180 s kill. `_until` is now `Kit.until`, the 30 s loop counts physics steps, and timers are `Kit.wait`. The real-time Tab hold (`ignore_time_scale` timers) is unchanged.
- **verify_combat_player** (B186): the heavy-recovery block time counted wall ms and is now physics steps; timers are `Kit.wait`. The game's timers (`PlayerCombat`, `PlayerStamina`) are all in `_physics_process`.
- **input_kit.gd:** `until(tree, cond, max_s)` and `wait(tree, s)`: the shared helper B186 asked for. The other `_until` copies (canyon_exit, city_life, …) are still open in B186.
- **verify_camera_transitions** failed alone on the merged tree, and its [7] also failed on the base:
  - «Canyon: the camera follows the run (0 moving frames)»: after [4]/[5] the Canyon is in RELIC_PICKUP. The run right walks into the bridge-descent cutscene, which detaches the camera. [7] now enters the Canyon with a new game's quest flags and restores them after.
  - «reaching the right limit…»: the Bandit Camp fight spawned mid-run (`Fight_CampTrigger`), and its bodies stopped the hero at x 631 / 905. [7] now turns the trigger's monitoring off, as `_go` already does for MayorHall's QueueTrigger. Fighters already out lose their collision layer and mask. `_set_collisions_disabled` does not stop them: the body still blocked the hero.
- **verify_camera_rooms** (AlchemistStore 41.7 px under J=4, PASS alone): it measures the camera's per-frame move. Smoothing runs on the real process delta while the hero moves in physics steps, so the number depends on frame time. Both camera tests are now `## SERIAL` (allowed for real-time tests). The 12 px bound is unchanged.
- **Shader:** yellow-sky's `depth_blur.gdshaderinc` passed `TEXTURE` into a function. Godot 4.6 printed `Condition "!actions.custom_samplers.has(function->arguments[j].tex_builtin)"` on every room load (42 in one camera run). It is now a `#define DEPTH_BLUR_SAMPLE` macro. The error is gone, and a windowed GL capture (`capture_yellow_sky`, `design/shots/yellow_sky.png` re-shot) shows the cream clouds as before.
- Under 6 tests on 4 cores, archer, mayor_hall, combat_player, combat_flow and scripts_compile were ALL PASS.

## Found while merging

- **verify_yellow_sky** CaveUnderBridge: yellow-sky keyed the cave's old placeholder far wall (`LizardCave/gen_far.png`); wire-backdrops replaced it with the painted `BridgeCave/gen_wall.png`, whose mouth has the canyon sky (its README). Added to `SkyTint.BAKED_SKY`; the re-shot cave row is identical left and right (rock untouched by the keyed tint).

- **B209:** in the re-shot `yellow_sky.png`, MountainPath's painted sky (wire-backdrops) stays blue-grey with the yellow sky on. SkyTint's room list predates the painted planes. Filed; the fix belongs with the room chain or a SkyTint follow-up.

## Left

- B207 (room chain), B208, B209, B186's other `_until` copies, Q125 (non-blocking).
- `verify_city_gates_raid` [7] «the hero stands on the floor under the arrival» (y 344 → 360) failed twice under load (6 tests on 4 cores, and the J=4 suite), PASS alone; B204's earlier fix did not cover it. Not fixed here; noted under B186.
- Balance reds: verify_difficulty, verify_lab_boss (Q114, Q116–Q118).
