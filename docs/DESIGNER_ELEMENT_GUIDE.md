# Complete Element Reference for Level Design

## Quick Reference - What You Can Place

### Collectibles
| Element | Scene Path | Key Exports | Notes |
|---------|------------|-------------|-------|
| **Coin** | `effect_Item/coin/coin.tscn` | `coin_value`, `float_animation` | Floats, sparkles |
| **TrapCoin** | `effect_Item/TrapCoin/trap_coin.tscn` | `effect_name`, `duration` | Looks like coin, applies effect |
| **Key** | `effect_Item/key/key.tscn` | `key_id`, `key_color` | Match `key_id` with Chest's `required_key_id` |
| **Health Potion** | `effect_Item/heal_potion/health_potion.tscn` | - | Restores health |
| **Chest** | `effect_Item/chest/chest.tscn` | `required_key_id`, `coin_reward`, `spawn_items` | Needs matching key |
| **Gold Chest** | `effect_Item/chest/gold_chest.tscn` | Same as Chest | Fancier visuals |

### Hazards
| Element | Scene Path | Key Exports | Notes |
|---------|------------|-------------|-------|
| **Static Spike** | `objects/spike/spike_static/spike.tscn` | `damage` | Always active |
| **Retractable Spike** | `objects/spike/spike_retractable/spike_retractable.tscn` | `trigger_mode` (INTERVAL/PRESSURE_PLATE/MANUAL), `cycle_time`, `retract_duration` | Cycles or triggers |
| **Left Wall Spike** | `objects/spike/left_spike/left_spike.tscn` | `damage` | Hurts from left |
| **Right Wall Spike** | `objects/spike/right_spike/right_spike.tscn` | `damage` | Hurts from right |
| **Ceiling Spike** | `objects/spike/spike_ceiling/spike_ceiling.tscn` | `damage` | Hurts from above |
| **Fake Spike** | `objects/spike/fake_spike/fake_spike.tscn` | - | Looks like spike, no damage |
| **Flame Hazard** | `objects/flame/flame_hazard.tscn` | `cycle_enabled`, `emit_light`, `damage` | Fire with optional cycling |
| **Death Zone** | `environment/death_zone/death_zone.tscn` | - | Instant kill |
| **Whirlpool** | `objects/whirlpool/whirlpool.tscn` | `pull_strength`, `damage_per_second` | Pulls and damages |
| **Stalactite** | `environment/cave/stalactite.tscn` | `trigger_mode` (PLAYER_PROXIMITY/RANDOM_TIMER/MANUAL), `respawn_time` | Falling ceiling hazard |

### Platforms & Terrain
| Element | Scene Path | Key Exports | Notes |
|---------|------------|-------------|-------|
| **One-Way Platform** | `objects/platform/one_way_platform.tscn` | - | Jump through from below |
| **Moving Platform (H)** | `objects/platform/horizontal_moving_platform.tscn` | `move_distance`, `speed` | Moves left-right |
| **Moving Platform (V)** | `objects/platform/vertical_moving_platform.tscn` | `move_distance`, `speed` | Moves up-down |
| **Circular Platform** | `objects/platform/circular_moving_platform.tscn` | `radius`, `speed` | Moves in circle |
| **Breakable Platform** | `objects/platform/breakable_platform.tscn` | - | Breaks when stood on |
| **Breakable (Slow)** | `objects/platform/breakable_platform_slow.tscn` | - | Breaks slower |
| **Floating Boat** | `objects/platform/floating_boat_platform.tscn` | `enable_drift`, `bob_enabled`, `drift_speed` | Floats on water |

### Interactive Objects
| Element | Scene Path | Key Exports | Notes |
|---------|------------|-------------|-------|
| **Lever** | `objects/lever/lever.tscn` | `target_type` (SIGNAL_ONLY/WATER_LEVEL/GATE), `water_node`, `gate_node` | Toggles things |
| **Timer Lever** | `objects/timer_lever/timer_lever.tscn` | `active_duration` | Temporary activation |
| **Gate** | `objects/gate/gate.tscn` | `direction` (VERTICAL/HORIZONTAL), `starts_open` | Blocks path |
| **Collapsable Wall** | `objects/collapsable_wall/collapsable_wall.tscn` | `hit_required` | Breaks on attack |
| **Spring** | `objects/spring/spring.tscn` | `launch_force` | Bounces player up |
| **Checkpoint** | `objects/checkpoint/checkpoint.tscn` | `checkpoint_id` | Respawn point |
| **Door** | `objects/door/door.tscn` | `target_scene`, `target_door_name` | Scene transition |

### Environment
| Element | Scene Path | Key Exports | Notes |
|---------|------------|-------------|-------|
| **Water** | `environment/water/water.tscn` | `water_size`, `enable_waves` | Swimmable water |
| **Wind Area** | `objects/wind/wind_area.tscn` | `wind_direction`, `wind_strength`, `affects_enemies` | Pushes entities |
| **Camp Fire** | `objects/camp_fire/camp_fire.tscn` | - | Decorative fire |
| **Stove** | `objects/stove/stove.tscn` | - | Decorative |

### Cave Lighting
| Element | Scene Path | Key Exports | Notes |
|---------|------------|-------------|-------|
| **Glowing Crystal** | `environment/cave/glowing_crystal.tscn` | `base_energy`, `light_color`, `light_radius`, `cast_shadows` | Main cave light |
| **Glowing Mushroom** | `environment/cave/glowing_mushroom.tscn` | Similar to crystal | Alternative style |
| **Dripping Water** | `environment/cave/dripping_water.tscn` | - | Atmospheric |

### Transitions
| Element | Scene Path | Key Exports | Notes |
|---------|------------|-------------|-------|
| **Section Transition** | `objects/section_transition/section_transition.tscn` | `direction`, `target_transition_name`, `auto_trigger` | Seamless room change |
| **Level Section** | `objects/section_transition/level_section.tscn` | `bounds_size`, `is_dark_section` | Defines room bounds |

---

## Enemies

| Enemy | Scene Path | Behavior | Difficulty |
|-------|------------|----------|------------|
| **Crab** | `enemy/crab/crab.tscn` | Patrol, basic melee | Easy |
| **Starfish** | `enemy/starfish/starfish.tscn` | Static obstacle | Easy |
| **Turtle** | `enemy/turtle/turtle.tscn` | Patrol, hides in shell | Easy |
| **Mushroom** | `enemy/mushroom/mushroom.tscn` | Sleeps → explodes → gas | Medium |
| **Tribe** | `enemy/tribe/tribe.tscn` | Patrol, flees from player | Easy |
| **Aggressive Tribe** | `enemy/aggressive_tribe/aggressive_tribe.tscn` | Throws coconuts | Medium |
| **Seahorse** | `enemy/seahorse/seahorse.tscn` | 3-shot ranged burst | Medium |
| **Shield Tribe** | `enemy/shield_tribe/shield_tribe.tscn` | Blocks front, 0.35s turn delay | Hard |
| **King Crab** | `enemy/king_crab/king_crab.tscn` | Mini-boss | Hard |
| **Warlord Turtle** | `enemy/boss/warlordturtle/warlord_turtle.tscn` | Boss | Boss |

---

## How to Connect Things (Designer Workflow)

### Key + Chest Matching
1. Place `Key` → Set `key_id = "blue"` 
2. Place `Chest` → Set `required_key_id = "blue"`
3. Now only that key opens that chest!

### Lever + Gate Connection
1. Place `Gate` 
2. Place `Lever` → Set `target_type = GATE`
3. Set `gate_node` to point to the Gate (use NodePath picker)
4. Done! No code needed.

### Lever + Water Level
1. Place `Water`
2. Place `Lever` → Set `target_type = WATER_LEVEL`
3. Set `water_node` to point to the Water
4. Lever will raise/lower water!

### Section Transitions (Seamless Room Changes)
1. In Room A: Place `SectionTransition` at right edge → Name it "ToRoomB", set `direction = RIGHT`
2. In Room B: Place `SectionTransition` at left edge → Name it "FromRoomA", set `direction = LEFT`
3. Set Room A's transition: `target_transition_name = "FromRoomA"`
4. Walking right in Room A → Fades → Appears at left side of Room B

### Spike Trigger Modes
- **INTERVAL**: Cycles on/off automatically (timing puzzles)
- **PRESSURE_PLATE**: Triggers when player steps nearby (trap)
- **MANUAL**: Only triggers from script/lever (puzzles)

---

## Darkness System (Level 3 Cave)

### Basic Setup
1. Add `CanvasModulate` to level → Color `(0.2, 0.2, 0.25, 1)` for darkness
2. Place `GlowingCrystal` for light sources
3. Ensure tileset has occlusion layer (see `docs/TILEMAP_OCCLUSION_SETUP.md`)

### Light Sources
| Source | Radius | Shadows | Use For |
|--------|--------|---------|---------|
| GlowingCrystal | 100px | ✅ | Cave illumination |
| PlayerTorch | Variable | ✅ | Player visibility |
| FlameHazard | 60px | ✅ | Hazard with light |
| Camp Fire | 80px | ❌ | Decorative warmth |

---

## Ice Physics

Ice tiles use `PhysicsMaterial2D` with low friction. The player automatically detects ice and applies:
- `accelecrationValue` - How responsive movement is
- `slideValue` - How slippery (lower = more slide)
- `fullStopValue` - Velocity needed to fully stop

To make a tile icy:
1. In TileSet, select tile
2. Add StaticBody physics with `PhysicsMaterial2D`
3. Set friction < 0.3

---

## Common Patterns

### "Locked Door" Pattern
```
GoldChest (needs key)
    ↑
Key (hidden/guarded)
    ↑
Challenge Area (enemies/puzzles)
```

### "Commitment Drop" Pattern
```
Entry Point
    ↓ (drop)
One-Way Wall (can't climb back)
    ↓
Challenge → Lever
    ↓
Gate (now open) → Exit
```

### "Timed Run" Pattern
```
Timer Lever → Gate opens temporarily
    ↓
Hazard Corridor (must rush through)
    ↓
Safe Zone (before gate closes)
```

### "Multi-Key" Pattern
```
Hub Area
├── Wing A → Key A
├── Wing B → Key B
└── Final Gate (needs both Key A and Key B)
```

---

## Checklist Before Building

- [ ] Player spawn marker placed
- [ ] Camera bounds set (via StageBase or LevelSection)
- [ ] At least one checkpoint
- [ ] Exit zone / door configured
- [ ] Darkness setup (if cave level)
- [ ] Tested all lever/gate connections
- [ ] Verified key/chest matching
- [ ] Enemy patrol paths don't walk off edges
