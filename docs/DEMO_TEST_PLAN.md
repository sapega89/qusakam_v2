# Demo Test Plan - Dark Realm RPG

## Overview
Comprehensive testing plan for the 7-day demo-ready implementation.
Tests all new systems: XP, Coins, VFX, Narrative, and Tutorial.

---

## 🎯 Critical Path Test (First Playthrough)

### Test 1: Complete First-Time Player Experience
**Duration:** ~5-10 minutes

#### Steps:
1. **Launch Game**
   - [ ] Prologue scene appears
   - [ ] Story text is readable
   - [ ] "Press any key to continue" appears after 5s
   - [ ] Any key press transitions to game

2. **Initial Tutorial (First 30 seconds)**
   - [ ] Movement hint appears after 2s: "Use A/D or Arrow Keys to move • Space to jump"
   - [ ] Hint slides in from bottom smoothly
   - [ ] Hint auto-hides after 4s

3. **First Combat (Player explores and finds enemy)**
   - [ ] Tutorial hint on first attack: "Press J or Z to attack enemies"
   - [ ] SlashTrail VFX appears on attack (white/blue particles)
   - [ ] HitImpact VFX appears when hit connects (orange particles)
   - [ ] Enemy flashes white on hit
   - [ ] Enemy health bar appears and updates

4. **First Enemy Kill**
   - [ ] Enemy flashes red 3 times
   - [ ] DeathParticles spawn (red/orange explosion)
   - [ ] 2-4 coins drop and scatter
   - [ ] Coins fly to player when close
   - [ ] XP bar fills with animation
   - [ ] Tutorial hint: "Defeating enemies grants XP and coins!"
   - [ ] Coin counter updates

5. **Second Enemy Kill**
   - [ ] XP bar fills more
   - [ ] Tutorial hint: "XP bar fills with each kill • Level up when full"
   - [ ] All VFX work correctly

6. **First Level Up (Kill 3-4 enemies)**
   - [ ] XP bar reaches 100%
   - [ ] Full-screen white flash (LevelUpFlash)
   - [ ] Golden particles burst from player (LevelUpParticles)
   - [ ] Level up notification appears: "LEVEL UP! Level 2"
   - [ ] Shows stat gains: "HP +20, Damage +5"
   - [ ] Tutorial hint after 3.5s: "Level up to increase HP and damage"
   - [ ] XP bar resets
   - [ ] Player max HP increased (check health bar)

**Expected Result:** Player understands progression loop and feels rewarded.

---

## 🧪 System-Specific Tests

### Test 2: XP System
**File:** `XPManager.gd`

#### XP Calculation:
- [ ] Melee enemy (100 HP) = 25 XP
- [ ] Tank enemy (200 HP) = 40 XP
- [ ] Fast enemy (60 HP) = 20 XP

#### Level Progression:
- [ ] Level 1→2 requires 100 XP (4 melee enemies)
- [ ] Level 2→3 requires 200 XP (8 melee enemies)
- [ ] Level 3→4 requires 300 XP (12 melee enemies)
- [ ] XP bar percentage calculates correctly

#### Stat Bonuses:
- [ ] Level 2: +20 HP, +5 Damage
- [ ] Level 3: +40 HP, +10 Damage (cumulative)
- [ ] Level 4: +60 HP, +15 Damage (cumulative)
- [ ] Player HP increases immediately on level up
- [ ] Current HP healed by HP increase amount
- [ ] Damage applies to attacks

---

### Test 3: Coin System
**File:** `InventoryManager.gd`, `Coin.gd`

#### Coin Drops:
- [ ] Melee enemy drops 2-4 coins
- [ ] Tank enemy drops 4-6 coins
- [ ] Fast enemy drops 1-3 coins
- [ ] Coins spawn in circle around enemy

#### Coin Collection:
- [ ] Coins start stationary
- [ ] Coins fly to player when within 150 units
- [ ] Collection speed accelerates
- [ ] Particle burst on collection
- [ ] Coin counter updates correctly
- [ ] No coin duplication or loss

---

### Test 4: Combat VFX
**Files:** `SlashTrail.tscn`, `HitImpact.tscn`, `DeathParticles.tscn`

#### Attack VFX (SlashTrail):
- [ ] Spawns on every attack
- [ ] Positioned in front of player
- [ ] Direction follows player facing (left/right)
- [ ] 20 white/blue particles
- [ ] Lasts 0.5s then auto-deletes

#### Hit VFX (HitImpact):
- [ ] Spawns when hit connects
- [ ] Positioned at enemy center
- [ ] 12 orange/white particles
- [ ] Enemy flashes white for 0.05s
- [ ] Flash doesn't break if enemy dies

#### Death VFX (DeathParticles):
- [ ] Red flash 3 times (0.1s intervals)
- [ ] 25 particles (red→orange→gray gradient)
- [ ] Explosive spread pattern
- [ ] Gravity pulls particles down
- [ ] Lasts 1.5s then auto-deletes

---

### Test 5: Level Up VFX
**Files:** `LevelUpFlash.tscn`, `LevelUpParticles.tscn`

#### Full-Screen Flash:
- [ ] White flash covers entire screen
- [ ] Fades in 0.1s, fades out 0.4s
- [ ] z_index 300 (above all UI)
- [ ] Doesn't block gameplay after fade

#### Particle Burst:
- [ ] 40 golden particles
- [ ] Spawns at player position
- [ ] Shoots upward (negative gravity)
- [ ] 45° spread angle
- [ ] Lasts 2.0s then auto-deletes
- [ ] z_index 200 (above gameplay, below flash)

---

### Test 6: Narrative Systems
**Files:** `PrologueScene.tscn`, `CombatContextDisplay.tscn`

#### Prologue:
- [ ] Fades in from black (2s)
- [ ] Text is centered and readable
- [ ] Continue label appears after 3s
- [ ] Continue label pulses (fade 0.3↔1.0)
- [ ] Any key/button advances
- [ ] Fades to black (1s)
- [ ] Loads Game.tscn correctly

#### Combat Context (if CombatZone placed):
- [ ] Slides in from top when entering zone
- [ ] Context text matches zone type
- [ ] Auto-hides after 3.5s
- [ ] One-shot zones don't retrigger

---

### Test 7: Tutorial System
**File:** `TutorialManager.gd`

#### Tutorial Hints Sequence:
1. [ ] **Movement** - Appears 2s after game start
2. [ ] **Attack** - Appears 1s after first attack
3. [ ] **First Kill** - Appears on first enemy death
4. [ ] **XP Bar** - Appears on second enemy death (after 2s delay)
5. [ ] **Level Up** - Appears 3.5s after first level up

#### Hint Display:
- [ ] Slides in from bottom
- [ ] Centered at bottom of screen
- [ ] Readable text
- [ ] Auto-hides after 4s
- [ ] Each hint only shows once
- [ ] Doesn't interrupt gameplay

---

## 🔧 Performance & Polish Tests

### Test 8: VFX Performance
**Objective:** Ensure no lag or memory leaks

#### Rapid Combat Test:
- [ ] Kill 10 enemies in quick succession
- [ ] All VFX spawn correctly
- [ ] No frame drops
- [ ] VFX particles auto-delete
- [ ] No memory leak (check Godot profiler)

#### Simultaneous VFX:
- [ ] Attack while enemy dies
- [ ] Level up during combat
- [ ] Multiple enemies die at once
- [ ] All VFX render without overlap issues

---

### Test 9: UI Integration
**Objective:** All UI elements work together

#### UI Layout:
- [ ] Health bar (top-left)
- [ ] XP bar (below health bar)
- [ ] Coin counter (below XP bar)
- [ ] Level up notification (center screen)
- [ ] Combat context (top center)
- [ ] Tutorial hints (bottom center)
- [ ] No UI overlap
- [ ] All text readable

#### UI Updates:
- [ ] Health bar updates on damage
- [ ] XP bar animates on XP gain
- [ ] Coin counter increments smoothly
- [ ] Level notification dismisses correctly
- [ ] All z_index values correct (no layering issues)

---

### Test 10: Edge Cases

#### Death During Animations:
- [ ] Player dies during level up VFX
- [ ] Enemy dies during hit flash
- [ ] Multiple enemies die simultaneously
- [ ] No errors in console

#### Extreme Values:
- [ ] Level up 5+ times rapidly
- [ ] Collect 100+ coins
- [ ] XP overflow (>1000 XP at once)
- [ ] System handles gracefully

#### Missing References:
- [ ] TutorialHintDisplay not in scene
- [ ] CombatContextDisplay not in scene
- [ ] XPManager not created
- [ ] Graceful fallbacks (warnings, no crashes)

---

## 🎮 User Experience Tests

### Test 11: Clarity & Feedback
**Objective:** Player understands what's happening

#### Questions to Answer:
- [ ] "Why am I fighting?" - Prologue explains motivation
- [ ] "What do I gain from combat?" - XP/coins clearly shown
- [ ] "How do I get stronger?" - Level up benefits explained
- [ ] "What do the UI elements mean?" - Tutorial hints explain
- [ ] "Am I making progress?" - XP bar shows clear progression

#### Feedback Loops:
- [ ] Attack → Slash VFX (immediate)
- [ ] Hit → Impact VFX + flash (immediate)
- [ ] Kill → Death VFX + coins + XP (satisfying)
- [ ] Level → Flash + particles + notification (celebratory)

---

### Test 12: Balance Check
**Objective:** Progression feels fair

#### Time to Level 2:
- [ ] Takes ~1-2 minutes (4 enemies)
- [ ] Not too fast (cheapens achievement)
- [ ] Not too slow (boring grind)

#### Combat Difficulty:
- [ ] Player can kill enemies before dying
- [ ] Enemies pose some threat
- [ ] Stat bonuses feel meaningful
- [ ] Level 2 player noticeably stronger

---

## 📊 Acceptance Criteria

### ✅ Demo is Ready When:

1. **Prologue works** - Player understands story context
2. **Tutorial guides** - New players learn controls naturally
3. **Progression clear** - XP/level system obvious and rewarding
4. **Combat feels good** - VFX make combat satisfying
5. **No crashes** - All edge cases handled
6. **Performance good** - No lag with multiple VFX
7. **UI readable** - All text clear, no overlap
8. **Feedback loop complete** - Attack → Kill → Reward → Level Up

### ❌ Demo NOT Ready If:

- Prologue skips or crashes
- Tutorial hints don't appear
- VFX missing or broken
- XP/coins not awarded
- Level up doesn't increase stats
- Console errors on enemy death
- UI elements overlap/unreadable
- Lag or memory leaks

---

## 🐛 Known Issues to Check

### From Previous Context:
1. [ ] Player teleportation bug (fixed in Game.gd:125-127)
2. [ ] Enemy spawn positioning (ЭТАП 2.8 complete)
3. [ ] MetSys integration (ЭТАП 2.4 cleanup done)

### Potential New Issues:
1. [ ] Tutorial hints block gameplay
2. [ ] VFX z_index conflicts
3. [ ] Level up during death
4. [ ] Coin collection while paused
5. [ ] XP overflow edge cases

---

## 📝 Testing Checklist Summary

- [ ] **Test 1:** Critical Path (First Playthrough)
- [ ] **Test 2:** XP System
- [ ] **Test 3:** Coin System
- [ ] **Test 4:** Combat VFX
- [ ] **Test 5:** Level Up VFX
- [ ] **Test 6:** Narrative Systems
- [ ] **Test 7:** Tutorial System
- [ ] **Test 8:** VFX Performance
- [ ] **Test 9:** UI Integration
- [ ] **Test 10:** Edge Cases
- [ ] **Test 11:** User Experience
- [ ] **Test 12:** Balance Check

---

## 🚀 Post-Testing Actions

### If All Tests Pass:
1. Create release build
2. Update CLAUDE.md with new features
3. Archive DEBUG_*.md files
4. Tag version: `v1.0-demo-ready`

### If Tests Fail:
1. Document failing tests
2. Fix critical issues first
3. Re-run failed tests
4. Iterate until passing

---

## 📈 Success Metrics

**Demo is successful if:**
- 90%+ of tests pass
- Critical path test completes without errors
- User can play for 10+ minutes without confusion
- Progression feels rewarding
- No crashes or soft-locks

**Current Status:** ✅ Implementation Complete, Testing Pending
