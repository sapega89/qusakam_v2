---
type: report
tags: [cloud, routines, dialogue, cutscene]
---

# cloud/story-text — dialogue and cutscene fixes from the 2026-10-23 playtest

**Summary.** All five items are done on `cloud/story-text`. D437: no speaker-less line is left in any `.dqd`, uk or en.
D457: the cage line is cut. D462: Malik walks over first, and it is one talk. B126: the cat stays in cell 3. D460:
`Cutscene.react(actor, kind)` is added and used in the LabCells cutscene. D438 and D459 were not touched.
**D-ID text:** D486 (react), D487 (D437 as built), D488 (D462 text). They are new numbers because D484 is missing
and D485 is taken in the register. **B rows fixed:** B126.
**Full suite** (one run): `SUITE: 2 FAIL`, `verify_cutscene` and `verify_story_journal`. Both broke because of the deleted files and are fixed. On rerun, `verify_cutscene`, `verify_story_journal` and `verify_journal` each report `RESULT: ALL PASS`.
The story-and-dialogue skill named in the prompt is not in the repo (`.claude/` is not tracked), so the work followed
D437/D457/D460–D462 and `docs/CLAUDE.md` alone.

## D-ID text for the register

| D486 | GAP | **`Cutscene.react(actor, kind)`, as built** (D460; agent call, Sapega to confirm). The kinds are `surprise` («!» plus a hop back and back again: 10 px up, 8 px back, 0.3 s), `confusion` («?»), `silence` («…»), `fear` (a sweat drop) and `pain`. Pain has no icon. The body recoils 10 px and returns, trembles 2 px and is tinted `UITokens.HURT_RED`, which fades out over 0.3 s. Only the body moves: that is the actor's first `Sprite2D` / `AnimatedSprite2D`, not the node. A `move()` tween on the node therefore still works, and Alisia's cat (her second sprite) stays put. A new reaction replaces the actor's previous one and its icon. The icon sits 4 px above the first opaque row of the current frame. The icons are new pixel SVGs, `Assets/UI/Icons/emote_{surprise,confusion,silence,fear}.svg`: a white glyph 10–12 px tall with a 1 px `BUBBLE_INK` outline, drawn at ×3. They are tinted from the tokens: `EMOTE_SURPRISE` = ACCENT, `EMOTE_CONFUSION` = TEXT_PRIMARY, `EMOTE_SILENCE` = TEXT_SECONDARY, `EMOTE_FEAR` = SP_FILL. Each pops in over 0.12 s, holds 0.9 s and fades over 0.25 s (`Scenes/FX/Emote.tscn`, `Scripts/FX/Emote.gd`). **In LabCells:** Alisia flinches (`pain`) at the injection. At the prisoner's cry the alchemist, Astrit, Alisia, Urizen and Malik show «!». At the djinn they all show a sweat drop. Each explosion hurts whichever of them stands nearest. Figma has no frame for this. |
| D487 | OVERRIDE | **D437 as built** (amends D437). The 32 `say \| \|` lines in 11 files are gone. `[Hero]` / `[Kusakam]` lines become `KUSAKAM`'s with the tag dropped (`LeavingVillage` 1–3 and 5, `RelicArmor_Examine` 1–7). Narration is cut (`LeavingVillage:4` "The village is left empty…", `Laboratory_AfterBoss:3` "[The laboratory gates grind open.]"). **Deleted, uk + en:** `Canyon_Monologue`, `Laboratory_BossFight`, `ReturnToCanyon`, `Canyon_MeditationAtRelic`, `AfterFight_Meditation` and `FirstFight_Canyon`, which no code played. `CityGates` and `Laboratory_Outside` were deleted too, because each was one narrator line. The CityGates raid now goes from the pan straight to `CityGates_Raid`. `LaboratoryOutside` `EXIT_LAB` sets `lab_outside_complete` and goes on to `Demo_End`. `RelicArmor_Examine` is kept and converted, because `RelicArmor.gd` names it (that script is in no scene). The `Canyon_MeditationAtRelic` arm in `Canyon.gd` is removed. The flag `canyon_relic_meditation_complete` was never set, because no code played that talk. Its Canyon II chronicle line in `story.json` ("At the canyon's edge he meditated beside the sacred armour…") is therefore removed, and the Canyon II chronicle keeps only `canyon_exit_complete`. |
| D488 | OVERRIDE | **The Laboratory meeting text** (D462 draft, [ЧЕРНЕТКА]). `Lab_Acquaintance` (uk + en) is the one talk. Malik: "Hey, you! Still alive? What a racket that was... Who are you?" Then Astrit, Urizen, Alisia with her cat, and Kusakam, each with their old self-introduction. Then Malik: "Malik, a humble merchant. Get me out of here, and at my humble place every one of you gets gold. Lots of gold." / "Alright — come with me!" Cut, because it came before Malik's question or after his "come with me": Astrit's "Alive, lizard?…", Kusakam's "You... from the mayor's line.", Kusakam's "I can't promise anything...", Malik's "Deal? Deal!" and Urizen's "The contract is sealed." `Lab_Malik_Quest` is deleted, and `quests.json` → `malik_escort.give_dialogue` is now `Lab_Acquaintance`. |

## B rows fixed

- **B126** — the cat walks out with Alisia. `LabCells._run()` now moves only `CompanionNPC_alisia/Sprite`. The node,
  and with it the `Cat`, stays in cell 3. `verify_lab_cells` [1] checks that the cat moved 0 px.

## Details

**1. D437**
- Dialogue: `dialogue_quest/{,en/}LeavingVillage.dqd`, `RelicArmor_Examine.dqd` (the typo «виходомф» is also fixed)
  and `Laboratory_AfterBoss.dqd`, plus the 16 deleted files.
- `grep -rnE "^say *\| *\|" dialogue_quest` returns nothing.
- Code:
  - `CityGates.gd` `_raid_cutscene` no longer plays `CityGates`.
  - `LaboratoryOutside.gd` `EXIT_LAB` no longer plays a talk.
  - `Canyon.gd` loses the `Canyon_MeditationAtRelic` match arm.
- Tests:
  - `verify_city_gates_raid` now expects `CityGates_Raid` first, with the camera at the gate.
  - `verify_lab_route` [5] now expects `["Demo_End"]`.
  - `verify_dialogue_speaker` [1b] now scans every uk/en `.dqd` for an empty speaker, which guards D437. It replaces the
    narration-box check, since that box state can no longer happen.
  - `verify_audio` drops the "narration does not babble" step, because it had no line left to use.

**2. D457.** `MayorHall_Victory.dqd:3` is cut in en and uk. What follows still plays.

**3. D462.** In `LabCells._acquaintance()`, Malik now walks to `MalikMeet` *before* `Lab_Acquaintance`. Then the task
and the assists come as before.
- `verify_lab_cells` [4] checks that Malik is at `MalikMeet` when the first line shows, and that exactly one talk plays.
- `verify_lab_route` [3] checks the merged talk.

**4. B126.** See above.

**5. D460**
- `Cutscene.gd`: `react()`, `_body()`, `_head_top()` and `_faces_left()`.
- `UITokens.gd` gets the `EMOTE_*` and `REACT_PAIN_FLASH` tokens. The theme is unaffected, so it was not regenerated.
- `LabCells.gd` gets `_react_all()` and `_nearest()`.
- `verify_lab_cells` [1] checks:
  - all five actors show «!» and a sweat drop;
  - Alisia and at least two others flash red;
  - afterwards every body is back in place, untinted, with no icon left.
- Shot: `design/shots/story_text_cutscene_react.png`.
  - Top: Astrit «!», Alisia mid-recoil. The red tint is caught only in a lucky frame under xvfb: one capture had it,
    this one does not. The test checks the tint.
  - Bottom: Urizen «?», Malik's sweat drop.
- Capture script: `SampleProject/UI/capture_cutscene_react.gd`.
- Not done: the other cutscenes ("then the other cutscenes, scene by scene") are a follow-up. The mechanism is ready.

**Touched tests, single runs.** `verify_lab_cells`: RESULT: ALL PASS. Everything else ran in the full suite.

## Full suite

One run of `Scripts/Tools/run_verify.sh`: `SUITE: 2 FAIL`. Every other script passed.
- `verify_cutscene` [0] still started `res://dialogue_quest/CityGates.dqd`, which D437 deleted. The fix is that it now
  starts `CityGates_Raid.dqd`. Rerun: RESULT: ALL PASS.
- `verify_story_journal`: "Canyon II chronicle: canyon_relic_meditation_complete exists in scene code". That flag was
  only named in the deleted `Canyon.gd` match arm and was never set. The fix removes the chronicle line from
  `story.json` (D487) and the flag from `capture_journal_prologue.gd`. Rerun: `verify_story_journal` ALL PASS and
  `verify_journal` ALL PASS.

