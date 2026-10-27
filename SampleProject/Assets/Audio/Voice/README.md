# Voices (D275, D277, D278)

Which event plays which file: `SampleProject/Resources/Data/sound_events.json` (`voices` maps every DialogueQuest
character to its babble voice). Plan and listening checklist: `design/audio_plan.md`.

| Folder | What | Source | Licence |
|---|---|---|---|
| `Babble/` | one 6-syllable blip set per character, played while their text types | synthesised by `Scripts/Tools/audio/make_babble.py` (numpy + stdlib `wave`) | made for this game, no third-party material |
| `Greetings/`, `Calls/`, `Hero/effort_*`, `Boss/shout_*` | short English lines: NPC greetings, companion assist calls, Kusakam's battle cries, boss shouts | **AI-generated** with **Kokoro-82M** (hexgrad, https://huggingface.co/hexgrad/Kokoro-82M — weights and voices **Apache 2.0**), run through `kokoro-onnx` (MIT, https://github.com/thewh1teagle/kokoro-onnx); pitch / reverb by `Scripts/Tools/audio/make_voices.py` | Apache 2.0 model; the output is ours |
| `Boss/brass_collector_roar_*`, `Boss/fire_djinn_roar_*`, `Boss/fire_djinn_laugh_*`, `Lab/prisoner_incantation_0` | the Laboratory bosses' roars (the Brass Collector ring-modulated like a golem) and the djinn's laugh; the prisoner's invented incantation (Q64) — queue row 9.8, D310 | **AI-generated** with **Kokoro-82M** (Apache 2.0) through `kokoro-onnx` (MIT): `make_voices.py ... Boss/brass_collector_roar Boss/fire_djinn_roar Boss/fire_djinn_laugh Lab/prisoner_incantation` | Apache 2.0 model; the output is ours |
| `Greetings/uk/` | the same six NPC greetings in Ukrainian (picked when the game language is Ukrainian, `SoundHooks.greet_event`, BACKLOG 31) | **AI-generated** with the **Piper** voice **`uk_UA-ukrainian_tts-medium`** (rhasspy/piper-voices on huggingface, 22 kHz, speakers lada, mykyta, tetiana); its `MODEL_CARD`: dataset OHF-Voice/voice-datasets, **licence CC0**, trained from scratch; the model repo is **MIT**. Run through `piper-tts` 1.x (GPL-3.0 — a build tool only, nothing of it ships); pitch / reverb by `Scripts/Tools/audio/make_voices_uk.py` (2026-10-27, S11) | MIT model, CC0 data; the output is ours |
| `Enemy/grunt_*`, `Enemy/death_*` | enemy pain grunts and death cries (pitch per enemy type at runtime) | "grunts of male death and pain" by thebardofblasphemy — https://opengameart.org/content/grunts-male-death-and-pain (cut) | CC0 |
| `Hero/hurt_*`, `Hero/death_0` | Kusakam's pain and death | "5 Hit Sounds + Dying" by tinyworlds — https://opengameart.org/content/5-hit-sounds-dying | CC0 |
| `Boss/roar_*`, `Boss/death_0` | boss roars | "CC0 Deep Monster Roar" by trazzz123 — https://opengameart.org/content/cc0-deep-monster-roar, layered with `roar_01–03` from "80 CC0 creature SFX" by rubberduck — https://opengameart.org/content/80-cc0-creature-sfx (pitched, layered, reverb) | CC0 |

Voices used: grandfather `bm_george`, blacksmith `am_onyx`, merchant `am_puck`, guard `am_eric`, Alisia `af_jessica`,
Astrit `af_kore`, Urizen `bm_lewis`, the oath keepers (D281) Sister Ilvane `bf_emma`, Morrow `bf_isabella` ×0.92, Kesh `bm_daniel` (their babble reuses the Alisia / Astrit / Urizen sets), Kusakam `am_liam`, bosses `am_onyx` ×0.72 + reverb; the Brass Collector `am_onyx` ×0.62 + ring/comb, the fire djinn `am_fenrir` ×0.7 / ×0.8 + reverb, the prisoner `am_adam` ×0.9. Never XTTS-v2 / F5-TTS or
other non-commercial weights (D275).

Ukrainian greetings: men speak with mykyta (grandfather ×0.9 and slower, blacksmith ×0.86, merchant as is, dervish ×0.93),
the priestess with tetiana (+ reverb), the witch with lada (×0.95). Until 2026-10-27 all six were one female x-low voice
(lada, 16 kHz) pitched down for the men. Never non-commercial weights.

**Steam:** the store page's "AI Generated Content" disclosure must say: *pre-generated voice lines (short greetings,
battle cries, companion calls, boss shouts, boss roars and laughs, one cutscene incantation) made with text-to-speech models (Kokoro-82M, Apache 2.0, English; Piper `uk_UA-ukrainian_tts-medium`, MIT / CC0 data, Ukrainian greetings)*. No live
generation in the game.
