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
| Q8 | 3 ✅ default applied | Blacksmith menu includes **Enchant**, but Enchanting is out of scope. Hide the entry or show it disabled? | Hide it. |
| Q9 | 3 ✅ default applied | Remove the old "blacksmith = shop Equipment mode" path in slice 3, or keep it until later? | Remove it once the Blacksmith NPC works (D69). |
| Q10 | 4 | `ForgeSystem.gd` is an 8-line stub. Replace it with the new `CraftingManager`, or keep both? | Replace it. |
| Q11 | 4 ⛔ **BLOCKING** | Recipes need a **gold cost** (D85). **Confirmed in slice 4: `crafting_recipes.json` has no price field** for any of the 18 recipes (all ingredients/results exist in `items.json`). Please give a gold cost per recipe — see *Q11 price sheet* below. | Slice 4 stopped here. No invented numbers. |
| Q12 | 1a | Prompt input badge: keyboard **E** + gamepad **A**, switching with the last used input device? | Yes. |
| Q14 | 1a | The pickup modal reuses the shared modal family (D79), which is larger than Figma's compact `UI/Modal/ItemPickup` card (327×140, small "You obtained:" caption over a larger item name). Build a dedicated compact pickup card, or keep the shared modal? | Keep the shared modal. |
| Q15 | 2 | The Figma shop replaces the party column with **Party Equipment Effects** (per-character stat changes, e.g. MAX HP 740 → 810). No stat-comparison logic exists yet. Build it (needs equip-slot rules per character), or keep the normal party panel? | Keep the normal party panel for now. |
| Q16 | 2 | Figma's category icons (sword, shield, helmet, bell, scroll) vs our item data: we map **sword → weapons, shield → shields, helmet → other armor, bell → accessories (none exist yet), scroll → consumables + materials**. OK? | Use this mapping. |
| Q17 | 2 | Figma's shop sidebar has **Equipment** next to Buy/Sell. What does it do in a shop (equip what you just bought)? D69 already says the Blacksmith is not a shop mode. | Hidden until defined. |
| Q18 | 2 | The Figma buy confirmation shows **Quantity: 4**, but no quantity picker is designed. Buy one at a time, or add a quantity selector? | One at a time (Quantity: 1). |
| Q19 | 2 | Figma has no "not enough gold" state. We show a modal "Not Enough Gold — You need ₹ N to buy X." from the shared family. OK, or grey out rows you can't afford? | Keep the modal. |
| Q20 | 3 | `merchants.json` has a **"blacksmith" stock list** (ingots, swords, iron armor), but the Figma blacksmith menu has no Buy. Should the blacksmith also sell, or is that data obsolete? | No Buy on the blacksmith; data left untouched. |
| Q21 | 3 | The merchant and blacksmith now use the Figma NPC art (`npc/merchant`, `npc/blacksmith`). Is that art final for in-game use, or placeholder? | Use it until replaced. |
| Q22 | 4 | Every recipe names a station: **furnace** (4 smelting), **workbench** (wood plank, leather armor), **anvil** (swords, iron armor/helmet/shield), **alchemy_table** (6 potions). The blacksmith is the crafting entry (D69). Which stations does the blacksmith cover — all four, or only furnace + anvil (+ workbench)? | Blacksmith offers furnace + anvil + workbench recipes; alchemy waits for its own NPC/station. |
| Q13 | 8 | `CLAUDE.md` says "154 tests (100% pass)", but no GUT tests exist; the real suite is 17 verify scripts. Update `CLAUDE.md`? | Yes, in slice 8. |

## Q11 price sheet — fill in the gold cost

Current recipes from `SampleProject/Resources/Data/crafting_recipes.json`. Fill the last column
(gold paid on top of the materials, D85). The value will be stored as `"gold_cost"` on each recipe.
For reference, `buy_price` of the result item is shown where it exists in `items.json`.

| Recipe id | Result | Materials | Station | Gold cost |
|---|---|---|---|---|
| smelt_iron_ingot | Iron Ingot ×1 (buy 30) | Iron Ore ×2 | furnace | ? |
| smelt_copper_ingot | Copper Ingot ×1 (buy 20) | Copper Ore ×2 | furnace | ? |
| smelt_silver_ingot | Silver Ingot ×1 (buy 150) | Silver Ore ×2 | furnace | ? |
| smelt_gold_ingot | Gold Ingot ×1 (buy 300) | Gold Ore ×2 | furnace | ? |
| craft_wood_plank | Wood Plank ×4 (buy 10) | Wood Log ×1 | workbench | ? |
| craft_copper_sword | Copper Sword ×1 (buy 100) | Copper Ingot ×3 + Wood Plank ×1 | anvil | ? |
| craft_iron_sword | Iron Sword ×1 (buy 200) | Iron Ingot ×3 + Wood Plank ×1 | anvil | ? |
| craft_silver_sword | Silver Sword ×1 (buy 600) | Silver Ingot ×3 + Wood Plank ×1 + Mana Crystal ×1 | anvil | ? |
| craft_potion | Potion ×2 (buy 20) | Herb ×2 + Stone ×1 | alchemy_table | ? |
| craft_hi_potion | Hi-Potion ×1 (buy 100) | Potion ×2 + Mana Crystal ×1 | alchemy_table | ? |
| craft_ether | Ether ×2 (buy 30) | Mana Crystal ×1 + Herb ×1 | alchemy_table | ? |
| craft_leather_armor | Leather Armor ×1 (buy 160) | Leather ×5 + Wood Plank ×2 | workbench | ? |
| craft_iron_armor | Iron Armor ×1 (buy 300) | Iron Ingot ×5 + Leather ×3 | anvil | ? |
| craft_iron_helmet | Iron Helmet ×1 (buy 120) | Iron Ingot ×2 + Leather ×1 | anvil | ? |
| craft_iron_shield | Iron Shield ×1 (buy 180) | Iron Ingot ×3 + Wood Plank ×2 + Leather ×1 | anvil | ? |
| craft_potion_lesser_chain | Lesser Potion ×1 (buy 40) | Potion ×2 | alchemy_table | ? |
| craft_potion_medium_chain | Medium Potion ×1 (buy 70) | Lesser Potion ×4 | alchemy_table | ? |
| craft_hi_potion_chain | Hi-Potion ×1 (buy 100) | Medium Potion ×8 | alchemy_table | ? |
