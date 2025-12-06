                  # Level Designer's Cheat Sheet 🎮

Concise guide to game elements, their settings, and "Genius" usage scenarios.

## 🏗️ Structural Elements

### Gate (`objects/gate/gate.tscn`)
*   **What:** Moving barrier controlled by signals.
*   **Settings:** `direction` (Vertical/Horizontal), `move_distance`, `open_duration`.
*   **Standard Use:** Door that opens when lever is pulled.
*   **🧠 Genius Use:**
    *   **Elevator:** Set `direction=VERTICAL`, `move_distance=500`. Player stands on top, pulls lever → rides up.
    *   **Moving Wall-Cling:** Set `direction=HORIZONTAL`. Player clings to side, rides it across a gap.
    *   **Crusher:** Set `direction=VERTICAL`, `move_distance` downwards. Closes *onto* the player (instant death zone).

### Collapsable Wall (`objects/collapsable_wall/collapsable_wall.tscn`)
*   **What:** Wall that breaks when attacked.
*   **Standard Use:** Hidden path revealer.
*   **🧠 Genius Use:**
    *   **Trap Door:** Place *under* an enemy. Player breaks it → enemy falls into spikes.
    *   **Timed Bridge:** Player must run across before an enemy projectile breaks the floor.

### Platform (`objects/platform/platform.tscn`)
*   **What:** Static or moving platform.
*   **Settings:** `move_speed`, `path_points`.
*   **Standard Use:** Floating island to jump on.
*   **🧠 Genius Use:**
    *   **Enemy Patrol Boat:** Put a patrolling enemy on it. The enemy moves *relative* to the platform.
    *   **Shield:** A moving platform that blocks projectiles but isn't for standing on.

---

## ⚡ Triggers & Logic

### Lever (`objects/lever/lever.tscn`)
*   **What:** Permanent toggle switch.
*   **Settings:** `target_type` (Gate/Water/Lava/Flame).
*   **Standard Use:** Open a door.
*   **🧠 Genius Use:**
    *   **"Bad" Lever:** Pulling it *closes* the exit or *fills* the room with lava.
    *   **Light Switch:** Connect to a `FlameHazard` to toggle lights in a dark room.

### Timer Lever (`objects/timer_lever/timer_lever.tscn`)
*   **What:** Temporary switch.
*   **Settings:** `duration`.
*   **Standard Use:** Open door for 3 seconds.
*   **🧠 Genius Use:**
    *   **Rhythm Section:** Series of timer levers that control disappearing platforms. Must hit them in flow.

### Pressure Plate (`objects/pressure_plate/pressure_plate.tscn`)
*   **What:** Weight-activated switch.
*   **Settings:** `require_weight` (Player vs Crate).
*   **Standard Use:** Stand on it to open door.
*   **🧠 Genius Use:**
    *   **"The Floor is Lava" Safety:** Plate drains lava only while standing on it. Step off → death.
    *   **Enemy Trap:** An enemy patrolling walks over it, triggering a trap that hits the *player*.

---

## 🌊 Fluids & Hazards

### Lava Pool (`environment/lava/lava_pool.tscn`)
*   **What:** Deadly fluid.
*   **Settings:** `drain_target_y`, `fill_duration`.
*   **Standard Use:** Pit of death.
*   **🧠 Genius Use:**
    *   **Tide:** Slowly rising/falling lava (using `fill_duration=30`). Player must climb high, then can drop low.
    *   **Visual Timer:** Lava draining indicates how much time is left to solve a puzzle.

### Water (`objects/water/water.tscn`)
*   **What:** Swimmable fluid.
*   **Settings:** `surface_pos_y`.
*   **Standard Use:** Swimming area.
*   **🧠 Genius Use:**
    *   **Fall Cushion:** Place at bottom of huge drop to save player.
    *   **Variable Gravity:** Vertical water column (waterfall) that player swims *up* to climb a wall.

### Flame Hazard (`objects/flame/flame_hazard.tscn`)
*   **What:** Intermittent fire jet.
*   **Settings:** `on_duration`, `off_duration`, `cycle_enabled`.
*   **Standard Use:** Obstacle to time jumps through.
*   **🧠 Genius Use:**
    *   **Lighting:** In dark levels, it's the *only* light source. When it turns off, total darkness.
    *   **Enemy Blocker:** Enemies can't pass through it either (if configured). Use it to pen them in.

### Wind Area (`objects/wind/WindArea.tscn`)
*   **What:** Invisible force zone.
*   **Settings:** `wind_force`.
*   **Standard Use:** Push player back.
*   **🧠 Genius Use:**
    *   **Jump Booster:** Upward wind (`y = -500`) for super jumps.
    *   **Projectile Shield:** Strong wind that blows enemy arrows away from player.
    *   **Speed Tunnel:** Horizontal wind *with* the player for super-speed section.

### Spring (`objects/spring/spring.tscn`)
*   **What:** Bouncer.
*   **Standard Use:** Reach high places.
*   **🧠 Genius Use:**
    *   **Pinball:** Series of angled springs (if rotated) to bounce player through a hazard maze without touching ground.

---

## 🛠️ Audit & Improvements

**Found Issues:**
1.  **Enemies vs Springs:** Enemies currently *cannot* use springs (missing `spring()` method).
    *   *Fix:* Add `spring()` to `EnemyCharacter` to allow bouncing enemies.
2.  **Gate Crush:** Gates don't have "crush" logic (damage if squishing player).
    *   *Fix:* Add Area2D check when closing to hurt player.

**Ready to Implement:**
*   [ ] **Bouncing Enemies:** Let crabs/turtles use springs for dynamic patrols.
*   [ ] **Crusher Gates:** Make gates dangerous if you stand under them.
