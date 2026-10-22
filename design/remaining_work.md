---
type: plan
status: active
tags: [queue, backlog, handoff]
---

# What is left after the overnight run (2026-10-22, 08:00)

Written for Sapega («запиши, що треба зробити, в беклог»). The cloud waves and the art lane built most of
[[play_feedback_queue]]; [[BACKLOG]] items are struck through by the integrators as they merge
(`design/cloud_reports/integration-*.md`). This note lists what is still open, grouped by who can do it.

## Still running (merge next)

| Branch | What | Status |
|---|---|---|

Merged already: `cloud/bow`, `cloud/weapons-all` and the integrators (round 4); `cloud/code-fixes`, `cloud/living-world`,
`cloud/skill-fx`, `cloud/art-fixes-wire` (round 5); `cloud/ui-bugs`, `cloud/misc-bugs`, `cloud/combat-stats` (round 6).

## Art (needs ComfyUI on the laptop)

1. ~~**A5 — foreground parallax and a living world**~~ — **wired 2026-10-22** (D392, `cloud/living-world`; open:
   a grass idle sheet). Was (BACKLOG 7 + 19): a near plane for Canyon, DesertRoad, CityGates,
   City, LaboratoryOutside; decor idle frames (banners, palms, lamps, crystals); drifting clouds. Then a cloud task wires it.
2. ~~**A6 — own effects for the 18 new skills**~~ — **drawn 2026-10-22** (`e86bef3c`): the 9 oath actives × charge +
   release = the 18 effects (the other 15 oath skills are passives, no cast); wiring: `cloud/skill-fx`. Was (D279 leftover: they reuse recoloured Fire/Electric/Healing effects —
   Searing Hex reads dark red, Balanced Strike looks like Fire Strike). Then wiring.
3. ~~**Missing weapon frames:**~~ — **drawn 2026-10-22** (`fe96e88a`); wiring: `cloud/art-fixes-wire`. Was: dagger Heavy and two Attack2 frames (kept turning into a sword), dual-wield Hurt.
4. **Small art fixes noted by agents** — **drawn 2026-10-22** (`fe96e88a`) except the faint pillar floor mark and
   slam dust; wiring and the stagger animation: `cloud/art-fixes-wire`. Was: Malik's walk shows white patches through the robe; the alchemist's mask reads
   as a beard; the boss-hall runes look like Latin letters; enemies have no stagger frames (only a tint); the djinn's
   death frame reads close to idle; the priestess has a stray stick in the prayer frames; the grandfather's staff
   swaps hands between idle and pipe; the pillar floor mark and slam dust are faint.
5. **BACKLOG 30 — effects polish** after Sapega's notes.
6. **Bow frames for the other poses** (B110): Air 1–3, Block, Hurt, Roll in the bow grip; then a cloud task adds them to
   `AnimationLibrary_bow`.
7. **A grass idle sheet** (BACKLOG 19 leftover) for `Scenes/Backgrounds/Decor/`.
8. **UI art pass** — UI art is hand-made, never generated (D239). Waiting for it: the speech-bubble body and tail
   (#26; Claude's temporary PNGs since D178 — Sapega 2026-10-22: keep them until this pass).

## Code (cloud or laptop)

1. **Ukrainian voices are thin** — Piper "lada" x-low (16 kHz, one female voice pitched down for men). A better
   licence-clean Ukrainian voice (e.g. `uk_UA-ukrainian_tts-medium`, three speakers) lives on huggingface.co, which the
   cloud could not reach — check its model card licence from the laptop and regenerate (`Scripts/Tools/audio/make_voices_uk.py`).
2. ~~**Boss charge telegraph** — the bosses' glint sits on the bandit's weapon position; charges have no ground line (4b leftover).~~ — done 2026-10-22, D388 (`cloud/code-fixes`).
3. ~~**Enemy attack cooldowns use the wall clock** (`EnemyLogic`/`BossLogic` `Time.get_ticks_msec`), so hitstop/slow-mo do
   not delay the next attack (4b leftover).~~ — done 2026-10-22, D388.
4. ~~**verify_souls_combat [0]** fails about 1 run in 10 (3 stuck seconds vs a limit of 2) — tune or fix.~~ — done 2026-10-22, D389 (a designed finisher stagger, not a lock; [0] now measures control).
5. **Subclass at level 40 and prestige at 70** (D260) — only outlined in [[skill_trees_plan]].
6. ~~**Journal Characters page portraits**~~ (done 2026-10-22, D391); **tutorial topic screenshots** (Game Menu batch leftovers).

## Sapega

1. **Regenerate the theme** after his local `GameUITheme.tres` edits are settled
   (`godot --headless --path . --script res://SampleProject/UI/build_game_ui_theme.gd`) — `verify_game_ui_theme` waits on it.
2. **Delete line 141 of `SampleProject/UI/playthrough.gd`** (`set_save_dir(save_system.SAVE_DIR)`) — script runs now
   refuse it so tests never touch real saves.
3. **BACKLOG 27** — ideas to make the oath more interesting.
4. **Texts:** quest hints (D159), lore for the scenarist, companion lore (the [ЗАГЛУШКА] stubs in [[lore]] go to the
   characters' creators), and one read-through of every `[ЧЕРНЕТКА]` dialogue line in both languages.
5. **Journal lore and city-flag pages from Figma** (BACKLOG 34) — Figma is reachable only from the laptop.
6. **Q66 remainder** — names for the subclass (level 40) and prestige (level 70).
7. **Confirm the agent calls** — every D-ID marked "agent call, Sapega to confirm" (D300s and later, the integrators'
   D319+), listed in [[play_feedback_queue]] → Open.
