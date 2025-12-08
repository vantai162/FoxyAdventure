# Elite Spawner Mushroom: Final Implementation

## Design: "Cautious Artillery Commander"

**Core Concept:** Distance-keeping spawner that avoids close combat while launching dumb missile minions.

---

## Elite Behavior

### States
- **Sleep:** Idle until player detected (300×120 detection area)
- **Run:** Simple patrol when no player
- **SpawnerPursue:** Distance-keeping AI:
  - Distance < 80px → Flee at 200 speed
  - Distance > 150px → Advance at 150 speed  
  - Distance 80-150px → Hold position
- **Hurt:** 0.2s pause, return to pursuit
- **Dead:** Spawn 3 final minis + fade out (1.0s)

### Stats
- Health: 150 (3× base mushroom)
- Detection: 300×120 (reduced from 400×150)
- Speeds: Patrol 100, Pursuit 150, Flee 200

### Spawning Rules
- Spawns **only while player detected** (timer paused when lost)
- Interval: 5.0s between spawns
- No panic spawn on hurt
- Death: 3 final minis at elite's position (spread pattern)

---

## Mini Mushroom: "Dumb Missile"

### Behavior
- **NO detection** — pure projectile
- Spawned with `initial_direction = elite.direction` (simple!)
- Constant velocity: `120 speed × initial_direction`
- Lifetime: 3.0s → auto-explode
- Early death (1 HP hit): explode immediately

### Properties Removed
- ❌ DetectPlayerArea2D
- ❌ ExplodeArea2D (proximity trigger)
- ❌ FrontRayCast2D / DownRayCast2D
- ❌ All `_on_player_*` callbacks

### Range
- Speed 120 × 3.0s = **360px max travel**
- Elite prefers 150px distance → minis cover gap easily

---

## Tuning Summary

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Elite Health | 150 | Tank (10-15 player hits) |
| Elite Detection | 300×120 | Wide but not unfair |
| Flee Threshold | 80px | Player melee range |
| Preferred Distance | 150px | Artillery sweet spot |
| Pursuit Speed | 150 | Slower than player (escapable) |
| Flee Speed | 200 | Faster retreat (urgency) |
| Spawn Interval | 5.0s | Breathing room between waves |
| Mini Lifetime | 3.0s | 360px max range |
| Mini Speed | 120 | Slow enough to dodge |
| Death Spawn | 3 | Final challenge |

---

## Implementation Simplifications

### What Was Removed
1. **Panic spawn** — too intense
2. **Max minion tracking** — unnecessary complexity (simple counter now)
3. **Minion cleanup array** — no tracking needed (they auto-die)
4. **Player position aiming** — just use elite's facing direction
5. **Mini detection logic** — pure velocity projectile

### Why It's Simple
- Elite: "Sleep → Detect → Pursue with distance-keeping → Spawn on timer → Die with 3-burst"
- Mini: "Spawn → Move in direction → Explode after 3s"

No pathfinding, no complex checks, no overengineering.

---

## Files Modified

### New Files
- `enemy/mushroom/states/elite_sleep.gd`
- `enemy/mushroom/states/elite_dead.gd`

### Modified Files
- `enemy/mushroom/mini_mushroom.gd` — stripped detection, added lifetime
- `enemy/mushroom/mini_mushroom.tscn` — removed detection areas
- `enemy/mushroom/states/mini_run.gd` — constant velocity only
- `enemy/mushroom/states/elite_run.gd` — simple patrol
- `enemy/mushroom/states/spawner_pursue.gd` — distance-keeping logic
- `enemy/mushroom/states/elite_hurt.gd` — removed panic spawn
- `enemy/mushroom/elite_spawner_mushroom.gd` — detection-gated spawning
- `enemy/mushroom/elite_spawner_mushroom.tscn` — added sleep/dead states, reduced detection

---

## Testing Checklist

1. Elite wakes on detection, returns to sleep when lost
2. Elite maintains 80-150px distance (flees if close, advances if far)
3. Elite spawns mini every 5s only while player visible
4. Mini moves straight in elite's facing direction
5. Mini explodes after 3s timeout or on taking damage
6. Elite death spawns 3 minis + fades out
7. No panic spawn on hurt
