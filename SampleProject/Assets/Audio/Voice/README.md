# Voices (D275, D277, D278)

Which event plays which file: `SampleProject/Resources/Data/sound_events.json` (`voices` maps every DialogueQuest
character to its babble voice). Plan and listening checklist: `design/audio_plan.md`.

| Folder | What | Source | Licence |
|---|---|---|---|
| `Babble/` | one 6-syllable blip set per character, played while their text types | synthesised by `Scripts/Tools/audio/make_babble.py` (numpy + stdlib `wave`) | made for this game, no third-party material |
| `Greetings/`, `Calls/`, `Hero/effort_*`, `Boss/shout_*` | short English lines: NPC greetings, companion assist calls, Kusakam's battle cries, boss shouts | **AI-generated** with **Kokoro-82M** (hexgrad, https://huggingface.co/hexgrad/Kokoro-82M — weights and voices **Apache 2.0**), run through `kokoro-onnx` (MIT, https://github.com/thewh1teagle/kokoro-onnx); pitch / reverb by `Scripts/Tools/audio/make_voices.py` | Apache 2.0 model; the output is ours |
| `Greetings/uk/` | the same six NPC greetings in Ukrainian (picked when the game language is Ukrainian, `SoundHooks.greet_event`, BACKLOG 31) | **AI-generated** with the **Piper** voice **"lada" (uk, x-low)** — `voice-uk-lada-x-low.tar.gz` from the rhasspy/piper v0.0.2 release; its `MODEL_CARD`: dataset egorsmkv/ukrainian-tts-datasets `lada`, **licence Apache 2.0**, trained from scratch. Run through `piper-tts` 1.8 (GPL-3.0 — a build tool only, nothing of it ships); pitch / reverb by `Scripts/Tools/audio/make_voices_uk.py` | Apache 2.0 model; the output is ours |
| `Enemy/grunt_*`, `Enemy/death_*` | enemy pain grunts and death cries (pitch per enemy type at runtime) | "grunts of male death and pain" by thebardofblasphemy — https://opengameart.org/content/grunts-male-death-and-pain (cut) | CC0 |
| `Hero/hurt_*`, `Hero/death_0` | Kusakam's pain and death | "5 Hit Sounds + Dying" by tinyworlds — https://opengameart.org/content/5-hit-sounds-dying | CC0 |
| `Boss/roar_*`, `Boss/death_0` | boss roars | "CC0 Deep Monster Roar" by trazzz123 — https://opengameart.org/content/cc0-deep-monster-roar, layered with `roar_01–03` from "80 CC0 creature SFX" by rubberduck — https://opengameart.org/content/80-cc0-creature-sfx (pitched, layered, reverb) | CC0 |

Voices used: grandfather `bm_george`, blacksmith `am_onyx`, merchant `am_puck`, guard `am_eric`, Alisia `af_jessica`,
Astrit `af_kore`, Urizen `bm_lewis`, the oath keepers (D281) Sister Ilvane `bf_emma`, Morrow `bf_isabella` ×0.92, Kesh `bm_daniel` (their babble reuses the Alisia / Astrit / Urizen sets), Kusakam `am_liam`, bosses `am_onyx` ×0.72 + reverb. Never XTTS-v2 / F5-TTS or
other non-commercial weights (D275).

Ukrainian greetings: one speaker (lada, female) for all six; the men (grandfather ×0.78, blacksmith ×0.74, merchant ×0.84,
dervish ×0.8) are pitched down tape-style and spoken faster to compensate; the witch ×0.92; the priestess as is + reverb.
x-low = 16 kHz source — audibly thinner than the Kokoro lines. Other Ukrainian Piper voices (`uk_UA-ukrainian_tts-medium`,
three speakers) live only on huggingface.co, which this build environment cannot reach, so their model cards were not
checked and they were not used. Never non-commercial weights.

**Steam:** the store page's "AI Generated Content" disclosure must say: *pre-generated voice lines (short greetings,
battle cries, companion calls, boss shouts) made with text-to-speech models (Kokoro-82M, Apache 2.0, English; Piper "lada", Apache 2.0, Ukrainian greetings)*. No live
generation in the game.
