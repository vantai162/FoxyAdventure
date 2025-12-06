# Level Elements Reference Guide

> **Complete Designer Guide**: See `DESIGNER_ELEMENT_GUIDE.md` for full element list
> **TileMap Light Occlusion**: See `TILEMAP_OCCLUSION_SETUP.md` for making walls block light

This document catalogs all available elements for level design in FoxyAdventure.
All elements are audited and ready for use.

---

## 🌑 DARKNESS & ILLUMINATION SYSTEM (Level 3)

Level 3 emphasizes light and dark. Understanding this system is critical.

### How Darkness Works

**CanvasModulate** - Applied at scene root, darkens EVERYTHING uniformly.

```gdscript
# In level scene - add CanvasModulate node under root
[node name="CanvasModulate" type="CanvasModulate"]
color = Color(0.7, 0.65, 0.8, 1)  # Twilight purple
```

| Level | Color | RGB Values | Feel |
|-------|-------|------------|------|
| 3-1 | Twilight | (0.15, 0.12, 0.18) | Dim entry, torch helpful |
| 3-2 | Dark | (0.10, 0.08, 0.12) | Deep, torch essential |
| 3-3 | Very Dark | (0.08, 0.06, 0.10) | Mushroom lights visible |
| 3-4 | Near Black | (0.06, 0.05, 0.08) | Maximum tension |
| 3-5 | Boss | (0.08, 0.06, 0.10) | Dramatic arena |

### Light Sources

**PointLight2D** - Pierces through CanvasModulate darkness.

Light sources available:
| Element | Type | Notes |
|---------|------|-------|
| `GlowingCrystal` | Pulsing ambient | Primary cave illumination |
| `FlameHazard` | Cycling flame | Dangerous light (has PointLight2D) |
| `CampFire` | Static | Tribe territory marker |

### Player Vision Radius

Consider adding a PointLight2D to player for personal visibility bubble:
```gdscript
# In player.gd or as child node
var torch = PointLight2D.new()
torch.energy = 0.6
torch.texture_scale = 2.0  # ~256px radius
torch.color = Color(1.0, 0.9, 0.7)  # Warm
add_child(torch)
```

---

## 📦 INTERACTIVE OBJECTS

### Lever (`objects/lever/lever.tscn`)
**UID:** `uid://ca1f6r665b1nr`

Toggle switch with multiple control modes.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `is_activated` | bool | false | Initial state |
| `target_type` | enum | SIGNAL_ONLY | What lever controls |
| `water_node` | NodePath | "" | Path to water (WATER_LEVEL mode) |
| `water_on_level` | float | -50.0 | Water height when ON |
| `water_off_level` | float | 50.0 | Water height when OFF |
| `water_transition_time` | float | 2.0 | Animation duration |
| `gate_node` | NodePath | "" | Path to gate (GATE mode) |
| `lava_node` | NodePath | "" | Path to lava (LAVA_LEVEL mode) |
| `lava_drain_time` | float | 2.0 | Drain animation duration |
| `lava_fill_time` | float | 3.0 | Fill animation duration |
| `flame_node` | NodePath | "" | Path to flame (FLAME mode) |

**Target Types:**
- `SIGNAL_ONLY` - Just emits signals (for custom scripts)
- `WATER_LEVEL` - Controls water height
- `GATE` - Controls gate open/close
- `LAVA_LEVEL` - Controls lava drain/fill
- `FLAME` - Controls flame ignite/extinguish

**Signals:**
- `lever_activated` - Player turned lever ON
- `lever_deactivated` - Player turned lever OFF

**See also:** `docs/PUZZLE_MECHANICS.md` for comprehensive puzzle design guide.

---

### Timer Lever (`objects/timer_lever/timer_lever.tscn`)
**UID:** `uid://yv24bc7sjvlq`

Timed toggle - stays ON for duration then auto-deactivates.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `duration` | float | 3.0 | Seconds before auto-deactivate |

**Signals:** Same as Lever

---

### Pressure Plate (`objects/pressure_plate/pressure_plate.tscn`)
**UID:** `uid://pressure_plate_001`

Activates while player/object stands on it.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `target_type` | enum | SIGNAL_ONLY | GATE, LAVA_LEVEL, FLAME, WATER_LEVEL |
| `stay_activated` | bool | false | If true, stays ON after first press |
| `require_weight` | bool | false | Only heavy/pushable objects trigger |
| `pressed_offset` | Vector2 | (0, 2) | Visual sink when pressed |

**Signals:**
- `plate_pressed` - When activated
- `plate_released` - When cleared (if not stay_activated)

**Design Patterns:**
- Hold-to-open: Player must stay on plate
- Weight puzzle: Push crate onto plate for permanent activation
- See `docs/PUZZLE_MECHANICS.md` for more patterns

---

### Gate (`objects/gate/gate.tscn`)
**UID:** `uid://ctr1b8p1h6p8y`

Animated barrier with vertical OR horizontal movement.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `direction` | enum | VERTICAL | Movement direction |
| `move_distance` | float | 160.0 | How far gate moves |
| `open_duration` | float | 1.0 | Animation time |

**Direction Options:**
- `VERTICAL` - Moves up when opened (default, legacy behavior)
- `HORIZONTAL_LEFT` - Slides left when opened
- `HORIZONTAL_RIGHT` - Slides right when opened

**Methods:**
- `open_gate()` - Opens gate
- `close_gate()` - Closes gate
- `toggle_gate()` - Switches state

---

### Spring (`objects/spring/spring.tscn`)
**UID:** `uid://cc07u3qfgccmq`

Bounces player/enemies upward when touched.

**Requirements:** Body must have `spring()` method.

---

### Collapsable Wall (`objects/collapsable_wall/collapsable_wall.tscn`)
**UID:** `uid://b336fup0h7gp5`

Destructible wall that breaks when attacked. Good for secrets.

---

### Checkpoint (`objects/checkpoint/checkpoint.tscn`)
**UID:** `uid://bmic0j4cnluey`

Saves player respawn position.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `checkpoint_id` | String | "" | Unique ID (auto-generated if empty) |

---

## ⚠️ HAZARDS

### Static Spike (`objects/spike/spike_static/spike.tscn`)
**UID:** `uid://cn3lm5txngxlq`

Always-dangerous floor spike. ~32×24px.

---

### Retractable Spike (`objects/spike/spike_retractable/spike_retractable.tscn`)
**UID:** `uid://b0h8a022mpy26`

Retractable spike hazard with **multiple trigger modes**.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `trigger_mode` | enum | INTERVAL | How spike activates |
| `detection_radius` | float | 32.0 | Detection range (PRESSURE_PLATE) |
| `up_pos` | Vector2 | (0, 0) | Extended position |
| `down_pos` | Vector2 | (0, 20) | Retracted position |
| `up_time` | float | 0.3 | Extension time |
| `down_time` | float | 0.3 | Retraction time |
| `hold_time` | float | 1.0 | Hold time (INTERVAL mode) |
| `pressure_delay` | float | 0.15 | Delay before extend (PRESSURE_PLATE) |
| `start_extended` | bool | true | Initial state |
| `start_delay` | float | 0.0 | Delay before cycle (staggering) |

**Trigger Modes:**
- `INTERVAL` - Cycles forever on timer (rhythm platforming)
- `PRESSURE_PLATE` - Extends when player steps near
- `MANUAL` - Only via `trigger_extend()`/`trigger_retract()` calls

**Staggering Example:**
```gdscript
# In level scene - place 3 spikes with delays
# Spike1: start_delay = 0.0
# Spike2: start_delay = 0.33
# Spike3: start_delay = 0.66
```

---

### Left Wall Spike (`objects/spike/left_spike/left_spike.tscn`)
**UID:** `uid://7j0fw4uvbg54`

Wall spike pointing LEFT. Prevents wall-cling cheese.

---

### Right Wall Spike (`objects/spike/right_spike/right_spike.tscn`)
**UID:** `uid://b6uwup34404a8`

Wall spike pointing RIGHT.

---

### FlameHazard (`objects/flame/flame_hazard.tscn`)
**UID:** `uid://d3h5flame_hazard`

Cycling flame jet hazard with **light emission**. The "flamethrower" style spray.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `cycle_enabled` | bool | true | If false, stays ON permanently |
| `on_duration` | float | 2.0 | Active time |
| `off_duration` | float | 1.5 | Off time |
| `emit_sparks` | bool | true | Spawn spark particles |
| `spark_count` | int | 8 | Max sparks |
| `damage` | int | 1 | Damage per hit |

**Scene Setup:** Includes `FlameLight` (PointLight2D) - configure color, energy, texture_scale in editor.

**Methods:**
- `ignite()` - Force flame ON (puzzles)
- `extinguish()` - Force flame OFF

---

### Wind Area (`objects/wind/WindArea.tscn`)
**UID:** `uid://coqrny0yf5swy`

Applies constant force to player.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `wind_force` | Vector2 | (-150, 0) | Force applied each frame |

---

### Whirlpool (`objects/whirlpool/whirlpool.tscn`)
**UID:** `uid://c5m8vno0qh3xy`

Water vortex that pulls player toward center, deals damage.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `strength` | float | 2000.0 | Pull force |
| `damage_dps` | float | 10.0 | Damage per second at center |
| `lifetime` | float | 8.0 | Duration (0 = infinite) |
| `auto_despawn` | bool | true | Remove when expired |

---

### Stalactite (`environment/cave/stalactite.tscn`)
**UID:** `uid://stalactite_cave`

Ceiling spike with **multiple trigger modes**.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `trigger_mode` | enum | PLAYER_PROXIMITY | How it activates |
| `detection_radius` | float | 80.0 | Trigger distance |
| `detection_below_only` | bool | true | Only trigger from below |
| `random_min_time` | float | 3.0 | Min random interval |
| `random_max_time` | float | 8.0 | Max random interval |
| `fall_delay` | float | 0.3 | Shake warning time |
| `fall_speed` | float | 500.0 | Initial fall speed |
| `damage` | int | 1 | Damage dealt |
| `destroy_on_impact` | bool | true | Break on ground |
| `respawn_time` | float | 5.0 | Respawn delay (0 = none) |

**Trigger Modes:**
- `PLAYER_PROXIMITY` - Falls when player gets close (default)
- `RANDOM_TIMER` - Falls at random intervals (ambient danger)
- `MANUAL` - Only via `trigger_fall()` call (puzzles)

---

### Death Zone (`environment/death_zone/death_zone.tscn`)
**UID:** `uid://ckaw6wc7acih8`

Instant kill when touched. Uses WorldBoundaryShape2D.

---

## 🌊 ENVIRONMENT

### Water (`objects/water/water.tscn`)
**UID:** `uid://giogr7michck`

Physics-based water with wave simulation. Full swim mechanics.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `water_size` | Vector2 | (8, 16) | Width × Height |
| `surface_pos_y` | float | 0.5 | Surface Y offset from origin |
| `segment_count` | int | 64 | Wave detail (2-512) |

**Methods:**
- `raise_water(target: float, duration: float)` - Animate water UP (negative target)
- `lower_water(target: float, duration: float)` - Animate water DOWN (positive target)
- `splash(pos: Vector2, velocity: float)` - Create ripple effect
- `set_water_level_instant(target: float)` - Immediate level set

**Lever Integration:**
Set lever's `target_type = WATER_LEVEL` and assign `water_node` path.

---

### One-Way Platform (`objects/platform/one_way_platform.tscn`)
**UID:** `uid://mikmney07ycb`

Player can jump through from below, stands on top.

---

## 🔮 CAVE ATMOSPHERE (Level 3)

### Glowing Crystal (`environment/cave/glowing_crystal.tscn`) ⭐ NEW
**UID:** `uid://crystal_light_source`

Primary light source for dark caves. Pulsing magical glow.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `base_energy` | float | 0.8 | Light brightness |
| `pulse_amount` | float | 0.3 | Brightness variation |
| `pulse_speed` | float | 1.5 | Pulse frequency |
| `light_color` | Color | cyan-green | Glow color |
| `light_radius` | float | 100.0 | Light reach |
| `crystal_color` | Color | light cyan | Crystal tint |
| `crystal_scale` | float | 1.0 | Size multiplier |
| `crystal_type` | enum | Medium | Small/Medium/Large/Cluster |
| `react_to_player` | bool | false | Brighten when near |
| `reaction_radius` | float | 60.0 | Detection distance |

**Crystal Types:**
- `Small` - Subtle accent lighting
- `Medium` - Standard illumination (default)
- `Large` - Major light source
- `Cluster` - Multiple crystals, fills area

**Methods:**
- `set_lit(bool)` - Turn on/off (puzzles)
- `set_glow_color(Color)` - Change color dynamically

---

### Glowing Mushroom (`environment/cave/glowing_mushroom.tscn`) - LEGACY
**UID:** `uid://glow_mushroom_cave`

**Use GlowingCrystal instead for new levels.**

---

### Camp Fire (`objects/camp_fire/camp_fire.tscn`)
**UID:** `uid://chfe3xrvw4004`

Animated decoration (40-frame loop). Tribe territory marker.
Does NOT emit PointLight2D by default.

---

## 👹 ENEMIES

### Crab (`enemy/crab/crab.tscn`)
**UID:** `uid://ufmc2gkfnv58`

Basic patrol enemy. Teaches timing and approach.

---

### Turtle (`enemy/turtle/turtle.tscn`)
**UID:** `uid://cgo8avpkxb1we` (or `uid://c1bijw8i8erx5`)

Patrol enemy that hides in shell when hit. Requires patience.

---

### Mushroom (`enemy/mushroom/mushroom.tscn`)
**UID:** `uid://cskp38w8uydma` (or `uid://bmgv5cgan4yt`)

Sleeps until player approaches, wakes, runs, then EXPLODES.
Releases toxic gas in both directions.

**States:** Sleep → Surprise → Run → Explode

---

### Starfish (`enemy/starfish/starfish.tscn`)
Basic stationary or slow-moving obstacle.

---

### Tribe (`enemy/tribe/friendly_tribe.tscn`)
**UID:** `uid://cevlp0wy5lsni`

Patrol enemy that FLEES when spotted. Tension builder.

---

### Aggressive Tribe (`enemy/aggressive_tribe/aggressive_tribe.tscn`)
**UID:** `uid://b1a2s3d4f5g6h`

Ranged enemy - throws coconuts with windup animation.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `throw_force` | float | 350.0 | Horizontal speed |
| `throw_arc` | float | 400.0 | Vertical component |
| `windup_time` | float | 0.4 | Warning before throw |

---

### Seahorse (`enemy/seahorse/seahorse.tscn`)
**UID:** `uid://bdkss15p4gbma`

Stationary ranged enemy - 3-shot burst pattern.

---

### Shield Tribe (`enemy/shield_tribe/shield_tribe.tscn`)
**UID:** `uid://dav8b7a6d5e4f`

Blocks frontal attacks. Has 0.35s turn delay.
Must attack from behind or exploit turn time.

| Export | Type | Default | Description |
|--------|------|---------|-------------|
| `spear_thrust_distance` | float | 72.0 | Attack range |
| `spear_thrust_out_time` | float | 0.6 | Attack duration |

---

### Warlord Turtle (Boss) (`enemy/boss/warlordturtle.tscn`)
**UID:** `uid://bdlk3sxo5ekwn`

Multi-phase boss with bombs, rockets, water raising, whirlpools.

---

## 📐 BUILDING BLOCKS

### Wall (`scenes/wall.tscn`)
**UID:** `uid://bn3w2ymt5pkh7`

128×128px base at CENTER.
Scale (sX, sY) → covers X ± 64×sX, Y ± 64×sY

| Scale | Pixel Size | Tiles | Use |
|-------|------------|-------|-----|
| (1, 0.5) | 128×64 | 4×2 | Floor segment |
| (0.5, 2) | 64×256 | 2×8 | Tall pillar |
| (3, 0.5) | 384×64 | 12×2 | Wide floor |

---

## ✅ AUDIT STATUS

All elements verified:
- ✅ Sprites present or procedural fallback
- ✅ Collision shapes configured
- ✅ Export defaults sensible
- ✅ Signals connected
- ✅ Editor-friendly

**New in this audit:**
- ✅ GlowingCrystal (replaces GlowingMushroom)
- ✅ Stalactite trigger modes (proximity/random/manual)
- ✅ Gate horizontal movement option
- ✅ Lever water control integration
- ✅ Darkness/illumination documentation

---

*Last updated: Session 2*
