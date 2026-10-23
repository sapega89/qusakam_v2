---
type: report
status: done
tags: [cloud, companions, assists, vfx, tutorial, d463, d464, d465]
---

# Cloud report: `cloud/companions` (2026-10-23)

**Summary.** All four parts are done:
- **D464 (1):** Laboratory companions are now only *available*. Nobody joins until the player picks them in Status, and the assist button calls only the picked ones.
- **D463:** the new tutorial topic `choose_companions` opens a window the first time more than one companion can be chosen. Its frames show the picker and then an assist, and its **Open Companions** button opens Status → Companions. It fires once; with Tutorial windows Off it shows as a banner.
- **D464 (2):** each assist now does something different: Alisia shoots the farthest enemy in front, Astrit's shield stuns, Urizen's coin chains to 3 enemies, and the guard is unchanged.
- **D465:** a first VFX pass built from particles, additive glow and hitstop, with no ComfyUI sheets.

**Q82 note:** Sapega answered Q82 (`ca8c2d1b`) after this prompt was stored: Astrit keeps the spiked shield, with no flail and no burn. I built the answer, not the old default, so her assist stuns and does not burn.

D-ID text: **D491–D493** (§5). The register on `feature/backlog` already runs to D490, so I did not use D484. No B rows were fixed.

Full suite: see §6.

Branch `cloud/companions` from `origin/feature/backlog` @ `ca8c2d1b`. Shots: `design/shots/companions_before_after.png`.

## 1. D464 (1): picked, not auto-joined

- `CompanionManager.gd:104` `announce_unlock(flag)` replaces `join_on_unlock`. It no longer touches the party; it only emits `companion_joined` for the notice. `call_next` / `peek_next` already walk only `get_party()`.
- `LabCells.gd` (`_acquaintance`) sets the three flags and announces them; the NPCs still run to Kusakam and vanish (D230).
- The notice now reads **"%s can join your party"** (uk «%s може приєднатися до загону»), in `CompanionJoinedNotification.gd` and the `.tscn` placeholder, with both `.po` files.
- The older `companions` hint (shown after the City Gates guard) said "Allies you meet will join your party". It now says "…can join your party: choose who goes with you in Status. {assist} calls the next ready companion." Both `.po` files are updated.
- Tests that relied on the auto-join now pick the companions explicitly (`toggle_party`): `verify_laboratory`, `verify_lab_boss`, `verify_lab_route` and `capture_tutorial_frames`. `verify_lab_cells` [4] now checks:
  - after the acquaintance the party is empty and all three companions are available;
  - the picker tutorial has fired;
  - F calls nobody before a pick, and does call a companion after one.

## 2. D463: the picker tutorial

- **Topic:** `tutorial.json` → `choose_companions`, titled "Choosing Companions", with key `{assist}`, frames `companion_picker`, `open: "companions"` and `open_label: "Open Companions"`. Every text has en and uk keys.
- **Trigger:** `LabCells.gd:202`, after the acquaintance cutscene ends, if `get_unlocked().size() > 1`. `TutorialHintDisplay.show_hint` queues the window until the game is free. It fires once (`seen_tutorials`), and with Tutorial windows Off it becomes the banner (existing D289 path).
- **Button:**
  - `tutorial_menu.tscn` has a new `OpenRow/OpenButton`. It is a kit HexButton (`ModalButton` / `ModalButtonOn` on focus, 260 × 36 from `UITokens`) and is shown only for topics with `open`.
  - Enter or pad A triggers it too, and the bottom bar lists it.
  - `tutorial_menu.gd:99` `_open_section()` closes the window, then `UIManager.open_companion_picker()` opens the Game Menu (or reuses it when the window came from Misc → Tutorial), switches to Status and calls `stats_component.focus_companions()`. That puts focus on the first card and scrolls the section into view.
- **Frames:** `SampleProject/Assets/UI/Tutorial/companion_picker/0–46.png` are 33 frames of the real Status picker (Astrit, Urizen and Alisia taken in turn, cards going "IN PARTY · n") plus 14 frames of an assist call. The script is `capture_companion_picker_frames.gd`.
  - It also re-records the `assist` set (14 frames, used by `call_guard` and `companions`), which used to show the cat clawing and now shows Alisia's shot.

## 3. D464 (2): distinct assists

`CompanionAssist.gd` modes are renamed and keep their indices, so the scenes' `mode` values still match: FRONT, **POUNCE**, **CHAIN**, **RANGED**. All numbers are provisional.

| Assist | What it does now | Numbers | Where |
|---|---|---|---|
| Astrit | pounce on the nearest enemy and hit with the spiked shield: knockback **and stun** (D207 `stun`) | 40 dmg, 60 px knockback, **1.5 s** stun, reach 320 | `companion_astrit.tscn` |
| Alisia | a **ranged** arrow from behind the hero at the **farthest enemy in front**; the cat runs out, swipes beside her and leaves with her (flavour, no damage) | **24** dmg (was 3 × 8 from the cat), reach **640** | `_shoot` l. 211, `_send_pet` l. 230 |
| Urizen | the coin drops on the nearest enemy in front, then hops in an arc to the next with `SkillTargeting.chain_target` (D207 chain), up to **3** | 30 dmg + 1 s stun per hit, hop radius **200 px** | `_smite_chain` l. 175 |
| Guard | unchanged knockback thrust on everything in front | 999, 80 px, 900 px | — |

A target that is freed mid-flight (arrow) or mid-hop (coin) is skipped with `is_instance_valid`, because the hero can kill it in that 0.2 s.

## 4. D465: first VFX pass

New scenes are in `SampleProject/Scenes/FX/Companions/`. They share `glow.tres` (radial GradientTexture2D), `ring.tres` and `additive.tres` (CanvasItemMaterial, ADD). The one-shot effects run `Scripts/FX/AssistFX.gd`: particles restart, "Flash…" sprites grow and fade, the effect drifts if set, and it frees itself.

- **Astrit:** `shield_slam.tscn` (impact glow, a flat dust ring sprite, left/right dust bursts, debris) and `stun_stars.tscn` (`Scripts/FX/StunStars.gd`). The stars are three additive stars circling a flat ellipse over the head for the stun's duration, and a new stun extends them. `Assets/FX/Companions/star.png` is a 9 × 9 star drawn by script, not ComfyUI.
- **Alisia:** `arrow_streak.tscn` (`Assets/FX/Projectiles/arrow.png` with a world-space particle streak and a glow) and `hit_spark.tscn`.
- **Urizen:** `assist_coin.tscn` gains a `Glint` world-space sparkle trail and a gold glow. `gold_burst.tscn` (glow, ring and sparks) fires on every hit.
- **Guard:** `wind_arc.tscn` (the `Smear/arc_2.png` crescent, pale, additive, rushing 380 px forward, plus gust particles) and `knockback_puff.tscn` on each enemy hit.
- **Hitstop:** this pass uses the existing hit feel for companion hits (`VFXHooks._on_damage_dealt`: 0.055 s, or 0.08 s with knockback), so nothing new was added.
- **Shots:** `design/shots/companions_before_after.png` has one row per assist, with before | after and two moments each (+0.08 s and +0.4 s after the first hit). The raw frames are in `design/shots/companions/`. The capture is `capture_companion_assists.gd -- <tag>`, and `Scripts/Tools/companion_shots.py` (needs Pillow) builds the image.
- **What reads in the shots:** the stun stars, the chained golden bursts and the guard's wind arc read well. Astrit's dust ring and Alisia's arrow streak are faint at this scale. They are the first things to strengthen in a second pass, or when ComfyUI sheets come.

## 5. D-ID text (proposed)

| ID | Kind | Text |
|---|---|---|
| D491 | ROUTINE CALL | **Companions as built for D463 / D464** (`cloud/companions`).<br>**Party:** the Laboratory makes Alisia, Astrit and Urizen available (`CompanionManager.announce_unlock`, notice "X can join your party"). None joins until picked in Status → Companions, and the assist button calls only the picked ones.<br>**Picker tutorial:** `choose_companions` opens after the acquaintance cutscene, the first time more than one can be chosen. Its frames show the real picker and an assist call; its **Open Companions** button (kit HexButton, also Enter / A) opens the Game Menu on Status with focus on the first companion card. With Tutorial windows Off it is the banner.<br>**Assist numbers (provisional):** Astrit 40 + 60 px knockback + 1.5 s stun on the nearest. Alisia 24 to the farthest enemy in front within 640 px; the cat is flavour only. Urizen 30 + 1 s stun, chaining to up to 3 enemies with hops of up to 200 px. The guard is unchanged. |
| D492 | ROUTINE CALL | **Astrit's assist follows Q82's answer, not its default** (`cloud/companions`). The routine prompt predates the answer in D472, so she stuns with the spiked shield and nothing burns (no flail, no D207 `burn`). |
| D493 | ROUTINE CALL | **First VFX pass for the assists (D465), with no ComfyUI sheets** (`cloud/companions`). The effects are particles, additive glow (`Scenes/FX/Companions`, `AssistFX.gd`) and the existing companion hitstop (`VFXHooks`, 0.055 / 0.08 s).<br>Astrit: impact glow, dust ring and debris, and stun stars that last as long as the stun.<br>Alisia: an arrow with a light streak and a green-white hit spark.<br>Urizen: a glinting coin that arcs between targets, with a golden burst on each hit.<br>Guard: a pale wind crescent rushing forward and a dust puff on each enemy.<br>The tutorial `assist` frames were re-recorded to show the ranged shot. |

## 6. Tests

- `verify_companions` covers:
  - [2] unlock ≠ join;
  - [3] picking, and only picked companions are called;
  - [4] Alisia hits the farthest enemy only, with the arrow streak and hit spark;
  - [5] Astrit's stun, stars and shield slam;
  - [6] Urizen hits exactly the three nearest of four, all stunned, with three gold bursts;
  - [8] the guard's wind arc and one puff per enemy, every effect freed, time scale back to 1;
  - [10] the D463 window: opens and pauses, right topic, frames play, assist key shown, the button opens Status with focus on a card, fires once, and becomes the banner when windows are Off.
  - It prints `RESULT: ALL PASS`.
- Related tests:
  - `verify_lab_cells`: ALL PASS. It needed one fix: the F-press check now sends Astrit back to camp, so the skipped-acquaintance comparison is unaffected.
  - `verify_laboratory`, `verify_lab_boss`, `verify_lab_route`, `verify_party_panel`, `verify_tutorial_hints`, `verify_locale`: ALL PASS.
- Full suite: SUITE_LINE
