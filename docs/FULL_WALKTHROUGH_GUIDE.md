# 🎮 Повний гайд проходження гри

## Огляд

Цей документ описує повне проходження гри від початку до кінця з усіма об'єктивами, діалогами та переходами.

## Маршрут проходження

### 🏜️ 1. CANYON (Початок)

**Початковий стейт**: INTRO

#### Об'єктиви:
- "Explore the Canyon" (INTRO)
- "Find a way forward" (EXPLORATION)
- "Pursue the kidnappers" (CUTSCENE_ABDUCTION)

#### Діалоги та переходи:
1. **Canyon_Intro** → Стейт: MONOLOGUE
2. **Canyon_StartMonologue** → Стейт: EXPLORATION
3. **Canyon_Exploration** → Стейт: EXPLORATION (залишається)
4. **Canyon_AbductionCutscene** → Стейт: TO_VILLAGE
5. **RoadToVillage** → Перехід до Village

#### Квести:
- `canyon_intro_complete` - після Canyon_StartMonologue
- `canyon_exploration_complete` - після Canyon_Exploration
- `canyon_abduction_complete` - після Canyon_AbductionCutscene

#### Перехід:
Canyon → Village (через Portal або автоматично)

---

### 🏘️ 2. VILLAGE (Викрадення, бій, лікування)

**Початковий стейт**: ABDUCTION_CUTSCENE

#### Об'єктиви:
- "Дослідити село" (ABDUCTION_CUTSCENE)
- "Дійти до центру села" (ARRIVAL)
- "Перемогти бандита на вулиці" (STREET_FIGHT)
- "Підійти до діда під деревом" (OLD_MAN_OUTSIDE)
- "Допомогти діду" (OLD_MAN_HEALING)
- "Прийняти рішення" (OLD_MAN_DECISION)
- "Покинути село" (LEAVING_VILLAGE)

#### Діалоги та переходи:
1. **VillageAbduction** → Стейт: ARRIVAL
2. **ArrivalToVillage** → Стейт: STREET_FIGHT
3. **FightWithBandit** → Стейт: OLD_MAN_OUTSIDE
4. **OldMan_Outside** → Стейт: OLD_MAN_HEALING
5. **OldMan_Healing** → Стейт: OLD_MAN_DECISION
6. **OldMan_Decision** → Стейт: LEAVING_VILLAGE
7. **LeavingVillage** → Перехід до DesertRoad

#### Квести:
- `village_abduction_complete` - після VillageAbduction
- `village_arrival_complete` - після ArrivalToVillage
- `village_fight_complete` - після FightWithBandit
- `village_oldman_complete` - після OldMan_Outside
- `village_left_complete` - після LeavingVillage

#### Перехід:
Village → DesertRoad (через Portal або автоматично)

---

### 🌵 3. DESERT_ROAD (Циклічні бої)

**Початковий стейт**: TRAVELING

#### Об'єктиви:
- "Продовжуйте шлях до міста" (TRAVELING)
- "Перемогти ворогів на дорозі" (FIGHT_ENCOUNTER)
- "Дійти до воріт міста" (TRANSITION_TO_CITY)

#### Діалоги та переходи:
1. **DesertRoad_Monologue** → Стейт: FIGHT_ENCOUNTER
2. **DesertRoad_Fight** → Стейт: TRANSITION_TO_CITY
3. Автоматичний перехід → CityGates

#### Перехід:
DesertRoad → CityGates (автоматично після TRANSITION_TO_CITY)

---

### 🏰 4. CITY_GATES (Ворота міста)

**Початковий стейт**: INTRO_DIALOGUE

#### Об'єктиви:
- "Підійти до воріт міста" (INTRO_DIALOGUE)
- "Перемогти охоронців воріт" (FIGHT_LOOP)
- "Увійти до міста" (AFTER_FIGHT_DIALOGUE)
- "Знайти лабораторію" (TO_CITY)

#### Діалоги та переходи:
1. **CityGates** → Стейт: FIGHT_LOOP
2. **CityGates_Fight** → Стейт: AFTER_FIGHT_DIALOGUE
3. **CityGates_AfterFight** → Стейт: TO_CITY
4. Автоматичний перехід → Laboratory

#### Перехід:
CityGates → Laboratory (автоматично після TO_CITY)

---

### 🧪 5. LABORATORY (Лабораторія, бос)

**Початковий стейт**: EXPLORE

#### Об'єктиви:
- "Дослідити лабораторію" (EXPLORE)
- "Поговорити з компаньйонами" (COMPANION_01)
- "Продовжити дослідження" (COMPANION_02)
- "Готуватися до битви" (COMPANION_03)
- "Пройдіть тест обмежень" (LIMIT_TEST)
- "Перемогти боса лабораторії" (BOSS_FIGHT)
- "Вийти з лабораторії" (AFTER_BOSS)

#### Діалоги та переходи:
1. **Lab_Companion_01** → Стейт: COMPANION_02
2. **Lab_Companion_02** → Стейт: COMPANION_03
3. **Lab_Companion_03** → Стейт: LIMIT_TEST
4. **Lab_LimitTest** → Стейт: BOSS_FIGHT
5. **Laboratory_BossFight** → Стейт: AFTER_BOSS
6. **Laboratory_AfterBoss** → Перехід до LaboratoryOutside

#### Перехід:
Laboratory → LaboratoryOutside (автоматично після AFTER_BOSS)

---

### 🌳 6. LABORATORY_OUTSIDE (Фінал)

**Початковий стейт**: EXIT_LAB

#### Об'єктиви:
- "Вийти з лабораторії" (EXIT_LAB)
- "Завершити демо" (DEMO_CLOSING)

#### Діалоги та переходи:
1. **Laboratory_Outside** → Стейт: DEMO_CLOSING
2. **Demo_End** → Показ DemoEndScreen

#### Перехід:
LaboratoryOutside → DemoEndScreen → MainMenu

---

### 🎬 7. DEMO_END (Екран завершення)

**Екран**: DemoEndScreen

#### Функціонал:
- Показує текст "Дякуємо за гру!"
- Кнопка "Повернутися до головного меню"
- Блокує ввід гравця
- Анімація появи/зникнення

#### Перехід:
DemoEndScreen → MainMenu (після натискання кнопки)

---

## Ключові моменти

### Переходи між сценами

Всі переходи реалізовані через `Game.load_room()`:
- Canyon → Village: через Portal
- Village → DesertRoad: через Portal
- DesertRoad → CityGates: автоматично
- CityGates → Laboratory: автоматично
- Laboratory → LaboratoryOutside: автоматично
- LaboratoryOutside → DemoEndScreen: автоматично

### Об'єктиви

Об'єктиви встановлюються через `Game.set_objective()` на кожному етапі, щоб гравець завжди знав, що робити далі.

### Квести

Квести завершуються автоматично після завершення відповідних діалогів через `Game.set_quest_flag()`.

### Фінальний екран

Після завершення демо показується екран DemoEndScreen з можливістю повернутися до головного меню.

---

## Час проходження

Орієнтовний час проходження: **15-30 хвилин** (залежить від темпу гравця)

---

## Статус

✅ **Повне проходження від початку до кінця реалізовано!**

Гравець може пройти від Canyon через всі локації до фінального екрану DemoEndScreen з чіткими об'єктивами на кожному етапі.
