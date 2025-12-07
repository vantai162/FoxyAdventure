# Elite Enemy FSM Bug Fixes & UID Cleanup

## Session Date: December 7, 2025

---

## 🎯 Critical Fixes Implemented

### 1. FSM State Reference Crashes (4 bugs fixed)

**Problem:** Elite enemies using base state scripts that referenced non-existent states.

#### Elite Ricochet Starfish ✅
- **Bug:** Base `run.gd` called `fsm.states.attack` (doesn't exist in elite scene)
- **Fix:** Created `enemy/starfish/states/elite_run.gd` calling `fsm.states.ricochet_dash`
- **Scene Updated:** `elite_ricochet_starfish.tscn` now references elite override

#### Elite Spawner Mushroom (2 bugs) ✅
- **Bug #1:** Base `run.gd` line 10 called `fsm.states.sleep` (doesn't exist)
- **Fix #1:** Created `enemy/mushroom/states/elite_run.gd` calling `fsm.states.spawner_pursue`

- **Bug #2:** Base `hurt.gd` line 22 called `fsm.states.explode` (doesn't exist)
- **Fix #2:** Created `enemy/mushroom/states/elite_hurt.gd` calling `fsm.states.run`

- **Scene Updated:** `elite_spawner_mushroom.tscn` references both elite overrides

#### Elite Spiny Turtle ✅
- **Bug:** Base `hurt.gd` line 16 called `fsm.states.hide` (should be `defensive_hide`)
- **Fix:** Created `enemy/turtle/states/elite_hurt.gd` calling `fsm.states.defensive_hide` with fallback
- **Scene Updated:** `elite_spiny_turtle.tscn` references elite override

---

### 2. UID Cleanup (All Elite Scenes)

**Problem:** Godot UIDs on ext_resources causing regeneration issues and version control conflicts.

**Solution:** Removed `uid="uid://..."` attributes from all elite-specific and shared script/shader ext_resources.

**Files Modified:**
1. `enemy/starfish/elite_ricochet_starfish.tscn`
   - Removed UIDs from: elite script, eye trail, shader, elite_run, hurt, ricochet_dash, dead states

2. `enemy/mushroom/elite_spawner_mushroom.tscn`
   - Removed UIDs from: elite script, eye trail, shader, elite_run, spawner_pursue, elite_hurt states

3. `enemy/turtle/elite_spiny_turtle.tscn`
   - Removed UIDs from: elite script, eye trail, shader, base run, aggressive_pursue, defensive_hide, elite_hurt states

4. `enemy/crab/elite_hunter_crab.tscn`
   - Removed UIDs from: elite script, eye trail, shader, run, hunt, hurt, dead states

5. `enemy/seahorse/elite_sniper.tscn`
   - Removed UIDs from: elite script, eye trail, shader, idle, sniper_shoot, hurt, dead states

6. `enemy/aggressive_tribe/elite_bombardier.tscn`
   - Removed UIDs from: elite script, eye trail, shader, run, pursue, windup, attack, hurt states

**Result:** Godot will auto-regenerate UIDs on next load, ensuring clean state.

---

### 3. Starfish Detection Debug Logging

**Problem:** User reports elite starfish sees player (raycast active) but doesn't trigger attack.

**Investigation Added:**
- Added verbose debug logging to `elite_ricochet_starfish.gd::_on_player_in_sight()`
  - Logs: found_player status, FSM initialization, current state name
  - Checks fsm.states.has("ricochet_dash") and logs result
  
- Added verbose debug logging to `enemy/starfish/states/elite_run.gd::_update()`
  - Logs when found_player is detected
  - Logs state transition attempt

**Debug Output Pattern:**
```
[EliteStarfish] Player in sight! found_player: true | fsm: true | current_state: run
[EliteStarfish] Current state: run | Checking for ricochet_dash...
[EliteStarfish] ricochet_dash state exists! Changing state...

[EliteRun] Found player! Facing and triggering ricochet_dash...
[EliteRun] ricochet_dash exists, changing state!
```

**Expected Failure Modes:**
- If FSM not initialized: `current_state: NULL`
- If state missing: `ERROR: ricochet_dash state NOT found in fsm.states!`
- If wrong state: `Current state: <other>` (should be `run`)

---

## 🔍 Technical Deep Dive

### FSM State Name Normalization
**Critical Discovery:** FSM normalizes all state node names to lowercase WITHOUT preserving underscores or case.

**Source:** `scripts/fsm/fsm.gd` line 33:
```gdscript
var normalized_name: String = state_node.name.to_lower()
states[normalized_name] = state_node
```

**Implications:**
- Scene node `Run` → fsm.states.run
- Scene node `RicochetDash` → fsm.states.ricochetdash (NO UNDERSCORE!)
- Scene node `SpawnerPursue` → fsm.states.spawnerpursue (NO UNDERSCORE!)
- Scene node `AggressivePursue` → fsm.states.aggressivepursue (NO UNDERSCORE!)
- Scene node `DefensiveHide` → fsm.states.defensivehide (NO UNDERSCORE!)
- Scene node `SniperShoot` → fsm.states.snipershoot (NO UNDERSCORE!)
- Scene node `MiniExplode` → fsm.states.miniexplode (NO UNDERSCORE!)

**CRITICAL:** All state checks MUST use lowercase names WITHOUT underscores, regardless of scene node naming.

---

### Detection Flow Architecture

**Base Detection System** (`scripts/enemy.gd`):
1. `_physics_process()` calls `_check_player_in_sight()` every frame
2. `_check_player_in_sight()` loops through all `detect_ray_casts[]`
3. On raycast hit Player:
   - Sets `found_player = <Player instance>`
   - Calls `_on_player_in_sight(player_pos)`
4. On raycast loss:
   - Clears `found_player = null`
   - Calls `_on_player_not_in_sight()`

**Elite Starfish Override**:
- `enable_check_player_in_sight()` called in `_ready()` (line 13)
- Enables raycast, enables DetectPlayerArea2D collision
- Overrides `_on_player_in_sight()` to trigger ricochet_dash instead of base attack

**Dual Trigger Points**:
1. **Callback trigger:** `_on_player_in_sight()` in elite_ricochet_starfish.gd
   - Called when raycast first detects player
   - Checks current state, changes to ricochet_dash
   
2. **State trigger:** `elite_run.gd::_update()` checks `obj.found_player`
   - Runs every frame while in Run state
   - Redundant safety check (in case callback missed)

---

### Why Two Triggers?

**Defensive Design:**
- Callback may fire before FSM initialization (race condition)
- State check ensures transition happens even if callback timing fails
- Both check `fsm.states.has("ricochet_dash")` for safety

---

## 📋 Elite Enemy Audit Summary

### Safe Elites (No FSM Bugs)
✅ **Elite Hunter Crab**
- States: Run (base - safe), Hunt (elite-specific), Hurt (base - safe), Dead (base - safe)
- Base run.gd has NO state transitions
- Base hurt.gd only references `fsm.states.dead` (exists)

✅ **Elite Sniper Seahorse**
- States: Idle (elite), SniperShoot (elite), Hurt (base), Dead (base)
- Base hurt.gd only references `fsm.states.dead` (exists) and `fsm.states.idle` (exists)

✅ **Elite Bombardier**
- States: Run, Pursue, Windup, Attack, Hurt, Dead (all elite-specific)
- No base state script conflicts

### Fixed Elites (Had FSM Bugs)
⚠️→✅ **Elite Ricochet Starfish** (1 bug fixed)
⚠️→✅ **Elite Spawner Mushroom** (2 bugs fixed)
⚠️→✅ **Elite Spiny Turtle** (1 bug fixed)

---

## 🧪 Testing Protocol

### Test Elite Starfish Detection
1. Run `test/levels/level_3_1.tscn` (or any level with elite starfish)
2. Approach starfish from distance
3. Watch console for debug output:
   ```
   [EliteStarfish] Player in sight! found_player: true | fsm: true | current_state: run
   [EliteStarfish] ricochet_dash state exists! Changing state...
   ```
4. **Expected Behavior:**
   - Starfish faces player
   - Starfish enters ricochet_dash state (brief windup animation)
   - Starfish dashes toward player, bouncing off walls 3 times
   - Red eye trail visible during entire dash

5. **Failure Modes to Check:**
   - "current_state: NULL" → FSM not initialized (check _ready() order)
   - "ERROR: ricochet_dash NOT FOUND" → Scene missing RicochetDash state node
   - No state change → Check raycast enabled, check player in raycast range

### Test Elite Mushroom/Turtle
1. Run level with elite spawner mushroom or spiny turtle
2. Take damage (hurt state)
3. **Expected:** Enemy returns to run/pursue (no crash)
4. **Failure:** Crash with "Invalid access to property 'explode'" or 'hide'

---

## 📝 Files Created

1. `enemy/starfish/states/elite_run.gd` - Override for ricochet_dash transition
2. `enemy/mushroom/states/elite_run.gd` - Override for spawner_pursue transition
3. `enemy/mushroom/states/elite_hurt.gd` - Override avoiding explode state
4. `enemy/turtle/states/elite_hurt.gd` - Override using defensive_hide

---

## 📝 Files Modified

**Scenes (6):**
- `enemy/starfish/elite_ricochet_starfish.tscn`
- `enemy/mushroom/elite_spawner_mushroom.tscn`
- `enemy/turtle/elite_spiny_turtle.tscn`
- `enemy/crab/elite_hunter_crab.tscn`
- `enemy/seahorse/elite_sniper.tscn`
- `enemy/aggressive_tribe/elite_bombardier.tscn`

**Scripts (2):**
- `enemy/starfish/elite_ricochet_starfish.gd` - Added debug logging
- `enemy/starfish/states/elite_run.gd` - Added debug logging

---

## 🔮 Next Steps (If Issues Persist)

### If Starfish Still Doesn't Attack:
1. Check console for debug output - which check is failing?
2. Verify DetectPlayerRayCast2D exists in scene (line 141 of .tscn)
3. Verify raycast enabled: `detect_ray_cast.enabled == true`
4. Check raycast target_position: should be `Vector2(100, 0)` or similar
5. Check raycast collision_mask: should include player layer (3 = layers 1+2)
6. Verify player is in raycast range and not behind wall

### If FSM Crashes Persist:
1. Verify .tscn files loaded correctly (check ext_resource paths match created files)
2. Check State node names match script expectations (Run, RicochetDash, etc.)
3. Verify FSM initialization order (fsm = FSM.new() BEFORE super._ready())

---

## 🎓 Lessons Learned

1. **Never assume base scripts are safe for elites** - always audit state transitions
2. **FSM state names are lowercase** - `fsm.states.run` not `fsm.states.Run`
3. **Godot UIDs are brittle** - strip them on path-based ext_resources to allow regeneration
4. **Defensive programming wins** - dual trigger points prevent race conditions
5. **Debug logging is essential** - verbose output reveals timing/initialization issues

---

## 💡 Design Patterns Applied

### Override State Pattern
When elite needs different behavior from base:
```gdscript
# enemy/<type>/states/elite_<state>.gd
extends EnemyState

func _enter() -> void:
    obj.change_animation("...")  # Same animation
    
func _update(delta: float) -> void:
    # Elite-specific logic
    if fsm.states.has("elite_state"):
        change_state(fsm.states.elite_state)  # NOT base state
```

Update scene ext_resource to point to elite override, not base.

### Safe State Transition Pattern
Always check state exists before transitioning:
```gdscript
if fsm.states.has("target_state"):
    change_state(fsm.states.target_state)
else:
    # Fallback or error handling
    push_warning("State 'target_state' not found!")
```

### Dual-Trigger Detection Pattern
Callback + state check for robust behavior:
```gdscript
# Callback trigger (first detection)
func _on_player_in_sight(_pos: Vector2) -> void:
    if fsm and fsm.current_state:
        if fsm.states.has("attack_state"):
            fsm.change_state(fsm.states.attack_state)

# State trigger (continuous check)
func _update(delta: float) -> void:
    if obj.found_player:
        if fsm.states.has("attack_state"):
            change_state(fsm.states.attack_state)
```

---

**End of Report**

---

## 🔧 ADDENDUM: Ricochet Dash Behavior Fix (Dec 7, 2025)

### Problem Discovery
1. **FSM State Name Bug:** References used `ricochet_dash` but FSM normalizes to `ricochetdash` (no underscore)
2. **Broken Behavior:** Implementation was doing terrain bounce physics (pinball-style) instead of Master Yi-style triple dash
3. **Debug Spam:** Console filled with verbose logging that revealed the state name mismatch

### Solution Implemented

#### FSM State Name Corrections
Fixed all references from underscore to no-underscore format:
- `fsm.states.ricochet_dash` → `fsm.states.ricochetdash`
- `fsm.states.spawner_pursue` → `fsm.states.spawnerpursue`
- `fsm.states.aggressive_pursue` → `fsm.states.aggressivepursue`
- `fsm.states.defensive_hide` → `fsm.states.defensivehide`
- `fsm.states.sniper_shoot` → `fsm.states.snipershoot`
- `fsm.states.mini_explode` → `fsm.states.miniexplode`

**Files Updated:**
- `enemy/starfish/elite_ricochet_starfish.gd`
- `enemy/starfish/states/elite_run.gd`
- `enemy/mushroom/elite_spawner_mushroom.gd`
- `enemy/mushroom/states/elite_run.gd`
- `enemy/turtle/elite_spiny_turtle.gd`
- `enemy/turtle/states/elite_hurt.gd`
- `enemy/turtle/aggressive_pursue.gd`
- `enemy/seahorse/elite_sniper.gd`
- `enemy/mushroom/mini_mushroom.gd`

#### Ricochet Dash Redesign
**Old Behavior (Broken):**
- Dash toward player once
- Bounce off walls/terrain like a billiard ball
- Reflect velocity using `Vector2.bounce()`
- Stuttering, unpredictable movement
- Gravity active throughout

**New Behavior (Master Yi Style):**
- **Phase 1: Prepare** - 0.15s windup, zero velocity
- **Phase 2: Dash Sequence** - 3 sequential dashes (configurable)
- **Each Dash:**
  - Calculates direction toward player (can be diagonal/upward)
  - Travels up to 100px (configurable)
  - Suppresses gravity (`velocity.y = min(velocity.y, 0)`)
  - Hitbox active entire sequence
  - Can be interrupted early by terrain collision
- **Phase 3: Pause** - 0.1s pause between dashes, zero velocity
- **Termination:** After 3 dashes OR 3 second timeout, return to run state

**Key Mechanics:**
```gdscript
@export var dash_speed: float = 350.0       # Fast dash velocity
@export var max_dashes: int = 3             # Triple dash sequence
@export var dash_distance: float = 100.0    # Max distance per dash
@export var prepare_time: float = 0.15      # Windup before first dash
@export var dash_pause: float = 0.1         # Pause between dashes
```

**Distance Check:**
```gdscript
var distance_traveled = obj.global_position.distance_to(dash_start_position)
if distance_traveled >= dash_distance:
    _end_current_dash()  # Start next dash or exit
```

**Collision Interrupt:**
```gdscript
if obj.get_slide_collision_count() > 0:
    _end_current_dash()  # Hit wall, start next dash early
```

**Gravity Suppression:**
```gdscript
obj.velocity.y = min(obj.velocity.y, 0)  # Allow upward dash, prevent falling
```

**Direction Recalculation:**
Each dash recalculates toward player's CURRENT position (tracks moving target).

### Debug Logging Removal
Removed all `print()` statements from:
- `enemy/starfish/elite_ricochet_starfish.gd::_on_player_in_sight()`
- `enemy/starfish/states/elite_run.gd::_update()`

Console output now clean - no spam during gameplay.

### Testing Validation
**Expected Behavior:**
1. Player approaches elite starfish
2. Starfish detects via raycast
3. Brief 0.15s windup (attack animation, stationary)
4. **First dash:** Toward player, up to 100px or until wall hit
5. Brief 0.1s pause (stationary)
6. **Second dash:** Re-aims toward player's new position
7. Brief 0.1s pause
8. **Third dash:** Final strike
9. Return to run/patrol state

**Visual Feedback:**
- Red eye trail visible throughout entire sequence
- Hue-shifted elite shader active
- Attack animation plays during dashes
- HitArea enabled (can damage player on contact)

**Physics Behavior:**
- Gravity suppressed (starfish can dash upward/diagonally)
- No stuttering or jittering
- Smooth transitions between dashes
- Wall collision doesn't bounce - just triggers next dash early

### Files Modified (Addendum)
**Rewrites:**
- `enemy/starfish/states/ricochet_dash.gd` - Complete redesign (120 lines → 105 lines)

**State Name Fixes (9 files):**
- All elite enemy scripts using multi-word PascalCase state names

**Documentation:**
- `docs/ELITE_FSM_FIXES_AND_UID_CLEANUP.md` - Updated FSM naming section + this addendum

---

**Addendum End**

