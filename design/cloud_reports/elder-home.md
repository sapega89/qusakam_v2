---
type: report
tags: [cloud, routine, village, rooms]
---

# Cloud report — elder-home (2026-10-26)

**Summary**
- Done: the grandfather's meeting now happens in his house (`ElderHouse`). That covers the NPC, the trigger, `OldMan_Outside` → `OldMan_Healing` → `OldMan_Decision`, the flags (same names), the gift with its hint, the key, the bark, the objective and its arrows. The Village keeps the street fight, «Check on the house» (its arrow points at `ElderDoor`) and LeavingVillage. The invented `VillageElder` is removed (D438).
- Done: the `LizardCave` exit (and its arrival) moved from the lizard shrine at x 96 to the lit cave opening at x 320. The `GatehouseCellar` door stays where it was: the stairs are only painted, so the hero has nowhere to stand at the top. No art was drawn.
- **Not done: no test was run.** The cloud sandbox refused to run the downloaded Godot binary (the permission classifier denied `--import`), so I could not get a single `RESULT:` line, a full-suite line or a capture. Every verify change was checked by reading the code only. The integrator must run the suite (list below).
- D-ID (next free number when written; the integrator renumbers): **D716**, text below.
- B rows fixed: none (this is the M13 playtest note, not a B-ID).
- Full suite: **not run** (no Godot).

## D716 (row for `figma_decision_register.md`)

| D716 | OVERRIDE | **Grandfather's meeting plays in his house, and the hero leaves by the door he came in** (Sapega, playtest 2026-10-26: «дід мав бути в своєму домі і там мав відбутись діалог Кусакама»; «якщо Кусакам входить в будинок через двері, то і через двері має вийти; так само з печерою, з лагерем, з підвалом — щоб не було такого, що бекграунд не співпадає з реальністю»; carries out D438; `cloud/elder-home`). The grandfather (`OldManQuest`, `grandfather.tscn`, StoryNpc `village_oldman_complete` / `OldMan_Decision`, bark `OldMan_Bark`) stands inside `ElderHouse` at x 560. A new room script, `ElderHouse.gd`, runs `BEFORE_FIGHT → OLD_MAN_WAITING → OLD_MAN_HEALING → OLD_MAN_DECISION → DONE`. While waiting, the objective is «Talk to the old man», with its arrow on him. `StateChangeTrigger_OldMan` (x 570) starts the talks, in order: OldMan_Outside → OldMan_Healing (full HP, Healing Palm light) → OldMan_Decision (copper sword, leather armour, the `oldman_gift` hint, `grandfather_key`). The flags keep their names (`village_oldman_met/_healed/_complete`, `village_oldman_gift`, `village_grandfather_key`), so old saves continue and the `elder_attic` gate and journal still read them. After the talks, the objective is «Leave the village», with its arrow on the house's `ExitDoor` (`ObjectiveTargets/canyon_bridge` there). The Village no longer has the grandfather, his trigger or the `old_man` mark. Its states are `ABDUCTION_CUTSCENE, ARRIVAL, STREET_FIGHT, CHECK_HOUSE, LEAVING_VILLAGE`. After the fight it plays Village_AfterFight and sets «Check on the house», with the `house` mark on `ElderDoor` (2163, 344). Once `village_oldman_complete` is set, it plays LeavingVillage as the hero steps out of the door, where before it played straight after the decision. D342's elder (`VillageElder`, Malik's frames, no lines) is removed with `village_elder.tscn`. The journal chronicle line now reads "He found the old man **in** his ruined house" (uk «в його зруйнованому домі»). Doors: the LizardCave exit and its arrival stand in the painted cave opening (x 320, not at the shrine on the left edge). The GatehouseCellar exit stays at the foot of the stairs, because the stairs have no step to stand on. The houses, camp, mural and mesa without a painted opening wait for M12. Grandfather's beaten / lying frames are still D438's art task. |

## What changed

**Grandfather → his house (task 1)**
- `SampleProject/Scripts/Gameplay/Scenes/ElderHouse.gd` (new; attached to the `ElderHouse` root). It holds the state machine above and the code moved from the Village: `_talk_to_old_man`, `_show_healing_light` (D437/D481), `_play_dialogue`, `_complete_quest_for_dialogue` (flags), `_give_oldman_gift`, `_give_grandfather_key`, the gift hint and its equip watcher, and `_exit_tree`.
  - Initial state: `village_oldman_complete` → DONE; `_healed` → DECISION; `village_fight_complete` → WAITING; otherwise BEFORE_FIGHT.
  - BEFORE_FIGHT and DONE do nothing and leave the objective alone, so a later visit to the attic does not overwrite the current objective.
  - A save made after `village_oldman_met` skips OldMan_Outside (as before). A save made after `_healed` plays the decision when the hero enters.
- `SampleProject/Maps/ElderHouse.tscn` changes:
  - Added: the script, `StateChangeTrigger_OldMan` (570, 824; r 32; `OLD_MAN_WAITING` → `OLD_MAN_HEALING`), and `OldManQuest` at (560, 876). The y is the floor (864) + 12, the same offset his sprite had on the Village floor (384 → 396).
  - Added `ObjectiveTargets/old_man` (on him) and `ObjectiveTargets/canyon_bridge` (= `ExitDoor`).
  - Removed `VillageElder`.
- `SampleProject/Scripts/Gameplay/Scenes/Village.gd` now keeps only the outside part: the abduction flag, the arrival, the street fight, CHECK_HOUSE (AfterFight + «Check on the house» → `house`) and LEAVING_VILLAGE. It no longer has the gift, key, healing or hint code.
- `SampleProject/Maps/Village.tscn`:
  - Removed `OldManQuest`, `StateChangeTrigger_OldManOutside`, the `grandfather.tscn` ext_resource and `ObjectiveTargets/old_man`.
  - `ObjectiveTargets/house` moved from 1582 to 2163, onto `ElderDoor`.
  - The painted `GrandpaHouse` (x 1398) has no door and stays as scenery. The door is on the house at x 1890 (the one titled «Дім діда» on the map).
- Who `VillageElder` was: D342 invented him as a "village elder" with Malik's frames and no lines. D438 (Sapega, 2026-10-23) says «зайвий нпц — його тут не має бути, і тут мав лежати дід» and «there is no village elder». So he was a stand-in where the grandfather belongs, and he is removed. `village_elder.tscn` was referenced only by the room and a test, so I deleted it too.
- Data checks:
  - The `.dqd` lines contain nothing about being outside. «за килимом у моїй хаті» works inside the house, so the dialogue is unchanged.
  - `story.json` objectives are unchanged. The chronicle line "by his ruined house" became "in his ruined house" (`story.json:32`, `en.po`, `uk.po`).
  - `quests.json` has no grandfather entry. `gates.json` `elder_attic` (flag `village_oldman_complete`) and `lizard_shrine` (key) are unchanged.
  - `game_menu.tscn` unlock flags have the same names.
  - D140 (the meeting) is still true. Its "he heals Kusakam" part now happens in the house.
- What comes after the meeting still works:
  - Leaving the village: the Village enters LEAVING_VILLAGE when `village_oldman_complete` is set and plays LeavingVillage, which sets `village_left_complete` for the Canyon gate.
  - The attic key and gate use the same flag.
  - Saves store only flags and have no new fields.
- One behaviour change: the gift hint banner now hides when the hero leaves the **house**, where before it hid when he left the village. As before, the room that gave the hint hides it.
- `StoryNpc.gd:4` doc comment updated.

**Doors (task 2)**
- `Scripts/Tools/build_rooms_batch1.py`: `CAVE_MOUTH_X = 320` for the LizardCave `Arrival` and `ExitDoor`. The lit opening in `LizardCave/gen_back.png` is at texture x ≈ 195–235, × 1.5 → room x ≈ 300–350. The fight trigger spans 460–580, so the arrival does not set it off. The generator was re-run: `LizardCave.tscn` changed only in those two positions, and the other four rooms came out byte-identical.
- GatehouseCellar left as it is: the floor is one flat tile row at y 416 with no ledge on the painted stairs, so the hero cannot stand at the top.
- Every door still leads back to its own door: Canyon `LizardCaveDoor` ↔ LizardCave `ExitDoor`, Village `ElderDoor` ↔ ElderHouse `ExitDoor`.
- `design/room_art_audit.md` rows for LizardCave and GatehouseCellar updated.

**Tests (task 3) — edited, NOT run**
- `verify_village_fight`:
  - [4] → CHECK_HOUSE.
  - [5] the objective's arrow is `ElderDoor` and there is no grandfather in the street.
  - [6] `ElderDoor` → ElderHouse, the hero at `ExitDoor`, OLD_MAN_WAITING, «Talk to the old man» on him, the trigger beside him starts the talks, full heal + light.
  - [7] the met/healed/complete flags, the key once, DONE, «Leave the village» on the house door.
  - [7b] new: `ExitDoor` → Village, the hero at `ElderDoor`, LEAVING_VILLAGE + LeavingVillage, `village_left_complete`.
- `verify_starter_loot`:
  - The gift comes from `ElderHouse`.
  - [4] the talks run in the house: Outside, Healing, Decision, then DONE.
  - [5] new: the Village then plays LeavingVillage, after the gift arrived.
- `verify_gift_popup` [2]: the talks run in `ElderHouse`.
- `verify_village_house`:
  - No grandfather or trigger in the street.
  - The grandfather stands inside the house, behind the hero.
  - No `VillageElder`.
  - Entering and leaving by the same door was already checked: the hero arrives at `ExitDoor` and comes back out at `ElderDoor`.
- `verify_rooms_batch1` [2]:
  - The key comes from `ElderHouse._complete_quest_for_dialogue`.
  - New: the cave exit is at x 320 with the `Arrival`, the hero arrives at it, and leaving the cave puts him at Canyon `LizardCaveDoor`.
- `verify_npc_recall` [1] and `verify_npc_activity`: the grandfather is in `ElderHouse`.
- `verify_onboarding`: `ElderHouse.gd` added to `EARLY_ROOMS`, and `canyon_bridge` must also be marked in ElderHouse.
- `verify_gates`: comment only.
- `verify_npc_flow` and `verify_npc_chatter` needed no change: they spawn `grandfather.tscn` themselves.
- Captures pointed at ElderHouse: `capture_art_fixes`, `capture_npc_activity`, `capture_npc_flow`, `capture_npcs_in_world`.
- **The integrator should run:** `verify_village_fight`, `verify_starter_loot`, `verify_gift_popup`, `verify_village_house`, `verify_rooms_batch1`, `verify_npc_recall`, `verify_npc_activity`, `verify_onboarding`, `verify_gates`, `verify_branches`, `verify_charms`, `verify_journal_notes`, `verify_story_journal`, `verify_locale`, then the full suite.
- Spots most likely to need a tweak:
  - The grandfather's y (876) if his feet float or sink.
  - `verify_village_fight` [7b]: the gift modal is closed with the focused button before going out of the door.
  - `ElderHouse.gd` has no `.gd.uid` yet. Godot writes one on the first import; commit it.

**Registers (task 4):** `design/MASTER_PLAN.md` M13 → 👀 (code on the branch, tests not run). I did not edit `figma_decision_register.md` (ROUTINE_RULES); D716 is above.

## Why Godot did not run
`curl` of `Godot_v4.6.2-stable_linux.x86_64.zip` worked. Running it (`$G --headless --path . --import`) was refused by the session's permission classifier ("Code from External"). The rules say not to work around that, so nothing headless ran. MASTER_PLAN M8 records the same "хмара не дала Godot" for `cloud/world-map`.
