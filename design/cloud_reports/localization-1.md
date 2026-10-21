---
type: report
status: done
tags: [cloud, localization, backlog-31]
---

# Cloud report — localization-1 (BACKLOG 31, part 1: the UI)

Branch `cloud/localization-1` (from `origin/cloud/integration` + `origin/feature/backlog`). Godot 4.6.2
headless, Linux. No display: nothing captured. Plan: [[localization_plan]].

## 1. What was built

### Runtime registration (no `project.godot`)
- `SampleProject/Scripts/Systems/LocalizationManager.gd:29` `_register_translations()` — loads
  `Resources/Translations/<lang>.po` for every language and `TranslationServer.add_translation()`s it;
  a missing file or a wrong `Language:` header is an assert. Before this the manager wrote a
  ProjectSetting at runtime, which loads nothing — the Language row switched nothing.
- `:49` `apply_language()` (locale + `language_changed`, no save) and `:37` `set_language()` (= apply + save).
- `SampleProject/Scripts/Systems/Save/Modules/SettingsModule.gd:55` — `apply_settings()` applies the saved
  language (the slot settings load deferred, after the autoload's `_ready`, so the old `_ready` read the
  default). `:18` default language **`en`** (was `uk`, which never took effect) — D-text 2.
- `export_presets.cfg` — both presets' `include_filter` gained `*.po`.

### Key scheme and files
- Key = the English text (gettext msgid); Labels/Buttons/tooltips translate their own text, so plain
  literals needed no code change. `SampleProject/Resources/Translations/uk.po` — **528 keys**, sectioned
  by screen; `en.po` the same keys with value = key.
- `Scripts/Tools/po_sync.py` — regenerates `en.po` from `uk.po`, fails on an empty or duplicate
  translation. Run it after every `uk.po` edit.

### Strings through translation (code changes = `tr()` around composed strings only)
- `Scripts/Menus/Game/skills_component.gd` — 66 `tr()` (format strings: `Lv %d`, `%d JP`, gives/effects,
  states, reasons, hints); `"%d attribute pt%s"` became `tr("attribute points: %d")` (no English plural
  trick in a translated string). String replacement only — the Skills screen is another branch's area.
- `Scripts/Menus/Game/options_component.gd:230` segment cells `"✓ " + tr(option)`, `:288` `Unlimited` / `%d FPS`.
- `stats_component.gd:120,121,127,368`, `inventory_component.gd:219,308,316,335`,
  `equipment_component.gd:197`, `journal_component.gd:95`.
- `Scripts/UI/modal_templates.gd:57,58,70,85,125` (static → `TranslationServer.translate`).
- `Scripts/UI/XPBar.gd:44,47`, `LevelUpNotification.gd:36,37`, `CompanionJoinedNotification.gd` (+ re-render
  on `NOTIFICATION_TRANSLATION_CHANGED`), `UI/Components/player_vitals_panel.gd:170`,
  `party_status_panel.gd:94`, `save_slot_card.gd:60`, `skill_hotbar.gd` (`%ds`, `Unarmed`),
  `Scripts/Crafting/crafting_service.gd:65` (`Requires: %s`), `enchanting_service.gd:70` (stat label).
- `Scripts/UI/input_glyphs.gd:72,89,94,100` — mouse buttons, sticks and D-pad names translated
  (ЛКМ, лівий стік, хрестовина вгору); pad buttons and keyboard keys stay as they are.
- Key-name labels never auto-translate (the pad button "Back" must not become «Назад»):
  `UI/Components/bottom_bar.gd` key badge, `skill_hotbar.gd` key badges,
  `Scenes/Menus/Game/controls_component.tscn` (both `Key` labels), `tutorial_menu.tscn` `Key` —
  `auto_translate_mode = DISABLED`.
- `Scenes/UI/DemoEndScreen.tscn` — the three texts were Ukrainian in the English game; now English keys
  (Ukrainian in `uk.po`); `Scripts/UI/DemoEndScreen.gd` no longer duplicates them in code.

### The language switch
Settings → Game → **Language** already existed (`options_component.gd:337`, segment row). It now works:
mouse click, keyboard Enter, pad A; tab names and every visible label switch at once; the choice is saved
and applied on the next start. Cells read `English | Ukrainian` / `Англійська | Українська` (D-text 3).

### `SampleProject/UI/verify_locale.gd`
- [0] en/uk registered from code and **not** via `project.godot`; same keys in both `.po`; every `uk.po`
  value translated and Latin-free (placeholders `{action}`, maaacks' `KEY`/`ACTION` excepted); no Cyrillic in `en.po`.
- [1] every `.tscn` with text under `Scenes/`, `UI/`, `Maps/` + `MainMenu.tscn`, `Game.tscn`, in each locale
  (skipped and printed: 3 dead scenes whose scripts no longer exist — `right_panel_component`,
  `sub_location_selection`, `timer_panel`; `Scenes/Test/`; nodes owned by addon scenes).
- [2] the Language row: mouse → uk (tabs read «Інвентар» at once, HUD under the menu clean, saved),
  keyboard Enter → en, pad A → uk → en, a saved `uk` applied when settings load.
- [3] per locale: title screen, Load menu, HUD, every Game Menu tab, the three Journal sections, the equip
  picker, Misc modal, all four Settings tabs, Tutorial list + a topic window, Controls, both exit confirms,
  all 16 `ModalTemplates`, Save screen, Shop (+ categories), Crafting (four stations), NPC menus (merchant,
  blacksmith, oath keeper + its confirm), Enchanting, level-up and companion-joined notifications, cutscene
  skip prompt, Game Over, demo end. Every walked screen must be found and show text.
- Rules: `en` fails on any Cyrillic; `uk` on any Latin word outside the allow-list (`verify_locale.gd:41`
  + every bound keyboard key from the InputMap, case-insensitive).
- **Part 2 switch:** `DATA_DEFERRED := true` (`:27`) cuts text from `Resources/Data/*.json` and `.dqd` out of
  the checked string and only counts it (233 occurrences today); `RUNTIME_FILLED` (`:32`) skips two scene
  placeholders the dialogue box / companion notification overwrite with data. Part 2 deletes both.

## 2. Decisions — ready-to-paste D-text (agent calls, Sapega to confirm)

1. **TECH — Translations: English keys, `.po`, registered in code** (BACKLOG 31; agent call, Sapega to confirm):
   the key of every string is its English text (gettext msgid) — scenes and code stay English (D121) and
   Godot's controls translate their own text; composed strings use `tr()`. `Resources/Translations/uk.po` is
   the source (sections per screen), `en.po` mirrors its keys (`Scripts/Tools/po_sync.py`). `.po` over CSV:
   one file per language, comments, plurals if needed. Registered at boot by
   `LocalizationManager._register_translations()` (`TranslationServer.add_translation`), because
   `project.godot` carries Sapega's uncommitted edits (the D270 pattern); `verify_locale` [0] asserts they
   are not in `project.godot` yet — when it is committed, move them to
   `internationalization/locale/translations` and delete the loop. Key-name labels are never translated.
2. **OVERRIDE — The game starts in English** (agent call, Sapega to confirm): `SettingsModule` default
   language `uk` → `en` (D121: English is the primary language; the old `uk` default never took effect
   because nothing was registered). Ukrainian is one click away: Settings → Game → Language.
3. **OVERRIDE — Language names in the current language** (agent call, Sapega to confirm): the Language row
   reads `English | Ukrainian` in English and `Англійська | Українська` in Ukrainian — the strict reading of
   «no Cyrillic in EN, no English in UK». The usual alternative is endonyms (`English | Українська` in both),
   which breaks both rules by one word each; switch if Sapega prefers that.
4. **GAP — Ukrainian wording of game terms** (agent call, Sapega to confirm): tabs Інвентар · Спорядження ·
   Мапа світу · Інше · Журнал · Навички · Стан; **JP → ОН** (очки навичок); **EXP → XP**; Lv → Рів.;
   FPS → кадр/с; mouse buttons **ЛКМ / ПКМ / СКМ**, sticks «лівий / правий стік», D-pad «хрестовина»; pad
   buttons (A, LB, RT, Start, Back…) and keyboard keys (Space, Enter, Esc, Tab, W…) stay as printed on the
   device; HP / SP / XP stay (Sapega). World and title: Khalahas → **Халахас**, «Khalahas Heroes» → «Герої
   Халахасу», title «WAY OF QUSAKAM» → **«ШЛЯХ КУСАКАМА»**, copyright «Студія «Халахас»». Craft → «Кувати» /
   «КУВАННЯ» (the blacksmith's screen), Misc → «Інше». The zone objectives (D121 placeholders) got
   Ukrainian too. Every value is in `uk.po` — edit there and run `po_sync.py`.
5. **GAP — Dialogue in two languages = one `.dqd` per language** (part 2 plan; agent call, Sapega to
   confirm): the Ukrainian files stay where they are (Sapega writes in Ukrainian), the English twin is
   `dialogue_quest/en/<id>.dqd` with the same structure; one resolver picks by locale (today 12 places build
   the path); a verify checks every file has a twin with the same `say`/`exit` count and speaker ids.
   Speakers become ids (`ALISIA`, `ASTRIT`, `URIZEN`, `MERCHANT`…) with display names from
   `journal_people.json`. Data JSON keeps English as the key, Ukrainian in `uk.po`. See [[localization_plan]] §4.

### B-ID candidates (for the integrator)
- **Keyboard Enter after a mouse click in the Game Menu does not press the focused button.** A click gives a
  content button focus but `FocusRouter.focus_mode` stays `"Tabs"`; the key press reaches
  `focus_router.gd:103 _unhandled_input` (the button does not consume it on press) → `focus_content()` moves
  focus to the first content control and the release lands nowhere. Seen on the Settings → Language cell
  (stack trace in the verify run); pad A is not affected (the router reacts to keys only).
  `verify_locale` [2] steps around it the way a keyboard player arrives (`focus_router.focus_content()` first).
- **The rebinding list (Settings → Controls) shows action ids as names** — `Dq Accept`, `Save Delete`,
  `Menu Prev Tab`, `Skills Unpick` (maaacks `String.capitalize()` of the action id). Translated to
  Ukrainian now; the English stays clumsy until the list gets readable names (`readable_action_names`).

## 3. Tests

| Verify | RESULT |
|---|---|
| `verify_locale` (new) | (suite run in progress) |

Full suite (`Scripts/Tools/run_verify.sh`): (suite run in progress)

Baseline before this branch (same container, same suite): `verify_game_ui_theme` — no RESULT line
(the headless theme build), `verify_onboarding` — `1 FAIL: pad: a held block does not pass Parry`; all
other verifies passed.

## 4. Left for part 2 (the next routine continues from this branch)

1. **Data JSON → `uk.po`** — items, recipes, skills (names, descriptions, trees, keepers, prestige,
   subclasses), attributes, quests, story (journal), journal_people, bestiary, tutorials (title, text,
   hint — `{action}` placeholders stay), merchants. Add a section per file; run `po_sync.py`. Then wrap
   the data part of composers in `tr()`: `crafting_service.gd:58` (`"%d %s"`), `:64` (`"%s ×%d"`),
   `enchanting_service.gd:69` (`"%s ×%d → %s  (%s %d → %d)"`), `skills_component.gd:462`
   (`_detail_kind` tree name), `:473` prerequisites, `inventory_component.gd:335`, the `"%s · %s"` joins,
   `modal_templates` item names, `recipe_panel.gd:18`. Delete `name_ru` / `description_ru` and the
   `language` params of `ItemDatabase.get_item_name/get_item_description` (`ItemDatabase.gd:169,179`).
2. **Character names** — `CharacterManager._get_default_character_data()` (Cyrillic names) and
   `CompanionManager.NAMES` to English keys (Kusakam, Alisia, Astrit, Urizen); `.dqd` speaker names to ids;
   `DialogueManager.PLAYER_SPEAKERS`. Update `verify_status`, `verify_party_panel`, `verify_dialogue_speaker`,
   `verify_companions` (they compare Cyrillic names).
3. **English `.dqd` twins** (`dialogue_quest/en/`, 59 files, 182 `say` lines) + `DialoguePaths.of(id)`
   replacing the 12 path builders listed in [[localization_plan]] §4 + a twin-structure verify. The English
   text has to be written (keep Sapega's voice; drafts marked like the `[ЧЕРНЕТКА]` lines).
4. **`verify_locale`:** `DATA_DEFERRED := false`, delete `RUNTIME_FILLED`, add a walk that opens a line of
   every `.dqd` in both locales (dialogue box + speaker name + choices) and the journal pages with entries.
5. Part 3 — greeting by locale (Kokoro EN per D277, a Piper Ukrainian voice with a release-clean licence).
6. Not touched on purpose: `project.godot`, `MainMenu.tscn` (its texts translate through `uk.po`, no edit
   needed), `GameUITheme.tres`, `playthrough.gd`; vault registers (BACKLOG, BUGS, D-register, queue).
