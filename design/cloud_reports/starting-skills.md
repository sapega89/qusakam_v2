---
type: report
tags: [cloud, skills, D815]
---

# cloud/starting-skills — D815 starting Shield Block + Healing Palm

**Summary (NOT TESTED: Godot could not be installed in this run).**
- Done (code, unrun): New Game grants Shield Block + Healing Palm (rank 1, no JP, Palm on hotbar slot 1); all skills sleep until the Canyon summit meditation; there a «Your Skills» tutorial window (en/uk drafts) names both skills, their buttons and the Skills screen; save/load and respec keep them. New `verify_starting_skills.gd`; `verify_difficulty`, `verify_canyon_exit`, `verify_kusakam_skills`, `verify_village_fight` updated.
- **Not done:** no test was run. The routine's Godot download (`curl … godot … && unzip`) was refused by the session's permission classifier ("Code from External"), so there is no RESULT line for any test, no `verify_difficulty` re-judge and no `design/shots/starting_skills.png`. The full-suite line is missing.
- D-ID text: D-ss1 … D-ss4 below (the orchestrator numbers them). No B rows fixed.
- Expected fallout: ~20 tests that boot New Game and then buy Shield Block / Healing Palm or cast skills before any meditation (list below). They need `sm.awaken_skills()` after boot, or ALREADY_UNLOCKED instead of OK, in a run that has Godot.
- Full suite: **not run**.

## D-ID text

**D-ss1 — Starting skills (D815).** On a New Game `SkillManager.grant_starting_skills()` (called from `Game._initialize_save_and_room`, new-game branch) learns `STARTING_SKILLS = [shield_block, healing_palm]` at rank 1 without spending JP. Healing Palm is the only heal in the base tree (`heal 25`, a 3-sip flask, D504), so there was no second candidate to choose from. Healing Palm goes on the first free hotbar slot (slot 1 in a new game, D261/D331). Shield Block is a passive, so it takes no slot. `player_state.starting_skills` records what was given; it is saved and loaded with `skills_awakened`. A gift's first rank counts 0 JP in `tree_spent` (caps, profession gates) and in `spent_points` (respec refund). A respec keeps the gifts at rank 1 in their slot and refunds only their extra ranks. `skills.json` is unchanged: Shield Block keeps `jp_cost 1`, which a pre-D815 state still pays. A save from before D815 gets nothing granted and no gate.

**D-ss2 — Skills sleep until the first meditation.** After `grant_starting_skills()`, `player_state.skills_awakened = false`. While it is false, `can_use_skill` returns `NOT_AWAKENED` (new `Result`) and every passive gives 0 (`passive_value`), so Shield Block does nothing yet. The hotbar shows this with its existing unusable look: the slot at `UNAVAILABLE_ALPHA` 0.4, no ring or glow (Figma 434:6628). There is no new widget. The Skills screen lists both as learned. In `Canyon._on_abduction_cutscene_state`, once Kusakam has sat for `MEDITATION_SIT_HOLD`, `awaken_skills()` sets it true and emits `EventBus.skills_awakened`, and the hotbar repaints. A state that never went through New Game (old saves, manager tests) has no gate (`skills_awakened` defaults to true).

**D-ss3 — The meditation tells the player.** A new tutorial topic `starting_skills` («Your Skills [DRAFT]» / «Ваші навички [ЧЕРНЕТКА]», frames `heal`) goes through `TipTray.show_tip`, and `open_tip` opens its window at once, during the meditation. The game stays paused and the cutscene waits for the window to close. Hints Off (D746) shows nothing. The topic shows once a playthrough (D745) and then stays in the Tutorial list. If the game is not free when the window would open, the «?» waits like any tip. The text takes its buttons from the InputMap ({block}, {skill_slot_1}, {game_menu}):
> You have skills. Grandfather's teaching wakes as you meditate. Shield Block: hold {block} to block, and a blow that breaks through your block hurts 20% less. Healing Palm: press {skill_slot_1} to heal — three sips, refilled each time you save. Press {game_menu} and open Skills to see them and the skills you can learn next. [DRAFT]

The uk text is in `uk.po`, marked `[ЧЕРНЕТКА]`. The old level-up «?» `healing_palm` ("You can learn Healing Palm") no longer fires in a new game, because Palm is already learned and level 2 shows `level_up`. It stays for pre-D815 states.

**D-ss4 — verify_difficulty with the starting skills (answers D810's re-judge, numbers pending).** `_make_hero` now calls `grant_starting_skills()` + `awaken_skills()` for both builds. The flask is there from level 1 (was level 2). The SKILLS build has 1 more JP, because Shield Block is free. Shield Block stays 0 in the sim, which never blocks (D809/D810); no assertion was changed. **No numbers:** the test was not run (see summary). The D810 rows that were red are elite brute L8, tower shield guard L9, armoured scorpion L11, Mercenary L12, scorpion L9 and the brute rows, all at L8+, where the flask was already counted. Only the +1 JP (one more active rank) can move them. One risk to check: at L1–2 the STRENGTH build now has a flask, which could make `[3]` (STRENGTH must not beat an elite) fail. The balance call stays with Sapega once the numbers exist.

## Files

- `SampleProject/Scripts/Managers/Gameplay/SkillManager.gd`: `NOT_AWAKENED`, `STARTING_SKILLS`, `grant_starting_skills`, `awaken_skills`, `skills_awakened`, `is_starting_skill`, `_paid_jp_cost`; gates in `can_use_skill` / `passive_value`; `tree_spent`, `spent_points`, `can_respec`, `_forget_all`.
- `SampleProject/Scripts/Managers/Gameplay/PlayerStateManager.gd`: `starting_skills []`, `skills_awakened true`.
- `SampleProject/Scripts/Systems/Save/Modules/PlayerDataModule.gd`: saves and loads both (defaults `[]` / `true`).
- `SampleProject/Scripts/Game.gd`: new game → `grant_starting_skills()`.
- `SampleProject/Scripts/Gameplay/Scenes/Canyon.gd`: `awaken_skills()` + `_tell_starting_skills()` in the summit meditation.
- `SampleProject/Scripts/Core/EventBus.gd`: `skills_awakened`.
- `SampleProject/UI/Components/skill_hotbar.gd`: repaints on `skills_awakened`.
- `SampleProject/Resources/Data/tutorial.json`, `Translations/en.po`, `uk.po`: topic `starting_skills`.
- Tests: new `verify_starting_skills.gd` (start state, dim slot, save/load before and after, the real `MeditationTrigger`, window on pause with the InputMap buttons, uk, once a playthrough, respec). `verify_canyon_exit` (asleep before, awake after the meditation). `verify_kusakam_skills` [2a] (D815 start state, then a pre-D815 hero for the learn-through-UI flow). `verify_village_fight` (Palm is the starting one). `verify_difficulty` (D-ss4).

## Tests expected to need updating (unverified, from grep)

These boot New Game and then buy Shield Block / Healing Palm (now ALREADY_UNLOCKED), count base-tree JP with Shield Block bought, or cast skills / read passives before any meditation (now NOT_AWAKENED / 0):
`verify_skill_rules` ([4] `unlock_skill("healing_palm") == OK`, `use_skill("fire_strike")`), `verify_skill_casts`, `verify_skill_fx`, `verify_skill_moves`, `verify_skill_ranks`, `verify_skill_trees`, `verify_skill_trees_ui` ("toughness + shield_block = 3 JP"), `verify_skill_screen` (picks Shield Block), `verify_oath`, `verify_oath_census` (toughness/shield_block/devotion for the 3-JP gate), `verify_souls_combat` (Shield Block reduction), `verify_bow`, `verify_charms`, `verify_attributes`, `verify_new_points`, `verify_lab_boss`, `verify_combat_stats`, `verify_hero_death`, `verify_archer`, `verify_damage_numbers`, `verify_equipment`, `verify_skills_ui`, `verify_onboarding`, `verify_audio`.
Fix pattern: after the New Game boot, call `sm.awaken_skills()` when the test plays after the Canyon. Where the test buys a starting skill, expect it already learned, or reset to a pre-D815 hero as `verify_kusakam_skills` [2a] does. Then run `verify_scripts_compile` and the suite.

## Not done

- No Godot run: no RESULT lines, no `verify_scripts_compile`, no full suite, no capture. The capture script `capture_starting_skills.gd` was not written, because an untested capture would add more unrun code. The shot goes to `design/shots/starting_skills.png` (xvfb) in the next run.
- `.uid` files for `verify_starting_skills.gd` are created by the next Godot import.
