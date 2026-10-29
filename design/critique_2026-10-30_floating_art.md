---
type: report
status: active
tags: [critique, rooms, art]
---

# Критика 2026-10-30: «плаваючий» арт у кімнатах

Пошук того самого класу дефектів, що Sapega знайшов у плейтесті 29.10 ([[BUGS]]): B215, B217, B220, B221, B224, B225, B230, B241, B245. Нічого в грі не змінено; B-ID не заведено — це робить оркестратор / [[BUGS]].

## Як міряли

Одноразовий Python-скрипт (поза репо) пройшов усі 50 `SampleProject/Maps/*.tscn`, розгорнув інстанси сцен (NPC, `room_entrance`, `platform_support`, декор) і для 613 `Sprite2D` / `AnimatedSprite2D` порахував світовий низ арту: позиція й масштаб усіх предків, `centered`, `offset`, `region_rect`, `hframes`/`vframes`/`frame`, `AtlasTexture`, і найнижчий непрозорий рядок текстури (PIL, alpha > 32). Для `RoomEntrance` враховано масштаб і offset, які ставить `RoomEntrance.gd` у `_ready()`. Підлога: верхня грань тайлів із колізією (`physics_layer_0` у `DesertTileset.tres` / `Tileset.tres`, вимкнені шари пропущено) плюс `StaticBody2D` (прямокутники, сегменти, полігони); під пропсом береться найближча поверхня в межах ±160 px.

**Зазор** = підлога y − низ арту: **плюс** = висить над підлогою, **мінус** = втоплений. Допуск: від −16 до +4 px, бо за D172 ноги героя й NPC намальовано на y = підлога + 12 (тому всі NPC, ковадло й `GiantScorpion` з −12 — це норма).

Калібрування на відомих багах збіглося: `Village/ElderHouse` −52.5, `GrandpaHouse` −41.5 (B221), `ShrineB*` +21.5, `ShrineA*` +9.5 (B225), шар `Waymarker` з `scroll_scale.y = 0.9` (B215).

**Межа методу.** Скрипт порівнює арт лише з **колізією**. Якщо підлогу намальовано всередині великої картинки фону, він цього не бачить: `Cistern/Well` (B241) має низ текстури на 387 (−3, «норма»), а чаша висить усередині самої картинки. Так само B230 (`SmugglersStash`, намальована долівка не там, де колізія). Такі випадки видно лише на скріні.

## Пропси, що стоять не на підлозі

| кімната | вузол | текстура | низ арту (world y) | підлога y | зазор px | вже відомо | як виправити |
|---|---|---|---|---|---|---|---|
| Laboratory | `Decor/Lamp2` (`lamp.tscn`) | `Decor/lamp/lamp_sheet.png` | 320 | 384 | **+64** | **нове** | зсунути y 320 → 384 (+64), як `Lamp1`/`Lamp3`. На скріні масляна лампа висить у повітрі на рівні голови героя, перед шафою (`lab_lamp2.png`, `lab_crystal1.png`) |
| Laboratory | `Decor/Crystal1` (`crystal.tscn`) | `Decor/crystal/crystal_sheet.png` | 320 | 384 | **+64** | **нове** | зсунути y 320 → 384 (+64), як `Crystal2`. Ймовірно, кристал ставили «на стіл», але меблі намальовано у фоні з паралаксом по X, тож кристал їде по них і на стіл потрапляє лише за однієї позиції камери: на одному скріні він висить перед колбою, на іншому біля столу |
| RockLedges | `Back/BurntHouses/Sprite` | `RockLedges/gen_burnt_houses.png` (×2.125) | 503.1 (у шарі) | 384 | −119 (статично) | **нове** (правило B215) | шар `Parallax2D` має `scroll_scale = (0.85, 0.85)`, тобто будинки зсуваються по Y відносно землі, коли камера йде вгору чи вниз. Або `scroll_scale.y = 1` і підігнати y, або прийняти як далекий план (рішення Sapega). На скріні не перевірено: кадр на схилі не захопив будинки |
| CaveUnderBridge | `Back/Waymark/Sprite` | `BridgeCave/gen_waymark.png` | 416.2 (у шарі) | 384 | −32 (статично) | B215 (там є «те саме перевірити») | `scroll_scale = (1, 0.9)`: перенести в шар зі scroll 1 і поставити низ на 384 (−32 px). На скріні `cavebridge_waymark.png` камінь поки що стоїть на уступі, бо камера близько до точки вирівнювання |
| MountainPath | `Back/Waymarker/Sprite` | `MountainPath/gen_waymarker.png` | 416.2 (у шарі) | 384 | −32 (статично) | B215 | вийняти з паралаксу `(0.9, 0.9)`, низ на 384 |
| Village | `ElderHouse` | `Village/gen_elder_house_burnt.png` | 436.5 | 384 | −52.5 | B221 | підняти; поріг дверей на 384 |
| Village | `GrandpaHouse` | `Village/gen_grandpa_house_burnt.png` | 425.5 | 384 | −41.5 | B221 | підняти; поріг дверей на 384 |
| LizardCave | `Back/Shrines/ShrineB0–B2` | `LizardCave/gen_shrine_b.png` | 394.5 | 416 | +21.5 | B225 | y +21.5 |
| LizardCave | `Back/Shrines/ShrineA1–A2` | `LizardCave/gen_shrine_a.png` | 406.5 | 416 | +9.5 | B225 | y +9.5 |
| ElderHouse | `PotBig`, `PotSmall` | `ElderHouse/prop_pot.png` | 822.5 | 864 | +41.5 від підлоги | B223 (п. 3) | стоять на намальованій кам'яній лаві, а не на підлозі; B223 уже каже, що частина «висить над краєм» |

### Перевірено на скріні: не баг

Скрипт позначив ці вузли, але в грі вони читаються нормально:

- **Будівлі City / CraftQuarter / DesertRoad:** `City/DervishTent` −48.5, `City/WitchHut` −30.5, `CraftQuarter/Forge` −52.5, `CraftQuarter/Chapel` −43, `DesertRoad/Shop` −22.5, `Tower` / `Shrine` / `Wreck` від −15.5 до −16.5. Низ арту ховається за дальнім краєм намальованої дороги (`*_Terrain.png`), поріг дверей стоїть на дорозі (`city_tent.png`, `city_witch_hut.png`, `craft_forge.png`, `craft_chapel.png`, `road_shop.png`). Від B221 їх відрізняє те, що в Village під дорогу заходить сам поріг. Отже, низ картинки — лише сито, а вирок дає поріг на скріні.
- **Драбина, кіоск, мотузка:** `City/RooftopsLadder`, `City/AtticStall`, `CityGates/RooftopsRope` мають +21. Низ арту закінчується на дальньому краї дороги, у кадрі це не читається як відрив (`city_rooftops_ladder.png`, `city_attic_stall.png`, `gates_rooftops_rope.png`).
- **Майданчик медитації:** `Canyon/Meditation/Shrine` −31 відносно `PrideRock` (−37 відносно `Meditation/Step`). Кам'яний диск лежить на краю скелі, герой стоїть на ньому (`canyon_shrine.png`). Лівий край диска трохи нависає над урвищем; якщо Sapega це помітить, треба зсунути x вправо.
- **Рамка фрески:** `DragonMural/Back/Frame` +17, це настінна рамка (`dragonmural_frame.png`). Темні колони тут — окремий баг B228.
- **За задумом не мають стояти на підлозі:** опори `platform_support` (Canyon, MesaClimb) за `PlatformSupport.gd` звисають з верху платформи; дошки мостів Canyon / Chasm — це сама платформа; `Laboratory/Atmosphere/Lamp*` — настінні лампи; `gen_slab` у `Surfaces` — це стіни й стеля; драбини й мотузка в `Rooftops` / `TavernAttic` (−96) йдуть крізь отвір у підлозі.
- **Бос MayorHall:** `GiantScorpion` −12 (лінія D172). `ScorpicoreWarrior` статично стоїть на 384. Тож B245 («літає») — це рантайм (BossLogic / фізика), а не розміщення в сцені.

## Смуги дороги й підлоги

### Лінія ходіння на верхньому краю смуги (як B217 / B224)

У **кожній** кімнаті зі смугою `gen_ground.png` / `gen_floor.png` колізія підлоги збігається з верхнім краєм смуги (0 % висоти смуги). Єдиний виняток — `StreamGorge` (34 %).

| смуга (текстура) | кімнати | відомо |
|---|---|---|
| `MountainPath/gen_ground` | MountainPath (+ ScreeSlide, RockLedges, CaveUnderBridge за текстом B217) | B217 |
| `MesaClimb/gen_floor` | MesaTop (5 %), MesaClimb | B217 (MesaTop) / нове (MesaClimb) |
| `GrandfatherAttic/gen_floor` | ElderHouse → `Attic/FloorArt` | B224 |
| `Aqueduct/gen_floor` | Aqueduct, Cistern | нове |
| `Cellar/gen_floor` | CisternStash, CollapsedDrain, MalikStash | нове |
| `ElderHouse/gen_floor` | ElderHouse (`Floor`), PigeonLoft, TavernAttic | нове |
| `Hall/gen_floor` | MayorHall, MayorArchive | нове |
| `LizardCave/gen_floor` | LizardCave, LizardCaves, CaveExit | нове |
| `BanditCamp/gen_floor`, `DragonMural/gen_floor` | BanditCamp, DragonMural | нове |
| `CanyonFloor`, `Chasm`, `DryRiverbed`, `Dunes`, `GateApproach`, `OldRuins`, `ZahraRest` (`gen_ground`) | однойменні кімнати | нове |

Не кожна така смуга — це дорога в перспективі. У `Dunes` смуга читається як край скелі збоку, і хода по її верху виглядає правильно (`dunes_band.png`). Тому це не 20 окремих багів, а **питання до Sapega**: правило B217 «ходити посередині» стосується лише перспективних доріг (MountainPath-група, City-дороги) чи всіх смуг підлоги? Від відповіді залежить, чи переносити зсув ~½ висоти смуги на перелічені кімнати. Пропоную Q-ID у [[questions_for_sapega]].

### Швів-рядків на всю ширину (як B220)

Шукали рядки, де ≥ 90 % пікселів одного кольору (±12) і контраст із сусідами ≥ 25:

| текстура | рядок(и) | колір | висновок |
|---|---|---|---|
| `StreamGorge/gen_ground.png` | 27, 28 | #FDD8A3 / #3B1646 | B220 (відомо) |
| `GrandfatherAttic/gen_floor.png` | 0 | #CA7E73 | B224, п. 1 (відомо) |
| `ElderHouse/gen_floor.png` | 0 | #CA7E73 | **нове**, та сама світла лінія, що B224 п. 1: це той самий настил, і його використовують ElderHouse, PigeonLoft, TavernAttic. Виправлення: зафарбувати рядок 0 кольором рядка 1 |
| `Cellar/gen_floor.png` | 0 | #F6C8A5, контраст 140 | **нове**, найяскравіша верхня лінія з усіх (CisternStash, CollapsedDrain, MalikStash). Виправлення те саме |
| `BanditCamp/gen_floor.png` | 0–1 | #FDC3A2 / #946290 | **нове**, слабше: тонка світла лінія з тінню по верху |
| `DragonMural/gen_floor.png` | 0 | #FACD9C (90 %) | слабке, на скріні не помітно |
| `Hall/gen_floor.png` | 0, 5, 16–24 | червоне / кремове | не шов: це край килима й кам'яний бордюр за задумом |
| `ElderHouse` / `GrandfatherAttic` рядок 21, `OldRuins` 37, `MesaClimb` 6–7, `MountainPath` 2 | — | — | межі намальованих деталей (балка, каміння), не шов |

## Скріни

Усі в `design/shots/critique_2026-10-30/`, 1920×1080, гра у вікні, герой поставлений біля пропса:

- `lab_lamp2.png`, `lab_crystal1.png`: Laboratory, лампа й кристал висять (нове)
- `cavebridge_waymark.png`: CaveUnderBridge, вказівник у y-паралаксі (B215)
- `rockledges_burnt_houses_a.png`, `rockledges_burnt_houses_b.png`: RockLedges; будинки в кадр не потрапили, тож потрібен ручний огляд
- `elder_pots.png`: ElderHouse, глечики на лаві (B223)
- `city_tent.png`, `city_witch_hut.png`, `city_rooftops_ladder.png`, `city_attic_stall.png`: City (не баг)
- `craft_forge.png`, `craft_chapel.png`: CraftQuarter (не баг)
- `gates_rooftops_rope.png`: CityGates (не баг)
- `road_shop.png`: DesertRoad (не баг)
- `canyon_shrine.png`: Canyon, майданчик медитації (не баг, диск трохи нависає)
- `dragonmural_frame.png`: DragonMural (не баг; колони — B228)
- `dunes_band.png`: Dunes, хода по верху смуги читається нормально (до питання про B217)
