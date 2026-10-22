---
type: report
status: done
tags: [cloud, localization, backlog-31]
---

# Cloud report — localization-2 (BACKLOG 31, part 2: data + dialogue; part 3: greetings)

Branch `cloud/localization-2` (from `origin/cloud/integration` + `origin/feature/backlog`;
`cloud/localization-1` was already in the base). Godot 4.6.2 headless, Linux, no display — nothing captured.
Plan: [[localization_plan]] (slices table updated). The owner was not reachable; every call below is an agent call.

## 1. What was built

### Speakers: ASCII ids, English names (slice 2b)
- `dialogue_quest/characters/`: the Cyrillic ids became `ALISIA`, `ASTRIT`, `URIZEN`, `MERCHANT`, `ENEMY`, `SUAN`,
  `GNOME_MECHANIC`, `DARK_PRIESTS` (files renamed with `git mv`); the duplicate «Кусакам» character was folded into
  `KUSAKAM` (file deleted, its 3 lines now say `KUSAKAM`). Every `character_name` is an English key (`Kusakam`,
  `Grandfather`, `Blacksmith`, `Sister Ilvane`, `Bandit leader`…) with the Ukrainian in `uk.po` — this also fixes the
  Russian names (Разбойник, Дед, Жрец, Торговец, Враг → Розбійник, Дід, Жрець, Торговець, Ворог).
- Updated with the ids: every `.dqd` speaker field, `sound_events.json` → `voices`, `journal_people.json`,
  `merchant.tscn` `character_id`, `DialogueManager.PLAYER_SPEAKERS`, `Scripts/Tools/build_portraits.gd`.
- `CharacterManager` party names and `CompanionManager.NAMES` are English keys; `CompanionJoinedNotification`
  translates the name inside its composed string; `player_vitals_panel.gd` translates before `to_upper()` and
  re-renders on a language switch (the HUD showed «КУСАКАМ» in English before).
- Old saves: `PlayerDataModule.RENAMED_SPEAKERS` rewrites the four Cyrillic ids a journal could hold
  (Торговец, Алісия, Астрит, Уризен) on load — otherwise the Journal → Characters page would crash on a dev save.

### Dialogue in two languages (slice 2c)
- `dialogue_quest/en/<id>.dqd` — an English twin of each of the 59 files: same lines, same order, same speaker
  fields; `[ЧЕРНЕТКА]` → `[DRAFT]` (drafts stay drafts in both languages). Translation by an agent; Sapega should
  read it (judgement calls in §2 D-text 1).
- `SampleProject/Scripts/Systems/dialogue_paths.gd` — `DialoguePaths.localized(path)`: `uk` → the file as is,
  anything else → `en/<id>.dqd` (an assert if the twin is missing). Used where the file is **read**:
  `DialogueManager.start_dialogue()` (parses the twin, plays it under the Ukrainian path as the dialogue id) and
  `DqdReader.lines()` (replay, bubbles, chatter, verifies). Scenes and triggers keep building the Ukrainian path,
  so every `dialogue_finished` listener works unchanged in both languages.
- Ukrainian sources fixed so they hold no English: `Canyon_Intro.dqd` and `DesertRoad_Monologue.dqd` were English
  (now Ukrainian — written by the agent from the English); Latin stage tags `[Canyon]`/`[Village]`/`[Lab]` →
  `[Каньйон]`/`[Село]`/`[Лабораторія]`; `[PLACEHOLDER]` → `[ЗАГЛУШКА]` in the Ukrainian file; «Вій вже почався» →
  «Бій уже почався» (typo); Russianisms «збився з путі» → «збився зі шляху», «в путь» → «в дорогу»;
  «Алісия» → «Алісія» in the line texts (as `design/lore.md`).
- `dialogue_box.tscn` lost its «Lorem ipsum» / «This is a man with a very long name» preview texts (the
  manager clears them before every line anyway), so the scene check needs no exception.

### Data JSON (slice 2a)
- `uk.po` +288 keys, one section per data file (`# ── Data: items.json`…) plus `# ── Character names`;
  `en.po` regenerated (818 keys). Existing «Малик» → «Малік», «Дідусь» → «Дід» (the speaker name).
- `SampleProject/Resources/Translations/data_fields.json` — the one list of shown data fields (file, path, where
  it is shown). `Scripts/Tools/po_data_keys.py` reads it and lists every shown data string missing from `uk.po`
  (`data strings: 292, missing in uk.po: 0`); `verify_locale` [4] reads the same list.
  Not in the list because no code shows them: recipe `name`, merchant `name`, oath `keeper`/`subclasses`/`prestige`,
  tutorial `key`.
- `ItemDatabase.get_item_name()` / `get_item_description()` return the text in the game language (enchanted
  items: translated base name + ` +N`); the unused `language` params and every `name_ru` / `description_ru`
  (Russian) are gone. One place, so every composer that glues item names (chest / pickup / loot toast /
  recipes / enchanting / modals) is covered. Equipment and Status read equipped names through it.
- Composers through `tr()`: `journal_component.gd` (titles, groups, descriptions in `_normalize`; chronicle
  paragraphs before the join), `skills_component.gd` (tree name, class / oath name, prerequisites, "needs X
  first", held skill, the bottom-bar hint), `tutorial_topics.gd` (text and hint before the glyphs are resolved).

### Greetings by locale (part 3)
- Voice: **Piper "lada" (uk, x-low)**, `voice-uk-lada-x-low.tar.gz` from the rhasspy/piper v0.0.2 GitHub release.
  Its `MODEL_CARD`: dataset `egorsmkv/ukrainian-tts-datasets` / lada, **License: Apache 2.0**, trained from
  scratch → release-clean. The other Ukrainian Piper voice (`uk_UA-ukrainian_tts-medium`, 3 speakers) is only on
  huggingface.co, which the cloud network policy refuses — its card could not be read, so it was not used.
- `Scripts/Tools/audio/make_voices_uk.py` (piper-tts 1.8 in a /tmp venv; GPL-3.0 tool, nothing of it ships) →
  `SampleProject/Assets/Audio/Voice/Greetings/uk/<npc>_{0,1}.ogg`, the same six NPCs and moods as the Kokoro set,
  processed like `make_voices.py` (trim, fade, tape pitch, reverb, `build_audio.save`). One female speaker: the men
  are pitched down (×0.74–0.84) and spoken faster to compensate.
- `sound_events.json`: `greet_<voice>_uk` next to each `greet_<voice>`; `SoundHooks.greet_event()` picks by locale.
- `SampleProject/Assets/Audio/Voice/README.md`: the row for `Greetings/uk/`, the voice, its licence, why not the
  other voice, and the Steam AI disclosure now names both models. (The README's Cyrillic companion names became
  English.)

### `verify_locale.gd`
`DATA_DEFERRED` and `RUNTIME_FILLED` are gone; new sections:
- [4] every field of `data_fields.json` in each locale (uk: an untranslated key is its own failure);
- [5] every Ukrainian `.dqd` has a twin with the same line shapes and speakers, every speaker is a character id,
  no Cyrillic ids; then **every line of every file** goes through the real dialogue window (`DialogueManager.replay`)
  in each locale — text and speaker name;
- [6] every greeting has a `_uk` twin with its own files; the blacksmith greets by locale.
Placeholder stripping now also allows digits (`{skill_slot_1}`).

Other verifies that compared Cyrillic names or Ukrainian lines now compare the English keys / the English twin
(the tests run in English): `verify_status`, `verify_party_panel`, `verify_dialogue_speaker`, `verify_companions`,
`verify_journal_sections`, `verify_npc_recall`, `verify_tasks`, `verify_canyon_exit`; `verify_village_fight` reads
the Ukrainian source directly for its «Длань» check.

## 2. Decisions — ready-to-paste D-text (agent calls, Sapega to confirm)

1. **GAP — English dialogue text** (BACKLOG 31; agent call, Sapega to confirm): every line in
   `dialogue_quest/en/` is an agent translation of Sapega's Ukrainian, kept short and plain. Calls worth a look:
   «ящуре/ящіре» → "lizard", the witch's «ящірко» → "little lizard"; the guard's «Ти не пройдеш!» → "You shall not
   pass!" (a Tolkien echo — change if unwanted); the Lab prisoner's invented incantation is transliterated
   ("Varra-khess um-tal! Shakraz-iduun! Takhmi-rakh ash-zarra!"), not translated; «Діду!» → "Grandpa!";
   «Затемнення» → "the Eclipse"; the smith's «бог угод» → "the god of deals". Two files were English in the
   Ukrainian folder (`Canyon_Intro`, `DesertRoad_Monologue`): the Ukrainian is now the agent's and the English is
   the old text.
2. **TECH — Dialogue locale is resolved when the file is read** (agent call, Sapega to confirm; refines
   localization-1 D-text 5): scenes keep the Ukrainian path, which stays the dialogue id; `DialoguePaths.localized()`
   reads `en/<id>.dqd` instead when the game is not Ukrainian. Every edit of a Ukrainian `.dqd` needs the same
   line in the twin — `verify_locale` [5] fails on a different line count or speaker.
3. **TECH — Speaker ids are ASCII, names are translation keys** (agent call, Sapega to confirm): DialogueQuest
   characters `ALISIA`, `ASTRIT`, `URIZEN`, `MERCHANT`, `ENEMY`, `SUAN`, `GNOME_MECHANIC`, `DARK_PRIESTS` (the
   duplicate «Кусакам» merged into `KUSAKAM`); `character_name` is the English name and `uk.po` the Ukrainian
   (Розбійник, Дід, Жрець, Торговець, Ворог replace the Russian forms). Old saves have their journal ids rewritten
   on load.
4. **GAP — Ukrainian game terms for data** (agent call, Sapega to confirm): Holy Warrior → Святий воїн, Paladin →
   Паладин, Dark Knight → Темний лицар, Warden of Balance → Вартовий рівноваги; trees Світло / Темрява /
   Нейтральність; attributes Сила / Спритність / Живучість / Мудрість; Ore → руда, Ingot → злиток, Potion → зілля
   (Мале / Середнє / Велике), Ether → Ефір, Mana Crystal → Кристал мани; parry → парирування, combo → серія; Priest
   of the Sky → Жриця Неба; Hunter → Мисливиця; Warrior-thaumaturge → Воїтелька-чудотворниця; Cleric of the god of
   contracts → Клірик бога угод; «Каньйон І / ІІ» with the Cyrillic І. Everything is in `uk.po`
   (`# ── Data: …` sections).
5. **OVERRIDE — Ukrainian greetings: Piper "lada", one voice for all six NPCs** (part 3; agent call, Sapega to
   confirm): the only Ukrainian Piper voice whose model card could be checked (Apache 2.0, trained from scratch);
   x-low quality (16 kHz), female, the men pitched down. A better multi-speaker voice can replace it by re-running
   `make_voices_uk.py` with another model — check its card first, never non-commercial weights. Steam disclosure:
   "pre-generated voice lines … made with text-to-speech models (Kokoro-82M, Apache 2.0, English; Piper "lada",
   Apache 2.0, Ukrainian greetings)".

### B-ID / data candidates (for the integrator)
- `items.json` Ether: "Restores 30 MP." — the game's resource is SP (the Ukrainian already says SP).
- Potions: "Potion" heals 50, "Lesser Potion" 75 — Lesser is stronger than plain.
- Part 1 objectives say «бандит», data now says «розбійник» — pick one word.

## 3. Tests

| Verify | RESULT |
|---|---|
| `verify_locale` | `RESULT: ALL PASS` — [0] 818 keys, [1] 428 scene texts per locale, [3] 1664 (en) / 1672 (uk) live texts, [4] 298 data texts per locale, [5] 59 twins, 322 window texts (182 lines + speaker names) per locale, [6] 6 greetings, 12 Ukrainian files |
| `po_sync.py` / `po_data_keys.py` | `en.po: 818 keys` / `data strings: 292, missing in uk.po: 0` |

Full suite: running — result added when it finishes.

## 4. Left

1. Sapega reads the English twins (`dialogue_quest/en/`) and the two Ukrainian files written by the agent
   (`Canyon_Intro`, `DesertRoad_Monologue`).
2. A better Ukrainian voice (multi-speaker, male voices) when huggingface.co is reachable — check the model card.
3. Not covered by a check: composed strings outside the walked screens (e.g. a save card's location for a room
   outside the journal, `scene.capitalize()` in `GameFlow.location_title`); weapon ids in a skill's "Weapon" fact.
4. Not touched on purpose: `project.godot`, `MainMenu.tscn`, `GameUITheme.tres`, `playthrough.gd`; the vault
   registers (BACKLOG, BUGS, D-register, queue).
