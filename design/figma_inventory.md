# Figma Inventory

Structural inventory of the Figma source file, produced as Phase 1 of the Figma
coverage audit (see `UI_SURFACE_AUDIT.md`). Inventory only — no matching against
runtime surfaces and no coverage verdicts yet; that is Phase 3.

- **File:** `zZet0eKcVhXSwQUNZsrOlO` ("Untitled")
- **Source:** `get_metadata` on each top-level page, 2026-09-26
- **Pages:** 3

| Page | Node | Contents |
|---|---|---|
| 🎮 Prototype | `144:1774` | 8 sections, 44 screen-level frames/instances |
| UI KIT / DESIGN SYSTEM | `222:4288` | ~70 components/component sets + 4 token documentation frames |
| 🎨 Icons & Assets | `106:586` | 4 icon sections + environment/NPC/prop art |

No DEV SPEC page or spec-annotation layers exist in the file.

**Cited in design/** = the node ID already appears somewhere under `design/`.
`—` means the frame has never been referenced by any mapping doc.

---

## 1. Prototype page (`144:1774`)

All screens are 1920×1080 unless stated.

### 1.1 Splash & Main Menu — `144:1775`

| Node | Name | Type | Cited in design/ |
|---|---|---|---|
| `258:5141` | UI/Splash Screen | instance of `258:5140` | — |
| `9:26` | main-menu | frame | — |

### 1.2 Save / Load — `144:1776`

| Node | Name | Type | Cited in design/ |
|---|---|---|---|
| `17:5` | save-game-screen | frame | — |
| `258:5162` | UI/Save Screen Modal | instance of `258:5161` | — |
| `150:1278` | load-game-screen | frame | — |

### 1.3 Settings — `144:1798`

| Node | Name | Type | Cited in design/ |
|---|---|---|---|
| `17:280` | settings-display | frame | settings_mapping, ui_implementation_plan, UI_IMPLEMENTATION_STATUS, UI_SURFACE_AUDIT |
| `17:409` | settings-audio | frame | settings_mapping, ui_implementation_plan |
| `17:632` | settings-gameplay | frame | settings_mapping, ui_implementation_plan |
| `17:756` | settings-controls | frame | settings_mapping, ui_implementation_plan |

### 1.4 Modals & Popups — `144:1799`

| Node | Name | Type | Cited in design/ |
|---|---|---|---|
| `274:5336` | UI/Modal/Confirm | instance (382×235) | — |
| `28:5` | item-pickup-standalone | frame | — |
| `28:25` | item-pickup-in-context | frame | — |
| `274:5375` | UI/Modal/ItemPickup | instance (327×140) | — |
| `41:83` | game-over-screen | frame | — |

### 1.5 Dialogues — `144:1800`

| Node | Name | Type | Cited in design/ |
|---|---|---|---|
| `36:6` | npc-dialog-simple | frame | — |
| `36:65` | conversation-dialog-choices | frame | — |

### 1.6 Game Menu — `144:1801`

Largest section (10300×7400). Also contains Shop, Crafting and Enchant flows.

| Node | Name | Type | Cited in design/ |
|---|---|---|---|
| `46:193` | menu-inventory | frame | inventory_diff_plan, ui_implementation_plan, UI_IMPLEMENTATION_STATUS, UI_SURFACE_AUDIT, ui_visual_qa |
| `58:4` | menu-equipment | frame | skills_system_plan, skills_ui_mapping, ui_implementation_plan, UI_IMPLEMENTATION_STATUS, ui_navigation_map, UI_SURFACE_AUDIT, ui_visual_qa |
| `58:230` | menu-healing | frame | — |
| `58:453` | menu-skills | frame | skills_system_plan, skills_ui_mapping, ui_implementation_plan, UI_IMPLEMENTATION_STATUS, UI_SURFACE_AUDIT, ui_visual_qa |
| `58:719` | menu-status | frame | ui_implementation_plan, UI_IMPLEMENTATION_STATUS, UI_SURFACE_AUDIT, ui_visual_qa |
| `58:947` | menu-jobs | frame | ui_navigation_map |
| `58:1246` | menu-miscellaneous | frame | ui_implementation_plan, UI_IMPLEMENTATION_STATUS, ui_navigation_map, UI_SURFACE_AUDIT, ui_visual_qa |
| `94:609` | menu-world-map | frame | ui_implementation_plan, UI_IMPLEMENTATION_STATUS, ui_navigation_map, UI_SURFACE_AUDIT, ui_visual_qa, world_map_mapping |
| `130:1172` | menu-tutorial | frame | — |
| `135:1260` | tutorial-content | frame | — |
| `192:1754` | journal-character-detail | frame | journal_audit, ui_implementation_plan, ui_navigation_map |
| `192:1529` | journal-main-story | frame | journal_audit, ui_implementation_plan, UI_IMPLEMENTATION_STATUS, UI_SURFACE_AUDIT |
| `192:1636` | journal-side-stories | frame | journal_audit, ui_implementation_plan |
| `153:1289` | shop-buy | frame | UI_IMPLEMENTATION_STATUS, ui_navigation_map, UI_SURFACE_AUDIT |
| `153:1523` | shop-sell | frame | — |
| `153:1760` | shop-buy-confirm | frame | — |
| `160:1291` | crafting-list | frame | — |
| `164:2326` | crafting-detail | frame | — |
| `164:2545` | crafting-confirm | frame | — |
| `164:2764` | crafting-error | frame | — |
| `164:1446` | crafting-confirm *(duplicate name)* | frame | — |
| `164:1621` | crafting-error *(duplicate name)* | frame | — |
| `177:1362` | enchant-list | frame | — |
| `177:1582` | enchant-detail | frame | — |
| `177:1836` | enchant-confirm | frame | — |
| `177:2108` | enchant-error | frame | — |

### 1.7 Game Scene — `144:1802`

| Node | Name | Type | Cited in design/ |
|---|---|---|---|
| `434:6556` | Game Scene / Combat HUD | frame | combat_hud_mapping, UI_IMPLEMENTATION_STATUS, UI_SURFACE_AUDIT, ui_visual_qa |

### 1.8 NPC Interaction — `164:1301`

| Node | Name | Type | Cited in design/ |
|---|---|---|---|
| `164:1302` | npc-menu-merchant | frame | — |
| `164:1318` | npc-speech-bubble | frame | — |
| `164:1334` | npc-dialogue-full | frame | — |
| `176:1357` | npc-menu-blacksmith | frame | — |
| `144:1735` | desert-oasis-scene | frame | ui_implementation_plan, ui_visual_qa |
| `197:1392` | fishing-village-scene | frame | — |

### 1.9 Loose canvas nodes (outside any section)

`194:1516`, `195:1516`, `198:1382`, `388:6329` ("image", 400×300) and
`316:7348` ("Frame", 100×100). Likely scratch/reference images, not screens.

---

## 2. UI KIT / DESIGN SYSTEM page (`222:4288`)

### 2.1 Token documentation

| Node | Frame | Values |
|---|---|---|
| `222:4363` | Colors | Background `#111118` · Surface `#111118` 56% · Surface Hover `#111118` 30% · Accent `#D4AF37` · Border `#3A3A42` · Border Hover `#D4AF37` · Text Primary `#FFFFFF` · Text Secondary `#A0A0A0` · Text Muted `#666666` · Disabled `#404040` |
| `222:4452` | Typography | Cormorant Garamond. Display Bold 36 · Title Bold 24 · Heading SemiBold 20 · Label SemiBold 16 · Body Regular 16 · Small Regular 14 · Value SemiBold 14 · Caption Bold 12 |
| `222:4524` | Spacing | 2xs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · 2xl 32 · 3xl 48. Semantic: panel padding 16 · list row padding 12 · icon-text gap 8 · section gap 24 · screen margin 48 |
| `224:4300` | Shape | Border 1px default / 2px selected · corner radius 0 everywhere · effects: inner shadow, drop shadow, panel glow |

### 2.2 Components with variants

| Node | Component set | Variants |
|---|---|---|
| `222:4628` | UI/Button | Type Primary/Secondary × State Default/Hover/Pressed/Focused/Selected/Disabled |
| `222:4639` | UI/Tab | Default/Hover/Selected/Focused/Disabled |
| `222:4681` | UI/ListRow | Default/Hover/Selected/Focused/Disabled |
| `222:4692` | UI/Inventory/Slot | Default/Hover/Selected/Empty/Disabled |
| `222:4827` | UI/Inventory/ItemRow | Default/Hover/Selected |
| `222:4703` | UI/Equipment/Slot | Empty/Default/Hover/Equipped/Disabled |
| `222:4734` | UI/Skills/SkillRow | Default/Hover/Selected/Locked/Disabled |
| `222:4839` | UI/Skills/Slot | Default/Active/Locked/Cooldown/Disabled |
| `222:4767` | UI/ResourceBar | HP/SP/XP/Stamina |
| `222:4785` | UI/Map/Marker | Default/Active/Selected/Visited/Locked |
| `222:4805` | UI/IconButton | Default/Hover/Pressed/Disabled |
| `222:4840` | UI/HexButton | yes/no/close |
| `276:467` | UI/Action Button | A/B |
| `121:1073` | UI/Bottom Bar | gamepad/keyboard |
| `248:62` | UI/Menu Item | active/inactive |
| `248:75` | UI/Sidebar Tab (60×40) | active/inactive |
| `386:6642` | UI/Sidebar Tab (270×45) *(same name as 248:75)* | active/inactive |
| `117:214` | UI/Settings Tab | active/inactive |

### 2.3 Single components

Primitives: `222:4640` UI/Panel · `222:4642` UI/Window · `222:4743` UI/Tooltip ·
`222:4746` UI/Badge · `222:4757` UI/ProgressBar · `222:4768` UI/Scrollbar ·
`222:4786` UI/CharacterSelector · `222:4794` UI/NavigationHint ·
`222:4806` UI/BackButton · `258:5348` UI/Potion Slot · `258:5399` UI/Restore Button ·
`258:5402` UI/RB Controller Button · `258:5428` UI/Archive Restore ·
`217:3017` UI/Diamond Divider · `218:4298` UI/Banner Graphic ·
`218:4341` UI/Character Pedestal · `390:6411` UI/Top Bar

Modals: `258:5332` UI/Modal/Confirm · `222:4880` UI/Modal/ItemPickup ·
`217:2983` UI/Craft Error Modal · `217:2189` UI/Recipe Confirmation Panel

Screen-level panels: `258:5110` UI/Equipment Panel · `258:5111` UI/Attributes Panel ·
`258:5112` UI/Skills Sidebar · `258:5113` UI/Quest List Panel ·
`258:5114` UI/Quest Detail Panel · `258:5080` UI/Legend Panel ·
`258:5108` UI/Dialogue Choices · `127:1087` UI/Character Dialogue ·
`68:1177` UI/Party Status Panel · `311:5291` UI/Party Equipment Effects ·
`324:6127` UI/Party Character Card · `324:6790` UI/Party Effect Card ·
`316:7708` UI/Game Menu Sidebar · `355:6422` UI/Inventory Center Panel ·
`217:2289` UI/Crafting Center Table Panel · `217:3038` UI/Save Load List Area ·
`217:1597` UI/Save Load Top Section · `217:1618` UI/Settings Top Section ·
`218:4264` UI/Settings Section Header · `117:834` UI/Settings Sidebar

Full-screen components: `258:5140` UI/Splash Screen · `258:5161` UI/Save Screen Modal ·
`68:1900` UI/World Map Base · `217:2623` UI/NPC Desert Scene Background

---

## 3. Icons & Assets page (`106:586`)

| Node | Section | Contents |
|---|---|---|
| `106:898` | 🎮 Menu Icons | **Empty.** Note in file: "Menu sidebar currently uses text-only labels. Add icons here for: World Map, Journal, Inventory, Healing, Equipment, Jobs, Skills, Status, Miscellaneous" |
| `106:900` | 📦 Item & Skill Icons | 10 item, 6 equipment, 13 skill, 5 UI icons (Lucide-style names) |
| `107:1117` | 🎮 Input Button Icons | Gamepad (A/B/X/Y, LB/RB, LT/RT, d-pad, sticks), full keyboard, mouse |
| `107:1568` | 🔹 UI Icons | ~28 UI icons, 8 equipment icons (incl. framed variants), 8 skill icons |

Loose art: `env/*` (desert sky, road, blacksmith, merchant tent, inn, cactus,
market goods, well, palm trees, oasis) · `npc/merchant`, `npc/blacksmith`,
`npc/local-resident` · `prop/treasure-chest`, `prop/glowing-crystal`, `prop/save-pillar`.

---

## 4. Observations for Phase 3

1. **28 of 44 prototype frames have never been mapped** in `design/`. All of Save/Load,
   Modals & Popups, Dialogues, NPC Interaction, Shop sell/confirm, Crafting,
   Enchant, Tutorial and Healing are unreferenced.
2. **Game Menu section also holds Shop, Crafting and Enchant.** Grouping in Figma
   does not match runtime reachability (Shop is reached via NPC, not the menu).
3. **Duplicate frame names:** two `crafting-confirm` (`164:2545`, `164:1446`) and
   two `crafting-error` (`164:2764`, `164:1621`). Positioned among the enchant
   frames, so `164:1446`/`164:1621` may be misnamed enchant or blacksmith variants.
   Needs a screenshot to resolve.
4. **Two different components share the name `UI/Sidebar Tab`** (`248:75` 60×40
   and `386:6642` 270×45).
5. **Childless frames:** `get_metadata` returns no layers for main-menu, save/load
   screens, game-over, npc-dialog-simple, menu-inventory, menu-skills and all
   Shop/Crafting/Enchant frames. Either their content is a flattened image or the
   metadata export omitted it. Coverage checks for these need
   `get_screenshot`/`get_design_context`, not metadata.
6. **Prototype links are not exposed by `get_metadata`.** Flow verification in
   Phase 3 must rely on `get_design_context` or be confirmed with the designer.
7. **Game-over screen exists** (`41:83`), but the audit lists the death/respawn
   screen as needing a Figma design. **Item pickup frames exist** (`28:5`, `28:25`,
   `274:5375`), but the audit lists loot toasts as needing a design. The audit's
   "Still need Figma designs" list must be re-checked.
8. **Menu icons were never designed.** The sidebar is text-only by explicit note.
