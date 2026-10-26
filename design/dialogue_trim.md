---
type: plan
status: planned
tags: [dialogue, text, routine-dialogue-triggers]
---

# Dialogue trim — drafts for Sapega

Sapega (2026-10-26): «діалоги блокують тригери. Це не дуже, тому або менше тексту, або якось не давати пройти далі,
поки іде діалог». The «не давати пройти далі» half is built ([[cloud_reports/dialogue-triggers]], D737). This note is the
«менше тексту» half: every dialogue on the main route (Canyon → Village → Desert Road → City Gates → City) that is longer
than 6 lines, with a trimmed **draft** in uk and en. **The live `.dqd` files are not changed.** Sapega picks, edits or
rejects each draft; the routine that applies one rewrites `dialogue_quest/<id>.dqd` and `dialogue_quest/en/<id>.dqd`
together (same line count in both, D121 / BACKLOG 31).

Count: `say|` lines in `dialogue_quest/<id>.dqd` (uk and en have the same count). Only three dialogues on the route
are over 6; two more sit exactly at 6 and are listed for reference.

| Dialogue | Where / when | Lines | Kind | Draft |
|---|---|---|---|---|
| `Canyon_Intro` | Canyon, the first thing in a new game (Canyon.gd → INTRO) | **7** | monologue bubble | 4 lines |
| `Canyon_StartMonologue` | Canyon, straight after `Canyon_Intro` (MONOLOGUE) | **7** | monologue bubble | 3 lines |
| `RelicArmor_Examine` | Canyon, E on the relic armour after the Village (RelicArmor.gd) | **7** | monologue bubble | 3 lines |
| `Canyon_AbductionCutscene` | Canyon, after the meditation (cloud talk) | 6 | cloud talk | — (at the limit) |
| `City_MayorHall` | City → Mayor Hall queue cutscene | 6 | window, 4 speakers | — (at the limit) |

`Canyon_Intro` and `Canyon_StartMonologue` play back to back: **14 lines** before the player first moves, and since
D737 the hero is held for both. That pair is the one worth cutting first. Merged, the drafts below give 7.

## Canyon_Intro — 7 → 4 (draft)

Keeps: the boredom, grandfather has not passed the staff on, «I am meant for more», the quiet doubt. Drops the second
complaint line and the quoted lectures.

```
// [ЧЕРНЕТКА] dialogue-trim — 7 → 4 рядки (Sapega: «менше тексту»)
say|KUSAKAM|Гей, вітре... щодня те саме: ті самі обличчя, ті самі дідові історії.
say|KUSAKAM|Він мав передати мені шаманський посох ще сто піщаних бур тому — а все повчає.
say|KUSAKAM|Я створений для більшого, ніж ці три глиняні хатини.
say|KUSAKAM|(тихіше) Навіть якщо... поки що нічого не виходить.
exit|
```

```
// [DRAFT] dialogue-trim — 7 → 4 lines
say|KUSAKAM|Hey, wind... every day is the same: the same faces, the same stories from grandpa.
say|KUSAKAM|He was supposed to pass me his shaman staff a hundred sandstorms ago — and he just keeps lecturing.
say|KUSAKAM|I'm meant for more than these three clay huts.
say|KUSAKAM|(quieter) Even if... nothing works out yet.
exit|
```

## Canyon_StartMonologue — 7 → 3 (draft)

Most of it repeats `Canyon_Intro` (the old fool, why not a shaman now). Keeps the one new idea: silence as a spirit of
the desert, which sets up the meditation.

```
// [ЧЕРНЕТКА] dialogue-trim — 7 → 3 рядки
say|KUSAKAM|Чому я не можу стати шаманом прямо зараз?
say|KUSAKAM|Тиша... Вона теж дух пустелі. Може, саме вона навчить мене шляху шамана.
say|KUSAKAM|Але поки що я тут, на початку свого шляху.
exit|
```

```
// [DRAFT] dialogue-trim — 7 → 3 lines
say|KUSAKAM|Why can't I become a shaman right now?
say|KUSAKAM|Silence... it's a spirit of the desert too. Maybe it will teach me the shaman's way.
say|KUSAKAM|But for now I'm here, at the start of my path.
exit|
```

**Alternative:** drop `Canyon_StartMonologue` entirely and keep the last line at the end of `Canyon_Intro`. Then
Canyon.gd's MONOLOGUE state has no dialogue (code change, `canyon_monologue_complete` still set) — a product call, not
assumed here.

## RelicArmor_Examine — 7 → 3 (draft)

Keeps: ancient, unknown symbols, «take it, time to go». Drops the line that states where it stands (the player sees
it) and the two guesses.

```
// [ЧЕРНЕТКА] dialogue-trim — 7 → 3 рядки
say|KUSAKAM|Ці обладунки... стародавні. На них символи, яких я не розумію.
say|KUSAKAM|Може, вони належали моїм предкам? Вони мають бути зі мною.
say|KUSAKAM|Пора вирушати в дорогу.
exit|
```

```
// [DRAFT] dialogue-trim — 7 → 3 lines
say|KUSAKAM|This armor... it's ancient. There are symbols on it I don't understand.
say|KUSAKAM|Maybe it belonged to my ancestors? It has to be with me.
say|KUSAKAM|Time to set out.
exit|
```

## How to apply a draft

1. Sapega marks a draft as accepted (or edits it) here.
2. A routine replaces the `say|` lines of both files, keeps the `// [ЧЕРНЕТКА]` header with the new D-ID, and runs
   `verify_locale` and the room's verify (`verify_canyon_exit`, `verify_starter_loot`).
3. No code depends on the line count of these three; the flags are set on `dialogue_finished`.
