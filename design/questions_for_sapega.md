# Questions for Sapega

Open questions from the Runtime UI Completion plan (`runtime_ui_completion_plan.md`).
None blocks the start of the work. Each has a **default** that will be used until
answered, and names the slice it affects.

Answer by number. Answered questions move to `figma_decision_register.md`.

| # | Slice | Question | Default until answered |
|---|---|---|---|
| Q1 | — | Your message starts at item 3. Were items 1 and 2 intentional, or did they get lost? | Treat the plan as complete without them. |
| Q2 | 1a | **Which pickups use prompt + confirmation modal (D71)?** Today everything is picked up on touch: coins, orbs, enemy loot. Showing a modal for every coin would stop play constantly. | Only world item pickups (collectibles, chests). Coins and enemy loot stay automatic. |
| Q3 | 1b | The Figma slot card shows **level, lead character, party portraits and a region name**. Save metadata has only date, room name and playtime. Store level and lead character (real data exists) and leave party portraits and region out until art/data exist? | Store level + lead character name. Show the room name as the location. Omit region and portraits. |
| Q4 | 1b | Player data (`player_data.json`) is saved to **one shared file, not per slot**, so loading slot 2 may restore slot 1's inventory and stats. Fix this inside slice 1b? | Yes: make player data per slot. It is required for slot selection to be correct. |
| Q5 | 1b | Save points **auto-save on touch** today. After the change (prompt → slot selection), should auto-save on touch be removed, or kept as a silent quick-save? | Remove it. Saving only through the prompt. |
| Q6 | 5 | **Game Over behaviour.** Today the player is teleported back and healed. What should the Game Over options do: "Resume from last save point" = reload the last saved slot? What is the second option (return to title?)? | Resume = reload the slot last saved or loaded. Second option = return to title. |
| Q7 | 1b | The runtime has a **delete save slot** action that Figma doesn't show. Keep it? | Keep it (no removal of existing functionality). Styled with the same modal family. |
| Q8 | 3 | Blacksmith menu includes **Enchant**, but Enchanting is out of scope. Hide the entry or show it disabled? | Hide it. |
| Q9 | 3 | Remove the old "blacksmith = shop Equipment mode" path in slice 3, or keep it until later? | Remove it once the Blacksmith NPC works (D69). |
| Q10 | 4 | `ForgeSystem.gd` is an 8-line stub. Replace it with the new `CraftingManager`, or keep both? | Replace it. |
| Q11 | 4 | Recipes need a **gold cost** (D85). If `crafting_recipes.json` has no prices, who sets them? | Slice 4 stops at that point and asks for the price list. No invented numbers. |
| Q12 | 1a | Prompt input badge: keyboard **E** + gamepad **A**, switching with the last used input device? | Yes. |
| Q13 | 8 | `CLAUDE.md` says "154 tests (100% pass)", but no GUT tests exist; the real suite is 17 verify scripts. Update `CLAUDE.md`? | Yes, in slice 8. |
