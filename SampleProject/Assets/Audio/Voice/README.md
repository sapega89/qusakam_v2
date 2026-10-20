# Voices (D275, D277, D278)

Which event plays which file: `SampleProject/Resources/Data/sound_events.json` (`voices` maps every DialogueQuest
character to its babble voice). Plan and listening checklist: `design/audio_plan.md`.

| Folder | What | Source | Licence |
|---|---|---|---|
| `Babble/` | one 6-syllable blip set per character, played while their text types | synthesised by `Scripts/Tools/audio/make_babble.py` (numpy + stdlib `wave`) | made for this game, no third-party material |
| `Greetings/`, `Calls/`, `Hero/effort_*`, `Boss/shout_*` | short English lines: NPC greetings, companion assist calls, Kusakam's battle cries, boss shouts | **AI-generated** with **Kokoro-82M** (hexgrad, https://huggingface.co/hexgrad/Kokoro-82M — weights and voices **Apache 2.0**), run through `kokoro-onnx` (MIT, https://github.com/thewh1teagle/kokoro-onnx); pitch / reverb by `Scripts/Tools/audio/make_voices.py` | Apache 2.0 model; the output is ours |
| `Enemy/grunt_*`, `Enemy/death_*` | enemy pain grunts and death cries (pitch per enemy type at runtime) | "grunts of male death and pain" by thebardofblasphemy — https://opengameart.org/content/grunts-male-death-and-pain (cut) | CC0 |
| `Hero/hurt_*`, `Hero/death_0` | Kusakam's pain and death | "5 Hit Sounds + Dying" by tinyworlds — https://opengameart.org/content/5-hit-sounds-dying | CC0 |
| `Boss/roar_*`, `Boss/death_0` | boss roars | "CC0 Deep Monster Roar" by trazzz123 — https://opengameart.org/content/cc0-deep-monster-roar, layered with `roar_01–03` from "80 CC0 creature SFX" by rubberduck — https://opengameart.org/content/80-cc0-creature-sfx (pitched, layered, reverb) | CC0 |

Voices used: grandfather `bm_george`, blacksmith `am_onyx`, merchant `am_puck`, guard `am_eric`, Алісия `af_jessica`,
Астрит `af_kore`, Уризен `bm_lewis`, Kusakam `am_liam`, bosses `am_onyx` ×0.72 + reverb. Never XTTS-v2 / F5-TTS or
other non-commercial weights (D275).

**Steam:** the store page's "AI Generated Content" disclosure must say: *pre-generated voice lines (short greetings,
battle cries, companion calls, boss shouts) made with a text-to-speech model (Kokoro-82M, Apache 2.0)*. No live
generation in the game.
