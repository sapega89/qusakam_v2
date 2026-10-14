# Investigation — missing `pathfinder_classes.json`

**Question:** was `res://SampleProject/Resources/Data/pathfinder_classes.json`
(A) accidentally removed, (B) present elsewhere, or (C) never implemented?

**Answer: C — never implemented.** No gameplay data was created or modified
during this investigation.

## Evidence

| # | Check | Result |
|---|---|---|
| 1 | `git log --all -- "*pathfinder_classes*"` | **no commits** — never tracked |
| 2 | `git log --all --diff-filter=D -- "*.json"` filtered for class/pathfinder | **no deletions** |
| 3 | `git ls-tree -r` on `main`, `refactor/player-components-dialogue-fix`, `origin/main` | **absent from every branch** |
| 4 | Tags | none exist in the repo |
| 5 | Vendored copy under `raw_assets/qusakam_v2-main/` | **not present** |
| 6 | Repo-wide search for `pathfinder` | 2 code hits only — `ResourcePaths.gd:75`, `CharacterManager.gd:214`. No data file, no fixture, no docs. |
| 7 | Class definitions anywhere else (`"classes"`, `champion`, `paladin`) | only **ids**, never definitions |

## What does exist

`CharacterManager._get_default_character_data()` references **6 class ids** and
**8 subclass ids**:

```
classes    : champion · druid · fighter · ranger · rogue · wizard
subclasses : evoker · guardian · hunter · necromancer · paladin ·
             protector · scoundrel · thief
```

`PlayerStateManager.player_state` defaults to `class_id: "champion"`,
`subclass_id: "paladin"`. The deprecated `SaveSystem_old.gd` uses the same pair
as fallbacks. So the *intent* was real and consistent — only the data file
describing those classes (display name, description, subclass table) was never
authored.

## Corroborating signal

`ResourcePaths.gd` declares two data paths; both files are missing and the
constants are never read:

| Constant | File | Exists? | Referenced? |
|---|---|---|---|
| `MAP_LOCATIONS_CONFIG` | `map_locations.json` | ❌ | ❌ |
| `PATHFINDER_CLASSES` | `pathfinder_classes.json` | ❌ | ❌ (CharacterManager hardcodes the path instead) |

Two declared-but-never-created data files, with unused constants, matches
"planned, never built" rather than "deleted".

`CharacterManager.get_class_data()` degrades cleanly: `FileAccess.open` fails,
it returns `{}`, and the Status screen renders `—`.

## Consequence and options

Status shows `—` for `PRIMARY JOB` / `SECONDARY JOB` (deviation **D14**). The
delegate chain is correct and verified; only the data is absent.

To populate it, the file needs this shape (inferred from the reader at
`CharacterManager.gd:212-243` — **not** authored here):

```json
{ "classes": { "<class_id>": { "name": "...", "description": "...",
    "subclasses": { "<subclass_id>": { "name": "...", "description": "..." } } } } }
```

Writing those 6 classes and 8 subclasses is a **game-design decision**, not a UI
one. No placeholder definitions were fabricated.
