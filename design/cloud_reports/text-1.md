---
type: report
tags: [cloud, text, localization, dialogue]
---

# cloud/text-1 — «бандит» everywhere, NPC chatter drafts

- **Done:** D566, «розбійник» → «бандит» in every Ukrainian text (19 strings, all in `uk.po`). D571: chatter drafts written for all five groups. Four groups are wired through `NpcBase.chatter_dialogue`: the smith, the three oath keepers, and the caravan merchant on the Desert Road.
- **Not done:** the City Gates guards and the City market folk have their lines written but not wired. The guard (`gate_guard.tscn`) is a plain sprite, not an `NpcBase`, and the market has no NPC at all. Both need a scene change that is the orchestrator's call (see Gaps).
- **D-ID text (orchestrator to apply):**
  - **D606** | GAP | **«Бандит» applied** (`cloud/text-1`, applies D566). Every «розбійник» form in `uk.po` (speaker names, objectives, journal, story, bestiary) now reads бандит / бандита / бандити / бандитів / бандитами. The `.dqd` files, `dialogue_quest/characters` and the JSON data had none, because the data are English with `uk.po` keys. `verify_locale` [7] keeps it that way. Sapega's own quote in [[lore]] stays as said.
  - **D607** | GAP | **NPC chatter drafts** (`cloud/text-1`, applies D571 through D338). The `*_Chatter.dqd` files carry 2–3 lines each, marked `[ЧЕРНЕТКА]`/`[DRAFT]`. Wired: `Smith_Chatter`, `City_Oath_{Priest,Witch,Dervish}_Chatter` (on the NPC scenes) and `DesertRoad_Merchant_Chatter` (on the DesertRoad map instance only, so the City merchant stays quiet). Written but not wired: `CityGates_Guard_Chatter` (the guard is not an NpcBase) and `City_Market_Chatter`, with a new speaker `MARKET_TRADER` «Крамар» (not in the journal). The quest bark (D452) still wins while an NPC has a marker. Tested by `verify_npc_chatter` [8].
- **B rows fixed:** none.
- **Full suite (one run):** `SUITE: 3 FAIL`, 99 PASS. Two of the fails were mine and are fixed, each re-run green: `verify_npc_flow` (the smith now says his plain chatter when he has nothing to give) and `verify_audio` (`MARKET_TRADER` needed a babble voice). The third, `verify_onboarding` («keyboard: a light hit does not pass Heavy»), fails the same way on `origin/feature/backlog` without these changes, so it is not this branch's.

## 1. «Бандит» (D566)

Only one file held the old word: `SampleProject/Resources/Translations/uk.po`.

| Form | → |
|---|---|
| Розбійник / розбійник | Бандит / бандит |
| розбійника | бандита |
| Розбійники / розбійники | Бандити / бандити |
| розбійників | бандитів |
| розбійниками | бандитами |

Lines touched: the enemy names `Bandit` → «Бандит», `Bandit leader` → «Ватажок бандитів», `Desert Bandit` → «Пустельний бандит»; the objectives «Здолайте бандитів» and «Здолайте бандита на вулиці»; «Проженіть бандитів від Міської брами…»; the story and journal entries (village raid, the bandit in the street, the stolen relic, the gate raid); the smith's helmet quest; the people entries for the gate guard and the merchant; and the bestiary text for the desert bandit and the archer. Each replaced word keeps the case of the word it replaced (both are second-declension masculine nouns), and the words around them already agreed (e.g. «Пустельний бандит»). A script check confirmed that every `msgid` containing "bandit" has a `msgstr` containing «бандит». English is unchanged.

Searched and clean: `dialogue_quest/*.dqd`, `dialogue_quest/characters/*.tres` and `SampleProject/Resources/Data/*.json`.

Left as they are: `design/lore.md` (Sapega's quote), and the decision register, questions file and older reports (they are the record).

## 2. NPC chatter (D571)

| Who | File (uk + `en/` twin) | Lines (uk / en) | Wired |
|---|---|---|---|
| City Gates guards (`GATE_GUARD`) | `CityGates_Guard_Chatter.dqd` | «Тримай очі долі, малий. На небо тут не дивляться.» / "Keep your eyes down, little one. Nobody here looks at the sky." · «Ти тремтиш, чи то пісок на тобі шурхотить?» / "Are you shaking, or is that just sand rustling on you?" · «Браму стережемо ми. А що над нею — того не стереже ніхто.» / "We guard the gate. What hangs above it, nobody guards." | **no**: guard is not an NpcBase |
| Caravan merchant, Desert Road (`MERCHANT`) | `DesertRoad_Merchant_Chatter.dqd` | «Мій караван… Бандити забрали навіть мотузки.» / "My caravan… The bandits took even the ropes." · «Двадцять років ходжу цією дорогою й жодного разу не підвів очей. Тому й живий.» / "Twenty years on this road and I never once raised my eyes. That is why I am alive." · «Ящір із краю світу? Я думав, там самий пісок.» / "A lizard from the edge of the world? I thought there was nothing out there but sand." | `Maps/DesertRoad.tscn` → Merchant |
| Smith (`BLACKSMITH`) | `Smith_Chatter.dqd` | «Залізо не бреше: або тримає удар, або ні.» / "Iron does not lie: it holds the blow, or it does not." · «Не стій біля горна — іскри не питають, чий то хвіст.» / "Keep away from the forge — sparks do not ask whose tail it is." · «Малий ти для обладунків. Та й кожен щит колись був грудкою руди.» / "You are small for armour. Then again, every shield was once a lump of ore." | `blacksmith.tscn` |
| Oath keeper, priest (`OATH_PRIEST`) | `City_Oath_Priest_Chatter.dqd` | «Я молюся з опущеними очима, дитино. Світлу не треба, щоб на нього дивились.» / "I pray with my eyes lowered, child. The light does not need to be looked at." · «Боги чують і тих, хто тремтить.» / "The gods hear those who tremble too." | `oath_priest.tscn` |
| Oath keeper, witch (`OATH_WITCH`) | `City_Oath_Witch_Chatter.dqd` | «Ш-ш, ящірко. У тіні хоч не кортить глянути вгору.» / "Shh, little lizard. In the shade, at least, nobody is tempted to look up." · «Страх — теж сила. Не викидай його, поки не навчишся тримати.» / "Fear is strength too. Do not throw it away before you learn to hold it." | `oath_witch.tscn` |
| Oath keeper, dervish (`OATH_DERVISH`) | `City_Oath_Dervish_Chatter.dqd` | «Пісок пам'ятає кожен крок. І твій теж.» / "The sand remembers every step. Yours too." · «Вітер дме — я стою. Ото й уся мудрість.» / "The wind blows, I stand. That is all the wisdom there is." | `oath_dervish.tscn` |
| City market folk (`MARKET_TRADER`, new) | `City_Market_Chatter.dqd` | «Фініки! Солодкі, як сон без неба!» / "Dates! Sweet as a dream without a sky!" · «Ящірка на базарі? Тримай гаманця ближче до хвоста.» / "A lizard at the market? Keep your purse close to your tail." · «Під навісом ціни ті самі, зате голова на місці.» / "Same prices under the awning, and you keep your wits." | **no**: no market NPC exists |

How the lines keep to the lore:
- No angels or demons appear. The only higher powers named are "the gods".
- The sky is something people keep their eyes off (the guard, the merchant, the priest, the witch and the market trader) and is never explained (D587).
- The merchant blames the bandits, and the stranger from the edge of the world surprises him (D579, D586).
- Kusakam is small and scared but moving: the guard teases him about shaking, and the smith and the priest encourage him.
- No line points at a quest, an item or a place to go.

The chatter route plays a file's lines one after another in the cloud, so each set reads as one short passing remark.

### Gaps (orchestrator)
- **City Gates guards:** `gate_guard.tscn` is a `Node2D` with a sprite and `NpcActivity`, not an `NpcBase`. Making it one would add an interact prompt and an NPC menu with no entries. Wiring options: give it an `NpcBase`/Interactable without a menu, or add the room-level trigger pattern that `City.gd` uses for the Mayor Hall guard (`say_in_passing(guard, …)`) to the CityGates room. This needs a call, so I did not build it.
- **City market folk:** the City has no market NPC (no scene, no sprite). The lines and the `MARKET_TRADER` speaker are ready for when one exists. This needs an art and scene decision.
- **Found, not fixed (outside this task):** in `City_Oath_Priest_Talk.dqd` the priest says «Небо світить усім однаково… лише світло», which praises the sky. That contradicts D587 (the sky is a curse). Suggested **B-ID** for that line's rewrite.

## Files changed
- `SampleProject/Resources/Translations/uk.po`: D566, plus «Крамар».
- `SampleProject/Resources/Translations/en.po`: `Market trader`.
- `dialogue_quest/{CityGates_Guard,DesertRoad_Merchant,Smith,City_Oath_Priest,City_Oath_Witch,City_Oath_Dervish,City_Market}_Chatter.dqd` and the same names in `dialogue_quest/en/` (new).
- `dialogue_quest/characters/MARKET_TRADER.tres` (new).
- `SampleProject/Resources/Data/journal_people.json`: `MARKET_TRADER` added to `not_listed`.
- `SampleProject/Scenes/Gameplay/Objects/NPCs/{blacksmith,oath_priest,oath_witch,oath_dervish}.tscn`: `chatter_dialogue`.
- `SampleProject/Maps/DesertRoad.tscn`: `chatter_dialogue` on the Merchant instance.
- `SampleProject/UI/verify_locale.gd`: new [7], «бандит» only (no «розбійн» in `uk.po` or any uk `.dqd`; the enemy names).
- `SampleProject/Resources/Data/sound_events.json`: `MARKET_TRADER` → the `villager` babble voice.
- `SampleProject/UI/verify_npc_flow.gd`: the smith with nothing to give no longer stays silent. He says his first `Smith_Chatter` line, not the D452 bark.
- `SampleProject/UI/verify_npc_chatter.gd`: uses `Smith_Chatter`; new [8] checks the wiring, 2–3 lines by one speaker, at most 90 characters, and the draft marks in both twins.

## Tests
- `verify_npc_chatter`: `RESULT: ALL PASS`
- `verify_locale`: `RESULT: ALL PASS` (60 dialogues with twins, 21 speakers, [7] OK)
- `verify_npc_flow`: `RESULT: ALL PASS` (after the fix)
- `verify_audio`: `RESULT: ALL PASS` (after the fix)
- `verify_onboarding`: `RESULT: 1 FAIL: keyboard: a light hit does not pass Heavy`, the same on `origin/feature/backlog`
