---
type: reference
tags: [handoff, orchestrator]
---

# Handoff — 2026-10-28, 12:00

The plan with statuses is [[MASTER_PLAN]]. Deferred items are in [[BACKLOG]]. Reply to Sapega in Ukrainian.

**Registers:** next free **D866**, **B207**, **Q125** — `integrate-32` takes them first; do not file IDs on `feature/backlog`
while an integrator runs.
**Exe:** `build/windows/Qusakam.exe` 2026-10-28 05:07 (after `integrate-31`). Rebuild after each merge (X1).

## 1. Cloud now
| Routine | Trigger | Task | On report |
|---|---|---|---|
| `integrate-32` | `trig_012dR1aKqF5HsvAvP12BqXW9` | merge elite-reach, enemy-sizes, ui-bugs-205-206, critter-tweaks, yellow-sky, skill-art-wire, wire-backdrops (to its report); fix the non-balance reds | fast-forward `feature/backlog`, rebuild exe |
| `lab-v3-now` | `trig_01YLoaxrR4LBAD3mUjVYZ4EP` | M8: the Laboratory as the v3 graph (D863, D865), Laboratory rooms only, parallel to the chain | → `integrate-33` |
| `skills-v2-ranged` | `trig_013tDiEHQH16UsNpuHLBppDF` | H3 slice 4: Holy Javelin, Lightspear, Hallowed Circle, Hellfire Stomp | → `integrate-33` |
| `skills-v2-stance` | `trig_013UG7eTWMee9h8n1e3w5iLe` | H3 slice 5: stances and buffs (glass shield stays off, Q115) | → `integrate-33` |
| `skills-v2-control-a` | `trig_01KRKfp56CqeWNcQQQ8YCypJ` | H3 slice 6a: Rising Slash, Ground Slam, Sweeping Arc, Shield Bash, Stone Palm | → `integrate-33` |
| `skills-v2-control-b` | `trig_01Wdp3pWEDHSmZg5VxkKB8Qy` | H3 slice 6b: Chain of Night, Sand Veil, Dread Howl, Radiant Flare, Night Reaper, Soul Harvest | → `integrate-33` |
| `small-fixes` | `trig_01RpuQict9Jgtg4GDWSThuRN` | B196, Astrit's `enter` in her drop, Q123 delete Collectible, B124/B110 | → `integrate-33` |
| `wire-leftovers` | `trig_01Us7XmYn2uaWEDPon76C3d6` | weapon variants of the skill poses (sword, dagger, mace, halberd), FX/Smear, kit icons, old Roll; lists room art still loose | → `integrate-33` |

**Room chain** (one room routine at a time, each waits for the previous report): `wire-backdrops` ✅ report →
`wire-backdrops-2` (`trig_011KdRNJ3WJNiU8AWzT9DHkL`, running) → `rooms-finish` (`trig_01KB4iH1vjuKHe3kmpnykZ1L`) →
`wire-backdrops-3` (`trig_018LGBuN2bP4eH27wHj7bB4A`) → `wire-backdrops-4` (`trig_01Rw2B9remFva5UTZGTx8SzC`) →
`prop-sizes` (`trig_015U2tbMG9yLHwpLrRMGBCSg`) → `wire-props` (`trig_01B4nHuyADwieMains6tHt2J`).
- **Waits run out 8 h after each trigger's creation** (UTC): rooms-finish 11:11, wire-backdrops-3 11:38,
  wire-backdrops-4 12:03, prop-sizes 15:15, wire-props 15:31. When one dies, re-run it with RemoteTrigger `run` — only
  after it died (`list_runs`), or two sessions build the same thing.
- The chain's own `lab-v3` (`trig_013ZcTiT1GvzqNabezNjssda`) is **superseded by `lab-v3-now`**: merge nothing from it
  unless lab-v3-now missed something.
- `rooms-finish` may build the old D849 Laboratory floors from Q113's struck answer: drop its Laboratory part on merge.
- B-ct1 (City pigeons sunk in the street, filed by integrate-32) goes to the next room routine.
- Never merge `cloud/lab-main-path`, `cloud/rooms-city`, `cloud/rooms-lab`.

**Next integrator `integrate-33`:** the four skills branches + small-fixes + wire-leftovers + lab-v3-now, then the
chain's last branch (`wire-props`). The skills branches all start from `cloud/skill-art-wire` and share PlayerCombat.gd /
skills.json — merge one at a time, re-run their tests after each.

## 2. Art lane (PC, one ComfyUI agent at a time)
H3 weapon variants: sword, dagger ✅ `d6279b38`; mace and halberd drawn 28.10 noon (sheet
`design/shots/h3_weapon_variants_2.png`), PC off after. Next: dual + bow → A15 the bandit in normal proportions (then
re-measure its `enemy_variety.json` scale) → A4 alchemist → burnt village charred palms, banners, grass (wire-backdrops
left them green) → craft quarter forge and chapel fronts. Sizes are fixed by scaling in the cloud, not redrawn
(memory: scale-before-redraw).

## 3. Rules learned
- **Code and tests in the cloud**, the PC only for ComfyUI (memory: tests-in-cloud). The cloud sometimes cannot
  download Godot — then the routine commits and lists its tests.
- **Tests:** 4 at a time with own user:// per test, `## SERIAL` last, `## MANUAL` (`verify_masher`) skipped (D806).
  `verify_difficulty` (17) and `verify_lab_boss` (2) are red on balance until Q114/Q116–Q118.
- **Chibi** only Kusakam and his companions (D816); NPCs and enemies normal proportions.
- **Scale chart approved** (D814): hero 64 art, adults 96, elites ×1.5 (D859), doors 112, palm 256.
- **Sky** yellow until the hero leaves the Laboratory, then blue (D864, [[lore]] 28.10).
- **Asset catalog** https://claude.ai/artifact/Qxty8beDtyy71ULkuvmocf — generator `Scripts/Tools/asset_catalog.py`
  (lists unused art).

## 4. Waiting on Sapega
- Balance: Q114, Q116–Q118 (P9).
- The glass shield's skill: Q115.
- Death frames 1 and 3 (B184, Q110); B195 check in the exe (die next to an enemy mid-swing, Resume, repeat).
- Looks at the art sheets A1, A5–A9, A13, A14 ([[asset_verdicts_2026-10-27]]).
- Q107–Q111, Q119–Q122, Q124 (defaults applied).
