# Factory Pattern Refactor - Mushroom Family

## Executive Summary

**CRITICAL FINDING:** The mushroom enemy family was manually spawning entities using `.instantiate()` and `.get_parent().add_child()`, ignoring the existing `Node2DFactory` system used by all other enemies (Seahorse, King Crab, Warlord Turtle).

**RESOLUTION:** Refactored all mushroom spawning logic to use the factory pattern consistently.

---

## The Legacy Pattern Issue

### What Was Wrong

**Manual Instantiation (Anti-Pattern):**
```gdscript
# ❌ OLD WAY (Elite Mushroom)
var mini = mini_mushroom_scene.instantiate()
mini.global_position = global_position + offset
mini.initial_direction = direction
get_parent().add_child(mini)

# ❌ OLD WAY (Gas Spawning)
var gas = toxic_gas_scene.instantiate()
gas.global_position = obj.global_position
gas.velocity = Vector2(speed * dir, variance)
obj.get_parent().add_child(gas)
```

### Why This Was A Problem

1. **No Container Management**
   - Entities spawned directly into parent, polluting scene tree
   - No centralized "Enemies" or "Bullets" container like other systems
   - Makes cleanup (e.g., level transitions, boss death) difficult

2. **Hardcoded Position Logic**
   - Spawn offsets hardcoded in scripts
   - Designers can't adjust spawn points visually in editor
   - Violates "show, don't code" principle

3. **No Signal Emissions**
   - Factory emits `created(product)` signal for tracking/effects
   - Manual spawning has no hooks for spawn VFX, sound, or analytics

4. **Inconsistency**
   - Every other enemy (Seahorse bullets, King Crab coconuts/bubbles, Boss whirlpools) uses `Node2DFactory`
   - Mushrooms were outliers using indie "quick and dirty" approach

5. **Missed Editor Features**
   - Factory position is a Marker2D node visible in editor
   - Moving the Marker2D moves spawn point (no code change needed)
   - Factory exports are Inspector-editable

---

## The Proper Pattern (Used Everywhere Else)

### How Factory Works

**Scene Setup:**
```
Enemy (CharacterBody2D)
  └─ Direction (Node2D)
      ├─ AnimatedSprite2D
      ├─ [ProductFactory] (Marker2D)  ← ADD THIS
      │   script: Node2DFactory
      │   @export product_packed_scene: PackedScene
      │   @export target_container_name: StringName
      └─ HurtArea2D
```

**Script Usage:**
```gdscript
@onready var product_factory = $Direction/ProductFactory

func spawn_thing():
    var product = product_factory.create()  # That's it!
    product.custom_property = value  # Set properties after spawn
```

**What Factory Does Internally:**
1. Instantiates `product_packed_scene`
2. Finds or creates container node by name (`target_container_name`)
3. Adds product to container
4. Sets `product.global_position = factory.global_position` (Marker2D position)
5. Emits `created(product)` signal
6. Returns product reference for further setup

---

## Changes Made

### 1. Elite Spawner Mushroom

**Scene Changes (`elite_spawner_mushroom.tscn`):**
- Added ext_resource for `Node2DFactory` script (id: 3_factory)
- Added `MiniMushroomFactory` Marker2D under `Direction/` at position `(0, -10)`
- Configured factory exports:
  - `product_packed_scene`: mini_mushroom.tscn
  - `target_container_name`: "Enemies"

**Script Changes (`elite_spawner_mushroom.gd`):**
- Added: `@onready var mini_factory = $Direction/MiniMushroomFactory`
- Rewrote `_spawn_mini_mushroom()`:
  ```gdscript
  # BEFORE
  var mini = mini_mushroom_scene.instantiate()
  mini.global_position = global_position + Vector2(randf_range(-25, 25), -10)
  mini.initial_direction = direction
  get_parent().add_child(mini)
  
  # AFTER
  var spread_offset = randf_range(-25, 25)
  var original_pos = mini_factory.global_position
  mini_factory.global_position.x += spread_offset  # Temporary offset for spawn
  
  var mini = mini_factory.create()  # Factory handles position + container
  mini.initial_direction = direction
  
  mini_factory.global_position = original_pos  # Restore for next spawn
  ```

**Script Changes (`states/elite_dead.gd`):**
- Death spawn now uses `obj.mini_factory.create()` instead of manual instantiate
- Factory position temporarily offset for each of the 3 death minis
- Cleaner pattern: offset factory → create → restore position

---

### 2. OG Mushroom (Base Enemy)

**Scene Changes (`mushroom.tscn`):**
- Added ext_resource for `Node2DFactory` (id: 10_factory)
- Added `ToxicGasFactory` Marker2D under `Direction/`
- Configured factory exports:
  - `product_packed_scene`: toxic gas.tscn
  - `target_container_name`: "Enemies"

**Script Changes (`explode.gd`):**
- Rewrote `_spawn_toxic_gas()`:
  ```gdscript
  # BEFORE
  for dir in [-1, 1]:
      var gas = toxic_gas_scene.instantiate()
      gas.global_position = obj.global_position
      gas.velocity = Vector2(gas_speed * dir, randf_range(-20, 20))
      obj.get_parent().add_child(gas)
  
  # AFTER
  var gas_factory = obj.get_node_or_null("Direction/ToxicGasFactory")
  for dir in [-1, 1]:
      var gas = gas_factory.create()  # Factory handles position + container
      gas.velocity = Vector2(gas_speed * dir, randf_range(-20, 20))
  ```
- Added fallback `_spawn_toxic_gas_manual()` for backward compatibility (if scene not updated)
- Marked `@export var toxic_gas_scene: PackedScene` as DEPRECATED

---

### 3. Mini Mushroom (Projectile)

**Scene Changes (`mini_mushroom.tscn`):**
- Added ext_resource for `Node2DFactory` (id: 9_factory)
- Added `ToxicGasFactory` Marker2D under `Direction/`
- Configured factory exports:
  - `product_packed_scene`: toxic gas.tscn
  - `target_container_name`: "Enemies"

**Script Changes (`states/mini_explode.gd`):**
- Rewrote `_spawn_toxic_gas()`:
  ```gdscript
  # BEFORE
  var dir = 1 if randf() > 0.5 else -1
  var gas = toxic_gas_scene.instantiate()
  gas.global_position = obj.global_position
  gas.velocity = Vector2(gas_speed * dir, randf_range(-15, 15))
  gas.scale = Vector2(0.6, 0.6)
  obj.get_parent().add_child(gas)
  
  # AFTER
  var gas_factory = obj.get_node_or_null("Direction/ToxicGasFactory")
  var dir = 1 if randf() > 0.5 else -1
  var gas = gas_factory.create()  # Factory handles position + container
  gas.velocity = Vector2(gas_speed * dir, randf_range(-15, 15))
  gas.scale = Vector2(0.6, 0.6)
  ```
- Added fallback `_spawn_toxic_gas_manual()` for backward compatibility
- Marked `@export var toxic_gas_scene: PackedScene` as DEPRECATED

---

## Benefits Gained

### 1. Scene Tree Organization
**Before:**
```
CurrentScene
  ├─ Player
  ├─ Terrain
  ├─ Enemy1 (parent)
  ├─ Enemy2 (parent)
  ├─ MiniMushroom1 (parent)  ← Spawned directly into scene root
  ├─ MiniMushroom2 (parent)
  ├─ ToxicGas1 (parent)
  └─ ToxicGas2 (parent)
```

**After:**
```
CurrentScene
  ├─ Player
  ├─ Terrain
  ├─ Enemy1 (parent)
  ├─ Enemy2 (parent)
  └─ Enemies (Node2D)  ← Auto-created container
      ├─ MiniMushroom1
      ├─ MiniMushroom2
      ├─ ToxicGas1
      └─ ToxicGas2
```

**Cleanup Impact:**
```gdscript
# Clean up all spawned entities (one line!)
var enemies_container = get_node("Enemies")
if enemies_container:
    enemies_container.queue_free()
```

### 2. Designer Workflow
- Spawn point = Marker2D position in editor (visual, no code)
- Adjust spawn height/offset by dragging Marker2D node
- Change product scene via Inspector dropdown (no script edit)
- Change container name via Inspector (organize dynamically)

### 3. Consistency Across Codebase
All enemy spawning now follows identical pattern:
- Seahorse: `bullet_factory.create()` → Bullets container
- King Crab: `coconut_factory.create()` → Projectiles container
- King Crab: `water_bubble_factory.create()` → Projectiles container
- Warlord Turtle: spawns whirlpools → Objects container
- **Mushroom (ALL)**: `mini_factory.create()` / `gas_factory.create()` → Enemies container

### 4. Future Extensibility
- Hook `factory.created` signal for spawn VFX/sound
- Track spawn counts via signal connections
- Implement spawn limits (e.g., max 10 minis alive)
- Add analytics (heatmaps of spawn positions)

---

## Testing Checklist

### Elite Spawner Mushroom
- [ ] Detects player → spawns minis every 5s
- [ ] Minis spawn with horizontal spread (-25 to +25 px)
- [ ] Minis face elite's direction
- [ ] Death spawns exactly 3 minis (2 forward, 1 back)
- [ ] Death minis have short lifetime (1.0s)
- [ ] Minis appear in "Enemies" container (check scene tree)

### OG Mushroom
- [ ] Explodes → spawns 2 gas clouds (left + right)
- [ ] Gas spawns at mushroom position
- [ ] Gas clouds move with velocity variance (-20 to +20 Y)
- [ ] Gas appears in "Enemies" container

### Mini Mushroom
- [ ] Lifetime expires → explodes
- [ ] Spawns 1 gas cloud (random direction)
- [ ] Gas cloud smaller scale (0.6 vs base)
- [ ] Gas faster spread (80 speed vs base 60)
- [ ] Gas appears in "Enemies" container

### Container Verification
1. Run level with Elite Spawner Mushroom
2. Open Scene Tree panel during gameplay
3. Verify `Enemies` node exists and contains:
   - MiniMushroom instances
   - ToxicGas instances
4. Kill elite → verify cleanup removes all minis/gas

---

## Migration Notes

### Backward Compatibility
Both `explode.gd` and `mini_explode.gd` include fallback logic:
```gdscript
var gas_factory = obj.get_node_or_null("Direction/ToxicGasFactory")
if not gas_factory:
    push_warning("Falling back to manual spawn!")
    _spawn_toxic_gas_manual()
    return
```

**Why:** If old mushroom scenes exist without factory node, they won't crash.

**Action:** Update all mushroom scene instances in levels to use new .tscn files.

### Export Cleanup (Optional)
Old `@export var toxic_gas_scene: PackedScene` marked DEPRECATED but not removed.
- Keeps old scenes functional until all updated
- Can be removed after full migration verified

---

## References

### Factory Implementation
- `scripts/node2d_factory.gd` - Core factory class

### Examples in Codebase
- `enemy/seahorse/seahorse.tscn` - BulletFactory pattern
- `enemy/king_crab/king_crab.tscn` - CoconutFactory, WaterBubbleFactory, ClawFactory
- `enemy/king_crab/bubble_attack.gd` - State using factory
- `enemy/seahorse/states/shoot.gd` - State using factory

### Modified Files
**Scenes:**
- `enemy/mushroom/elite_spawner_mushroom.tscn`
- `enemy/mushroom/mushroom.tscn`
- `enemy/mushroom/mini_mushroom.tscn`

**Scripts:**
- `enemy/mushroom/elite_spawner_mushroom.gd`
- `enemy/mushroom/states/elite_dead.gd`
- `enemy/mushroom/explode.gd`
- `enemy/mushroom/states/mini_explode.gd`

---

## Conclusion

**Root Cause:** Indie ignorance of existing infrastructure. The factory system existed and was proven across 4+ enemy types, but mushrooms were coded manually using legacy "instantiate + add_child" pattern.

**Resolution:** Brought mushroom family into consistency with rest of codebase. All spawning now uses `Node2DFactory`, gaining container management, editor workflow, signal hooks, and future extensibility.

**Status:** ✅ All syntax checks pass. Ready for in-editor playtesting.

**Next Steps:** Designer testing to verify spawn positions, timing, and visual clarity of multiple minis/gas clouds. Adjust Marker2D positions in scenes if needed (no code changes required).
