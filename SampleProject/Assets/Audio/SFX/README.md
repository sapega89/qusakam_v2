# Sound effects (D217, D275)

All **CC0** (Creative Commons Zero, https://creativecommons.org/publicdomain/zero/1.0/), author **Kenney** (kenney.nl).
Which event plays which file: `SampleProject/Resources/Data/sound_events.json`; plan: `design/audio_plan.md`.

| Files | Pack | URL |
|---|---|---|
| `knifeSlice*`, `drawKnife*`, `cloth*`, `beltHandle*`, `doorOpen_*`, `doorClose_*`, `handleSmallLeather`, `handleCoins` | RPG Audio | https://kenney.nl/assets/rpg-audio |
| `impactPunch_*`, `impactSoft_heavy_*`, `impactMetal_light_*`, `impactBell_heavy_*`, `impactPlate_heavy_*`, `impactSoft_medium_*`, `impactWood_light_*`, `footstep_snow_*` (sand), `footstep_concrete_*` (stone), `footstep_wood_*` | Impact Sounds | https://kenney.nl/assets/impact-sounds |
| `cast_heal_windup` (forceField_001, cut), `cast_fire_windup` (thrusterFire_003, cut), `cast_fire_release` (thrusterFire_001 + lowFrequency_explosion_000), `cast_electric_windup` (laserSmall_000–002), `cast_electric_release` (laserLarge_001) | Sci-Fi Sounds | https://kenney.nl/assets/sci-fi-sounds |
| `cast_heal_release` (confirmation_002), `cast_interrupt` (error_001), `level_up` (confirmation_001) | Interface Sounds | https://kenney.nl/assets/interface-sounds |

Cut / mixed files are rebuilt by `Scripts/Tools/audio/build_audio.py combat world`. Full RPG Audio and Impact Sounds packs
with their `License.txt`: `assets/kenney_rpg-audio/`, `assets/kenney_impact-sounds/` (not in git).
