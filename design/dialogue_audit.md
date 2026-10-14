# Dialogue Audit — Slices 6 and 7 (audit only, D83)

Runtime UI Completion slices 6 (standard NPC dialogue) and 7 (special story dialogue).
Per D83 this is **audit only**: no implementation, and no decision yet between
restyling the DialogueQuest addon and building an own presentation layer. The
options, costs and risks below are for that decision. 2026-09-27.

---

## 1. What Figma designs

| Surface | Node | Content |
|---|---|---|
| **Dialogue box** (shared) | `UI/Character Dialogue` `127:1087` | Panel `#111118`@56%, **2px accent border**, padding 24/32, gap 8. Speaker name **Bold 24** white → 1px accent separator → text **Regular 20** white + a small gold diamond "continue" marker. A pointer triangle under the box (towards the speaker). **No portrait.** Component props: `character-name`, `dialogue-text`. |
| Standard NPC dialogue | `npc-dialog-simple` `36:6` | The box (1120 wide) centred at the bottom over live gameplay (HUD stays visible). No Auto/Skip buttons. |
| **Choices** | `UI/Dialogue Choices` `258:5108` | Panel `#111118`@56%, 1px `#3a3a42` border, padding 24, gap 16. Rows 38px with chevron pointer; selected row gold fill — **its text is gold on gold (same defect as D26)**; others Regular 18 white. Not placed in any frame. |
| Speech bubble | `npc-speech-bubble` `164:1318` | Small bubble 199×89: name SemiBold 12 accent, line **Italic 16**, tail, `B Close` hint. For short ambient lines. |
| Full-screen NPC dialogue | `npc-dialogue-full` `164:1334` | Only a dim overlay + `A Continue` hint — **no dialogue panel drawn** (PARTIAL in coverage). |
| **Special story scene** | `conversation-dialog-choices` `36:65` (D70) | Black screen, ornate 1px frame with corner marks, **chapter header** "CHAPTER 3: THE FORGOTTEN SHRINE" Bold 36 + ruled diamond, **two character portraits** (left/right spotlights, 160×320), the same `UI/Character Dialogue` box (1584 wide), bottom hint `↑↓ Select Option · ENTER Confirm · ESC Back`. |

## 2. What the game has today

- **Addon:** DialogueQuest **0.7.0-rc3**, vendored in `addons/dialogue_quest`, no update path.
  Presentation = `dialogue_box.tscn` (`DQDialogueBox`) + `choice_menu.tscn` (`DQChoiceMenu`)
  driven by `dialogue_player.tscn` (`DQDialoguePlayer`).
- **Instanced** by `SampleProject/Scenes/DialogueSystem.tscn` (CanvasLayer) at `Game.tscn:314`, so it
  is **live in every gameplay session**.
- **Look today:** addon `default_theme.tres` (orange panel), hardcoded purple speaker name
  (`dialogue_box.tscn:59`), Auto/Skip buttons, an empty 128px portrait frame (portraits never set and
  `hide_portrait()` never called). `DialogueManager.gd:84-93` also **overrides the panel stylebox at
  runtime** on every start.
- **Flow:** `DialogueManager.start_dialogue()` (`Scripts/Systems/DialogueManager.gd:163`) — layer 100,
  process always, input blocked via `set_movement_enabled(false)` (tree not paused), advance with the
  addon action `dq_accept` (Enter / left mouse). End → `EventBus.dialogue_finished` (used by Canyon,
  CityGates, SceneStateManager, CanyonStateManager, DialogueStateTrigger).
- **Callers:** NpcBase (Talk), RelicArmor, Canyon, CityGates, DesertRoad, DialogueStateTrigger.

### Data actually used (34 `.dqd` files)

| Feature | Used? |
|---|---|
| `say` lines | 90 |
| `exit` | 34 |
| Choices / branches / flags / signals / calls | **none** |
| Speakers | narration (no speaker) 51, `KUSAKAM` 30, `Кусакам` 4 (duplicate ID of the same character), 5 one-off speakers |
| Portraits | **none** — 16 character `.tres` with name + colour only |
| Chapter / story-scene concept | **none** in data or code |

Location labels are written into the text (`[Village]`, `[Lab]`, `[Canyon]`, `[PLACEHOLDER]` ×7).

### Defects found (not fixed — audit only)

1. `CutsceneDialogueStep.gd:24` looks the manager up with `Engine.has_singleton("ServiceLocator")`
   → always "not found". Nothing uses the step today.
2. `DialogueManager.gd:186` default path prefix `res://dialogue_quest/dialogues/` doesn't match the
   flat folder layout (callers pass full paths, so it only bites short IDs).
3. 8 stray `*.dqd*.tmp` files in `dialogue_quest/`.
4. The project already edited 4 addon files in `2ce15306` (default portrait path, `get_as_text()`
   call, stripped UIDs) — the addon is effectively forked already.

---

## 3. Options (D83 decision)

### A — Restyle the addon through project-owned scenes (no addon file edits)

Project scenes whose root scripts **extend `DQDialogueBox` / `DQChoiceMenu`**, keeping the `%` node
names and signals the player expects, styled only from `GameUITheme`; swap them in
`DialogueSystem.tscn`. Remove the runtime stylebox override in `DialogueManager`, hide Auto/Skip and
the portrait frame, add the pointer and diamond marker.

- **Cost:** small–medium (one slice). Reuses the player, typing, bbcode, `dq_accept`, signals.
- **Risks:** tied to the rc addon's internal node contract (`%Name`, `%DialogueText`, …). An addon
  update could break the subclass. Advancing stays on `dq_accept` (Enter/mouse — no gamepad A unless
  mapped).
- **Covers:** standard dialogue (36:6) and choices (258:5108) fully; story scenes (36:65) only if a
  second box variant + chapter header/portrait layer is added around it.

### B — Own presentation layer

Our own dialogue UI drawing Figma exactly, fed by the dialogue data.

- **Blocker:** `DialogueQuest.Signals` only emits started/ended/signal/choice_made — **say text is
  not exposed**, and `DQDialoguePlayer` requires a `DQDialogueBox`. Option B therefore means either
  writing our own DQD player (reusing the addon's parser) or forking the player.
- **Cost:** medium–large. **Benefit:** full control (speech bubbles, story scenes, gamepad input,
  pause rules) and no dependency on addon internals.

### Recommendation (for discussion, not a decision)

**A for standard dialogue now**, because the data uses only `say` + `exit` and A delivers the Figma box
with the least risk. Revisit **B only when special story scenes are actually authored** (they need
chapter titles, portraits and choices that neither the data nor the code has today).

---

## 4. Slice 7 — special story dialogue (36:65)

Not implementable today without inventing content:

- no chapter/story-scene concept (no chapter titles anywhere);
- no portraits (0 of 16 characters have one; `36:65` needs two 160×320 portraits);
- no choices in any `.dqd`, while `36:65` is built around choosing;
- the only cutscene path (`CutsceneDialogueStep`) is unreachable (defect 1).

Minimum needed before building it: which scenes are "special story scenes" (D70), their chapter
titles, portrait art per speaking character, and at least one scene with choices.

## 5. Coverage impact

| Surface | Coverage | Runtime |
|---|---|---|
| Dialogue box | MATCH (`36:6`, `127:1087`) | 🟡 addon style — pending D83 |
| Dialogue choices | PARTIAL (`258:5108`) | unused by data |
| Speech bubble | MATCH (`164:1318`) | ❌ none |
| Full-screen NPC dialogue | PARTIAL (`164:1334`) | 🟡 addon box |
| Boss / cutscene dialogue | MATCH (`36:65`, D70) | 💀 no content, step unreachable |
