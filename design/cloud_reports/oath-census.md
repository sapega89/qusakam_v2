---
type: report
tags: [cloud, oaths, census, skills]
---

# oath-census — the census at the City Gate chooses the path (D725–D728, D718)

**Summary.** Built [[oath_affinity_plan]] as it stood on `feature/backlog` on 2026-10-26: D728 is the latest word, so there is no «ще подумаю» and the Skills screen shows only the chosen path's tree.
- **Done:**
  - The Mayor Hall opens without an oath. The D488 gate is gone, along with the guard's line and the «Swear an oath» objective.
  - Three hidden leanings live in `player_state.leanings` and are saved. They grow from the fighting style and from three draft deed choices.
  - The census: after the gate fight, the gate scribe runs one dialogue in the normal dialogue box. He checks the eyes, asks the name and «Кому служиш?», then on «Не знаю» asks 3 questions, names the 3 paths, advises one and accepts «Та ні, краще…». The choice is the oath, at any level; its tree opens at level 5.
  - The priests of the three paths are plain NPCs. The contract priest has the new art and name.
  - D718 text work is done, and the god's name is one key (Q100).
  - Journal: three emblems on Characters, plus one «?» tip.
- **Not built:**
  - The scribe's table: there is no art for it.
  - Voiced greetings for the scribe and the contract priest: no audio files exist.
  - Two of the five deeds in the plan, «wounded in the burning village» and «Bandit Camp / brute's key»: no dialogue beat exists for them.
- **D-IDs (calls beyond the plan):** OC1–OC7 below. The orchestrator numbers them.
- **B rows:** none fixed. One new defect is filed below (OCB1).
- **Full suite:** 115 PASS, 9 FAIL. Eight of the failures also fail on the base merge; the ninth (`verify_combat_player`) is a flake that passed on re-run.

## What changed (file:line pointers)

### 1. No oath gate
- `SampleProject/Scripts/Gameplay/Scenes/City.gd`: the gate logic is removed; it is now only a doc comment.
- `Maps/City.tscn`: the `GateTalk` area and the `ObjectiveTargets/oath_keepers` marker are removed. `MayorHallGate`, the east wall, stays.
- `dialogue_quest/(en/)City_MayorHall_Guard.dqd`: deleted.
- `SkillManager.can_swear_oath` no longer checks the level. Oath skills keep `required_level` ≥ 5, so the tree opens at 5, at once if the hero is already there.

### 2. Leanings
- `Scripts/Systems/OathLeanings.gd` (new, preloaded): a child of SkillManager, reached as `skill_manager.leanings`.
- Combat events it listens to:
  - `player_blocked` / `player_parried` → Samal.
  - Damage dealt below ⅓ HP, and hits traded within 0.6 s → contract.
  - The new `EventBus.player_dodged_through`, emitted from `Player.take_damage` and `Arrow` while the hero rolls → no god.
  - A won fight with no damage taken → no god.
- Points are added per fight and capped. Deeds use `signal|leaning|<path>` in dialogue.
- Saved in `PlayerDataModule`; a save without leanings loads as zeros.

### 3. Census
- `Scripts/Gameplay/NPCs/CensusScribe.gd` and `Scenes/Gameplay/Objects/NPCs/gate_scribe.tscn` (art `gate_scribe/sheet.png`, idle/front/work rows, same layout as the witch scene). It stands in `Maps/CityGates.tscn` at x 1150, between the cellar door and the guards.
- `CityGates.gd` `_after_fight()`: the census plays by itself, then the old after-fight line.
- `dialogue_quest/(en/)CityGates_Census.dqd` is uk/en `[ЧЕРНЕТКА]/[DRAFT]` text, with dialogue choices and branches. Signals:
  - `census|answer|<path>`: one of the questions.
  - `census|advise`: the scribe picks the advice from the leanings plus the answers.
  - `census|pick|<path>`: `swear_oath`.
- A low-level line («сила прийде з 5-го рівня») shows only below level 5.
- Old saves past the fight with no oath: the scribe wears the crest and calls out (`CityGates_Scribe_Bark`). His menu offers **Census**.
- `DqdReader` (replays, bubbles) skips everything inside `branch … branch|end`.

### 4. The path priests
- `OathKeeper.gd` keeps only the talk: one dialogue for a hero who follows this priest's path, another for everyone else. There is no swear menu, no crest and no bark (the bark files are deleted).
- `oath_witch.tscn` now uses `contract_priest/sheet.png`. `OATH_WITCH.tres` is renamed «Priest of contracts» with a new portrait. Node and character ids stay as they were, to avoid churn.

### 5. D718 text
- The priests' Talk / Sworn / Chatter lines are rewritten, uk + en, all drafts. Samal is the Paladin's god, «${contract_god}» the Dark Knight's, and the dervish serves no god.
- Urizen's line now reads «Мій бог — ${contract_god}».
- Skills: Sky's Grace → **Samal's Grace**, Skyfall Blessing → **Samal's Blessing**, Judgement of the Sky → **Judgement of Samal**. Two descriptions now say «Samal's light». The keeper field, subclass and prestige names in `skills.json` are renamed the same way.
- `journal_people.json`: the three priests and a new GATE_SCRIBE entry.
- The god's name is one key: `DialoguePaths.CONTRACT_GOD` = «the god of contracts» / «Бог контрактів». It is set as the DialogueQuest flag `contract_god` on every dialogue start and solved in `DqdReader`. **Q100** asking for the name is added to `questions_for_sapega.md`.

### 6. Journal and tip
- `journal_component.tscn`/`.gd`, `%PathEmblems`: on Characters only. The three emblems use existing skill icons (radiant_smite / blood_pact / balanced_strike). Brightness goes from `UITokens.PATH_EMBLEM_DIM` to 1 by `OathLeanings.shares()`; no numbers are shown.
- The `paths` topic in `tutorial.json` (hint_topic). `TutorialManager` shows it on the first `leanings_changed`; TipTray limits it to once per playthrough.

### 7. Skills screen (D728)
- `skills_component.gd`: before the census only the base tab and tree show. After it, the base tree plus the chosen path's tab and tree.
- The tree's status line says «Opens at level N» until level 5.
- `show_tree` asserts on any tree other than the chosen one.

### Deeds (draft choices in existing scenes)
| Dialogue | Choice | Paths |
|---|---|---|
| `OldMan_Decision` | the grandfather's charge | protect / «what's in it for me» / «I'll see whose business it is» |
| `Merchant_Caravan_Give` | the caravan | help / bargain / it's on my way |
| `Lab_Acquaintance` | Alisia | support / she's worth money / walk on your own |

The Alisia deed comes after the census, so it only shows in the emblems.

## Calls I made (D-ID text for the orchestrator)
- **OC1, numbers:** these leaning numbers are drafts.

  | Event | Path | Points |
  |---|---|---|
  | Parry | Samal | 2 |
  | Block | Samal | 1 |
  | Hit dealt below ⅓ HP | contract | 1 |
  | Hit traded within 0.6 s | contract | 1 |
  | Roll through an enemy swing (once per enemy per 0.5 s) | no god | 1 |
  | Fight won untouched | no god | 3 |
  | Deed choice | its path | 3 |

  - Cap: at most 5 per path per fight. A lost fight adds nothing.
  - Advice: the strongest leaning counts 6 and the others in proportion (`ADVICE_WEIGHT`); each answer to the scribe counts 4. Ties go to Samal, then contract, then no god.
- **OC2:** the census starts by itself once the gate fight ends, at the scribe's spot. A save past the fight with no oath runs it from the scribe's menu (Census), shown with a crest and a call-out.
- **OC3:** a cutscene skip stops at an answer: it never picks for the player, and skipping goes on by itself once the player answers (`DialogueManager.skip_line`). For the verify scripts, `DQDialoguePlayer.accept()` chooses the answer in focus. The game never calls it.
- **OC4:** the scribe and the priest of contracts have no voiced greeting (`NpcBase.greets = false`) until voices exist. Their babble uses the `villager` and `priest` voices.
- **OC5:** the Journal emblems are the path skills' icons (Radiant Smite, Blood Pact, Balanced Strike), labelled Samal / Contract / No god, with a «ШЛЯХИ» caption above the Characters card.
- **OC6:** Sky-named skills and titles are renamed to Samal (list in §5). Ids, icons and sounds keep their old names.
- **OC7:** a modal keeps focus on its default button while nothing else has focus (`modal_dialog.gd _process`). Without this, the grandfather's gift popup, right after the new deed choice, opened with no focus and could not be closed from the keyboard.

## New defect
- **OCB1:** during the census at the gate, an interact prompt panel (the cellar door's «Enter», x 1090) shows behind the answer buttons. Visible in `design/shots/oath_census/census_serve.png`. In-world prompts are not hidden while a dialogue is open.

## Tests
- `verify_oath_census.gd` (new): ALL PASS.
  - [1] A GOOD bot that blocks and parries drifts to Samal (3 blocks → Samal 3). A dodger drifts to no god (4 rolls, rolled through, untouched). Per-fight cap and deed signals are checked, and each deed has uk/en drafts.
  - [2] Real input: gate fight → scribe → Down×3 + Enter «I don't know» → 3 answers → advice «Samal» → «No, rather no god» → Warden. The level-5 line shows below 5. Afterwards the scribe only talks.
  - [3] Old save: the crest and the Census menu (Enter) → direct answer → Dark Knight. At level 5 the tree is open at once; the other trees stay shut.
  - [4] Journal emblems: brightness 1.00 / 0.60 / 0.20, no numbers, Characters only. The tip topic is checked.
  - [5] Replays skip branches; `${contract_god}` is solved; no Sky/Eclipse worship in the priests' lines.
- `verify_oath.gd`: rewritten for plain priests (Talk only), the oath at any level with the tree at 5, old saves keeping their oath, and leanings saved. ALL PASS.
- Updated for the new rules, ALL PASS:
  - `verify_progression` (the Mayor Hall opens without an oath; the hero walks in)
  - `verify_npc_flow` (the scribe's crest and bark replace the keepers')
  - `verify_skill_trees_ui`, `verify_skill_screen`, `verify_skills_ui`, `verify_skill_trees` (only the chosen tree)
  - `verify_locale` (no oath confirm menu)
  - `verify_lab_cells` (the skip waits for the answer)
- Also passing: `verify_city_gates_raid`, `verify_journal`, `verify_journal_sections`, `verify_starter_loot`, `verify_village_fight`, `verify_tutorial_hints`.
- Captures: `SampleProject/UI/capture_oath_census.gd` → `design/shots/oath_census/` (census_scribe, census_serve, census_advice, census_en, journal_emblems, priests). `capture_skill_trees.gd` no longer shoots the removed oath menu or the other trees.

## Full suite
`Scripts/Tools/run_verify.sh`: **115 PASS, 9 FAIL**.
- 8 of the failures also fail on the base merge `419aa49e` (elites-first + hints-toggle), checked one by one: `verify_dialogue_speaker` (hangs: the parser is compiled before the autoloads), `verify_gamepad_parity`, `verify_living_world`, `verify_npc_arrival`, `verify_onboarding`, `verify_save_load_room`, `verify_tasks`, `verify_xp_curve`.
- `verify_combat_player` («ten rolls in a row all start (9)») is a timing flake: it passed in the first full run and again on its own re-run.
- The first full run also showed regressions from this work in `verify_lab_cells`, `verify_starter_loot` and `verify_npc_arrival` (Arrow's compile order). All three are fixed (OC3, OC7, Arrow reaches EventBus at runtime). `verify_npc_arrival` still fails, as it does on the base.
