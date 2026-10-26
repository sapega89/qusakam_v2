---
type: reference
tags: [cloud, routines]
---

# Cloud routine rules

A routine prompt says «Read design/cloud_reports/ROUTINE_RULES.md first and follow it», then names its branch, its
report and its task. This note is the shared part, so the prompts stay short. Routines are logged in [[routines]].

## Setup
1. `git fetch origin && git checkout -B cloud/<name> origin/feature/backlog`. Work only there; `git push -u origin
   cloud/<name>` after every commit-worthy step. Never push to main or feature/backlog.
2. Godot: `curl -sSL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_linux.x86_64.zip && unzip -o -q /tmp/godot.zip -d /tmp/godot`;
   `export G=/tmp/godot/Godot_v4.6.2-stable_linux.x86_64 TEST_LOCK=/tmp/godot_test_lock`;
   `$G --headless --path . --import > /tmp/import.log 2>&1` once.
3. One test: `Scripts/Tools/godot_locked.sh --headless --path . --script res://SampleProject/UI/verify_<area>.gd 2>&1 | grep -E '^RESULT|^  FAIL|SCRIPT ERROR|Parse Error'`
   (exit 139 is normal). The full suite once, at the end: `Scripts/Tools/run_verify.sh | grep -v '^PASS'`.
4. Captures need a window: `xvfb-run -a -s "-screen 0 1920x1080x24" $G --path . --resolution 1920x1080 --rendering-driver opengl3 --script res://SampleProject/UI/capture_<x>.gd`.

## Rules
- The owner (Sapega) is not reachable: never ask, make the call and write it down.
- Read the root `CLAUDE.md` and `docs/CLAUDE.md` first.
- Before any game-design call (a number, a behaviour, a look), read `design/pillars.md`: hard readable combat,
  locations with secrets, a build through profession and skills, companions. Free gifts on the road are out (D583).
- Never commit `SampleProject/UI/playthrough.gd`: the laptop holds uncommitted work in it.
- Do not edit `design/BUGS.md`, `design/figma_decision_register.md`, `design/remaining_work.md`, `design/BACKLOG.md`:
  routines run side by side. The report carries the D-ID text and the B rows fixed; the orchestrator applies them.
- No fallbacks (no silent null / `has_method` guards); static typing; LF line endings; layout in `.tscn`, behaviour in
  `.gd`; colours and sizes from `UITokens.gd`; user text through keys in both `en.po` and `uk.po`; new scripts are
  preloaded, without `class_name`; tests never touch real saves.
- Commit messages end with exactly (your own model name if it differs):
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_01A2gnDWaoeJGbj3GPH4dnCF`

## Spend few tokens
- Wait for background work through its one completion notice. No Monitor that wakes you on every event, no polling.
- Never read a raw Godot log or a whole large file: `grep -n`, then `sed -n a,b`. Do not re-read what has not changed.
- While working, run only the tests your change touches; the full suite once, at the end.
- Look at as few screenshots as you need, and never twice; put before and after into one image.

## Waiting for a routine before you
Some routines continue another routine's branch (both change the same code). Sapega (2026-10-26): «навіщо когось чекати?
чого одразу не запустити?» — so they start at once and wait in the cloud instead of on a fixed hour. If your prompt
says you continue after `<prev>` and `origin/cloud/<prev>` has no `design/cloud_reports/<prev>.md` yet, wait for it,
one tool call at a time, each at most 9 minutes, nothing else in between (cheap):
`for i in $(seq 1 9); do git fetch -q origin && git cat-file -e origin/cloud/<prev>:design/cloud_reports/<prev>.md 2>/dev/null && echo READY && break; sleep 55; done`
Repeat until it prints READY, up to 8 hours in all; then branch from it as your prompt says and start. If 8 hours
pass, write your report saying so and stop.

## Report
`design/cloud_reports/<name>.md`, committed and pushed at the end. It opens with a summary of at most 8 lines: what is
done and what is not, the D-ID text, the B rows fixed, the full-suite line. Details (file:line, RESULT lines, shots)
follow.
