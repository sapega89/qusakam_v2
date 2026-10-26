---
type: report
tags: [cloud, routine, enemies, placement, gates]
---

# Cloud report — elites-first (2026-10-26)

**Summary**
- Done: D722, D723 and D724 are built and tested (branch `cloud/elites-first`, continues `archer-first`).
- D722: the old vulture first flies **alone** on DesertRoad after the Caravan. The road has one lane, so the fight is optional through its chest: walking past `Chest_OldVulture` (by the shrine, x 4680) does nothing, and pressing E wakes the vulture. D723: `BanditCampDoor` is locked until the lone brute is beaten. He gives `bandit_camp_key`, and E with the key opens the door for good. Old saves that were already in the camp keep the door open. D724: the tower shield guard stands **alone** in the Laboratory's middle-floor pocket, east of the ladder's foot (the way on goes west), and guards `Chest_TowerGuard`.
- **D719's order problem is solved by D723:** the camp now opens only after `Fight_LoneElite` (x 4300). That is past the Mesa (x 2700), so the hero meets the ordinary archer, then the lone brute, and only then the camp's heavy archer and its brute among the others. archer-first's untested D719 changes were tested here and are green (`verify_enemy_variety`, `verify_difficulty`, `verify_archer`, `verify_road_sections`, `verify_rooms_batch1`, `verify_room_entrances`, `verify_map_geometry`).
- Not done: `verify_masher` is not on this branch (it is only on `cloud/hard-fights`). Its two new rows are below for the integrator.
- D-ID texts: **D722, D723, D724** (below). B rows fixed: none.
- Full suite: see the last section.

## D-ID rows (for `figma_decision_register.md`)

| D722 | OVERRIDE | **The old vulture first flies alone on the road, over a chest after the Caravan** (Sapega 2026-10-26, Q95 «A»; D582, D583, D708). `DesertRoad Fight_OldVulture` is a `RoomEnemySpawner`: `state_key = "enemies_oldvulture"`, `respawns = true` (an ordinary fight under D492, so the fight music and the reset rules are the usual ones), and **`enemy_level = 4`**. That is the hero's level after the Caravan (D642, measured by `verify_difficulty`). D708's L2/L3 figures were for the vulture's old trial place. It has one point, `BigSlot_OldVulture_1` (x 4740, y 200 in the air; `enemy_type = vulture`, `big_kind = old_vulture`, `spawn_id = "Fight_OldVulture_EnemySpawnPoint1"`). `Chest_OldVulture` (Chest.tscn, x 4680 on the road floor, at the shrine's foot after the Caravan and the lone brute, on flat open sand) holds **Lesser Potion × 2 + Mana Crystal × 2**. That is the road's chest tier: the tower stash has Mana Crystal × 2 and the camp has Lesser Potions (agent call, since there are no loot tables). **Optional on a one-lane road (agent call):** DesertRoad is one 480-px cell high, so there is no side lane where a zone could be avoided. So the fight has **no trigger zone**, and the chest wakes it: `Chest.guard` points at the fight, the first E spawns the vulture, and the chest opens only once the fight is won. Walking past does nothing. The vulture is alone. The Caravan (x 3500–3960) and the lone brute (x 4300–4480) are behind the hero by then. A hero who runs past a live brute and wakes the vulture anyway fights both, by his own choice. After D492 brings the fights back, the chest stays open (`opened_Chest_OldVulture`). Optional fights add no XP to `verify_difficulty`'s route (as side rooms don't). At L4 the old vulture falls to both builds, as the road's elites before the oath must. |
| D723 | OVERRIDE | **The Bandit Camp opens with the lone brute's key** (Sapega 2026-10-26, Q96: «табір відчиняється тільки після того, як переможеш громилу-одинака на дорозі; тоді з нього ключ»; D582, D643, D710; it settles D719's order). `DesertRoad BanditCampDoor` (RoomDoor) gets `gate_id = "camp_door"`, a new key gate in `gates.json`: `key = "bandit_camp_key"`, `consumes_key = true`, `locked_dialogue = "Gate_CampDoor_Locked"`. The prompt named `camp_stockade`, but that gate is the stockade **inside** the camp, opened by the chief's `camp_key`, and it stays as it is. `Fight_LoneElite` (the lone brute, L2) has `reward = {"bandit_camp_key": 1}`, given once on the first win (D583 rewards; D492 returns do not repeat it). The item is `bandit_camp_key`, «Bandit Camp Key» / «Ключ від табору бандитів», a `key_item`. It has no `icon_path`, like every other key: the repo has no key icon art, the jrpg_icons folder is the known missing-icons baseline, and the only "Key.png" is a MetSys map symbol. **RoomDoor now takes key gates.** E without the key plays the hero's line: «Двері табору замкнено, ключа в мене немає…» / "The camp door is locked, and I have no key. One of them carries it — that brute with the club guarding the road further on." E with the key spends it and sets room state `opened_BanditCampDoor` (saved), and the hero goes in. **Old saves:** a key-gated RoomDoor whose target room the hero has already explored (any MetSys cell of it visited) is open, so a save made in or after the camp before D723 keeps the door open, with no key and no lock-out. The World Map uses the same rule (`RoomDoor.locked`). `CampShortcutDoor` keeps its own flag gate `camp_shortcut`. **Order:** the camp now comes after the Mesa (2700), the Caravan (3500) and the lone brute (4300). The ordinary archer (Mesa) comes before the camp's heavy archer (D719), and the brute is met alone before the camp's group. So D719's first meeting in the camp still makes sense, and it is now in the right order. |
| D724 | OVERRIDE | **The tower shield guard first stands alone in the Laboratory, over a chest** (Sapega 2026-10-26, Q97 «(а) окремий необов'язковий бій у Лабораторії з нагородою»; D582, D711). `Laboratory Fight_TowerGuard` has `state_key = "enemies_towerguard"`, `respawns = true` (ordinary, D492) and `enemy_level = 9`, the middle floor's level (D642, measured). Its zone is `Trigger` at x 1580 on the middle floor. Its one point is `BigSlot_TowerShieldGuard_1` (x 1630, `enemy_type = shield`, `big_kind = tower_shield_guard`, `spawn_id = "Fight_TowerGuard_EnemySpawnPoint1"`). `Chest_TowerGuard` (x 1668, against the east wall) holds **Hi-Potion × 1 + Silver Ingot × 2**, the city tier the hero has just passed: the city merchant sells silver ingots (agent call, since there are no loot tables). **Off the main way:** the hero comes down `Ladder1` (x 1504) onto the middle floor, and the way on goes **west** (Fight_Cursed at 1330, Fight_Middle, Ladder2). The pocket east of the ladder's foot (x 1536–1696) is a dead end that is only entered on purpose. The Laboratory has no other side room: it is three full floors joined by two ladders. The ordinary shield-bearer has been met long before, alone on the road (`Fight_LoneShield`, L2) and paired on the Mesa. The guard fights alone. A hero who backs off west past x 1330 also wakes the cursed jackal. The chest opens only once the fight is won (`Chest.guard`), and stays open after D492 returns. At L9, SKILLS wins and STRENGTH loses (D652 [3]). |

## Details

Changed files:
- `SampleProject/Scripts/Gameplay/RoomDoor.gd`
  - Key gates: `is_open()`, the static `locked(gate, room, node_name, target)`, and key use in `_on_interacted`.
  - The "target room already explored" rule for old saves.
- `SampleProject/Scripts/Systems/LocationMap.gd:158`: RoomDoor uses `RoomDoor.locked` (the visited rule on the World Map too).
- `SampleProject/Scripts/Gameplay/Chest.gd`: `@export var guard: NodePath`.
  - While the guarding fight is not won, E does not open the chest.
  - A fight with no zone is woken by the chest.
- `SampleProject/Maps/DesertRoad.tscn`
  - `Fight_LoneElite.reward`, `BanditCampDoor.gate_id`.
  - `Fight_OldVulture` + `BigSlot_OldVulture_1`, `Chest_OldVulture`. These are placed after `Fight_Caravan` in the file, so the route's file order matches the road.
- `SampleProject/Maps/Laboratory.tscn`: the Chest ext_resource, `Fight_TowerGuard` (+ `Trigger`, `BigSlot_TowerShieldGuard_1`), `Chest_TowerGuard`.
- `Resources/Data/gates.json` (`camp_door`), `items.json` (`bandit_camp_key`), `en.po` / `uk.po` (name + description).
- `dialogue_quest/Gate_CampDoor_Locked.dqd` and `dialogue_quest/en/Gate_CampDoor_Locked.dqd`.
- Tests:
  - `verify_gates` [5] old vulture, [6] tower guard, [7] camp door + old save made in the camp.
  - `verify_rooms_batch1` [4]: the door is locked with the line, the brute's key, the door opens and the key is spent. [7]: the door stays open after loading.
  - `verify_difficulty`: optional (chest-guarded) fights give no route XP, and [0a] checks that each is optional with one elite. The two "unplaced" meetings are now the real placements (old vulture L4, tower guard L9).
  - `verify_enemy_variety`: big slots 11 → 13, and each new kind's one place.
  - `verify_road_sections` [3]: the one gift on the road is the guarded chest.
- `design/MASTER_PLAN.md` §5: Q95–Q97 ✅ and rows D722, D723, D724. The D719 row is updated.
- Shot: `design/shots/elites_first/old_vulture_and_tower_guard.png`. Top: the old vulture woken at its chest by the shrine. Bottom: the tower guard in the lab pocket with the chest against the wall.

RESULT lines (run here):
- `verify_gates` ALL PASS (35 new checks in [5]–[7]); `verify_rooms_batch1` ALL PASS; `verify_difficulty` ALL PASS;
  `verify_enemy_variety` ALL PASS; `verify_road_sections` ALL PASS; `verify_archer`, `verify_flying_enemies`,
  `verify_room_entrances`, `verify_map_geometry`, `verify_chests`, `verify_lab_rooms`, `verify_laboratory`,
  `verify_world_map`, `verify_locations`, `verify_desert_road` ALL PASS.

`verify_masher` (on `cloud/hard-fights` only): add these two rows to `FIGHTS`. The masher calls `spawn_all_enemies()` itself, so a fight with no zone works:
```
{"name": "lone old vulture (chest after the Caravan)", "room": "DesertRoad", "fight": "Fight_OldVulture", "cls": "elite"},
{"name": "lone tower shield guard (Laboratory chest)", "room": "Laboratory", "fight": "Fight_TowerGuard", "cls": "elite"},
```

Agent calls to confirm (P1): the chest wakes the road fight (no side lane on the road); the old vulture's L4; both chests' contents; the gate is named `camp_door` (not `camp_stockade`); the keys have no icon; the "already explored" rule for old saves.
