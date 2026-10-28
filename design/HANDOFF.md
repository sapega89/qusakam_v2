---
type: reference
tags: [handoff, orchestrator]
---

# Handoff — 2026-10-28, night

The plan with statuses is [[MASTER_PLAN]] (§5 playtest P1–P9, §6 the art queue). Deferred items are in [[BACKLOG]] →
«Moved out of MASTER_PLAN 2026-10-27». Reply to Sapega in Ukrainian.

**Registers:** next free **D866**, **B207**, **Q125** (`integrate-32` takes them first). Do not file IDs on `feature/backlog` while an integrator runs.
**Exe:** `build/windows/Qusakam.exe` 2026-10-27 23:35 (menu effects, B195 fix, starting skills). Rebuild after each merge.

**STOP lab-main-path:** `cloud/lab-main-path` (`trig_016p6nP4vDDN4ef4kGP91rKz`) was briefed to build the M4 zigzag DOWN — Sapega rejected that graph («лабораторія під землею, тому ми піднімаємось»); do NOT merge its branch. The M4 graph is redrawn in Figma first (memory: Claude draws Figma), shown to him, then built.

**Cloud, 28.10 morning:** room chain (each waits for the previous report, max 8 h): `wire-backdrops` (re-run 08:38 after a 5-hour limit) → `wire-backdrops-2` → `rooms-finish` → `wire-backdrops-3` → `wire-backdrops-4` → `prop-sizes` → `wire-props` → `lab-v3` (`trig_013ZcTiT1GvzqNabezNjssda`, D863/D865, the approved Lab v3 graph). If one dies (limit, timeout), re-run it with RemoteTrigger `run` and check the next ones are still waiting. Independent: `enemy-sizes`, `skill-art-wire`, `critter-tweaks`, `yellow-sky` (D864), reported and waiting to merge: `elite-reach` (B203), `ui-bugs-205-206`. Art lane: H3 weapon variants mace + halberd, then dual + bow, then A15 the bandit (normal proportions). Lore 28.10 in [[lore]] (yellow sky, flying city, god of greed).

**Cloud, 28.10 09:44 UTC (parallel to the room chain):** `integrate-32` (`trig_012dR1aKqF5HsvAvP12BqXW9`) merges elite-reach, enemy-sizes, ui-bugs-205-206, critter-tweaks, yellow-sky, skill-art-wire, wire-backdrops (only to its report) and fixes the non-balance reds; skills v2 slices from `cloud/skill-art-wire`, all at once: `skills-v2-ranged` (`trig_013tDiEHQH16UsNpuHLBppDF`), `skills-v2-stance` (`trig_013UG7eTWMee9h8n1e3w5iLe`), `skills-v2-control-a` (`trig_01KRKfp56CqeWNcQQQ8YCypJ`), `skills-v2-control-b` (`trig_01Wdp3pWEDHSmZg5VxkKB8Qy`); `small-fixes` (`trig_01RpuQict9Jgtg4GDWSThuRN`: B196, Astrit's `enter` in her drop, Q123 delete Collectible, B124/B110). Then (Sapega «лабораторію в3 перебудуй зараз», «залий всі арти»): `lab-v3-now` (`trig_01YLoaxrR4LBAD3mUjVYZ4EP`, from `cloud/wire-backdrops`, Laboratory rooms only, parallel to the chain) — **the chain's own `lab-v3` (`trig_013Z…`, waiting for wire-props) is superseded: merge nothing from it unless lab-v3-now missed something**; `rooms-finish` may build the old D849 floors from Q113's struck answer — drop its Laboratory part on merge; `wire-leftovers` (`trig_01Us7XmYn2uaWEDPon76C3d6`): weapon variants of the skill poses (sword, dagger, mace, halberd), FX/Smear, kit icons, old Roll. Next integrator (`integrate-33`) merges the four skills branches + small-fixes, then the room chain's `lab-v3`; B-ct1 (City pigeons) goes to the next room routine. Art lane: H3 mace ✅ frames, halberd finishing; dual + bow, A15, A4 next.

## 1. Running now
| What | Where | Task | When it reports |
|---|---|---|---|
| `fewer-road-enemies` | ☁ `trig_01YMTKTqVyu8aFA3CYpNLRp5` | D817: DesertRoad groups ≤ bandit + jackal or two bandits + jackal | it may not have run Godot (the cloud classifier blocks the download now and then): merge, then run its tests locally in a worktree |
| `world-rooms` | ☁ `trig_0199FwJ19fwAHb4RcSm3FjMo` | M7 **Canyon** on placeholder backdrops (its prompt also covers City and Lab — merge only its Canyon slice; City/Lab come from the two routines below, Sapega: «розбити на регіони») | ✅ merged whole by `integrate-31` (D844–D850) |
| `rooms-city` | ☁ `trig_01Eqok3DZCxs6TVcwtYQGn8Q` | M7 City region only (M3) | ⛔ not merged (duplicates world-rooms); the gate's meditation spot ported (D861) |
| `rooms-lab` | ☁ `trig_01EWiH9f4dELT3EzAsQb2zt1` | M7 Laboratory region only (M4), no platforms/ladders | ⛔ not merged (duplicates world-rooms); Malik's stash hint ported (D861) |
| `wire-art` | ☁ `trig_01FEuvNNspn9Qr36pPxSNUby` | wire shields, status icons, mouse; leftovers | ✅ merged by `integrate-31` (D851–D854) |
| `playtest-tuning` | 🖥 worktree agent (godot-dev) | B197 the jackal flies; D825 shorter micro-stun; D826 slower enemies; D827 free Shield Block = 1 point toward the D497 gate; then D828 skills hit hard, D829 bigger elites, B198 enemies jump up to a step | merge its branch, file its D-IDs, rebuild, send Sapega the verify_difficulty table |

**Night of 27–28.10 (Sapega asleep, «згенеруй все, що можна»):** `integrate-31` (`trig_01PHgm6qwHGNwgL9QYaE2ewU`) merges world-rooms' tail, wire-art, fight-occluders, enemy-stamina, enemy-scaling → scaling-partial → hero-points-only, elites-bigger, shield-break-wire, ladder-holes; skips rooms-city/rooms-lab (duplicates of world-rooms). `wire-backdrops` (`trig_01CkNSRbfUkrfkqNPCW3SM8B`) wires road, BridgeCave, GrandfatherAttic, MesaTop, ZahraRest, burnt Village after world-rooms. **Still to wire** (next wiring routine, rooms are generated by `Scripts/Tools/build_world_rooms.py` — wire there): Dunes, OldRuins (`d2d6c19b`), Chasm + its drawbridge, DryRiverbed (`b2804c15`), Aqueduct + GateApproach (M6b-5, running). Art next after M6b-5: smugglers' stash + canyon floor + cave exit, then M6c City rooms, M6d Lab rooms, then A6, A7, A8–A14.

**Art lane status (morning 28.10):** all new rooms painted (M6b-1…6, M6c-1…3, M6d-1); A1, A5, A6, A7 (1–4), A14 done; A8 running. Left: A7 items 5 (tutorial `basic_controls`/`journal` = re-shoot with `capture_tutorial_shots.gd` in a window, also overwrites `the_map`/`saving` of A9), 6 (Collectible, Q123), 7 (DarkTiles/DesertTiles tile-by-tile, its own batch); A9, A10–A13, A4. Code lane for later: let Astrit's `enter` play during her drop (CompanionAssist pauses frame 0 for drops; Urizen's drop must stay paused).

## 2. Next, in order
00. **B200 first in the art lane** after M6b-1: shieldless frames of the shield-bearer and the tower shield guard (same poses, cells, feet); then a cloud routine wires the swap on shield break + shards.
0. **Wire the art that lies unused** (Sapega: «чому не всі арти підключені?»; the catalog's unused list): the shield spells
   (H2: magic + glass phases on block, glass shards hurt the attacker), the status icons (bleeding, burning, cursed, stunned),
   the mouse with its hole (ambient_critters_plan), and the road planes onto `world-rooms`' new rooms; then either wire or
   delete the leftovers (old front planes, plank_posts, stone_balcony, Sprites/MC.png, kit icons, old Roll). From now on
   every art batch ends with its wiring. The 8 cloud branches with unmerged commits hold only report tails — nothing lost.
1. **P6 / D824 enemy stamina** — a new system: `plan-missing-system` → `design/enemy_stamina_plan.md` (mirror the hero's
   PlayerStamina D776), then build it (worktree agent) after `playtest-tuning` (both touch EnemyLogic).
2. **P5 / D830** — the Desert Road floor flat, no steps (Sapega: «на дорозі не має бути сходинок»); after `fewer-road-enemies` merges (same scene).
3. **P8 / B196** — «Hold Tab to skip» over the «Your Skills» window.
4. **Art queue** [[asset_verdicts_2026-10-27]] on the PC, one ComfyUI agent at a time: A5 (road planes + the Rock Ledges
   redo) → A6 (shield phases) → A7 (Brass Collector, dust, hit flash, tiles, tutorial pics) → A8/A9 → A10–A13 (scale) →
   A14, A4. Each with a before | after sheet sent to Sapega.
5. **M6a-3** burnt village (D796: the Village's own houses, scorched, not ruined) after A5.

**Burnt village (M6a-3, `785e7f49`)** is made, not wired: after `world-rooms`' Canyon slice merges (it may touch Village.tscn), swap the four Village textures for `_burnt`, open the regions (Back 0,0,576,324; Houses 0,0,576,276; offsets 0), darken the Backdrop modulate ~(0.72,0.66,0.68), green palms/banners/butterflies/larks/pollen → charred/embers. The village is burnt in every state the game uses.

**D840 partial scaling:** done in the cloud by `scaling-partial` (`trig` created 2026-10-27 23:20 UTC, waits for `enemy-scaling`); merge order enemy-scaling → scaling-partial → hero-points-only (the last two both branch from enemy-scaling; resolve verify_difficulty by re-running it).

## 3. Rules learned today
- **Tests:** the full suite runs 4 at a time with its own user:// per test, `## SERIAL` real-time tests last, `## MANUAL`
  (`verify_masher`) skipped (D806). Tests run in the cloud by preference (memory: tests-in-cloud), but cloud routines
  sometimes cannot download Godot — then finish them in a local worktree. At most two Godot lanes on the PC with ComfyUI.
- **Chibi** only Kusakam and his companions (D816, like Skul); NPCs and enemies keep normal proportions; the bandit's
  look is a BACKLOG item.
- **Scale chart approved** (D814): hero 64 art, adults 96, elites more than ×1.25 (D829), doors 112, palm 256.
- **Asset catalog** https://claude.ai/artifact/Qxty8beDtyy71ULkuvmocf — verdicts in db `verdicts`; generator
  `Scripts/Tools/asset_catalog.py`.

## 4. Waiting on Sapega
- Death frames 1 and 3 (B184, `design/shots/hero_death.png`).
- Check B195 in the exe: die next to an enemy mid-swing, Resume, repeat.
- The main menu art (candidate C2) and its effects — he liked the art; any notes on the effects.
- Where the steps are (D830).
- The 3 red SKILLS rows (P9) — re-judge after `playtest-tuning`.
