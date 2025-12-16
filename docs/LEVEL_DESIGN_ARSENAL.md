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
| **Lever** | `objects/lever/lever.tscn` | Toggle ON/OFF or timed auto-reset | `mode` (TOGGLE/TIMED), `timer_duration`, `channel` |
| **Pressure Plate** | `objects/pressure_plate/pressure_plate.tscn` | Activates while stood on | `stay_activated`, `require_weight`, `channel` |
| **Gate** | `objects/gate/gate.tscn` | Blocks path, `open_gate()`/`close_gate()` | `listen_channel`, `starts_open` |
| **Collapsable Wall** | `objects/collapsable_wall/collapsable_wall.tscn` | Breaks on attack | `hit_required` |

### Movement Aids

| Object | Scene | Mechanic |
|--------|-------|----------|
| **Spring** | `objects/spring/spring.tscn` | Launches player up (`launch_force`) |
| **Checkpoint** | `objects/checkpoint/checkpoint.tscn` | Respawn point |
| **Door** | `objects/door/door.tscn` | Scene transition (fade to black) |

---

## 🚪 Scene Transitions

### SceneTransition (NEW! Seamless Cross-Level)

The new **SceneTransition** system provides modern, seamless level-to-level transitions with directional wipe effects. Player walks through an edge and the screen wipes in the direction of movement.

| Component | Scene | Purpose |
|-----------|-------|---------|
| **SceneTransition** | `objects/scene_transition/scene_transition.tscn` | Exit zone that loads next level |
| **TransitionEffects** | Autoload | Handles directional wipe animations |

### How to Set Up Level 3-1 → 3-2 Transition:

**In Level 3-1 (exit):**
1. Instance `SceneTransition` at the right edge where player exits
2. Set properties:
   | Property | Value |
   |----------|-------|
   | `exit_direction` | `RIGHT` (or `DOWN` if exiting bottom) |
   | `target_scene` | `res://test/levels/level_3/level_3_2.tscn` |
   | `target_spawn_name` | `"FromLevel3_1"` |
   | `spawn_offset` | `Vector2(48, 0)` |
3. Name it something descriptive like `"ToLevel3_2"`

**In Level 3-2 (entry):**
1. Instance `SceneTransition` at the left edge where player enters
2. Set properties:
   | Property | Value |
   |----------|-------|
   | `exit_direction` | `LEFT` (opposite of how they entered) |
   | `target_scene` | `res://test/levels/level_3/level_3_1.tscn` |
   | `target_spawn_name` | `"ToLevel3_2"` |
   | `spawn_offset` | `Vector2(-48, 0)` |
3. Name it `"FromLevel3_1"` (matches `target_spawn_name` from 3-1)

### SceneTransition Properties:

| Property | Type | Description |
|----------|------|-------------|
| `target_scene` | String (file path) | Path to the next level's .tscn file |
| `target_spawn_name` | String | Name of SceneTransition in target scene to spawn at |
| `exit_direction` | Direction | LEFT/RIGHT/UP/DOWN - direction player is walking |
| `spawn_offset` | Vector2 | Offset from target transition position |
| `wipe_duration` | float | How fast the wipe animation (default 0.18s - WHOOSH!) |
| `wipe_color` | Color | Color of the wipe (default BLACK) |
| `trigger_threshold` | float | Minimum velocity to trigger (default 10) |
| `preload_distance` | float | Proximity distance to start preloading (default 400px) |

### Smart Preloading:
- Scene is NOT loaded when level starts (keeps initial load fast)
- When player gets within `preload_distance` of the transition, background loading begins
- By the time player reaches the exit, scene is usually already loaded
- If not loaded yet, there's a brief pause (but rare)

### Visual Effect ("WHOOSH!"):
```
Player walks RIGHT at edge of 3-1:
  → Player keeps walking (NOT frozen!)
  → Fast black wipe sweeps from RIGHT (0.09s - half of wipe_duration)
  → Scene changes to 3-2
  → Fast black wipe sweeps out (0.18s)
  → Player appears at left edge of 3-2, continuing to walk
```

The key is SPEED (0.18s) and player momentum is preserved - they keep walking INTO the wipe, not freezing. This creates the "step step step WHOOSH" feeling.

### Comparison: Door vs SceneTransition

| Feature | Door | SceneTransition |
|---------|------|-----------------|
| Trigger | Walk into door | Walk through zone |
| Effect | Fade to black | Directional wipe |
| Feel | "Entering a room" | "Continuous world" |
| Use for | Going behind gates | Walking off level edges |

---

## 🧱 Platforms

| Platform | Scene | Mechanic |
|----------|-------|----------|
| **One-Way** | `objects/platform/one_way_platform.tscn` | Fall through, can't jump through |
| **Moving Platform** | `objects/platform/moving_platform.tscn` | **Unified designer-friendly platform** - works for horizontal, vertical, diagonal, or any direction. Drag the `EndPoint` marker in editor to set destination. Shows green trajectory line preview. |
| **Circular** | `objects/platform/circular_moving_platform.tscn` | Circular path |
| **Breakable** | `objects/platform/breakable_platform.tscn` | Breaks when stood on |
| **Breakable (Slow)** | `objects/platform/breakable_platform_slow.tscn` | Breaks slower |
| **Floating Boat** | `objects/platform/floating_boat_platform.tscn` | Floats on water, bobs with waves |

### Moving Platform Features (NEW!)
The new unified `MovingPlatform` replaces the old horizontal/vertical variants:
- **Visual Preview**: Green trajectory line shows exact path in editor
- **Any Direction**: Horizontal, vertical, diagonal - just drag the EndPoint
- **Movement Types**: `PING_PONG`, `ONE_WAY`, `LOOP`
- **Easing Options**: Linear, Ease In/Out
- **Channel Support**: Can be controlled via lever/pressure plate
- **Properties**: `speed`, `pause_at_endpoints`, `start_at_end`, `start_paused`

> ⚠️ **DEPRECATED**: `horizontal_moving_platform.tscn` and `vertical_moving_platform.tscn` are legacy. Use `moving_platform.tscn` for all new levels.

---

## 💎 Collectibles

| Item | Scene | Purpose |
|------|-------|---------|
| **Coin** | `effect_Item/coin/coin.tscn` | Currency |
| **Health Potion** | `effect_Item/heal_potion/health_potion.tscn` | Restores health |
| **Key** | `effect_Item/key/key.tscn` | Unlocks chests/doors (`key_id` for specific locks) |
| **Blade** | `effect_Item/BladeItem/blade.tscn` | +1 blade to inventory (first pickup unlocks throw ability) |
| **Blade Container** | `effect_Item/BladeContainer/blade_container.tscn` | +1 holster slot AND fills inventory (max 3 containers) |
| **Trap Coin** | `effect_Item/TrapCoin/trap_coin.tscn` | Looks like coin, applies negative effect |
| **Chest** | `effect_Item/chest/chest.tscn` | Contains rewards, may need key |

### Blade System Details
- **Natural capacity**: 3 blades
- **Max containers**: 3 (each adds +1 slot)
- **Absolute max**: 6 blades (3 natural + 3 containers)
- **Loyal blade**: Fox's first/blood-bound blade — always returns, thrown LAST
- **Scrap blades**: Expendable — only the most recent one auto-returns; orphans expire
- **Flame Blade**: Shop upgrade — causes burn damage over time, extinguishes in water

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
- **Lever (Timed mode)** — Timed puzzle sequences
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
4. **Levers (Timed mode)** — Timed puzzle sequences
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

## 🔗 Channel System (NEW - Designer-Friendly Connections)

The **Channel System** lets you connect triggers (levers, pressure plates) to receivers (gates, spikes, flames) **without writing any code**. Just type the same channel name on both objects!

### How It Works
1. **Trigger objects** (Lever, PressurePlate) have a `channel` export
2. **Receiver objects** (Gate, SpikeRetractable, Wind, Stalactite, etc.) have a `listen_channel` export
3. **Same channel name = connected!**

### Example: Lever Opens Gate
| Object | Property | Value |
|--------|----------|-------|
| Lever | `channel` | `gate_1` |
| Gate | `listen_channel` | `gate_1` |

That's it! When lever is pulled, gate opens. When lever is unpulled, gate closes.

### Advanced: Multiple Connections

**One lever → Two gates** (same channel on both gates):
| Object | Channel |
|--------|---------|
| Lever | `door_puzzle` |
| Gate A | `door_puzzle` |
| Gate B | `door_puzzle` |

**Two levers → One gate** (same channel on both levers):
| Object | Channel |
|--------|---------|
| Lever A | `big_door` |
| Lever B | `big_door` |
| Gate | `big_door` |

### Receiver Actions

Receivers can be configured to do different things on activate/deactivate:

**Gate** (`on_activate`, `on_deactivate`):
- `OPEN` — Open the gate
- `CLOSE` — Close the gate  
- `TOGGLE` — Switch state

**SpikeRetractable** (set `trigger_mode = CHANNEL`):
- `EXTEND` — Spike pops out (dangerous)
- `RETRACT` — Spike hides (safe)
- `TOGGLE` — Switch state

**WindArea** (`on_activate`, `on_deactivate`):
- `ENABLE` — Wind blows
- `DISABLE` — Wind stops
- `TOGGLE` — Switch state

**Stalactite** (set `trigger_mode = CHANNEL`):
- Activate = Falls immediately (one-shot)
- Deactivate = No effect (can't un-fall!)

### Channel-Enabled Objects

| Object | Role | Channel Property | Designer Controls |
|--------|------|------------------|-------------------|
| **Lever** | Trigger | `channel` (broadcasts) | `mode` (TOGGLE/TIMED), `timer_duration` |
| **PressurePlate** | Trigger | `channel` (broadcasts while pressed) | `stay_activated`, `require_weight` |
| **Gate** | Receiver | `listen_channel` | `on_activate`/`on_deactivate` (OPEN/CLOSE/TOGGLE), `direction`, `move_distance` |
| **SpikeRetractable** | Receiver | `listen_channel` (mode = CHANNEL) | `on_activate`/`on_deactivate` (EXTEND/RETRACT/TOGGLE) |
| **WindArea** | Receiver | `listen_channel` | `on_activate`/`on_deactivate` (ENABLE/DISABLE/TOGGLE), `start_enabled` |
| **Stalactite** | Receiver | `listen_channel` (mode = CHANNEL) | Falls on activate (one-shot trap) |
| **Water** | Receiver | `listen_channel` | `on_activate`/`on_deactivate` (RAISE/LOWER/STAY/OPPOSITE), `surface_level`, `raised_level`, `lowered_level`, `raise_duration`, `lower_duration` |
| **LavaPool** | Receiver | `listen_channel` | `on_activate`/`on_deactivate` (DRAIN/FILL/STAY/OPPOSITE), `surface_level`, `drained_level`, `filled_level`, `drain_duration`, `fill_duration` |
| **FlameHazard** | Receiver | `listen_channel` | `on_activate`/`on_deactivate` (IGNITE/EXTINGUISH/TOGGLE) |

### Water & Lava Level Configuration

Both **Water** and **LavaPool** use an intuitive **absolute level-based** API:

| Property | Description | Example |
|----------|-------------|---------|
| `surface_level` | Normal resting position (pixels from top of pool) | `20.0` |
| `raised_level` / `filled_level` | Where surface goes when RAISED/FILLED | `8.0` (higher up) |
| `lowered_level` / `drained_level` | Where surface goes when LOWERED/DRAINED | `80.0` (further down) |
| `on_activate` | What happens on channel activation | `RAISE`/`LOWER` or `DRAIN`/`FILL` |
| `on_deactivate` | What happens on channel deactivation | `RETURN_TO_SURFACE`/`STAY`/`OPPOSITE` |
| `start_empty` | Start with fluid at bottom (empty pool) | ✅ for rising traps |
| `start_full` | Start with fluid at top (full pool) | ✅ for drain puzzles |
| `show_level_guides` | Editor-only: draw visual guide lines | ✅ for debugging |

**Designer-friendly features:**
- All values are "pixels from TOP" — intuitive Y coordinate system
- `show_level_guides` draws colored lines in editor showing all three levels
- `start_empty`/`start_full` convenience toggles — no math needed!
- `on_deactivate = STAY` for one-way permanent puzzles
- `on_deactivate = OPPOSITE` for alternating behavior
- Editor warnings for illogical configurations (drained < surface, etc.)
- `return_to_normal()` function to reset surface to resting position

---

## 🗡️ Blade Triggering (NEW - Ranged Puzzle Potential!)

The **Blade Projectile** can now trigger interactive objects, enabling exciting ranged puzzles!

### What Blade Can Trigger

| Object | Trigger Condition | Effect |
|--------|-------------------|--------|
| **Lever (Toggle)** | Blade hits lever (flying or bouncing) | Lever toggles state |
| **Lever (Timed)** | Blade hits timed lever | Activates for `timer_duration` then resets |
| **PressurePlate** | Blade lands on plate (GROUNDED state) | Plate activates while blade rests there |

### Puzzle Design Ideas

**Remote Lever Puzzle**
> Player can't reach the lever, but can see it. Throw blade to hit it from a distance!

**Thrown Weight Puzzle**
> Pressure plate in unreachable area. Throw blade so it lands on the plate. Blade stays there, keeping the plate pressed until picked up.

**Timed Throw Challenge**
> Timed lever (`mode = TIMED`) in a high alcove. Player must throw blade, hit the lever, then quickly navigate before the timer expires.

**Blade Sacrifice Puzzle**
> Throw blade onto a pressure plate to open a gate. But now you don't have your blade! Navigate the next section without ranged attacks, then retrieve it.

### How It Works (Technical)
- Lever uses `collision_layer = 1024` (Layer 11: Interactable) and group `blade_interactable`
- Blade has `collision_layer = 128` (Layer 8: Projectiles), `collision_mask = 1035` (detects environment + player + enemy + interactable)
- PressurePlate has `collision_mask = 130` (detects Layer 2: player + Layer 8: Projectiles)
- Blade only triggers pressure plate when GROUNDED (not flying through)

---

### Legacy Support

The old NodePath-based system (`gate_node`, `water_node`, etc.) still works! Channel system is **additive** — if you set a channel AND a NodePath, both will work.

### Debugging

Set `InteractionChannel.debug_mode = true` in code to see channel activity:
```
[Channel] ACTIVATE 'gate_1' by MyLever
[Channel] DEACTIVATE 'gate_1' by MyLever
```

---

## 🔗 Legacy Connection Reference (Old System)

### Lever → Gate (NodePath method)
```gdscript
# On Lever, set in Inspector:
target_type = GATE
gate_node = "../MyGate"
```

### Code-based Connection (stage scripts)
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
