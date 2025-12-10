# Designer Workflows
**How To Connect Things — Quick Reference for Level Building**

> **For the complete element shelf, see `LEVEL_DESIGN_ARSENAL.md`**

---

## 🔗 Connection Patterns

### Lever → Gate (Toggle)
1. Place `Gate`
2. Place `Lever` → Set `target_type = GATE`
3. Set `gate_node` to point to the Gate (use NodePath picker)
4. Done! No code needed.

**OR via code:**
```gdscript
func _ready() -> void:
    super._ready()
    var lever = $Puzzle/MyLever
    var gate = $Puzzle/MyGate
    lever.lever_activated.connect(gate.open_gate)
    lever.lever_deactivated.connect(gate.close_gate)
```

### Timer Lever → Gate (Timed)
1. Place `Gate`
2. Place `TimerLever` → Set `active_duration`
3. Connect in code:
```gdscript
timer_lever.lever_activated.connect(gate.open_gate)
timer_lever.lever_deactivated.connect(gate.close_gate)
```
Gate opens on press, closes after duration.

### Pressure Plate → Gate (Hold)
1. Place `Gate`
2. Place `PressurePlate` → Set `target_type = GATE`
3. Set `gate_node` to point to Gate
4. Gate stays open WHILE player stands on plate.

**For permanent unlock**: Set `stay_activated = true`

### Lever → Water Level
1. Place `Water`
2. Place `Lever` → Set `target_type = WATER_LEVEL`
3. Set `water_node`, `water_on_level`, `water_off_level`
4. Lever raises/lowers water!

### Key → Chest Matching
1. Place `Key` → Set `key_id = "blue"`
2. Place `Chest` → Set `required_key_id = "blue"`
3. Only that key opens that chest.

**Generic key (any chest)**: Leave `key_id` empty.

---

## 🚪 Section Transitions

For seamless room-to-room movement:

1. In Room A: Place `SectionTransition` at right edge
   - Name: "ToRoomB"
   - `direction = RIGHT`
   - `target_transition_name = "FromRoomA"`

2. In Room B: Place `SectionTransition` at left edge
   - Name: "FromRoomA"
   - `direction = LEFT`

3. Walking right in Room A → Fades → Appears at left of Room B

---

## 🎨 Darkness Setup (Cave Levels)

### Basic Cave Darkness
1. Add `CanvasModulate` to level root
2. Set color to darkness level:
   - Light cave: `(0.15, 0.12, 0.18)`
   - Dark cave: `(0.08, 0.06, 0.10)`
   - Near-black: `(0.06, 0.05, 0.08)`

3. Place `GlowingCrystal` for light sources
4. Player torch automatically provides local visibility

### Light Source Radius Guide
| Source | Radius | Shadows | Use |
|--------|--------|---------|-----|
| Glowing Crystal | 100px | ✅ | Main cave illumination |
| Player Torch | Variable | ✅ | Player's local light |
| Flame Hazard | 60px | ✅ | Dangerous light source |
| Camp Fire | 80px | ❌ | Decorative, warm glow |

---

## 📐 Design Patterns

### Locked Door Pattern
```
                    ┌─────────────┐
                    │  Gold Chest │ ← Reward
                    │ (needs key) │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │     Key     │ ← Hidden/guarded
                    └──────┬──────┘
                           │
              ┌────────────┴────────────┐
              │    Challenge Area       │ ← Enemies/puzzles
              │  (guards the key)       │
              └─────────────────────────┘
```

### Commitment Drop Pattern
```
    Entry Point
         │
         ▼ (drop)
    ┌─────────┐
    │ One-Way │ ← Can't climb back!
    │   Wall  │
    └────┬────┘
         │
         ▼
    Challenge → Lever
         │
         ▼
    Gate (now open) → Exit
```

### Timed Run Pattern
```
    Timer Lever ────► Gate opens (5 seconds)
         │
         ▼
    ┌─────────────────────┐
    │   Hazard Corridor   │ ← Must rush!
    │  (spikes, enemies)  │
    └──────────┬──────────┘
               │
               ▼
    Safe Zone ← (make it before gate closes)
```

### Multi-Key Hub Pattern
```
              Hub Area
             ╱    │    ╲
            ╱     │     ╲
       Wing A   Wing B   Wing C
       Key A    Key B    Key C
            ╲     │     ╱
             ╲    │    ╱
         Final Gate (needs ALL keys)
```

### Skill Gate Pattern
```
                    Path continues...
                          ▲
                          │
              ┌───────────┴───────────┐
              │     Shield Tribe      │ ← MUST defeat
              │   (blocks passage)    │
              └───────────────────────┘
                          ▲
                          │
              Narrow corridor (can't skip)
```

---

## ⚠️ Spike Trigger Modes

| Mode | Behavior | Use For |
|------|----------|---------|
| `INTERVAL` | Cycles on/off automatically | Rhythm platforming |
| `PRESSURE_PLATE` | Triggers when player steps nearby | Traps |
| `MANUAL` | Only from script/lever | Puzzles |

---

## ✅ Pre-Build Checklist

Before testing your level:

- [ ] Player spawn marker placed (`PlayerSpawn` Marker2D)
- [ ] Camera bounds set (StageBase `camera_left/right/top/bottom`)
- [ ] At least one checkpoint
- [ ] Exit zone or door configured
- [ ] Darkness setup (if cave level)
- [ ] All lever/gate connections tested
- [ ] Key/chest IDs match
- [ ] Enemy patrol paths don't walk off edges
- [ ] No skippable sections (check fall paths!)

---

## 🔧 Stage Script Template

```gdscript
extends StageBase

func _init() -> void:
    camera_left = 0.0
    camera_right = 1600.0   # Level width
    camera_top = 0.0
    camera_bottom = 2400.0  # Level height

func _ready() -> void:
    super._ready()
    
    # Connect puzzles
    var lever = get_node_or_null("Puzzle/MyLever")
    var gate = get_node_or_null("Puzzle/MyGate")
    if lever and gate:
        lever.lever_activated.connect(gate.open_gate)
        lever.lever_deactivated.connect(gate.close_gate)
```

---

*Last updated: December 9, 2025*
