# Level Design Arsenal
**The Complete Shelf — What We Have, What It Does, How To Use It**

---

## 🦊 Fox's Capabilities

| Ability | Details | Design Implication |
|---------|---------|-------------------|
| **Run** | 300 px/s | ~9 tiles per second at 32px |
| **Jump** | ~2.3 tiles high | Basic vertical reach |
| **Double Jump** | +1.5 tiles (0.8x) | ~3.8 tiles max height |
| **Dash** | 400 speed, 0.3s, 2s cooldown | Burst movement, commitment required |
| **Wall Cling** | Slide down walls | Enables wall jumps |
| **Wall Jump** | Leap off walls | Vertical climbing |
| **Swim** | Slower movement, underwater | Different movement feel |
| **Attack** | Melee + air slash | Close combat |
| **Throw Blade** | Returning boomerang | Ranged option when equipped |

**CRITICAL**: Fox takes **NO FALL DAMAGE**
- Descent without barriers = FREE for player
- Pure vertical drops are NOT challenges
- HORIZONTAL barriers and GATES create engagement

---

## 👹 Enemy Roster

### Tier 1: Basic (Teach Fundamentals)

| Enemy | Scene | Behavior | Player Demands | Notes |
|-------|-------|----------|----------------|-------|
| **Crab** | `enemy/crab/crab.tscn` | Patrol left/right, basic melee contact | Timing, approach angle | No special abilities |
| **Turtle** | `enemy/turtle/turtle.tscn` | Patrol, **hides in shell when hurt** (3s invuln) | Patience, wait for opening | Shell = complete immunity |
| **Starfish** | `enemy/starfish/starfish.tscn` | Static obstacle, no movement | Obstacle awareness | Pure positioning hazard |
| **Friendly Tribe** | `enemy/tribe/friendly_tribe.tscn` | Patrol, **flees when player approaches** | N/A (non-combat) | Atmospheric, foreshadowing |

### Tier 2: Area Control (Teach Positioning)

| Enemy | Scene | Behavior | Player Demands | Notes |
|-------|-------|----------|----------------|-------|
| **Mushroom** | `enemy/mushroom/mushroom.tscn` | Sleeps → wakes → **kamikaze chases** → explodes → **toxic gas BOTH directions** | Kill from range OR lead to safe spot | 8s hunt timeout, gas lingers |
| **Seahorse** | `enemy/barrel/barrel.tscn` | Stationary, **3-shot burst**, fires horizontally | Use cover, close distance during reload | Fixed position = predictable |

### Tier 3: Ranged Threats (Teach Dodging/Cover)

| Enemy | Scene | Behavior | Player Demands | Notes |
|-------|-------|----------|----------------|-------|
| **Aggressive Tribe** | `enemy/aggressive_tribe/aggressive_tribe.tscn` | Patrol, **throws coconuts with windup** | Dodge timing, punish during windup | Distance-scaled throw force |

### Tier 4: Skill Gates (Test Mastery)

| Enemy | Scene | Behavior | Player Demands | Notes |
|-------|-------|----------|----------------|-------|
| **Shield Tribe** | `enemy/shield_tribe/shield_tribe.tscn` | **Blocks front attacks**, 0.35s turn delay, spear thrust | Get behind, exploit turn delay | Only vulnerable from back! |

### Bosses

| Enemy | Scene | Behavior | Player Demands |
|-------|-------|----------|----------------|
| **King Crab** | `enemy/king_crab/king_crab.tscn` | Mini-boss, bubble attacks, claw swipes | Pattern recognition, dodging |
| **Warlord Turtle** | `enemy/boss/warlordturtle/warlord_turtle.tscn` | Multi-phase boss, **raises water level**, coconut rain, dive attacks, spawns whirlpools | Everything learned |

---

## 🔴 Elite Variants

All elites have: **Red glowing eyes**, **hue-shifted color**, **aggressive pursuit AI**

| Elite | Base | Core Mechanic | Threat Level |
|-------|------|---------------|--------------|
| **Hunter Crab** | Crab | Jump attack pursuit | Medium |
| **Bombardier** | Aggressive Tribe | All-slowing coconuts | High |
| **Spiny Turtle** | Turtle | 8-spike explosion when hiding | High |
| **Sniper Seahorse** | Seahorse | 5-shot diagonal tracking burst | Very High |
| **Ricochet Starfish** | Starfish | Pinball dash attacks, bounces off walls | Very High |
| **Spawner Mushroom** | Mushroom | Spawns mini-mushroom "missiles" | Very High |

---

## ⚠️ Hazards

### Static Hazards

| Hazard | Scene | Mechanic | Use For |
|--------|-------|----------|---------|
| **Static Spike** | `objects/spike/spike_static/spike.tscn` | Instant damage | Pit punishment, wall decoration |
| **Wall Spike (Left)** | `objects/spike/left_spike/left_spike.tscn` | Damage from left side | Block wall-cling cheese |
| **Wall Spike (Right)** | `objects/spike/right_spike/right_spike.tscn` | Damage from right side | Block wall-cling cheese |
| **Ceiling Spike** | `objects/spike/spike_ceiling/spike_ceiling.tscn` | Damage from below | Ceiling hazards |
| **Fake Spike** | `objects/spike/fake_spike/fake_spike.tscn` | Looks deadly, harmless | Mind games, secret paths |
| **Death Zone** | `environment/death_zone/death_zone.tscn` | **Instant kill** | Ultimate stakes, bottomless pits |

### Dynamic Hazards

| Hazard | Scene | Mechanic | Use For |
|--------|-------|----------|---------|
| **Retractable Spike** | `objects/spike/spike_retractable/spike_retractable.tscn` | Cycles up/down on timer | Rhythm platforming |
| **Flame** | `objects/flame/flame_hazard.tscn` | Cyclic damage area, optional light | Timing corridors |
| **Stalactite** | `environment/cave/stalactite.tscn` | **Falls when player near** (0.3s shake warning) | Ceiling awareness, keeps player moving |
| **Whirlpool** | `objects/whirlpool/whirlpool.tscn` | Pulls to center, damages, **depresses water surface** | Water terror, escape challenge |

### Environmental Forces

| Hazard | Scene | Mechanic | Use For |
|--------|-------|----------|---------|
| **Wind Area** | `objects/wind/wind_area.tscn` | Applies force vector, visible streaks | Precision disruption, push toward hazards |
| **Water** | `objects/water/water.tscn` | Swim mechanics, slower movement, oxygen depletion | Pace change, seahorse territory |

---

## 🔧 Interactive Objects

### Puzzle Elements

| Object | Scene | Mechanic | Exports |
|--------|-------|----------|---------|
| **Lever** | `objects/lever/lever.tscn` | Toggle ON/OFF, emits signals | `target_type`, `gate_node`, `water_node` |
| **Timer Lever** | `objects/timer_lever/timer_lever.tscn` | Temporary activation, auto-resets | `active_duration` |
| **Pressure Plate** | `objects/pressure_plate/pressure_plate.tscn` | Activates while stood on | `stay_activated`, `require_weight` |
| **Gate** | `objects/gate/gate.tscn` | Blocks path, `open_gate()`/`close_gate()` | `starts_open` |
| **Collapsable Wall** | `objects/collapsable_wall/collapsable_wall.tscn` | Breaks on attack | `hit_required` |

### Movement Aids

| Object | Scene | Mechanic |
|--------|-------|----------|
| **Spring** | `objects/spring/spring.tscn` | Launches player up (`launch_force`) |
| **Checkpoint** | `objects/checkpoint/checkpoint.tscn` | Respawn point |
| **Door** | `objects/door/door.tscn` | Scene transition |

---

## 🧱 Platforms

| Platform | Scene | Mechanic |
|----------|-------|----------|
| **One-Way** | `objects/platform/one_way_platform.tscn` | Fall through, can't jump through |
| **Moving (Horizontal)** | `objects/platform/horizontal_moving_platform.tscn` | Left-right movement |
| **Moving (Vertical)** | `objects/platform/vertical_moving_platform.tscn` | Up-down movement |
| **Circular** | `objects/platform/circular_moving_platform.tscn` | Circular path |
| **Breakable** | `objects/platform/breakable_platform.tscn` | Breaks when stood on |
| **Breakable (Slow)** | `objects/platform/breakable_platform_slow.tscn` | Breaks slower |
| **Floating Boat** | `objects/platform/floating_boat_platform.tscn` | Floats on water, bobs with waves |

---

## 💎 Collectibles

| Item | Scene | Purpose |
|------|-------|---------|
| **Coin** | `effect_Item/coin/coin.tscn` | Currency |
| **Health Potion** | `effect_Item/heal_potion/health_potion.tscn` | Restores health |
| **Key** | `effect_Item/key/key.tscn` | Unlocks chests/doors (`key_id` for specific locks) |
| **Blade** | `effect_Item/BladeItem/blade.tscn` | Unlocks throw ability |
| **Trap Coin** | `effect_Item/TrapCoin/trap_coin.tscn` | Looks like coin, applies negative effect |
| **Chest** | `effect_Item/chest/chest.tscn` | Contains rewards, may need key |

---

## 🏔️ Cave Environment (Level 3)

### Darkness System
Levels use **raw CanvasModulate** nodes directly for darkness:
```gdscript
# In level scene, add CanvasModulate node with:
color = Color(0.05, 0.04, 0.07, 1)  # Adjust RGB for mood
```

### Lighting & Atmosphere

| Element | Scene | Purpose |
|---------|-------|---------|
| **Glowing Crystal** | `environment/cave/glowing_crystal.tscn` | Light source with 6 color presets (Emerald/Sapphire/Ruby/Amethyst/Gold/Ice), pulse animation, sparkle particles. Texture slot for art override. |
| **Dripping Water** | `environment/cave/dripping_water.tscn` | Atmospheric ceiling drips with GPU particles, splash effects, audio. Configurable intensity. |
| **Camp Fire** | `objects/camp_fire/camp_fire.tscn` | Warm light source, animated flames. Tribe territory marker. |

### Cave Hazard

| Element | Scene | Purpose |
|---------|-------|---------|
| **Stalactite** | `environment/cave/stalactite.tscn` | Falling ceiling spike. 3 trigger modes: `PLAYER_PROXIMITY` (default), `RANDOM_TIMER`, `MANUAL` (for puzzles). Shake warning, respawn option. Texture slot for art. |

### Lava (environment/lava/)

| Element | Scene | Purpose |
|---------|-------|---------|
| **Lava Pool** | `environment/lava/lava_pool.tscn` | Dynamic fluid hazard with wave physics. `drain(duration)`/`fill(duration)` for puzzles. Emits light, ember particles, bubbles. Instant kill or DPS configurable. |

---

## 📊 Level 1 & 2 Usage Analysis

### Level 1 (Beach/Island) — Elements Used:
**Enemies**: Crab, Turtle, Starfish, Friendly Tribe, Mushroom, Aggressive Tribe, Seahorse, Shield Tribe  
**Platforms**: Breakable, Breakable Slow, Horizontal Moving, Vertical Moving, Circular Moving, One-Way  
**Objects**: Spring, Collapsable Wall  
**Collectibles**: Coin, Key, Health Potion, Trap Coin, Blade  

### Level 2 (Boss Arena) — Elements Used:
**Enemies**: Turtle, Starfish, Seahorse, Shield Tribe, Friendly Tribe, **Warlord Turtle (Boss)**  
**Environment**: Water, Floating Boat  
**Objects**: Spring, Collapsable Wall, Gate, Lever, Door, Checkpoint, Sign  
**Collectibles**: Coin, Blade  

### 🆕 READY FOR LEVEL 3 (Built, Awaiting Use):
- **Stalactite** — 3 trigger modes, gameplay-complete
- **Wind Area** — GPU shader streaks, force physics
- **Lava Pool** — Dynamic fluid, drain/fill puzzles
- **Death Zone** — Instant kill stakes
- **Retractable Spikes** — Rhythm platforming
- **Flame Hazard** — Cycling damage zones
- **Timer Lever** — Timed puzzle sequences
- **Pressure Plate** — Weight/hold puzzles, multi-target
- **Whirlpool** — Water terror, pull mechanics
- **Wall Spikes** — Anti-wallcling
- **Cave Lighting** — Glowing crystals, dripping water
- **All Elite enemies** — Escalation ready
- **Fake Spikes** — Mind games, secret paths

---

## 🎯 Level 3 Design Opportunities

### Fresh Elements to Introduce:
1. **Stalactites** — Ceiling awareness, keeps player moving
2. **Wind Areas** — Precision disruption, combo with hazards
3. **Retractable Spikes** — Rhythm platforming
4. **Timer Levers** — Timed puzzle sequences
5. **Pressure Plates** — Weight/hold puzzles
6. **Wall Spikes** — Punish wall-cling cheese
7. **Death Zones** — Ultimate stakes for key moments
8. **Whirlpools** — Water terror (player-faced, not just boss)
9. **Flame Hazards** — Cycling damage zones
10. **Elite enemies** — Escalated regular encounters

### Underutilized (Refresh):
1. **Mushroom** — Used in L1 but barely. Kamikaze mechanics are TERRIFYING in caves
2. **Seahorse** — Great for crossfire rooms
3. **Shield Tribe** — Perfect skill gate

### Avoid Boring:
- ❌ Pure vertical drops (no challenge)
- ❌ Wide open platforms (skip content)
- ❌ Only regular enemies (no escalation)
- ❌ Single path (no exploration)

---

## 🔗 Quick Connection Reference

### Lever → Gate
```gdscript
func _ready() -> void:
    super._ready()
    var lever = $Puzzle/MyLever
    var gate = $Puzzle/MyGate
    lever.lever_activated.connect(gate.open_gate)
    lever.lever_deactivated.connect(gate.close_gate)
```

### Key → Chest Matching
1. Key: `key_id = "blue"`
2. Chest: `required_key_id = "blue"`

### Water Level Control
```gdscript
water_node.raise_water(target_height, duration)  # negative = higher
water_node.lower_water(target_height, duration)
```

---

## 📐 Wall Primitive Reference

Base wall.tscn: 128×128 px (4×4 tiles at 32px)

| Scale | Size | Tiles | Use |
|-------|------|-------|-----|
| (1, 0.5) | 128×64 | 4×2 | Floor segment |
| (2, 0.5) | 256×64 | 8×2 | Wide floor |
| (0.5, 2) | 64×256 | 2×8 | Tall pillar |
| (0.25, 4) | 32×512 | 1×16 | Thin tall wall |

**Position Formula**: Wall at (X,Y) with scale (sX,sY) covers:
- X: from `X - 64×sX` to `X + 64×sX`
- Y: from `Y - 64×sY` to `Y + 64×sY`

---

*Last updated: December 9, 2025*
