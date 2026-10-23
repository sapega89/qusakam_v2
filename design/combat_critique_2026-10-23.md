---
type: audit
status: reference
tags: [combat, souls-like, enemies, bosses, skills]
---

# Combat critique, 2026-10-23

Sapega asked for it in two steps: «бойову систему треба покритикувати», then «це має бути соулс лайк, тому треба добре
попрацювати над боями». So the bar is a 2D souls-like: Salt and Sanctuary (S&S), Blasphemous, Tails of Iron (ToI) and
the bosses of Hollow Knight (HK). Dark Souls, Sekiro and Elden Ring come in only where they set the genre's rule. This
is a critique, not a plan. No game code and no register was changed.

**How it was read.** The code is `feature/backlog` at 926157d6. The unmerged `cloud/combat-feel` branch (ad665a94:
B128, D443, D456, D444, B125) is cited where it changes the picture. Paths are under `SampleProject/Scripts/` unless
written out. Three bug readings were confirmed with a throwaway headless probe that was not committed (see
[[#Broken while reading]]). Everything else comes from reading the code and the [[figma_decision_register]]. Work
already in flight (B128, D443, D456, B125 / D444, D494, D495, D464) is not proposed again. It is mentioned where it
changes the reasoning.

## Verdict

The combat already uses the words of a souls-like: telegraphed wind-ups with a parry cue, poise and staggers on both
sides, a heavy you can be knocked out of, block and parry, and rest spots that will bring enemies back. What it lacks
is the economy that makes those words matter. A souls-like is a game of commitments paid for with something scarce:

- you choose when to swing, because a swing cannot be taken back;
- you choose when to heal, because the flask holds three;
- you fear death, because it takes what you carried.

Here every one of those choices is free.

### Where it is not a souls-like at all

1. **Nothing commits you to an attack.** The hit comes out on the first frame, and the hero runs at full speed while
   swinging. D456 (in flight) lets a roll or a block cut any swing.
2. **Defending costs nothing.** There is no stamina and no guard meter. A block costs nothing, a missed parry has no
   penalty, two invulnerable dashes chain back to back, and up to a third of the hits miss the hero at random (the
   cap is half).
3. **Healing is not a resource.** Healing Palm refills with time, and potions are drunk from a paused menu.
4. **Death is a reload.** Nothing is dropped and nothing is won back. The world rolls back to the last save.
5. **Enemies do not threaten.** They cannot finish a wind-up against a hero who keeps swinging. By mid-game a hit takes
   2–5 % of his HP.
6. **Power comes from levels and dice, not from learning.** Levels, crit, evasion and attack speed beat skill.

### What already works (keep it)

- **Wind-ups that track the hero, then lock (D215).** A late roll behind the enemy dodges the hit, which is real souls
  behaviour.
- **The core vocabulary.**
  - Poise both ways (D264, D265).
  - A heavy wind-up that a hit interrupts (D269).
  - A skill interrupted mid-cast still costs its SP (D259).
  - A parry cue (D264).
- **Hit feel.** It is better than in most 2D souls-likes:
  - hitstop, camera kick and enemy flinch in three strengths (`Systems/VFXHooks.gd:30-40`);
  - cut streaks, pad rumble and layered impact sounds (D268).
- **Bosses.** Each move has its own pose and glint (D388), and a boss holds its strike pose while recovering (D316).
  The Laboratory boss has a save point right before it, so there is no long walk back after a death, and losing the
  Mayor Hall fight does not end the game (D300).
- **The planned bosses.** D466's brute shows off after each move, and that flourish is his punish window. His tail
  sweep answers a hero who stands behind him. Both are the right ideas.
- **The guard bar (D495).** It is Sekiro's posture, or HK's False Knight armour. The hero should get the same bar (#2).
- **The rest loop.** D447 (meditation spots) with D492 (enemies come back) is a bonfire loop.
- **The archer's spacing (`Gameplay/Characters/Enemies/ArcherLogic.gd`).** It is the template every other kind should
  copy (§B).

## Top 10, by impact

### 1. Attacks commit to nothing (M, GAME DESIGN DECISION)

**What, and why it hurts.**
- **The hit comes out at once.** The light swing turns its hitbox on in the frame the button is pressed
  (`Player/Components/PlayerCombat.gd:337`). It stays on for the whole 0.3 s swing (:25).
- **The swing does not hold the hero in place.** `locks_movement()` leaves the swing out (:296-297; D223 removed D215's
  40 % speed). So the hero:
  - runs at full speed while swinging;
  - can jump in the middle of a swing, which carries on in the air (`PlayerMover._handle_jump` still runs);
  - turns with the stick, and the body and weapon turn too, but the hitbox stays where it appeared (B-4).
- **The "recovery" after a combo's last swing or after a heavy is only a cooldown** (`attack_cooldown`, :241, :326). It
  stops the next attack and nothing else, so the hero can roll, block and run during it.
- **D456 goes further** (unmerged ad665a94, `PlayerCombat.can_cancel_attack`). A roll or a block cuts a light swing, the
  heavy's wind-up or the heavy's strike at any frame. The light hit has already landed on frame 1–2, so "swing, then
  roll" costs nothing at all.

So pressing attack is never a decision, and an enemy wind-up never needs reading. You swing until something flashes,
then you roll.

**References.** S&S, Blasphemous and ToI plant the hero for each swing: a small step forward and no steering. Only the
recovery can be cut short, so a hit that has come out is paid for. HK lets the Knight move while slashing, but HK is the
reference here only for bosses. Its Knight also has no invulnerable dash until late in the game.

**Recommendation.** Keep the 0.3 s swing, and give it the phases the drawing already has. The drawn strike runs from
0.05 to 0.13 s (`Player/Components/WeaponView.gd:75-79`, D224).
1. The hitbox is on only from 0.05 to 0.13 s.
2. The hero is planted during the swing, and each swing carries him forward 8–12 px (the last swing of a combo 20–30
   px). This answers Sapega's «мені не подобається що я зупиняюсь» (D223) without giving free steering back.
3. The facing is locked until the hit is out. The hero may turn in the window between two swings of a combo.
4. Keep D456 but move it to the recovery:
   - from 0.13 s, a roll cuts the swing (a block does not);
   - the heavy's wind-up cannot be cut, because it is the heavy's risk (D269);
   - a roll may cut the heavy's recovery only in its second half.

Details are in [[#A. What the hero can do at the same time]].

**Size.** M: the PlayerCombat timings, the PlayerMover lock and a verify check. It amends D223 and D456.

### 2. Defending costs nothing, and the defences stack (M–L, GAME DESIGN DECISION)

**What, and why it hurts.** The hero has four free defences:
- **Block.** Held, instant, and free. A hit from the front on a held block costs 0 HP. It brings no pushback, no
  freeze and no cost (`Player.gd:459-462`). The hero can let go and act on the next frame. Only hits that freeze him for
  0.6 s or longer break the guard (`PlayerCombat.GUARD_BREAK`, :58).
- **Parry.** Any hit in the first 0.25 s of a block is parried (:465-471). Nothing is lost when a parry catches nothing,
  so tapping block over and over reopens the window on every tap.
- **Dash.** The roll is invulnerable for its whole 0.3 s (`PlayerMover.gd:100`). It has two charges: the second can
  start 0.1 s after the first, also in the air (:89-99). Both come back 0.6 s after the last (:26). Two dashes in a row
  give 0.6 s of invulnerability every 1.2 s.
- **Evasion.** Hits miss at random (`Player.gd:477`, `Systems/StatCalculator.gd:69-76`, D393): 5 % at the start,
  about a third by level 20 with every attribute point in Agility (0.3 % per point, `Resources/Data/attributes.json`),
  and the cap is 50 %.

There is also no stamina (D264, "no stamina ✅ confirmed"). The reason D264 wrote down was "no HUD element without
Figma", which is a production reason, not a design one. ToI, Blasphemous and HK show that a souls-like can live
without stamina. They pay for it with planted swings and short invulnerability. This game removed both, so nothing
limits defending.

**References.**
- S&S: every attack, roll and blocked hit costs stamina.
- ToI and Blasphemous: no stamina, but planted swings, one dodge with a short invulnerable part, and a parry that is
  punished when it misses.
- Sekiro: a posture bar on both sides. HK's False Knight: armour that breaks after enough hits.

**Recommendation.** This keeps "no stamina".
1. The hero gets the guard bar D495 builds for enemies, as the same component. Blocked hits drain it by their weight,
   and it refills while he is not blocking. At zero the guard breaks: a 1.0 s freeze.
2. A blocked hit freezes and pushes the hero a little: 0.15 s and 10 px for a normal hit, 0.3 s and 25 px for a heavy
   one.
3. A parry that catches nothing blocks the next parry for 0.4 s (the block itself stays up).
4. Keep the double dash (✅ D264) for movement. Only the first dash of the pair is invulnerable, and only for its first
   0.2 s. The second dash moves him but does not protect him.
5. Evasion stops being a dice roll (#4, Q-IDs).

The alternative is S&S stamina on attacks, rolls and blocks. It reverses D264's ✅ and is not recommended. The guard
bar reuses D495's code and the bar D495 already draws.

**Size.** M for points 2–4. The guard bar is part of D495's slice 3, as a shared component (M). It amends D200, D264
and D393.

### 3. Healing is not a resource (M, GAME DESIGN DECISION)

**What, and why it hurts.**
- **Healing Palm refills itself.** It heals 40 HP for 5 SP, with a 4 s cooldown and a 0.95 s cast that a hit can
  interrupt (`Resources/Data/skills.json`, D252). SP comes back at 1 per second, all the time
  (`Managers/Gameplay/SkillManager.gd:55`, :205-212; D146). That is 8 HP/s for as long as a fight lasts. A melee bandit
  deals 14 every 1.5 s, about 9 HP/s if every swing lands, so the palm almost cancels him.
- **Potions are drunk in a paused menu.** Crafted potions heal 75 or 200 HP (D261). They are used from the inventory,
  which lives in the Game Menu, and the Game Menu pauses the game (`UI/States/game_menu_state.gd:11`;
  `Menus/Game/inventory_component.gd:297-321`; D286). So a potion works instantly, even mid-boss, limited only by stock.
- **Resting does not heal.** The meditation spot will be the bonfire (D447), but a save point heals nothing
  (`SavePoint.gd:30-44`). Any load, though, gives back full HP (B-6).

**References.** Estus, S&S's Red Flasks, Blasphemous's Bile Flasks and ToI's Bug Juice all work the same way: a few
charges, refilled only at a rest spot, drunk in real time in an animation that can be punished. HK's Focus spends SOUL
that you earn by hitting enemies, and it makes the Knight stand still for a second.

**Recommendation.**
1. Healing Palm stays the hero's heal (D252 stands), but it works like a flask:
   - 3 charges to start, with one more at each of two milestones;
   - refilled only by meditating;
   - no SP cost;
   - it heals 30–35 % of max HP, so it keeps up with levels.
2. Potions are drunk from a quick slot, in real time, with the same interruptible animation. The menu only lists them.
3. Meditating restores full HP, all charges and full SP, and brings regular enemies back (D492).

**Size.** M. It amends D252, D286 and D146 (for healing).

### 4. Levels outgrow flat enemies, so the difficulty collapses (M, GAME DESIGN DECISION)

**What, and why it hurts.**
- **Enemies are the same everywhere.** Each kind has one set of stats, the same in every region
  (`Resources/Enemies/enemy_stats_*.tres`; no spawn point sets `custom_enemy_stats`).
- **The hero grows in a straight line:**
  - +5 Phys. Atk. and +20 HP per level (`Managers/XPManager.gd:19-22`);
  - 5 attribute points per level (D335);
  - armour adds twice its defence in HP and cuts damage taken by a percentage (D205, D206).
- **D492 makes level 20 reachable by farming.**

The table in [[#The numbers]] shows the result. By level 10 a bandit dies in 2 light hits and needs 27 hits to kill the
hero. By level 16 it dies in one hit and needs 48. The Laboratory boss (1100 HP) falls in 6–9 hits. D253 asked for
"enemies are dangerous, fights need dodge/parry, death has a felt cost", and that is gone by the City.

**References.** S&S and Dark Souls keep enemies dangerous in two ways: enemies get stronger region by region, and each
new level gives the player less than the one before. HK has no levels at all, only a few nail upgrades. A good way to
plan this is to count hits: a regular enemy should die in 3–5 hits and kill in 6–10; a boss should die in 25–40 and
kill in 3–6.

**Recommendation.**
1. Write this down as a table per region: the expected level, and for each enemy kind the hits to kill and the hits to
   die.
2. Give each region a strength level for its enemies: one multiplier on HP and damage, set on the spawner or the room.
   D495's size and elite multipliers apply on top.
3. Make each level give less (for example +2 attack and +8 HP), so weapons and upgrades carry the damage.
4. Set each boss's HP from the table, at the level D492 expects there.

**Size.** M. The numbers need Sapega's call, together with Q85.

### 5. Enemies cannot fight back (L, split; partly GAME DESIGN DECISION)

**What, and why it hurts.**
- **Every light combo breaks a regular enemy's poise.** A light hit takes 1 poise and the last swing of a combo takes
  2, so a combo takes 4. A melee enemy has 3, a fast one 2 and an archer 2 (`PlayerCombat.gd:51-53`,
  `DefaultEnemy.take_poise` :606-613). A broken enemy is staggered for 0.6 s and its poise refills. A hero who keeps
  swinging and walking forward breaks it again with every combo.
- **Knockback cancels every wind-up, armoured or not.** `DefaultEnemy.knockback` calls
  `EnemyLogic.start_knockback(push)`, which sets `attack_broken` without any armour check (:370-374). Knockback comes
  from:
  - the last swing of every combo (40 px, `PlayerCombat.gd:43`);
  - every mace hit (60 px, `items.json`).

  So the tank's armour (D208) and a boss's poise mean nothing against the end of a combo. The probe confirmed this on
  the Brass Collector (B-2). D208 wanted knockback to break regular enemies' swings. A souls-like does the opposite: it
  makes committed swings impossible to interrupt.
- **Between attacks, enemies stand still.** In their attack state they stop moving and wait out their cooldown
  (:291-323). The hero cannot see the punish window either: they drop straight back to idle
  (`EnemyView.on_attack_ended` :115-122). D494's longer cooldowns (×1.5) stretch exactly this standing time.
- **Their combos are random.** The length is rolled for each attack (`EnemyLogic.gd:380-382`, 50 % chance per extra
  swing). The last swing is the one that breaks the guard (:387; `DefaultEnemy.hit_stagger_time` :628-629). A jackal's
  second swing may or may not break the guard, and both look the same.
- **They never back off, and never react.** They retreat only at 1 HP or less (:583-621). They do not answer the hero
  healing, casting or missing, and they never use height (§B).

**References.** In the reference games, big enemy swings cannot be interrupted, so the hero has to choose when to
attack. Dark Souls enemies punish heals and misses. Their combos are fixed per move, so they can be learned.

**Recommendation.**
1. Once its tell has shown, an enemy swing can no longer be cancelled by knockback. Only a poise break, a parry, or a
   stun on an unarmoured enemy can stop it (S).
2. After every enemy swing, a recovery pose that lasts as long as the punish window. Bosses already hold their strike
   pose (D316) (S).
3. Fixed combos per kind. The melee enemy always swings twice. The fast enemy picks one swing or three, by distance,
   and each has its own wind-up (S).
4. Movement between attacks: step back after a combo, wait just outside reach, step in to strike. When the hero heals,
   uses a heavy or casts within reach, the enemy attacks at once (M).
5. Group rules: at most two enemies attacking at once (§B) (S).

These should land before D494, or with it: longer cooldowns only work if enemies do something during them.

**Size.** L in total, as five S or M slices. Point 3 needs Sapega's call because it changes D265's random combos. The
rest are agent calls.

### 6. Death costs only time (L, GAME DESIGN DECISION)

**What, and why it hurts.** Death opens Game Over, and "Resume from last save point" reloads the slot
(`UI/game_over_screen.gd:122-134`). Everything since the last meditation rolls back: picked-up items, opened chests,
story flags. Nothing is carried, dropped or won back. So carrying things is never a risk, and there is no run back to
win them.

**References.**
- Dark Souls and S&S: you come back at the bonfire, with the world as you left it. Your currency lies where you died
  (in S&S the creature that killed you holds it). If you die again before you reach it, it is gone.
- HK: your Geo stays with your Shade until you beat it.
- Blasphemous: a Guilt Fragment lowers your Fervour until you collect it.

**Recommendation.** Death brings the hero back at the last meditation spot (D447), with the world kept and regular
enemies back (D492). His coins stay where he died, as a marked echo:
- touching the echo gives them back;
- dying before that loses them.

XP and levels stay, because they are not a currency in this game. A boss's HP resets, and the save point before each
boss keeps the walk back short.

**Size.** L: the Game Over flow, a death marker, and keeping state without a reload. It needs a plan. It overlaps
[[questions_for_sapega]] (Q69).

### 7. The tells do not teach (S–M, partly GAME DESIGN DECISION)

**What, and why it hurts.** Every enemy swing, every boss move and every hazard shows the same red-and-white glint,
exactly 0.25 s before it lands (`EnemyLogic.wind_up` :413-422; D264). That causes three problems:
- **One sign, three answers.** These three look the same:
  - a hit you can block;
  - a hit that breaks the guard (a combo's last swing, every tank hit, every Brass hit, anything that freezes the hero
    for 0.6 s or longer);
  - a hazard on the floor.
- **The glint is the deadline, not the warning.** 0.25 s is about a human's reaction time. A player who reacts to the
  glint presses block just as the parry window closes, because the window starts at the glint.
- **The glint is silent.** `SoundHooks` plays `enemy_windup` when the wind-up starts (:64-76), and nothing when the
  glint appears.

**References.** ToI colours its tells by the right answer: red means roll, the other colour means block or parry.
Sekiro shows a symbol with a sound at the start of the wind-up for attacks that must not be blocked.

**Recommendation.**
1. Two tell colours:
   - white: block or parry;
   - red: it breaks the guard or it is a hazard, so roll.

   This amends D200's "no parry colours", which was written before the parry existed.
2. Show the glint 0.45 s before the hit. The parry window stays the last 0.25 s before the hit.
3. Play a short sound with the glint.
4. Fixed combos and recovery poses (#5).

**Size.** S for each point. Point 1 needs Sapega's call.

### 8. Bosses stand in place and pick moves at random (M–L, partly GAME DESIGN DECISION)

**What, and why it hurts.**
- **Random moves.** `BossLogic.pick_move` draws a random move, by weight, from those that fit the distance (:64-78).
- **No walking.** Within its attack range (Brass 460 px, djinn 500 px) a boss never walks. It stands and fires moves by
  distance (`EnemyLogic.gd:291-323`). Its only travel is a charge.
- **Random combos.** Boss combos inherit the random length: the djinn's claws come 1–3 at a time.
- **Recovery only sometimes.** A boss recovers only after its special moves (:49-50), not after a combo.
- **Easy to interrupt.**
  - The last swing of every combo, and every mace hit, cancels any boss move during its wind-up (B-2).
  - A parry staggers the boss for 1.0 s, from any distance (B-1).
- **Short fights.** At level 16 the Laboratory boss dies in 6–9 hits.
- **Phase 2 is the same fight, faster** (`BossEnemy.gd:94-101`).

Both bosses are being replaced (D466's brute, D468's pair), but the boss code stays, so these points apply to the new
bosses.

**References.** HK's bosses (Hornet, the Mantis Lords) and S&S's bosses move around the arena, attack in short fixed
combos, and leave an opening after their big moves.

**Recommendation.**
1. Rules in `pick_move`: no move three times in a row, and a new move kind that moves the boss (walk to its preferred
   distance, jump back, leap over the hero).
2. Fixed combos for combo moves.
3. A recovery after every move, longer for more dangerous moves.
4. Bosses ignore knockback. Only a poise break or a parry interrupts them, and a parry works only on melee strikes
   (B-1, B-2).
5. HP from the budget (#4): 25–40 hero hits at the expected level.
6. Phase 2 adds a move or a longer combo, not only speed.
7. The camera keeps the boss in view (R14).

**Size.** M for the logic, plus data. The HP budget and the D466 / D468 movesets need Sapega's call.

### 9. A parry is a free stagger with nothing to win (M, GAME DESIGN DECISION)

**What, and why it hurts.** A parry staggers the attacker for 1.0 s (`DefaultEnemy.parried` :624-625), and that is all.
- There is no counter-attack and no extra damage: nothing the hero could not get by swinging at any staggered enemy.
- It can be spammed, because a missed parry costs nothing (#2).
- It works on anything an enemy sends, including the boss's fireball, floor pillar and slam shockwave, from any
  distance (B-1).

D495 rules out a backstab too, so the hero has no special counter at all.

**References.** Dark Souls, S&S and Blasphemous turn a parry into a riposte: a guaranteed heavy counter-attack with its
own animation. Blasphemous also finishes off staggered enemies with an execution.

**Recommendation.**
1. A parry opens a 1.0 s riposte window: the next light attack becomes a riposte, with ×3 damage and its own animation.
   On an enemy with a guard bar it breaks the bar. It can reuse the heavy's frames.
2. A missed parry is punished (#2).
3. Only melee strikes and arrows can be parried. Hazards on the floor are rolled or jumped.

**Size.** M.

### 10. Skills are a trap, and SP refills on a timer like an MMO (M, GAME DESIGN DECISION)

**What, and why it hurts.**
- **Skill damage ignores Phys. Atk.** It is the base value × rank × Wisdom (`SkillManager.scaled` :131-132,
  `Combat/Systems/SkillCombatExecutor.gd:17-34`). Fire Strike (level 6) deals 20 when a light hit deals about 70.
  Eclipse Cleave, a level-20 ultimate that D491 says "hits big", deals 50 when a light hit deals about 150 (B-5).
- **Two clocks.** SP refills over time (1 per second) and every skill also has a cooldown, so two timers limit the same
  thing.
- **Missing is free.** A skill that finds no one when it fires costs nothing (:608-615). A skill that is interrupted
  costs its SP and cooldown (D259).

**References.** HK's SOUL and Blasphemous's Fervour fill up when you hit enemies, so skills become the reward for
fighting well. S&S and Dark Souls spells grow with a stat, and they spend a resource that refills at the rest spot.

**Recommendation.**
1. Skill damage becomes a multiple of Phys. Atk.: strikes 1.5–2.5×, ultimates 4–6×. Rank and Wisdom stay as extra
   multipliers (S).
2. SP fills by landing hits and parries (about 1 per hit, 3 per parry), not over time. Ethers stay as the item that
   refills it (M).
3. Drop cooldowns under about 10 s; keep them only on ultimates (S).
4. A skill that fires and misses still spends its SP.

**Size.** M. Points 2–4 need Sapega's call. Point 1 fixes D491's intent.

## The rest

Grouped by area. Each item says what is wrong, gives a reference where one helps, a recommendation, a size, and
whether it needs Sapega.

### Moveset

- **R1. The heavy is worse than the light combo at everything.**
  - A heavy deals ×1.5 and takes 3 poise, and one heavy takes 1.65 s (0.4 s wind-up, 0.25 s strike, 1.0 s recovery).
    That is 0.9 Phys. Atk. and 1.8 poise per second.
  - A light combo deals ×3.4 and takes 4 poise in about 1.4 s (three 0.3 s swings, then 0.5 s of recovery with a
    sword). That is 2.4 Phys. Atk. and 2.9 poise per second (`PlayerCombat.gd:23-53`).
  - The heavy's only edge is taking all its poise in one hit, and pushing 70 px.

  Souls-likes make the heavy impossible to interrupt while it strikes, and let it damage the guard.

  *Recommendation:* the heavy cannot be interrupted during its strike (it takes one hit without being staggered), it
  does double guard damage (already in D495), and its recovery drops from 1.0 to 0.6 s. Keep ×1.5 damage (Sapega's
  D264 call). S. **GAME DESIGN DECISION** (the "cannot be interrupted" part is new).
- **R2. Every weapon swings in the same 0.3 s.** One `swing_time` serves all weapons (:25). The weapons differ only in
  the cooldown after a combo and in knockback (`items.json`). A mace swings as fast as a dagger and knocks everything
  over. In S&S and ToI, the weapon class sets speed, reach and poise.

  *Recommendation:* a swing time and a poise value per weapon in `weapon_profile`. Provisional values:
  - dagger: 0.22 s, poise 1;
  - sword: 0.3 s, poise 1;
  - mace: 0.42 s, poise 2;
  - halberd: 0.38 s, poise 1, plus its reach.

  The mace stops cancelling swings (B-2). S. No decision needed.
- **R3. Moves a souls-like expects are missing.**
  - A riposte (#9).
  - A roll attack. D496's planned conditional passive, "after a roll the next hit +30 %", is the hook for it.
  - One jump attack, instead of the ground combo carried into the air (`perform_attack` never checks for the floor).

  S each. **GAME DESIGN DECISION.**
- **R4. Blocking, casting and heavy attacks work in the air.** None of them check for the floor
  (`PlayerCombat.begin_cast` :424-440, `heavy_attack` :341-355, the block from the ready state :215-217). They all stop
  the hero's sideways movement, so he drops like a stone mid-pose.

  *Recommendation:* ground only. S. No decision needed.

### Readability

- **R5. The hit lands before it is drawn.** The hitbox is on from the first frame, but the drawn strike comes at 0.05 s
  (D224). The fix is #1, point 1.
- **R6. Hit feel is the strongest part.** Keep it. One problem: at the highest attack speed (2.0×, D393) with two
  weapons (D267), a swing takes 0.12 s and each hit freezes the game for 55 ms, so almost half of a combo is frozen.

  *Recommendation:* scale the freeze on light hits with the swing time. S.
- **R7. The hero cannot see an enemy's punish window.** The fix is the recovery pose in #5, point 2.

### Risk and reward

- **R8. Nothing the hero does gets punished.** Enemies attack on a timer, never in answer to him. Even after #1, a
  commitment only matters if someone answers it. The fix is #5, point 4.
- **R9. The freeze from a hit outlasts the hero's invulnerability.** After a hit the hero is invulnerable for 0.5 s
  (`Combat/CombatBody2D.gd:8`, :63-65), but a combo's last swing freezes him for 0.6 s
  (`EnemyLogic.FINISHER_STAGGER`). With two enemies there is a 0.1 s gap in which he can be hit again while still
  frozen, and he can get stuck that way once elites and groups arrive (D495).

  *Recommendation:* invulnerability lasts at least the freeze plus 0.1 s. S. No decision needed.

### Skills and SP (beyond #10)

- **R10. Use D496's conditional passives to reward souls play.** Reward a parry, a well-timed roll or a hit on an enemy
  whose guard is broken, rather than adding flat stats. S. **GAME DESIGN DECISION** (D496 is still open).

### Healing (beyond #3)

- **R11. Lifesteal and the healing skills add to the problem.**
  - Blood Pact and Crimson Thirst each heal 10 % of the damage of every hit, a little more per rank
    (`SkillManager.gd:145-151`).
  - Second Wind heals 60 HP on a 20 s cooldown.

  *Recommendation:* once Healing Palm works like a flask, keep lifesteal to a few per cent, and let Second Wind refill
  one Healing Palm charge instead of healing. S. **GAME DESIGN DECISION.**

### Stamina

Covered in #2. The choice is the hero's guard bar (recommended) or S&S stamina.

### Camera

- **R12. The camera does not frame the fight.** It is a `Camera2D` on the hero with zoom 2.25, smoothing and the
  room's limits (`Game.tscn:188-190`, `Game.gd:444`). It shows 853 × 480 world px, 426 px on each side of the hero.
  - Brass starts attacking at 460 px and the djinn at 500 px, so their moves begin at the edge of the screen or off it.
  - The Laboratory boss hall is two cells wide (1728 px), so a distant boss is off screen.
  - A tell off screen cannot be read.

  D483 fixes only the vertical framing. HK locks the camera to the arena in boss rooms.

  *Recommendation:* in a fight, lean the camera toward the enemies the hero is fighting (up to about 180 px). In a boss
  hall, keep the boss in view: frame both fighters, or zoom out a little in that hall only. M. **GAME DESIGN DECISION**
  only if the zoom changes.

### Difficulty curve and death (beyond #4 and #6)

- **R13. The rest loop is decided, but not built.** D447 (meditation) and D492 (enemies come back) make the right
  loop. Today, though:
  - a save point only saves (`SavePoint.gd:30-44`);
  - death reloads the save instead of taking the hero back to the spot;
  - D492's reason for respawns, farming to level 20, makes #4 worse unless enemies scale.

  *Recommendation:* meditating heals, refills the healing charges and SP, brings regular enemies back, and becomes the
  spot the hero returns to after death. M. **GAME DESIGN DECISION** (with #3 and #6).

### Remembering presses (input buffering) and responsiveness

- **R14. The game remembers early presses only for the light combo** (and for the roll, in combat-feel). Every other
  early press is lost:
  - attack pressed during the recovery after a combo (`PlayerCombat.gd:314`);
  - heavy pressed during a swing (:347);
  - a skill pressed while the hero is busy fails with `BUSY` (`SkillManager.gd:582-583`);
  - jump has a short grace period after leaving a ledge, but a press just before landing is lost
    (`PlayerMover.gd:228`);
  - combat-feel remembers a roll for 0.1 s, which is shorter than any freeze from a hit (0.2–0.6 s), so a roll pressed
    during the freeze is lost.

  A souls-like remembers the press through the lock and acts on the first free frame.

  *Recommendation:* one buffer in `Player._unhandled_input`, about 0.2 s, that lasts through hit freezes and
  recoveries. When several presses wait, the order is roll, block, attack, heavy, skill. Jump gets a 0.1 s buffer of its
  own. S–M. No decision needed.

### Companions

- **R15. A companion's assist is free, instant and untouchable, and works even while the hero is frozen.**
  - `call_next()` checks only for cutscenes, menus and dialogue (`Player.gd:201-206`). It works while the hero is
    frozen, rolling, casting or in the air.
  - Each companion has its own 15 s cooldown (`Managers/Gameplay/CompanionManager.gd:11`), so three can be called back
    to back.
  - Damage is fixed and never grows: Alisia 8 × 3, Astrit 40, Urizen 30 with a 1 s stun, the guard 999. By level 16 an
    assist deals less than one light hit.
  - Their real value is control. Astrit's 60 px knockback and the guard's 80 px knockback cancel even a boss's move
    (B-2). D464 turns Astrit's hit into a stun, which armoured bosses ignore mid-move.

  In the genre, Elden Ring's spirit ashes cost FP and work only near a Rebirth Monument, and HK's helpers cost charm
  notches.

  *Recommendation:*
  - each companion can be called once per meditation (or for an SP cost);
  - no calls while the hero is frozen or rolling;
  - decide their role: control (damage stays fixed) or damage (it grows with Phys. Atk.).

  S. **GAME DESIGN DECISION.**

## A. What the hero can do at the same time

Read from `Player.gd` `_unhandled_input` (:189-240), from `PlayerCombat.locks_movement` and `owns_animation`
(:291-297), and from `PlayerMover.physics_move` (:107-144). The D456 column is ad665a94.

| Can the hero… | Now (`feature/backlog`) | With D456 (`combat-feel`) | As a souls-like | S&S / Blasphemous / ToI | Proposed |
|---|---|---|---|---|---|
| move during a light swing | yes, at full speed (D223; :296-297) | same | too free | planted, with a step forward | planted, with a forward step |
| move during a heavy | no, he is planted | same | right | planted | keep |
| attack in the air | yes: the ground combo carries on in the air (D215). The heavy works too, but his sideways movement stops | same | air combo passable, air heavy odd | a jump attack of its own | one jump attack, no heavy in the air |
| block while moving | no: blocking plants him (:296-297) | same | a little too strict | Dark Souls walks with the guard up (no running) | walk at about 40 % with the guard up, facing locked |
| block in the air | yes, and his sideways movement stops | same | too free | no | ground only |
| roll out of a swing | no (`Player.gd:212-215`) | yes, at any frame, even out of the heavy's wind-up and strike | too free | only during the recovery | only during the recovery, never out of the heavy's wind-up |
| block out of a swing | no: the block waits for the swing to end | yes, at any frame | too free | no | no |
| roll out of the freeze from a hit | no, and the press is lost | no; the 0.1 s memory is shorter than the freeze, so the press is still lost | locking him is right, losing the press is wrong | locked, the press remembered | locked, the press remembered until the first free frame |
| roll out of a skill cast | no | no | right (D259) | spells commit | keep |
| roll out of a block | he must let go first (1 frame) | same | fine | — | keep |
| jump out of a swing | yes: he can jump during a light swing, and the swing goes on in the air | same | too free | no | jump only during the recovery |
| turn mid-combo | yes: the next swing takes the new facing. Mid-swing the body and weapon turn, the hitbox does not (B-4) | same | too free, plus a bug | the facing is fixed during a swing | facing locked until the hit is out; turning allowed between swings |
| heal while moving | Healing Palm plants him (it is a cast); potions work from the paused menu at any moment | same | menu potions break it | the flask is drunk in real time, slowly | flask in real time, planted, interruptible |
| cast in the air | yes, and his sideways movement stops | same | odd | ground | ground only |
| attack out of a block | no | no | fine | a riposte after a parry | a riposte after a parry (#9) |
| attack right after a roll | yes; a roll has no recovery | same | free | a roll attack | a roll attack, otherwise 0.1 s of recovery |
| call an assist | at any moment: frozen, mid-roll, mid-cast, in the air | same | too free | a summon is a commitment | only when he is free to act |
| switch weapons | anywhere but during an attack, including while blocking, frozen or casting (a strike skill then fizzles, B-7) | same | odd | switching takes time | only when he is free to act |

### The freeze after a hit or a block

| Event | Now | Proposed |
|---|---|---|
| The hero is hit by a normal swing | He freezes for the enemy's `stagger_time` (melee 0.25 s, fast 0.2, tank 0.6, Brass 0.6, djinn 0.4) and is pushed 50 px in 0.15 s (`PlayerCombat.stagger` :476-492). Then 0.5 s of invulnerability | Keep. Invulnerability lasts at least the freeze plus 0.1 s |
| The hero is hit by a combo's last swing | 0.6 s (`FINISHER_STAGGER`), longer than his invulnerability | Keep 0.6 s, invulnerability 0.7 s |
| The hero blocks a normal swing | 0 HP lost, no freeze, no push, no cost | A 0.15 s freeze, a 10 px push, and the guard bar drains |
| The hero blocks a heavy swing (one that freezes for 0.6 s or more) | The guard breaks: full damage and a freeze | The guard bar drains three times as much; at zero, a 1.0 s freeze |
| An enemy takes a light hit | An 8 px push, its attack goes on (`PlayerCombat.HIT_PUSH`, D265) | Keep |
| An enemy's poise breaks | A 0.6 s stagger, then its poise refills | Keep |
| An enemy is knocked back (the last swing of a combo, a heavy, a mace) | Its attack is cancelled at any point, armour or not | Cancelled only before its tell, never on a boss |
| An enemy is parried | A 1.0 s stagger | A 1.0 s stagger plus a riposte window |

### Proposed rules for cutting actions short

| Action | Phases (s) | What can cut it short |
|---|---|---|
| Light swing (0.3 s) | wind-up 0–0.05, hit 0.05–0.13, recovery 0.13–0.3 | Nothing until 0.13. Then the next swing of the combo, a roll, or a jump |
| A combo's last swing | the same, plus the weapon's 0.5 s recovery | A roll, only in the second half of the recovery |
| Heavy | wind-up 0.4, strike 0.25, recovery 1.0 → 0.6 (R1) | Only being staggered during the wind-up (D269). A roll in the last 0.3 s |
| Block | parry 0–0.25, then held | Letting go, at any time. After a parry that caught nothing, no new parry for 0.4 s |
| Roll (0.3 s) | invulnerable 0–0.2, then 0.2–0.3 | A roll attack or a light swing from 0.2. The chained air dash is not invulnerable |
| Skill cast | wind-up, then release | Nothing (D259) |
| A freeze from a hit or a block | — | Nothing. A remembered press acts on the first free frame |

All timings are provisional and need playtesting.

## B. Enemy behaviour and movement around the arena

Read from `Gameplay/Components/EnemyLogic.gd`, `Gameplay/DefaultEnemy.gd`,
`Gameplay/Characters/Enemies/ArcherLogic.gd`, `Gameplay/Characters/Bosses/BossLogic.gd` and the spawn points in
`SampleProject/Maps/*.tscn`.

### How they move today

- **Approach.** They walk straight at the hero along X, at a fixed speed, ignoring Y (`handle_chase_state` :229-289).
  They stop at `attack_range`, measured along X only.
- **Spacing and keeping distance.** None for melee kinds. The archer is the exception:
  - it keeps 170–380 px from the hero;
  - it backs off while there is floor and no wall behind it (`ArcherLogic._can_back_away` :57-72);
  - it shoots only at its own height (:26).
- **Circling and backing off.** None. They retreat only at 1 HP or less (`should_retreat_after_attack` :583-601).
  After a swing an enemy stands where it is until the next one (`handle_attack_state` stops it, :305-306).
- **Surrounding or lining up.** Enemies spawn in a row 80–100 px apart, all on one side (for example DesertRoad's
  `Fight_Caravan`: tank, melee, fast, melee, tank at x 3640–3960).
  - They collide with each other (default physics layers), so they form a queue.
  - With D443 they cannot walk through the hero either, so they never get behind him.
  - The hero fights the front one while the rest wait their turn. They arrive at different times only because their
    speeds differ (fast 120, melee 70, tank 50 px/s).
- **Reacting to where the hero is.** Only by turning. The wind-up follows him until the tell, then locks (D215). That
  is the one truly souls-like behaviour: a late roll behind the enemy dodges the hit.
- **Reacting to each other.** None. Nothing limits how many attack at once, so every enemy in range swings on its own
  timer.
- **Jumping and repositioning.** No enemy jumps, climbs, or drops through a one-way platform.
- **Floors and edges.**
  - Melee kinds never check for ledges or walls (`DefaultEnemy._physics_process` moves only along X, :283-296). They
    walk off edges and push into walls.
  - Enemies notice the hero inside a 300 px circle that passes through walls and floors
    (`Scenes/Characters/Enemies/default_enemy.tscn`, `CircleShape2D_enemy_detection`), and they also check distance
    along X only when idle (`EnemyLogic.gd:222-227`).
  - So in the vertical Laboratory (D225, D487) an enemy two floors down notices the hero, walks under him and swings at
    the ceiling. It also counts as engaged, so the hero draws his weapon and the fight music starts
    (`PlayerCombat._enemy_engaged` :274-278; B-8).
- **Leash.** An enemy goes home once it is farther than max(chase range × 1.5, 450 px) from where it started
  (`DefaultEnemy.get_enemy_params` :251-262). That is good for a metroidvania, because you can run past enemies, but it
  also lets the hero reset any fight by stepping away.
- **Bosses.** They stand still within their attack range and pick moves by distance (#8). A charge is their only
  travel.

### Why it hurts

- **A group is longer, not harder.** With no spacing and no limit on attackers, it plays like one enemy after another.
- **Vertical regions break the AI.** Enemies cannot see floors, and D487 asks for vertical regions.
- **D494 gives the hero more free hits.** Enemies do nothing between attacks, so longer cooldowns just mean longer
  windows to hit them.

**References.** In Dark Souls, knights circle and step back between combos; in 2D the same idea is stepping in and out
of reach. HK's enemies leap and dive. A common rule in action games is that only one or two enemies attack at a time,
while the rest move into position.

### Recommendation, per kind (reusing what exists)

| Kind | Behaviour | Reuse |
|---|---|---|
| Melee (bandit) | A duelist: waits just outside reach, steps in to strike, steps back 60–100 px after a combo. If the hero heals, uses a heavy or casts within reach, it attacks at once | `ArcherLogic._can_back_away` for stepping back |
| Fast (jackal) | Hit and run: lunges (exists), then retreats 120 px and waits. If an ally blocks its way, it leaps over to the hero's other side | the lunge (D208); the leap is new |
| Tank (scorpion) | Advances slowly behind its armour (D495), stops to strike, never retreats | D495's guard bar |
| Archer | As now. Add: it prefers a ledge when one is near, and steps back and shoots when the hero gets close | `ArcherLogic` |
| Shield-bearer (D495) | The front line: holds the hero in place, and bashes when he commits | D495 |
| Flyers (D445) | Dive from above, so not everyone comes from one side | [[flying_enemies_plan]] |

### Group rules

1. At most two enemies wind up an attack at once; the rest wait at 1.5× their reach and shuffle. A static counter on
   `EnemyLogic` is enough (S).
2. Some groups are placed on both sides of the hero, or get a second wave from behind (`RoomEnemySpawner` already
   supports waves) (S; room-content).
3. Enemies notice only a hero on their own floor (within ±64 px), or one they can see by a ray (S).
4. Every walking enemy checks for ledges and walls, using the archer's check (S).
5. Bosses get a move that repositions them, and a preferred distance (#8) (M).

**Size.** L in total, as the S slices above. Only the per-kind personalities need Sapega's call, because they are a
matter of feel. The attack limit and the floor and ledge checks are agent calls.

## The numbers

How many light hits the hero needs to kill each enemy, and how many hits that enemy needs to kill him (each cell:
hero hits to kill / enemy hits to kill the hero). The formulas come from `Managers/Core/GameManager.gd` (D199, D205,
D206), `XPManager.gd:19-22` and the enemies' `.tres` files.

The assumptions:
- no attribute points spent (with every point in Strength the hero's side gets even more lopsided);
- level 1: bare hands, no armour;
- level 5: iron sword, leather armour;
- level 10: iron sword, iron armour;
- level 16: silver sword, plus iron armour, helmet and shield.

The probe matched the formulas: at level 1 a bare-hand combo dealt 30, 30 and 42.

| Level | Phys. Atk. | HP, damage taken | Bandit (100 HP, deals 14) | Jackal (60 HP, deals 10) | Scorpion (200 HP, deals 20; ×0.3 from the front) | Boss |
|---|---|---|---|---|---|---|
| 1 | 30 | 100, ×1.0 | 4 / 8 | 2 / 10 | 7, or 23 from the front / 5 | — |
| 5 | 65 | 200, ×0.91 | 2 / 16 | 1 / 23 | 4 (10) / 12 | Brass at about level 7: 19 / 7 slams |
| 10 | 90 | 320, ×0.83 | 2 / 27 | 1 / 40 | 3 (8) / 19 | — |
| 16 | 130 | 480, ×0.71 | 1 / 48 | 1 / 69 | 2 (6) / 35 | Laboratory boss (1100 HP, deals 24): 9 / 29 |

The proposed budget, per region at its expected level:

| Enemy | Hero hits to kill it | Its hits to kill the hero |
|---|---|---|
| Regular | 3–5 | 6–10 |
| Heavy (scorpion, elite) | 6–10 | 4–6 |
| Boss | 25–40 | 3–6 |

Healing Palm restores about 8 HP/s on its own SP, which almost matches one bandit's full damage (14 every 1.5 s, about
9 HP/s).

## Broken while reading

These are bugs, kept apart from the design opinions above. They are for the orchestrator to file as B-IDs; none was
filed here.

| # | Bug | Where | Status |
|---|---|---|---|
| B-1 | Parrying a boss's fireball, pillar or slam staggers the boss from any distance, and a floor pillar can be blocked just by facing the boss. The hazards name the boss as the source of the damage, and `guard_against` uses the source's position to decide which side the hit came from, then calls `source.parried()` | `Gameplay/Characters/Bosses/Hazards/BossFireball.gd:30`, `BossPillar.gd:26`, `BossLogic.gd:103` → `Player.gd:454-457`, `PlayerCombat.gd:465-471`, `DefaultEnemy.gd:624-625` | **Confirmed** by the probe: a fireball blocked 0.1 s before it hit staggered the djinn 450 px away (0.93 s of stagger left), and the hero took no damage |
| B-2 | Knockback cancels any wind-up, including armoured enemies and bosses. `start_knockback` sets `attack_broken` without checking armour or whether the enemy is a boss. So the last swing of every combo (40 px), every mace hit (60 px), and Astrit's and the guard's assists all cancel boss moves | `Gameplay/Components/EnemyLogic.gd:370-374`, through `DefaultEnemy.knockback` :636-637, `PlayerCombat._hit_effects` :178-183, `Gameplay/Characters/Companions/CompanionAssist.gd:108-109` | **Confirmed** by the probe: a level-1 bare-hand combo (30, 30, 42) during the Brass slam's wind-up cancelled the slam at 0.65 s. No shockwave came, and the boss's poise was 10 of 14 (not broken) |
| B-3 | Boss timers keep running while the game is paused. The recovery, the charge, the gap between fireballs, and the pillar's mark and fire all run on through a pause (D388 fixed only `attack_ready_in`). A pillar marked just before a pause (the Game Menu, a D289 tutorial window) burns the hero while the game is paused, and a pause during a boss's recovery eats the punish window | `BossLogic.gd:50`, :90, :118; `Hazards/BossPillar.gd:21`, :27. These call `create_timer` without `process_always = false`; compare `EnemyLogic.gd:400`, :417, :422 | **Confirmed** by the probe: the hero lost 38 HP during 1.2 s of pause |
| B-4 | Turning during a swing turns the body and the weapon, but not the hitbox. The hitbox is placed once, when the swing starts (`_set_hitbox_active`); the swing does not hold the hero in place, and his facing follows the stick | `PlayerCombat.gd:494-497`, :296-297; `Player.gd:153-155`, :260-267; `Player/Components/WeaponView.gd:119` | By reading |
| B-5 | Skills hit for less than a light swing. A level-20 ultimate (D491: "hits big") deals 45–50 at base, against about 150 for a light hit, because skill damage never reads Phys. Atk. | `SkillManager.gd:131-132`, `Combat/Systems/SkillCombatExecutor.gd:17-34`, `skills.json` | By reading (the numbers) |
| B-6 | The hero's saved HP is never used. `PlayerDataModule` saves `player_state.current_health`, but nothing ever updates it (`update_player_health` has no callers) and nothing applies it on load. Every load, Game Over → Resume included, starts him at full HP | `Systems/Save/Modules/PlayerDataModule.gd:31`, :103-104; `Managers/Gameplay/PlayerStateManager.gd:33`; `Player.gd:70-71` | By reading |
| B-7 | Switching weapons during a skill's wind-up makes a strike skill fizzle at no cost. The switch is allowed whenever the hero is not attacking (`is_attacking`), and when the skill fires `use_skill` fails with `WRONG_WEAPON`: no SP spent, no cooldown. D259 says an interrupted cast costs both | `Player.gd:208-211`, `PlayerCombat.gd:116-118`, `SkillManager.gd:192-193` | By reading |
| B-8 | Enemies notice and chase the hero through floors and walls (a 300 px circle, plus distance along X only). An enemy on another floor walks under the hero, swings at the ceiling, and keeps him "in a fight": weapon drawn, fight music on | `default_enemy.tscn` (detection radius 300), `EnemyLogic.gd:222-227`, `PlayerCombat.gd:274-278` | By reading |
| B-9 | (unmerged `cloud/combat-feel`) A roll or block that cuts a heavy's strike skips its 1.0 s recovery. `cancel_attack` keeps `attack_cooldown`, but the heavy sets that cooldown only when its strike ends normally | ad665a94 `PlayerCombat.cancel_attack`; `PlayerCombat.gd:239-242` | By reading |
| B-10 | Dead code: `VFXHooks.play_boss_attack_effect` and its four helpers (nothing calls them), and `EnemyLogic`'s HP-based retreat (it can run only at 1 HP or less) | `Systems/VFXHooks.gd:202-303`; `EnemyLogic.gd:459-525`, :583-621 | By reading |

## Suggested D-IDs and Q-IDs

The orchestrator assigns the numbers (the register ends at D501, the questions at Q85).

**Q-IDs: each needs Sapega's call.** The default is what happens if he does not answer.

| Proposal | Default |
|---|---|
| Commitment: planted swings with a forward step instead of full-speed swings (amends D223). D456's cut-short moves to the recovery, and never applies to the heavy's wind-up | yes |
| A substitute for stamina: the D495 guard bar on the hero's block too, a short freeze on blocked hits, a lockout after a missed parry, and invulnerability only on the first dash and only for its first 0.2 s. This keeps D264's "no stamina" and the double dash | the guard bar |
| Evasion and crit stop being dice rolls (amends D393): Agility shortens the roll cooldown and raises crit damage on enemies that are staggered, guard-broken or parried | yes |
| Healing Palm becomes the flask: 3 charges (+1 twice), refilled only by meditating, about 33 % HP each. Potions only from a real-time quick slot (amends D252, D286, D146) | yes |
| Death: back at the last meditation spot with the world kept, coins dropped where the hero died, one chance to win them back (amends the Game Over flow; touches Q69) | yes |
| The difficulty budget: hits to kill and hits to die per region, a strength level per region on enemy stats, a smaller bonus per level | the budget in [[#The numbers]] |
| A parry leads to a riposte; only melee strikes and arrows can be parried | yes |
| SP comes from hits and parries, not time; cooldowns only on ultimates; a skill that fires and misses still spends SP | yes |
| Two tell colours (white: block or parry; red: roll), which amends D200's "no parry colours"; fixed enemy combos, which amends D265 | yes |
| Companions: each can be called once per meditation, not while the hero is frozen or rolling; their role is control | yes |
| A personality for each enemy kind (the table in §B) | that table |

**D-IDs: agent calls, Sapega to confirm.** These are fixes and tuning.

| Proposal |
|---|
| An enemy swing whose tell has shown cannot be cancelled by knockback, and bosses ignore knockback (closes B-2) |
| Area hazards cannot be blocked or parried. Projectiles can be blocked, and a parried one never staggers whoever sent it from a distance (closes B-1) |
| The hitbox is on only while the strike is drawn (the hero: 0.05–0.13 s), and the facing is locked until the hit is out (closes B-4) |
| The glint shows 0.45 s before the hit, with a sound; the parry window stays the last 0.25 s before the hit |
| One buffer of about 0.2 s that remembers presses through freezes and recoveries, plus a 0.1 s buffer for jump |
| Skill damage becomes a multiple of Phys. Atk. (closes B-5, as D491 intends) |
| Enemies notice only a hero on their own floor or in sight, and every walking enemy checks for ledges and walls (closes B-8) |
| At most two enemies wind up an attack at once |
| A recovery pose after every enemy swing |
| Rules for a boss's `pick_move`: no move three times in a row, and a move that repositions it |
| Camera framing in fights and in boss halls |
| The hero's invulnerability after a hit lasts at least the freeze plus 0.1 s |

B-3, B-6, B-7, B-9 and B-10 are plain B-IDs that need no decision.
