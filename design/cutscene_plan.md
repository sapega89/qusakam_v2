---
type: plan
status: planned
---

# Cutscenes — plan

**Nothing implemented.** Every "cutscene" today is a dialogue in the normal dialogue box while
the player stands frozen. `CutsceneStep.gd` is an unused stub. 2026-10-13.
Figma: no design exists (story scenes `36:65` is a dialogue layout, D70/D112).

## What exists today

| Thing | Where | State |
|---|---|---|
| Abduction "cutscene" | `Canyon.gd` state `CUTSCENE_ABDUCTION` → `Canyon_AbductionCutscene.dqd` | ⚠️ dialogue only — nobody is seen being abducted |
| Canyon exit "cutscene" | `Canyon.gd` `EXIT_CUTSCENE` → `Canyon_ExitCutscene.dqd` → teleport to the road (D137) | ⚠️ dialogue + cut; no descent shown |
| Mayor's Hall "cutscene" | `City_MayorHall.dqd` → teleport to the Laboratory (D130) | ⚠️ dialogue + cut |
| Village abduction / old man | `Village.gd` `ABDUCTION_CUTSCENE`, `OLD_MAN_*` | ⚠️ dialogue only |
| Prologue | `Scenes/UI/PrologueScene.tscn`, `Scripts/UI/PrologueScene.gd` | ✅ text intro screen (not in-world) |
| Step stub | `Scripts/Systems/Cutscenes/CutsceneStep.gd` (57 lines) | ❌ referenced by nothing (`grep CutsceneStep` outside its file → 0) |
| Building blocks | dialogue queue (`DialogueManager`), `Player.set_movement_enabled`, `Game.teleport_to_room`, Camera2D in `Game.tscn`, `SceneManager` fade layer | ✅ all exist |

## Missing entirely

- A way to script **in-world action**: characters walking, camera pans, fades, sprites appearing,
  timed waits — interleaved with dialogue lines.
- A skip control.
- Actors for the scenes (abductors, the village people, the mayor) — see [[character_animation_plan]].

## Decisions required

1. **Q42 — GAME DESIGN DECISION REQUIRED (blocks everything).** What should a cutscene show, and
   which story beats get one? Candidates: Canyon abduction, Village abduction, Canyon descent,
   Mayor's Hall → Laboratory, lab boss intro. Options per beat: dialogue only (today) · dialogue +
   fade/camera · fully staged (actors move).
2. **Mechanism — D177: Tween.** Motion (camera, actors, fades) is `create_tween()` awaited in the
   room script's state chain, like `ScreenFade` and the Village. No `AnimationPlayer` timeline.
3. **Skip** (not blocking): hold B / Esc skips to the end state; recommended yes.

## Decided (2026-10-13)

D140: the **Village** is the first staged sequence — abduction as fade + dialogue → talk with the
first bandit → fight → "oh no, the house!" → **old man cutscene**: he heals Kusakam, Kusakam heals
him with **Healing Palm** (player action, D145), first skill learned (D141). Lines are drafts
marked `[ЧЕРНЕТКА]` for Sapega to edit.

D176 (2026-10-15): Canyon abduction, Canyon descent and Mayor's Hall → Laboratory get **fully
staged** cutscenes. Screenplay with shot lists and draft lines: [[cutscene_script]]. Scene 3 waits on
Q51 (its story). Lab boss intro: not chosen.

## Built (2026-10-13)

**Village sequence** (D140, D145): `ScreenFade` (`Scripts/Systems/Cutscenes/ScreenFade.gd`) for the
abduction; Village states drive the rest (`Village.gd`: `_abduction_scene`, `Village_AfterFight`,
`_talk_to_old_man`, new `OLD_MAN_TREATMENT` → `_teach_healing_palm`). The old man (`OldMan.gd`)
joins `allies` only for the treatment step, so Healing Palm's normal targeting (D142) heals him.
Draft lines `// [ЧЕРНЕТКА]` in `dialogue_quest/`. Test: `verify_village_fight` [0]–[7].
`CutsceneStep.gd` deleted. Scripted with the scene's existing await chain rather than an
`AnimationPlayer` — enough for fade + dialogue + one player action; revisit when a beat needs
actors moving.

## Built (2026-10-20) — Canyon descent, D254/D256

The first fully staged beat. `Canyon.gd` `_on_exit_cutscene_state`: the edge trigger takes the input
(`set_movement_enabled(false)`, physics stops, so no fall and no damage), `CanyonBridge.collapse()` is awaited,
the dialogue plays (input re-taken after it, the dialogue manager hands it back), the hero is tweened between
markers `Descent/Edge` → `Descent/Below` with Walk/Climb frames behind `ForegroundRock` (generated, z 20), the
camera is detached (`top_level`) and tweened up to `Descent/Sky`, its `limit_top` lifted to the `HighSky`
plane above the room (blue gradient + clouds), then `ScreenFade` → teleport → light from the hero.
Motion is Tween in the room's await chain (D177) — no shared tween helpers yet: one beat used them; extract
when the second staged beat (abduction, Mayor's Hall) needs the same moves. No skip control yet.
Test: `verify_canyon_exit` [2]–[4] (real `move_left` input, the hero's frame covered by the rock's opaque
pixels, camera above the room, no Fall, HP unchanged, road arrival).

## Built (2026-10-20) — Meditation on the summit, D257

The abduction beat staged with the same moves as the descent (second use — still inline in `Canyon.gd`, the
helpers are three tweens; extract when a third beat needs them). `MeditationTrigger` on the Pride Rock summit
(`EXPLORATION` → `CUTSCENE_ABDUCTION`) — the old full-height trigger at the rock's west foot is gone, so nothing
fires before the climb. `_on_abduction_cutscene_state`: input taken, walk to `Meditation/Seat`, `Canyon_Exploration`
(bubble), `Meditate` pose (re-applied after each dialogue start: the dialogue manager resets the hero to Idle),
camera `top_level` tween to `Meditation/Look`, `ScreenFade` + `VillageAbduction`, light, `Canyon_AbductionCutscene`,
camera back, control back. Test: `verify_canyon_exit` [0] (real climb with move_left + jump from the east foot).

## Slices

### Slice 1 — Cutscene runner + one beat
- Next to `ScreenFade.gd`: static tween helpers the beats share — pan camera to a point, move an
  actor to x, wait — each `await`-able (D177). Locks the player for the beat; skip kills the
  running tweens and jumps to the end state.
- First beat chosen by Q42 (recommended: Canyon abduction).
- `UI/verify_cutscene.gd`: starts, locks input, plays lines in order, skip lands in the end state,
  quest flags match the dialogue-only version.

### Slice 2 — Remaining beats
- One beat per commit, each keeps today's quest flags and teleports (D130, D137).

## Order and dependencies

`Q42 → 1 → 2`. Staged beats need actor art from [[character_animation_plan]]; a fade/camera-only
version can ship before the art.

## Out of scope for this pass

Dialogue box redesign (D110), full-body art in dialogue (D112), branching choices (D113).
