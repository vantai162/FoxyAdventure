# Mushroom Kamikaze Rework - December 8, 2025

## Design Philosophy Change

### OLD: Passive Flee-Trap
- Wakes up → Freezes in fear → Runs AWAY from player
- Player chases it down → Eventually explodes
- Can return to sleep if player leaves
- Low threat, predictable behavior

### NEW: Active Kamikaze Bomber
- Wakes up → Processes threat → Runs TOWARD player
- Player must decide: fight or flight?
- **ALWAYS ends in explosion** (no sleep return)
- High threat, strategic positioning

---

## Behavioral Changes

### **Run State Transformation** (`run.gd`)

#### Core Mechanic Inversion
```gdscript
// OLD: Flee away from player
obj.velocity.x = obj.direction * 250  // Runs opposite

// NEW: Chase toward player  
obj.velocity.x = obj.direction * 180  // Pursues player (same direction)
```

#### New Systems Added

**1. Memory System (Sentience)**
- Stores `last_known_position` when player detected
- If player escapes: continues to ghost position
- Explodes when reaching destination
- Shows intelligence: "I know you were there"

**2. Hunt Timeout (Safety)**
- 8-second maximum hunt duration
- Auto-explodes after timeout
- Prevents infinite chase loops
- Creates urgency for player

**3. Obstacle = Explode**
- Hits wall → can't reach target → explodes
- Hits cliff edge → can't continue → explodes
- Simple navigation (no pathfinding needed)
- Terrain becomes tactical: lead mushroom into walls

**4. No Sleep Return**
- Removed `change_state(fsm.states.sleep)`
- Once awake → hunt → explode (inevitable)
- Player controls WHERE/WHEN, not IF

---

## Tuning Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `chase_speed` | 180 px/s | 60% of player speed (300) - escapable but threatening |
| `hunt_timeout` | 8.0 seconds | Long enough to traverse level, short enough for urgency |
| `destination_threshold` | 20 px | "Close enough" to ghost position before explosion |

### Speed Comparison
- **Player Sprint**: 300 px/s (can outrun mushroom)
- **Mushroom Chase**: 180 px/s (slower but relentless)
- **OLD Mushroom Flee**: 250 px/s (player chased it)

---

## Gameplay Impact

### Strategic Depth
1. **Positioning Puzzle**: Where do I want this explosion?
2. **Fight/Flight Decision**: Engage close = gas at MY position
3. **Baiting**: Lead mushroom to desired explosion point
4. **Area Denial**: Designer can force player routing with mushrooms
5. **Terrain Interaction**: Walls/cliffs cause early detonation

### Player Counterplay
- **Back Away**: Kite mushroom, control explosion location
- **Wall Bait**: Lead into obstacle for quick detonation
- **Ranged Attack**: Trigger explosion from safe distance
- **Speed Advantage**: Use 300 vs 180 speed gap to escape

### Threat Escalation
- **Early Game**: Player learns "it chases me!"
- **Mid Game**: Strategic explosion positioning
- **Late Game**: Mushroom clusters create overlapping threat zones

---

## State Flow Diagram

```
Sleep (Zzz icon, dormant)
  ↓ [Player enters 285px detection range]
Surprise (1.5s freeze, ! icon, "hyperawareness")
  ↓ [Timer expires]
Run/Hunt (chases player at 180 speed)
  ├─ [Active tracking: player in sight]
  │  └─ Updates last_known_position continuously
  │
  ├─ [Memory tracking: player escaped]
  │  └─ Pursues ghost position
  │      └─ [Reached destination] → Explode
  │
  ├─ [Hit obstacle: wall or cliff] → Explode
  │
  └─ [Hunt timeout: 8 seconds elapsed] → Explode
      ↓
Explode (1.5s animation, spawns 2 toxic gas clouds)
  ↓
Death (queue_free)
```

**Key Change**: Every path leads to explosion (no return to Sleep)

---

## Technical Implementation

### Performance Optimizations
- ✅ No pathfinding (straight-line chase only)
- ✅ No complex AI (memory = Vector2 storage)
- ✅ Timeout prevents infinite loops
- ✅ Same FSM structure (reuses existing system)
- ✅ No new assets required

### Code Quality
- ✅ Export variables for designer tuning
- ✅ Clear comments documenting behavior
- ✅ Safety checks for state transitions
- ✅ Consistent with codebase patterns

### Asset Reuse
- Same animations: sleep, run, explode, hurt
- Same visual feedback: Zzz icon, ! icon
- Same explosion: toxic gas clouds (2x, 60 speed)
- Same detection areas (can tune sizes if needed)

---

## Testing Scenarios

### Core Behavior
- [ ] Mushroom chases player (not flees)
- [ ] Speed differential: player can outrun (300 > 180)
- [ ] Memory system: continues to last position if player hides
- [ ] Explosion at ghost position when reached
- [ ] Timeout explosion after 8 seconds
- [ ] Wall collision triggers explosion
- [ ] Cliff edge triggers explosion

### Edge Cases
- [ ] Player kills mushroom mid-chase (hurt → explode)
- [ ] Multiple mushrooms chase simultaneously (no interference)
- [ ] Mushroom spawned on platform edge (immediate cliff check)
- [ ] Player uses dash to escape (speed burst beats 180 chase)

### Strategic Gameplay
- [ ] Player can bait mushroom away from valuable area
- [ ] Wall-bait tactic works (lead into wall = instant explode)
- [ ] Toxic gas creates area denial as intended
- [ ] 8-second urgency creates tension

---

## Design Notes

### Why 180 Speed?
- **Too Fast (>250)**: Player can't escape, feels unfair
- **Too Slow (<150)**: No threat, trivial to kite
- **180 Sweet Spot**: Player MUST move, but CAN escape with skill

### Why 8 Second Timeout?
- **Too Short (<5s)**: Mushroom explodes before reaching player
- **Too Long (>12s)**: Player can kite forever, no urgency
- **8s Balance**: Enough time to traverse level areas, but pressure builds

### Why Memory System?
- **Without**: Mushroom goes back to sleep when player hides (nonsensical)
- **With**: Shows intelligence, forces player commitment
- **Simple**: Just Vector2 storage, no pathfinding complexity

### Why Obstacle = Explode?
- **Alternative**: Complex pathfinding around walls
- **Problem**: Performance cost, AI complexity, asset limitation
- **Solution**: Frustration explosion (can't reach target → boom)
- **Benefit**: Creates wall-bait tactic, terrain interaction

---

## Comparison to Industry Examples

| Game | Enemy Type | Behavior | Similarity |
|------|-----------|----------|------------|
| **Minecraft** | Creeper | Chases, explodes when close | ✅ Core concept |
| **Nuclear Throne** | Exploding Enemies | Pursue player, detonate | ✅ Speed balance |
| **Spelunky** | Tiki Trap | Static, but pursues in range | ⚠️ More dynamic |
| **Hollow Knight** | Exploding Husk | Slow chase, area denial | ✅ Toxic aftermath |

**Mushroom Innovation**: Memory system (ghost position) + obstacle interaction

---

## Files Modified

- ✅ `enemy/mushroom/run.gd` - Complete kamikaze rework
  - Inverted chase direction
  - Added memory system
  - Added hunt timeout
  - Added obstacle explosion
  - Removed sleep return

---

## Status

✅ **IMPLEMENTATION COMPLETE**
- Syntax verified (no errors)
- Export variables for tuning
- Comments document behavior
- Performance optimized
- Ready for playtesting

**Next Steps**: In-game testing to validate speed/timeout balance

---

## Designer Tuning Guide

Adjust these export variables in the Godot editor:

```gdscript
@export var chase_speed: float = 180.0
# Increase: More threatening, harder to escape
# Decrease: Easier to kite, less pressure

@export var hunt_timeout: float = 8.0
# Increase: Longer chase, more room traversal
# Decrease: Faster explosion, more urgency

@export var destination_threshold: float = 20.0
# Increase: Explodes further from ghost position
# Decrease: More precise positioning required
```

**Recommended starting values**: 180 / 8.0 / 20.0 (current)
