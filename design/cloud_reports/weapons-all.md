---
type: cloud-report
branch: cloud/weapons-all
date: 2026-10-22
tags: [cloud, combat, animation, art]
---

# Cloud report: weapons-all (BACKLOG 42: every weapon type + palette swap)

Start: `origin/cloud/integration`, then `origin/feature/backlog` merged in (the owner's A3 art for dagger, mace,
halberd, dual and A4 bow). Godot 4.6.2 on Linux, headless for the verifies; one capture under Xvfb (OpenGL) to check
that the shader compiles and recolours only the metal. Bow code was not touched (`cloud/bow`). The plan note
[[hero_weapon_animation_plan]] is updated (slices 2–6 done).

## What was built

### 1. Every weapon type in Kusakam's own frames

- **Libraries** `SampleProject/Resources/Player/WeaponAnimations/{dagger,mace,polearm,dual_sword_dagger}.tres`, written
  by the new `Scripts/Tools/weapon_libraries.py` (same names and timings as the sword library, D345: `Attack1–N` 0.3 s
  with the strike frame at 0.05 s, `HeavyWindup` 0.4 s, `HeavyStrike` 0.25 s, offset (0, −16) for the 96×96 cell).
  Mounted in `SampleProject/Player.tscn:76-79` (ext_resources) and `:1244-1247` (`libraries/…`).
- `SampleProject/Scripts/Player.gd:237` `body_animation()`: every swing body (`Attack`, and the mace / halberd
  `AttackSmash` / `AttackThrust` from `PlayerCombat.SWING_ANIMATIONS`) resolves to `<library>/Attack<step+1>` (`:242`).
- `SampleProject/Scripts/Player/Components/WeaponView.gd:136` `body_library()`: no longer one-handed only — the
  two-handed halberd (`polearm`) and dual-wield (`dual_<in hand>_<off hand>`) find their libraries too.
- **Missing frame kinds** (closest animation of the same set, `weapon_libraries.py`):
  - dagger `Heavy` → its `Attack3` (wind-up `Attack3/1`, strike `Attack3/2 → 3`);
  - dagger `Attack2` (only `Attack2/1` exists) → `Attack2/1` crouch + `Attack1/2–3` stab;
  - dual `Hurt` → `sword/Hurt/1`, as the dual README says (the dual set has no recoil pose; the dagger hand is
    hidden behind his body). Not strictly "the same set" — the dual set is built on the sword set's frames.
- Hitbox timings are unchanged: every swing keeps the base swing's length and strike time; `verify_souls_combat`
  [12a] (reach = drawn overlay reach) still passes. Measured reach of the frames themselves is in B112.

### 2. Weapon variants by palette swap

- **Key** = the sword set's blade metal `#F8F8E4` / `#C2C2C2` / `#87878C` (light / mid / dark; the A3 READMEs and the
  `hero_weapon_*` entries draw every set in it).
- **Problem found:** the hero's armour plate, bracers and eye highlight use the same three colours (e.g. ~45 px of
  `#87878C` per artist frame). A plain key swap would turn his armour copper. **Fix:** new
  `Scripts/Tools/weapon_key_fixups.py` moves those body pixels 2 RGB steps off the key (invisible) in the five weapon
  sets (sword, dagger, mace, halberd, dual; 6874 px). It tells weapon from body by connected key-colour blobs:
  outline/background neighbours vs body neighbours, outside the torso box under the head, or long and thin. Run it
  after `comfy_sprite.py` and the `*_fixups.py`; a second run changes nothing. The few misses are B111.
- `SampleProject/Shaders/weapon_palette.gdshader` (new) on `Player.tscn → Sprite2D` (`:82`, `:1217`): maps the key
  to the item's palette; `shimmer` (a light band running along the metal) and `glow` (pulsing metal + a 1 px halo
  around it) for crystal. `active` only while a weapon-library frame is on screen, so the base frames (whose armour
  keeps the key) are never touched.
- `SampleProject/Resources/Data/weapon_palettes.json` (new): `iron` (= the key), `copper`, `silver` (the tones of
  `draw_weapons.py` METAL), `crystal`. items.json: `"palette"` on every weapon (`items.json:176…301`).
- `WeaponView.gd:170` `_set_palette()` on every equip / weapon switch (`:159`); `:119` turns the shader on and off.
- **Crystal Sword** `crystal_sword` (`items.json:235`) + its overlay `Assets/Weapons/crystal_sword.png` (casts still use
  the overlay, D271) drawn by `Scripts/Tools/draw_weapons.py` with a new `crystal` METAL (the other six PNGs redraw
  pixel-identical). Copper and silver swords already existed. Not placed in a shop, chest or loot (none fits yet).
- Capture: `SampleProject/UI/capture_weapon_palettes.gd` → `design/shots/weapon_palettes.png` (rows iron / copper /
  silver / crystal; columns sword idle + slash, dagger lunge, mace, halberd, dual): the armour stays steel in every row.

### Bug fixed on the way

- `WeaponView.gd:145` `_drawn_in_frame()` read `current_animation`, which is empty once a short non-looping pose ends
  (Block 0.1 s, Hurt). Holding block, the overlay sword came back on top of the sword drawn in the frame (B110).
  It reads `assigned_animation` now.

## Decisions (agent calls, Sapega to confirm)

**D380–D385 and B110–B112 were picked clear of the other overnight branches (`cloud/bow`). Integrator: renumber if taken.**

| D-ID | Decision |
|---|---|
| D380 | **Every weapon type wired like the sword** (BACKLOG 42; agent call, Sapega to confirm). One `AnimationLibrary` per items.json `category` — `dagger`, `mace`, `polearm` (the halberd) — in `Resources/Player/WeaponAnimations/*.tres` written by `Scripts/Tools/weapon_libraries.py`, with the sword's names and timings (D345). Any grip uses its library, two-handed included; the mace and halberd swing bodies (`AttackSmash` / `AttackThrust`) resolve to `<library>/Attack<step>`. Dual-wield is a library per pair, `dual_<in hand>_<off hand>`: only `dual_sword_dagger` exists (sword in hand, dagger off hand, 4-swing `Attack1–4`, D267); any other pair keeps the overlay. |
| D381 | **Missing frame kinds** (agent call, Sapega to confirm). Dagger heavy = the dagger's `Attack3` (wind-up `Attack3/1`, strike `Attack3/2–3`); dagger `Attack2` = `Attack2/1` + `Attack1/2–3`; dual `Hurt` = `sword/Hurt/1` (dual README). |
| D382 | **Palette swap** (BACKLOG 42 'Weapon variants'; agent call, Sapega to confirm). The key is the sword set's blade metal `#F8F8E4` / `#C2C2C2` / `#87878C`. `Shaders/weapon_palette.gdshader` on the hero sprite recolours exactly those, only while a weapon-library frame is on screen. Body pixels that shared the key are moved 2 RGB steps off it in the weapon frames (`Scripts/Tools/weapon_key_fixups.py`, part of the art pipeline). Palettes live in `Resources/Data/weapon_palettes.json`; items.json names one per weapon (`"palette"`). Dual-wield shows the palette of the weapon in hand on both blades. |
| D383 | **Palettes** (agent call, Sapega to confirm): iron = the key; copper `#FABE82 / #D6844E / #A05836`; silver `#FFFFFF / #D6E2F0 / #9EB0C8` (both = `draw_weapons.py` METAL); crystal `#E8FCFF / #96E2F0 / #5496D2` with shimmer 1.0, glow 0.6, glow colour `#9AF2FF`. |
| D384 | **Crystal Sword** (agent call, Sapega to confirm): `crystal_sword`, sword, palette crystal, rare, Attack +32, Magic +10, buy 1000 / sell 500, the swords' weapon profile (reach 78, cooldown 0.5). Not placed in any shop, chest or loot yet. |
| D385 | **Hitbox stays as it is** (agent call, Sapega to confirm): the frames keep the base swing timing, and the hitbox keeps items.json `reach` (= the SlashTrail arc, D268, [12a]), not the shorter reach the frames draw (B112). |

## Bugs (for BUGS.md)

| B-ID | Bug | State |
|---|---|---|
| B110 | Holding block (or after a hurt) with a weapon that has frames: once the 0.1 s pose ended, the overlay weapon appeared on top of the weapon drawn in the frame, and the palette turned off. `_drawn_in_frame` read `current_animation`, which is empty after a non-looping animation ends. | Fixed, `WeaponView.gd:145` (`assigned_animation`); `verify_weapon_animations` block checks |
| B111 | Palette swap misses (the art is not clean): the halberd's butt spike stays iron in `Air/1`, `Block/1`, `CombatIdle` (below the torso box); the dual dagger stays iron in `Heavy/1` and `Run/7` (pressed to the chest) and is drawn in `#FCF3D5` (not a key colour) in `Air/3`, `Run/2`, `Run/4`, so it stays pale in every palette; a few small arm pixels in `sword/Attack2/2` and `Attack3/2` tint with the palette. | Open — repaint those pixels on the laptop (key on the weapon, off-key on the body), or per-frame masks |
| B112 | The frames draw a shorter weapon than the hitbox reaches: halberd 72 px (the pole hits the 96 px cell edge) vs 134; sword 62 vs 78; dagger 58 vs 77; mace 64 vs 66 (max x of the attack frames ×1.5). The SlashTrail arc still shows the hitbox length. | Open — Sapega: a wider cell for the halberd, or shorter reach |

## Verifies

Full suite still running at this commit; results follow in the next commit.

## Left

- B111 art touch-ups, B112 decision.
- No shop / loot placement for the crystal sword.
- Bare-hands combat stance (optional slice 7).
- Other dual pairs (sword + sword, dagger in hand + sword…) keep the overlay; frames per pair if Sapega wants them.
- Sapega to look at the capture and in the game: the crystal shimmer/glow strength, copper's tone.
