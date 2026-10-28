---
type: report
branch: feature/backlog
base: origin/feature/backlog @ 51abc119
date: 2026-10-28
---

# integrate-34

- **Merged:** `worktree-agent-ad042771da03c68fd` (`b5025231` D910 HP, `a58c3b34` D911–D913 test rows, `7d74f886` D922/D923 rows) with `--no-ff` (`43a8e760`). The branch appeared on the first wait round; no conflicts. No `Maps/*.tscn` edited.
- **Register:** D910 (`b5025231`), D911–D913 (`a58c3b34`), D922, D923 (`7d74f886`) marked ✅ Built. No new D/B/Q IDs (next free stays D924, B214, Q128).
- **Balance:** `verify_difficulty` RESULT: ALL PASS (was 17 FAIL), `verify_lab_boss` RESULT: ALL PASS (was 2 FAIL).
- **Full suite:** `SUITE: 2 FAIL in 30 min 45 s, J=4` (nproc 4; 146 PASS), after `verify_scripts_compile` ALL PASS.
- **Re-runs (alone, J=1, twice each):** `verify_repeat_load` PASS, PASS (under J=4: «node count does not grow (633 → 634)»); `verify_camera_rooms` PASS, PASS (under J=4: Aqueduct inside, camera 17.7 px > 12 per frame, cell (18, 7) move_left frame 37). Both are load flakes, the known B186 frame-time kind (integrate-32 saw camera_rooms do the same in AlchemistStore). No assertion changed.
- **main:** fast-forwarded to `feature/backlog`.
- **Left:** M10 (Sapega's playtest); B186's remaining frame-time measurements (camera_rooms is `## SERIAL` yet still drifted once in this run); delete the remote branch `worktree-agent-ad042771da03c68fd` and the local worktree; rebuild `build/windows/Qusakam.exe`.
