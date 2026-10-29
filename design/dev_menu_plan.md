---
type: plan
status: planned
---

# Режим розробника (dev menu) — plan

**Nothing implemented.** 2026-10-29. Sapega в плейтесті: «треба додати меню режиму розробника, де я можу наклацати
собі HP, урон, зробити безсмертним, пригати по локаціях і золото нараховувати». Figma: no design exists (службове
меню, не частина гри для гравця; вигляд — спільна тема `GameUITheme`, без власних кольорів).

## What exists today
| Thing | Where | State |
|---|---|---|
| Гроші | `Scripts/Systems/InventoryManager.gd:64` `add_coins(amount)` | ✅ works |
| HP героя | `Scripts/Player.gd:86,396,524,531` `current_health` / `Max_Health` | ✅ works, сеттера «встановити максимум» немає |
| Безсмертя | `Scripts/Combat/CombatBody2D.gd:7` `is_invulnerable`; перевірка `Player.gd:552` | ✅ прапорець є, ним ніхто не керує, крім ривка |
| Телепорт | `Scripts/Game.gd:423` `teleport_to_room(room_path, arrival)` | ✅ works (затемнення, підлога, B153) |
| Список локацій і кімнат | `Scripts/Systems/LocationDB.gd:15` `all()`, `:21` `location(id)`; `Resources/Data/locations.json` | ✅ works |
| Debug-гаряча клавіша, приклад | `Scripts/Combat/HitAreaDebug.gd:16` (F9, лише `OS.is_debug_build()`) | ✅ патерн, який можна повторити |
| Урон героя | множника «урон ×N» немає; шкода рахується в `PlayerCombat` + `CharacterManager` | ❌ немає точки входу |

## Missing entirely
Перевірено: `grep -ri "cheat|god_mode|dev_menu|debug_menu|DevMenu" SampleProject Scripts` → 0 hits; рядка в BACKLOG
і D-ID немає.
- сцена `UI/Components/dev_menu.tscn` + `dev_menu.gd` (модалка в `ModalLayer`, як інші модалки);
- input action `dev_menu` (клавіша — Q128);
- множник шкоди героя `dev_damage_mult` в одному місці, де рахується шкода героя (не по всіх вміннях окремо);
- `Max_Health` сеттер для «встановити HP».

## Decisions required
1. **Q128 — у яких збірках є меню.** Exe, у який грає Sapega, — release-експорт, а `OS.is_debug_build()` там `false`.
   Варіанти: (a) лише debug-збірка / редактор; (b) усі збірки, відкривається клавішею F10, у публічному релізі
   вимикається одним прапорцем `AppConfig`; (c) окремий export-preset «Dev». Рекомендація: (b). **Блокує slice 1.**
2. Чи зберігаються зміни меню в сейв (HP, золото — так, бо це звичайні дані героя; безсмертя й множник урону —
   ні, скидаються при перезапуску). Default: як сказано, не блокує.

## Slices
### Slice 1 — меню, золото, безсмертя, HP
- `UI/Components/dev_menu.tscn/.gd`; `project.godot` action `dev_menu`; відкриття з `Game.gd` (`_unhandled_input`)
- рядки: «+100 / +1000 золота» (`add_coins`), «Безсмертя вкл/викл» (`is_invulnerable`), «HP: повне / +50 max»
- `SampleProject/UI/verify_dev_menu.gd`: золото росте, безсмертний не отримує шкоди, HP повне
- окремий коміт
### Slice 2 — урон
- `dev_damage_mult` (×1 / ×2 / ×5 / ×10) у точці розрахунку шкоди героя; рядок у меню
- `verify_dev_menu` [урон ×5 = 5 × базова шкода по манекену]
### Slice 3 — стрибки по локаціях
- список: локація → кімната (з `LocationDB.all()`), вибір → `Game.teleport_to_room(path, ^"Arrival")`
- `verify_dev_menu` [телепорт у кожну кімнату Canyon of Whispers ставить героя на підлогу]; скрін через playthrough

## Order and dependencies
`1 → 2 → 3`; 2 і 3 незалежні одне від одного, обидва після 1 (сама сцена меню).

## Out of scope for this pass
Спавн ворогів, видача предметів / вмінь, прапорці сюжету, рівень героя — не просили; додати рядками, коли попросить.
