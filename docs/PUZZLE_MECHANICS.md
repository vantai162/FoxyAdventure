# Puzzle Mechanics Reference

Complete guide to interactive puzzle elements and how to connect them.

---

## Quick Reference: What Connects To What

| Trigger | Gate | Water | Lava | Flame | Custom |
|---------|:----:|:-----:|:----:|:-----:|:------:|
| **Lever** | ✅ | ✅ | ✅ | ✅ | ✅ signal |
| **Timer Lever** | ✅ | ✅ | ✅ | ✅ | ✅ signal |
| **Pressure Plate** | ✅ | ✅ | ✅ | ✅ | ✅ signal |
| **Script Signal** | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Triggers

### Lever (`objects/lever/lever.tscn`)
**UID:** `uid://ca1f6r665b1nr`

Toggle switch - stays in ON or OFF state until player interacts again.

| Export | Type | Description |
|--------|------|-------------|
| `target_type` | enum | SIGNAL_ONLY, WATER_LEVEL, GATE, LAVA_LEVEL, FLAME |
| `water_node` | NodePath | Target water for WATER_LEVEL |
| `water_on_level` | float | Water surface Y when ON (negative = higher) |
| `water_off_level` | float | Water surface Y when OFF |
| `gate_node` | NodePath | Target gate for GATE |
| `lava_node` | NodePath | Target lava for LAVA_LEVEL |
| `lava_drain_time` | float | Drain animation duration |
| `lava_fill_time` | float | Fill animation duration |
| `flame_node` | NodePath | Target flame for FLAME |

**Signals:**
- `lever_activated` - Emitted when switched ON
- `lever_deactivated` - Emitted when switched OFF

**Usage:**
```gdscript
# In stage script - manual signal connection
func _ready() -> void:
    super._ready()
    var lever = $Puzzle/MyLever
    var gate = $Puzzle/MyGate
    lever.lever_activated.connect(gate.open_gate)
    lever.lever_deactivated.connect(gate.close_gate)
```

Or use the **built-in target_type** in editor - just set the node paths!

---

### Timer Lever (`objects/timer_lever/timer_lever.tscn`)
**UID:** `uid://dtimer_lever001`

Temporary activation - returns to OFF after duration.

| Export | Type | Description |
|--------|------|-------------|
| `active_duration` | float | How long it stays ON |
| `cooldown_duration` | float | Time before can activate again |

**Signals:**
- `lever_activated` - When pressed
- `lever_deactivated` - When timer expires

**Best For:** Timed gate puzzles, temporary safe passages

---

### Pressure Plate (`objects/pressure_plate/pressure_plate.tscn`)
**UID:** `uid://pressure_plate_001`

Activates while player/object stands on it.

| Export | Type | Description |
|--------|------|-------------|
| `target_type` | enum | SIGNAL_ONLY, GATE, LAVA_LEVEL, FLAME, WATER_LEVEL |
| `stay_activated` | bool | If true, stays ON forever after first press |
| `require_weight` | bool | Only heavy/pushable objects trigger (not player) |
| `pressed_offset` | Vector2 | Visual sink when pressed |

**Signals:**
- `plate_pressed` - When something steps on
- `plate_released` - When cleared (if not stay_activated)

**Design Patterns:**
- **Hold-to-open door**: Player must stand on plate to keep gate open
- **Weight puzzle**: Push crate onto plate to permanently open passage
- **Safety zone**: Stand on plate to drain lava temporarily

---

## Targets

### Gate (`objects/gate/gate.tscn`)
**UID:** `uid://ctr1b8p1h6p8y`

Physical barrier that blocks player movement.

**Methods:**
- `open_gate()` - Raises gate (player can pass)
- `close_gate()` - Lowers gate (blocks passage)

| Export | Type | Description |
|--------|------|-------------|
| `starts_open` | bool | Initial state |
| `open_speed` | float | Animation speed |

---

### Water (`objects/water/water.tscn`)
**UID:** `uid://giogr7michck`

Dynamic fluid with wave physics.

**Methods:**
- `raise_water(target_y, duration)` - Raise water level
- `lower_water(target_y, duration)` - Lower water level
- `set_water_level_instant(target_y)` - Instant change

| Parameter | Type | Description |
|-----------|------|-------------|
| `target_y` | float | New surface_pos_y (negative = higher) |
| `duration` | float | Transition time in seconds |

**Design Patterns:**
- **Flood escape**: Water rises, player must climb before drowning
- **Drain to reveal**: Lower water to expose underwater secrets
- **Boss arena flood**: Scripted water level changes during fight

---

### Lava Pool (`environment/lava/lava_pool.tscn`)
**UID:** `uid://lava_pool_001`

Deadly fluid that kills on contact.

**Methods:**
- `drain(duration)` - Lowers lava, disables damage
- `fill(duration)` - Raises lava back, re-enables damage
- `is_drained()` - Check if safe to cross
- `is_filled()` - Check if at dangerous level

**Signals:**
- `lava_drained` - When drain animation completes
- `lava_filled` - When fill animation completes

| Export | Type | Description |
|--------|------|-------------|
| `drain_target_y` | float | Where lava drains to |
| `fill_target_y` | float | Normal dangerous level |
| `default_drain_duration` | float | Default drain time |
| `default_fill_duration` | float | Default fill time (slower = tension) |

**Design Patterns:**
- **Timed crossing**: Lever drains lava, player has limited time to cross
- **Pressure hold**: Stand on plate to keep lava drained
- **Boss phase**: Drain lava to expose weak point

---

### Flame Hazard (`objects/flame/flame_hazard.tscn`)
**UID:** `uid://d3h5flame_hazard`

Cycling flamethrower jet.

**Methods:**
- `ignite()` - Force flame ON
- `extinguish()` - Force flame OFF

| Export | Type | Description |
|--------|------|-------------|
| `cycle_enabled` | bool | If false, stays permanently ON |
| `on_duration` | float | Active time per cycle |
| `off_duration` | float | Off time per cycle |

**Design Patterns:**
- **Lever shutoff**: Pull lever to permanently disable flame
- **Timed corridor**: Memorize flame patterns to pass
- **Pressure safety**: Stand on plate to keep flames off

---

## Puzzle Design Patterns

### 1. Simple Gate Puzzle
```
Player sees: Locked gate with lever nearby
Solution: Pull lever to open gate
Teaching: Lever-gate connection

Setup in editor:
- Lever: target_type = GATE, gate_node = "../Gate"
```

### 2. Timed Gate Puzzle
```
Player sees: Gate with timer lever, chest behind gate
Challenge: Pull lever, run to chest before gate closes
Teaching: Time pressure, commitment

Setup:
- TimerLever with active_duration = 3.0
- Connect lever_activated → gate.open_gate
- Connect lever_deactivated → gate.close_gate
```

### 3. Lava Crossing
```
Player sees: Lava pit with lever on far side... wait, that's impossible
Actually: Lever on near side, drains lava, player crosses
Tension: Lava slowly refills after crossing

Setup in editor:
- Lever: target_type = LAVA_LEVEL, lava_node = "../LavaPool"
- LavaPool: default_fill_time = 5.0 (slow refill for tension)
```

### 4. Weight Puzzle
```
Player sees: Pressure plate, locked door, pushable crate
Solution: Push crate onto plate to permanently open door
Teaching: Environmental interaction

Setup:
- PressurePlate: stay_activated = true, require_weight = true
- PressurePlate: target_type = GATE, gate_node = "../Door"
```

### 5. Flame Gauntlet
```
Player sees: Corridor with alternating flames
Challenge: Time movement through safe gaps
Variation: Lever disables ALL flames permanently (reward for exploration)

Setup:
- Multiple FlameHazard with staggered on_duration/off_duration
- Optional: Hidden lever with target_type = FLAME
```

### 6. Multi-Lever Puzzle
```
Player sees: Gate that won't open, two levers in different rooms
Solution: Both levers must be ON simultaneously
Teaching: Multi-step puzzles

Setup (in stage script):
var lever_1_on = false
var lever_2_on = false

func _ready():
    $Lever1.lever_activated.connect(func(): lever_1_on = true; _check_gate())
    $Lever1.lever_deactivated.connect(func(): lever_1_on = false; _check_gate())
    # Same for Lever2

func _check_gate():
    if lever_1_on and lever_2_on:
        $Gate.open_gate()
    else:
        $Gate.close_gate()
```

### 7. Rising Water Escape
```
Player sees: Arena, boss defeated, water starts rising
Challenge: Climb to exit before drowning
Tension: Water is faster than comfortable

Setup (in stage script):
func _on_boss_defeated():
    $Water.raise_water(-500.0, 30.0)  # Rise over 30 seconds
    $ExitGate.open_gate()  # Reveal escape route
```

### 8. Lava + Flame Combo
```
Player sees: Flame blocking path, lava pit beyond
Solution: Extinguish flame with lever, cross platform over lava
Twist: Lava is rising! Must be quick

Setup:
- Lever: target_type = FLAME
- LavaPool with slowly increasing drain_target_y over time
```

---

## Signal Connection Cheat Sheet

### In Stage Script (_ready)
```gdscript
# Basic lever → gate
$Lever.lever_activated.connect($Gate.open_gate)
$Lever.lever_deactivated.connect($Gate.close_gate)

# Lever → lava
$Lever.lever_activated.connect($Lava.drain)
$Lever.lever_deactivated.connect($Lava.fill)

# Lever → flame
$Lever.lever_activated.connect($Flame.extinguish)
$Lever.lever_deactivated.connect($Flame.ignite)

# Plate → gate (while standing)
$Plate.plate_pressed.connect($Gate.open_gate)
$Plate.plate_released.connect($Gate.close_gate)

# Lava drained → open escape
$Lava.lava_drained.connect($EscapeGate.open_gate)
```

### Using Editor NodePath (No Code!)
Just set these in the Inspector:
- `target_type` = GATE/WATER_LEVEL/LAVA_LEVEL/FLAME
- `gate_node` / `water_node` / `lava_node` / `flame_node` = path to target

The lever/plate handles the connection automatically!

---

## Adding New Puzzle Elements

To add a new controllable target:

1. **Add methods** to target script:
   - `activate()` or specific like `open()`, `drain()`
   - `deactivate()` or `close()`, `fill()`

2. **Add signals** (optional but useful):
   - `activated`, `deactivated`
   - Or specific like `drained`, `filled`

3. **Update Lever enum** in `lever.gd`:
   ```gdscript
   enum LeverTarget { ..., MY_NEW_TYPE }
   ```

4. **Add exports** for node path and settings

5. **Handle in _on_lever_on/off**:
   ```gdscript
   LeverTarget.MY_NEW_TYPE:
       if _my_ref and _my_ref.has_method("activate"):
           _my_ref.activate()
   ```

6. **Update PressurePlate** similarly if needed

---

## Testing Checklist

Before shipping a puzzle:
- [ ] Can player see the connection? (Lever near gate, plate visible)
- [ ] Is timing fair? (Enough time to complete action)
- [ ] Is there feedback? (Gate animates, lava drains visibly)
- [ ] Can player retry? (Not softlocked if they fail)
- [ ] Does it teach something? (New mechanic or combination)
