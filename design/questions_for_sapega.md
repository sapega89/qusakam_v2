# Questions for Sapega

Open questions from the Runtime UI Completion plan (`runtime_ui_completion_plan.md`).
None blocks the start of the work. Each has a **default** that will be used until
answered, and names the slice it affects.

Answer by number. Answered questions move to `figma_decision_register.md`.

| # | Slice | Question | Default until answered |
|---|---|---|---|
| Q1 | — | Your message starts at item 3. Were items 1 and 2 intentional, or did they get lost? | Treat the plan as complete without them. |
| Q2 | 1a | **Which pickups use prompt + confirmation modal (D71)?** Today everything is picked up on touch: coins, orbs, enemy loot. Showing a modal for every coin would stop play constantly. **Found in slice 1a:** no world object in the production maps gives an inventory item (orbs exist only in legacy maps and only raise a counter). `ItemPickup.tscn` is built and tested but not placed. Where should pickups go, and should orbs/chests become `ItemPickup`s? | Only world item pickups use it. Coins and enemy loot stay automatic. No map placement until you name items and places. |
| Q3 | 1b ✅ default applied | The Figma slot card shows **level, lead character, party portraits and a region name**. Save metadata has only date, room name and playtime. Store level and lead character (real data exists) and leave party portraits and region out until art/data exist? | Store level + lead character name. Show the room name as the location. Omit region and portraits. |
| Q4 | 1b ✅ default applied | Player data (`player_data.json`) is saved to **one shared file, not per slot**, so loading slot 2 may restore slot 1's inventory and stats. Fix this inside slice 1b? | Yes: make player data per slot. It is required for slot selection to be correct. |
| Q5 | 1b ✅ default applied | Save points **auto-save on touch** today. After the change (prompt → slot selection), should auto-save on touch be removed, or kept as a silent quick-save? | Remove it. Saving only through the prompt. |
| Q6 | 5 | **Game Over behaviour.** Today the player is teleported back and healed. What should the Game Over options do: "Resume from last save point" = reload the last saved slot? What is the second option (return to title?)? | Resume = reload the slot last saved or loaded. Second option = return to title. |
| Q7 | 1b ✅ default applied (Delete / pad Y) | The runtime has a **delete save slot** action that Figma doesn't show. Keep it? | Keep it (no removal of existing functionality). Styled with the same modal family. |
| Q8 | 3 | Blacksmith menu includes **Enchant**, but Enchanting is out of scope. Hide the entry or show it disabled? | Hide it. |
| Q9 | 3 | Remove the old "blacksmith = shop Equipment mode" path in slice 3, or keep it until later? | Remove it once the Blacksmith NPC works (D69). |
| Q10 | 4 | `ForgeSystem.gd` is an 8-line stub. Replace it with the new `CraftingManager`, or keep both? | Replace it. |
| Q11 | 4 | Recipes need a **gold cost** (D85). If `crafting_recipes.json` has no prices, who sets them? | Slice 4 stops at that point and asks for the price list. No invented numbers. |
| Q12 | 1a | Prompt input badge: keyboard **E** + gamepad **A**, switching with the last used input device? | Yes. |
| Q14 | 1a | The pickup modal reuses the shared modal family (D79), which is larger than Figma's compact `UI/Modal/ItemPickup` card (327×140, small "You obtained:" caption over a larger item name). Build a dedicated compact pickup card, or keep the shared modal? | Keep the shared modal. |
| Q15 | 2 | The Figma shop replaces the party column with **Party Equipment Effects** (per-character stat changes, e.g. MAX HP 740 → 810). No stat-comparison logic exists yet. Build it (needs equip-slot rules per character), or keep the normal party panel? | Keep the normal party panel for now. |
| Q16 | 2 | Figma's category icons (sword, shield, helmet, bell, scroll) vs our item data: we map **sword → weapons, shield → shields, helmet → other armor, bell → accessories (none exist yet), scroll → consumables + materials**. OK? | Use this mapping. |
| Q17 | 2 | Figma's shop sidebar has **Equipment** next to Buy/Sell. What does it do in a shop (equip what you just bought)? D69 already says the Blacksmith is not a shop mode. | Hidden until defined. |
| Q18 | 2 | The Figma buy confirmation shows **Quantity: 4**, but no quantity picker is designed. Buy one at a time, or add a quantity selector? | One at a time (Quantity: 1). |
| Q19 | 2 | Figma has no "not enough gold" state. We show a modal "Not Enough Gold — You need ₹ N to buy X." from the shared family. OK, or grey out rows you can't afford? | Keep the modal. |
| Q13 | 8 | `CLAUDE.md` says "154 tests (100% pass)", but no GUT tests exist; the real suite is 17 verify scripts. Update `CLAUDE.md`? | Yes, in slice 8. |
