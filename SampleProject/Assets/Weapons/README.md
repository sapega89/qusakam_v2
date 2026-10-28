# Weapons in hand (D223)

Drawn by `Scripts/Tools/draw_weapons.py` (original work): one PNG per weapon id in `items.json` that has a
`weapon_profile` — `iron_sword`, `copper_sword`, `silver_sword`, `crystal_sword`, `iron_dagger`, `iron_mace`, `iron_halberd`.
`iron_halberd` redrawn in A9 (2026-10-28, D813 «поправити»): the heavy two-handed trade-off weapon (D698) — a wide crescent blade with horns, a leaf spike, a back hook, a dark iron socket with a rivet and a ferrule on the shaft (was a grey axe rectangle on a stick). Point up, grip at the bottom centre, 3 px above the last row (`GRIP`); hero outline and light; ×1.5 in the game.
Shown by `WeaponView.gd` on `Player.tscn → WeaponMount`. A new weapon needs its PNG here, or loading it fails.
