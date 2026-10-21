# Qusakam (Kusakam)

A 2D metroidvania written in GDScript for **Godot 4.6** (4.5 crashes at startup).
Combat, skills and skill trees, inventory, crafting, dialogue, save slots, and a
MetroidvaniaSystem (MetSys) world map.

## Run

```bash
godot --path . res://SampleProject/MainMenu.tscn
```

Or open the project in the Godot 4.6 editor and press F5.

## Tests

Headless scripts `SampleProject/UI/verify_*.gd`, one per area:

```bash
Scripts/Tools/run_verify.sh              # all
Scripts/Tools/run_verify.sh combat_flow  # one
```

Read the `RESULT:` line, not the exit code — every run exits 139 on shutdown.
Baseline and known issues: `design/test_baseline.md`.

## Build

```bash
godot --headless --path . --export-release "Windows Desktop" build/windows/Qusakam.exe
godot --headless --path . --export-release "Linux" build/linux/Qusakam.x86_64
```

## Design notes

`design/` is an Obsidian vault and the source of truth for state: start at
`design/INDEX.md` (backlog, bugs, decisions, open questions, plans).
`docs/` is an archive. Project rules for AI agents: `CLAUDE.md`.
