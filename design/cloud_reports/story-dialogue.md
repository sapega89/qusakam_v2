---
type: report
branch: cloud/story-dialogue
tags: [cloud, dialogue, story, ui]
---

# Cloud report — story-dialogue (MASTER_PLAN S5: D110, D111, D112)

**Summary**
- **Built:** the story presentation from Figma `36:65`. It is a project-owned layer (D110) over the same DialogueQuest player. It shows the darkened scene, the location as the chapter title with a thin rule, the hero's and the speaker's full-body cards, the line box with the name over a rule and a gold advance diamond, and the key hints. It is used by 12 prologue story `.dqd` files only. Barks, clouds, monologues and all other talks keep the plain window.
- **NOT RUN: Godot.** The auto-mode permission classifier refused to download and run the Godot 4.6.2 binary (ROUTINE_RULES setup 2, «Code from External»). So **no test has run, no capture exists, and there is no full-suite line.** The code was only checked by reading it. Before merging, run: `Scripts/Tools/run_verify.sh 'story_dialogue'`, `run_verify.sh 'dialogue_*'`, `run_verify.sh npc_recall`, `run_verify.sh game_ui_theme`, `run_verify.sh interaction`, the capture below, then the full suite.
- **D-ID text (new, proposed D774):** *Story dialogues use the story presentation (D110–D112; S5).* These are the prologue's main talks: OldMan_Outside, OldMan_Healing, OldMan_Decision (the grandfather); CityGates_Census (the scribe); CityGates_Raid (the guard); City_MayorHall, MayorHall_WallBurst, MayorHall_Defeat (the Mayor Hall); Lab_Cells_Arrival, Lab_Cells_Injection, Lab_Cells_Prisoner (the alchemist); Lab_Acquaintance (Malik). The list is in `Scripts/Systems/story_dialogues.gd`. A full-screen layer darkens the scene. The chapter title is the location of the hero's room (D565, `GameFlow.location_title`, already in en.po/uk.po). The cards show the hero's Idle frame on the left and the current non-hero speaker on the right, scaled up by a whole number with nearest filtering (D112: the game's own frames until full-body art exists). The speaking card is lit and the other is dimmed. The line box behaves exactly like the plain window: D736, D738, D739, D753, and story talks hold the hero (D737). Left out on purpose: CityGates_Scribe_Talk and CityGates_Cellar_Guard (repeat or side talks), the lab boss and djinn talks (not named in S5), and monologues (still a cloud, D178).
- **B rows fixed:** none.
- **Full suite:** not run (see above).

## What was built
| File | What |
|---|---|
| `SampleProject/Scripts/Systems/story_dialogues.gd` | `STORY` (the 12 ids), `HERO`, `CAST` (speaker → sheet + full-body cell), `is_story(path)`, `card(speaker)` (asserts that the speaker has a cell; no fallback) |
| `SampleProject/Scenes/UI/story_dialogue.tscn` + `Scripts/UI/story_dialogue.gd` | The layer: `Scrim`, `Chapter` (`ChapterTitle` TitleLabel UPPER + `ChapterRule`), `HeroCard`/`SpeakerCard` (theme `CardPanel`, `TextureRect` nearest), `Box`, `Hints` (shared `UI/Components/bottom_bar.tscn` as `PlainPanel`, actions only: dq_accept «Next line of dialogue», dq_accept «Hold: skip to the choice»). The layer is visible exactly when `%Box` is visible. `open(path, room)` sets the title and both cards; `speaker_changed` swaps and lights the cards. |
| `SampleProject/Scenes/UI/story_dialogue_box.tscn` + `Scripts/UI/StoryDialogueBox.gd` | The line box. It extends `GameDialogueBox.gd`, so it has the same typing, click-through, hold-skip and auto-advance. Theme `WindowPanel` (opaque, accent border). The name sits left over `NameRule`. The `BobbingMarker` icon is `diamond_sm.svg` tinted ACCENT. It never shows a portrait and emits `speaker_changed(id)`. |
| `SampleProject/Scenes/DialogueSystem.tscn` | `StoryDialogue` instance placed before `DialogueBox`/`ChoiceMenu`, so choices draw on top; `choice_menu` points to `../ChoiceMenu`. |
| `SampleProject/Scripts/Systems/DialogueManager.gd` | `start_dialogue()`: a story path → `_use_story_box()`, which hands the player the story box, connects the letter sounds and journal hooks, and calls `story.open()`. `_find_dialogue_system_in_scene()` still resets to the plain box at every start, so replays (D158) and other talks keep the plain window. New `is_story_presentation()`. |
| `SampleProject/UI/Tokens/UITokens.gd` | `STORY_*` tokens: scrim 0.72, margin 64, chapter 36 px, rule 600 px + colour, box 1584 wide with its bottom 260 px above the frame edge, card 216×336, card gap 48, idle tint, hints 72 px from the bottom. These are code-only consts, so **no theme regeneration is needed**. |
| `en.po` / `uk.po` | New key «Hold: skip to the choice» / «Утримання: до вибору». |

Layout at 1920×1080: title at (64, 64). Cards are 216×336 at y 306–642, flush with the box's left and right edges (x 168 and 1752). The box spans x 168–1752 with its bottom at y 820 and grows upward (B122). Hints sit at y 944–1008. The box sits lower than in Figma (Figma's bottom is about y 717) because `ChoiceMenu` is centred on the screen. With the Figma position, a 3-row choice list would cover the top of the box.

## Tests (written, not run)
- **New `verify_story_dialogue.gd`:**
  - [1] Each of the 12 ids exists in uk and en, has a non-hero speaker, and every speaker has a `CAST` cell inside its sheet. A bark and the scribe's repeat talk are not story talks.
  - [2] OldMan_Outside opens the layer with the story box and the plain box shut. The title is the location, top-left, with a thin rule. Cards show the hero on the left and the grandfather on the right, each with its own frame at an integer ≥×2 scale and nearest filtering, both above the box. The box has no portrait and the hero's line lights his card.
  - [3] A click shows the whole line, the marker appears, and the next click goes to the grandfather and lights his card. The hero is held, the layer closes at the end, and the hero is free again.
  - [4] Mayor Hall: Urizen, Astrit and Alisia each take the right card.
  - [5] A bark (`say_in_passing` Smith_Bark) does not open the layer. CityGates_Scribe_Talk opens the plain window. The next story talk (Lab_Cells_Arrival) opens the layer again.
- **Adjusted, because their talks became story talks:**
  - `verify_dialogue_speaker` [1]/[2] now test the plain window with CityGates_Cellar_Guard and Smith_Enchant_Give. The companion-portrait-in-window check was dropped: companions only speak in story talks now, and [4] above checks them on cards.
  - `verify_npc_recall` [5] now uses CityGates_Scribe_Talk.
  - `verify_dialogue_triggers` [3]/[4] re-read `dm.current_dialogue_box` after starting City_MayorHall. They now check the D736/D738/D739 behaviour in the story box.
- **`verify_game_ui_theme` [3b]:** the story layer uses GameUITheme, the story box is the opaque `WindowPanel`, and its Auto/Skip buttons are hidden.
- **Capture `capture_story_dialogue.gd`:** writes `design/shots/story_dialogue/{grandfather,census}_{uk,en}.png`, each with the game on the left and Figma `36:65` on the right (3840×1080).
- **Risks to watch when it first runs:**
  - The new scripts have no `.uid` files yet; Godot writes them on import.
  - `capture_story_dialogue` reaches the census through the gate fight, like `capture_oath_census`.
  - The card idle tint (`STORY_CARD_IDLE`) and scrim alpha are my calls and may need a tweak after the shots.
