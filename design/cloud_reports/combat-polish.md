---
type: report
status: done
tags: [cloud, combat, hit-feel, stamina]
---

# Cloud report: `cloud/combat-polish` (2026-10-23)

**Summary.** Pillar 1, hard readable combat. Both parts are built and shown in a real fight capture.
- **Stamina is gone (D551).** That covers `PlayerStamina.gd` and its node, every cost (swing, heavy, quick and charged shot, roll, blocked hit), the weak block, the ST row, `STAMINA_FILL`, the `ST` string in both `.po` files and `player_stamina_changed`. Attacks still commit, and the potion slot stays.
- **Hit feel (D581).** Hitstop now rises from light to heavy to riposte to a boss's blow. The screen shakes on the heavy, the riposte and every hit the hero takes, scaled to the blow and off when Screen Shake is off. The hero flashes white for 0.12 s, and the heavy and the riposte each have their own hit sound.
- **Proof:** `design/shots/combat_polish_fight.png`, the training bandit in the Village street: light, heavy, parry and a hit taken, each before and at the hit.
- Not done: no knockback scaling (out of scope), and no death-screen "killed by" line (D581 idea, left open).
- D-ID text for D612–D613 is below. No B rows fixed. Full suite: 101 PASS, 2 FAIL. Both were fixed and re-run as ALL PASS: `verify_audio` now expects the heavy's new sound, and `verify_onboarding` was already red on `feature/backlog`.

## D-ID text (the orchestrator applies it to the register)

| ID | Kind | Text |
|---|---|---|
| D612 | GAP (`cloud/combat-polish`) | **Stamina removed, as built (D551; reverses D537).** `Player/Components/PlayerStamina.gd` and its `PlayerStamina` node in `Player.tscn` are deleted. Swings, the heavy, quick and charged shots, rolls and blocked hits cost nothing. The weak block (`Player.WEAK_BLOCK_DAMAGE`) is gone, so a block always holds a normal hit, and a hit that would guard-break still breaks it. `EventBus.player_stamina_changed`, the hero panel's **ST** row, `UITokens.STAMINA_FILL` and the `ST` / `ВТ` strings are removed. The panel now reads HP, SP, XP. Kept: committed attacks (D536), the potion quick slot (D538), no HP bar over ordinary enemies (D539) and the fast tutorial (D540). `tutorial.json` had no stamina text. Tests: `verify_combat_player` [3]. |
| D613 | ROUTINE CALL (`cloud/combat-polish`) | **Hit feel scaled to the blow, as built (D581).** `VFXHooks.HIT_FEEL` has four tiers by `hit_strength`: 0 light, 1 finisher or knockback weapon, 2 heavy strike, and 3 riposte (new, from `PlayerCombat.riposting`). `HURT_FEEL` has three by `hurt_tier`: 0 normal, 1 guard-breaking or miniboss, and 2 boss (new). Each tier has a `shake` (px, s) played through `shake_camera`: none on a light swing or finisher, rising on the heavy and riposte, and on every hit the hero takes. Hero arrows don't shake the screen. `shake_camera` emits `shake_started` and then honours Settings → Screen Shake (D426). The old directional camera kick stays. **Hurt flash:** a `flash` uniform in `weapon_palette.gdshader` (the hero's frame shader) turns his frames white and fades over `HURT_FLASH_TIME` 0.12 real seconds (`VFXHooks.flash_hero`). **Sounds:** `SoundHooks.HIT_SOUNDS` is `hit` (light), `hit_heavy` (finisher), `hit_strike` (heavy: impactPunch_heavy, pitch 0.8, +2 dB) and `hit_riposte` (pitch 0.65, +4 dB). Block (`block`, metal) and parry (`parry`, bell, plus `hit_heavy`) are unchanged. Every number is provisional (table in `cloud_reports/combat-polish.md`). Tests: `verify_hit_feel` [1]–[5]. |

## 1. Stamina removal (D551)

| Where | What |
|---|---|
| `SampleProject/Scripts/Player/Components/PlayerStamina.gd` (+ `.uid`) | deleted |
| `SampleProject/Player.tscn` | the `PlayerStamina` node and its ext_resource removed |
| `SampleProject/Scripts/Player.gd` | `stamina` field, roll check and cost, respawn refill, block cost and weak block (`WEAK_BLOCK_DAMAGE`) removed |
| `SampleProject/Scripts/Player/Components/PlayerCombat.gd` | four `stamina.spend` calls removed: light, heavy, quick shot, charged shot |
| `SampleProject/Scripts/Core/EventBus.gd` | `player_stamina_changed` removed |
| `SampleProject/UI/Components/player_vitals_panel.gd` | ST row, its signal and its refresh removed |
| `SampleProject/UI/Tokens/UITokens.gd` | `STAMINA_FILL` removed (nothing else used it) |
| `en.po` / `uk.po` | `msgid "ST"` removed (`tutorial.json` had no stamina text) |
| `SampleProject/UI/capture_combat_player.gd` | the `stamina.spend` line removed |
| `SampleProject/UI/verify_combat_player.gd` | [3] rewritten. It checks there is no node, field, script or signal, that the panel rows are `[HP, SP, XP]`, that ten rolls in a row all start, and that eight blocked hits in a row cost no HP and cause no stagger. |

`verify_combat_player`: `RESULT: ALL PASS`.

**Design note, not a blocker.** Without stamina, defending costs nothing again: a block holds any number of normal hits. That is the "defending costs nothing" problem in `combat_critique_2026-10-23.md` #2, which recommended a guard bar instead. D551 settles the stamina question only. A guard bar would be a new product call for Sapega.

## 2. Hit-feel pass (D581)

**What existed before.** `TimeManager.hitstop` and tiered `HIT_FEEL` / `HURT_FEEL` (light, finisher, heavy; normal and big hurt). A directional camera kick (`_kick_camera`) on every hit, which respects Screen Shake. `shake_camera` used only by ultimates. A red vignette and a HP-row shake on hurt. Gamepad rumble.

**The gaps:**
- The riposte counted as a plain heavy.
- A boss's blow had the same tier as a tank's.
- There was no real screen shake on heavy blows or on hits taken.
- The hero had no flash.
- The finisher and the heavy shared one hit sound.

**Numbers (provisional):**

| Blow | Hitstop (s) | Shake (px / s) | Camera kick (px) | Hit sound |
|---|---|---|---|---|
| Hero light swing | 0.055 | none | 1.5 | `hit` |
| Hero finisher / knockback weapon | 0.08 | none | 3 | `hit_heavy` |
| Hero heavy strike | 0.11 | 3 / 0.15 | 5 | `hit_strike` |
| Hero riposte | 0.15 | 5 / 0.20 | 6 | `hit_riposte` |
| Parry | 0.07 | none | 5 | `parry` + `hit_heavy` |
| Block | none | none | none | `block` |
| Hit taken, normal | 0.09 | 3 / 0.15 | 4 | `hero_hurt` + `hit` |
| Hit taken, guard-breaking / miniboss | 0.14 | 5 / 0.25 | 7 | `hero_hurt` + `hit_heavy` |
| Hit taken, boss | 0.18 | 7 / 0.30 | 8 | `hero_hurt` + `hit_heavy` |
| Hero hurt flash | white, fading over 0.12 s (real time) on every hit taken | | | |

Measured hitstop in a real fight (`verify_hit_feel` [2]): light 58 ms, heavy 111 ms, riposte 162 ms.

**Files:**
- `SampleProject/Scripts/Systems/VFXHooks.gd`: the tiers, `hurt_tier`, `flash_hero`, `shake_started`, and shakes in `_on_damage_received` / `_on_damage_dealt`.
- `SampleProject/Shaders/weapon_palette.gdshader`: the `flash` uniform.
- `SampleProject/Scripts/Systems/SoundHooks.gd`: `HIT_SOUNDS`.
- `SampleProject/Resources/Data/sound_events.json`: `hit_strike` and `hit_riposte`, reusing the impactPunch_heavy assets.

**Test:** the new `SampleProject/UI/verify_hit_feel.gd` runs the hero against a bandit on DesertRoad. `RESULT: ALL PASS`.
- [1] The scale order of hitstop and shake.
- [2] Real light, heavy and riposte hits: hit strength 0 / 2 / 3, no shake on the light, one shake each on the heavy and riposte, and measured hitstop rising.
- [3] A hit taken: the flash is at 1.00 and fades to 0. Normal and guard-breaking hits shake at their tiers.
- [4] Screen Shake Off: the shake is requested but the camera never moves.
- [5] The six hit sounds exist and no two match.

`verify_souls_combat` and `verify_bow` (the older hitstop checks) also give `RESULT: ALL PASS`.

## 3. Proof in a real fight

![[shots/combat_polish_fight.png]]

`SampleProject/UI/capture_hit_feel.gd` runs in the Village street with the training bandit. Tab skips the lesson banner so it does not cover the hero, and the bandit keeps fighting. The rows are light, heavy, parry and hit taken. The left column is before the hit (the swing, or the glint for parry and hurt); the right column is the hit frame.
- Light: 30 damage and a small cut.
- Heavy: 45 damage, the long cut and the bandit knocked back.
- Parry: sparks, and the bandit staggered.
- Hit taken: the hero white, with the red cut.

Under xvfb the game draws at about 6 fps, which is slower than the 0.12 s flash. So the capture pauses running tweens for the one hit frame (`_grab_hit`) to show their first frame. The game itself is not changed.

## Full suite

`Scripts/Tools/run_verify.sh`: **101 PASS, 2 FAIL** (`SUITE: 2 FAIL`). After the fixes below, both give `RESULT: ALL PASS`.
- `verify_audio`: "heavy hit lands → hit_heavy on SFX ([])". The heavy strike now plays its own `hit_strike` (D613), so the check expects `hit_strike`.
- `verify_onboarding`: "keyboard: a light hit does not pass Heavy". This was **already red on `origin/feature/backlog`**, checked in a separate worktree. Right after the Parry lesson, the riposte window (D575, 1.0 s) is still open. The test's "wrong" light tap therefore became a riposte, which uses the heavy strike and so passes the Heavy lesson. The test now waits `RIPOSTE_WINDOW` before that tap. The game is unchanged. A riposte straight after the Parry lesson still counts as the Heavy lesson. That reads as fine, but Sapega may want it otherwise.
