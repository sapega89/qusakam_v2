---
type: report
tags: [cloud, routines]
---

# wire-backdrops-3 — NOT STARTED (prerequisite never arrived)

- **Not done:** nothing was wired. The routine waits for `origin/cloud/rooms-finish:design/cloud_reports/rooms-finish.md`
  (without `SUITE_LINE`); after 8 hours of polling (≈54 fetches, 9-minute calls, ending 2026-10-28 10:47 UTC) the branch
  `origin/cloud/rooms-finish` did not exist on origin at all, so per ROUTINE_RULES «Waiting for a routine before you» this run stops.
- No D-IDs, no B rows fixed, no code changed, Godot not downloaded, no tests run. Full suite: not run.
- This branch is `origin/feature/backlog` + this report only (not rooms-finish, which does not exist).
- To redo: re-fire the routine once `cloud/rooms-finish` has pushed its finished report, or drop the wait and branch from
  `origin/feature/backlog` if rooms-finish was cancelled.

## Untouched scope (for the next run)
Wire the City backdrops in `Scripts/Tools/build_world_rooms.py` (D833/D844): CraftQuarter, PalaceSquare (forge + chapel
move per D773, keep ForgeDoor reachable, update verify_city_life / capture teleports), Rooftops, PigeonLoft, TavernAttic,
MayorArchive, Cistern, CisternStash and props `City/gen_rooftops_ladder.png`, `City/gen_attic_stall.png`,
`Gates/gen_rooftops_rope.png`. Known conflicts still open: `City/TavernAtticDoor` x 2450 inside Kesh's `DervishTent`
(2076–2532 world); `RooftopsLadder` ending at world 933 touching the Forge at 934.
