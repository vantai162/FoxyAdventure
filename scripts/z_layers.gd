class_name ZLayers
## ============================================================
## Z-INDEX LAYER SYSTEM - The Visual Stacking Order
## ============================================================
##
## Z-index determines draw order within the same parent context.
## Lower numbers draw FIRST (behind), higher numbers draw LATER (in front).
##
## CONCEPTUAL MODEL - Think of layers like a theater stage:
##
##   AUDIENCE VIEW (what player sees)
##   ─────────────────────────────────
##   
##   [FOREGROUND]     z = 30-50    VFX, overlays, UI hints
##        ↑
##   [GAMEPLAY]       z = 0-20     Player, enemies, projectiles
##        ↑  
##   [ENVIRONMENT]    z = -10-0    Water, lava, interactive objects
##        ↑
##   [TERRAIN]        z = -30--20  Walls, platforms, ground
##        ↑
##   [BACKGROUND]     z = -100--50 Parallax, atmosphere, distant
##
##   BACKSTAGE (hidden from audience)
##   ─────────────────────────────────
##
## ============================================================
## THE GOLDEN RULES
## ============================================================
##
## 1. PLAYER IS KING (z = 10)
##    - Player should be visible AT ALL TIMES
##    - Player goes BEHIND water surface (submerged effect)
##    - Player goes IN FRONT OF terrain and background
##
## 2. WATER/FLUID HIERARCHY
##    - Fluid BODY (fill): BEHIND terrain (walls mask rectangle edges)
##    - Fluid SURFACE (line): BEHIND terrain (visible through pool opening)
##    - Player renders IN FRONT of terrain+fluid, appearing to swim in visible area
##    - Fluid EFFECTS (splash/bubbles): ABOVE player (particle overlay)
##
## 3. ENEMIES MATCH PLAYER
##    - Same z-range as player (they interact on same plane)
##    - Bosses might be slightly higher to feel dominant
##
## 4. TERRAIN IS FOUNDATION
##    - Always BEHIND gameplay elements
##    - Decorative terrain can be BACKGROUND (further back)
##
## 5. EFFECTS FLOAT ON TOP
##    - Particles, lights, indicators above gameplay
##    - But NOT above UI (that's CanvasLayer territory)
##
## ============================================================

## --- BACKGROUND TIER (far behind everything) ---
const PARALLAX_FAR: int = -100      ## Distant mountains, sky
const PARALLAX_MID: int = -80       ## Mid-distance scenery
const PARALLAX_NEAR: int = -60      ## Near background elements
const BACKGROUND_DECOR: int = -50   ## Decorative cave walls, vines

## --- TERRAIN TIER (the world itself) ---
const TERRAIN_BACK: int = -30       ## Back layer of terrain (caves behind caves)
const TERRAIN_MAIN: int = -20       ## Main walkable terrain, walls, pool containers
const TERRAIN_DETAIL: int = -15     ## Terrain details, moss, cracks

## --- ENVIRONMENT TIER (interactive world elements) ---
## CRITICAL: Fluids must be BEHIND terrain so pool walls mask the fluid rectangle edges!
## The fluid is only visible through the "opening" at the top of the pool container.
## Player (z=10) renders in front of everything, appearing to swim in the visible area.
const FLUID_BODY: int = -25         ## Water/lava FILL polygon - BEHIND terrain walls
const FLUID_SURFACE: int = -22      ## Water/lava SURFACE line - BEHIND terrain (visible through opening)
const FLUID_FALL_BODY: int = -24    ## Waterfall/lavafall fill - BEHIND terrain
const FLUID_FALL_SURFACE: int = -21 ## Waterfall/lavafall edges - BEHIND terrain

## --- OBJECTS TIER (things in the world) ---
const OBJECT_BEHIND: int = -2       ## Objects player walks in front of
const OBJECT_GROUND: int = 0        ## Ground-level objects (spikes, springs)
const OBJECT_FRONT: int = 3         ## Objects that overlay slightly

## --- GAMEPLAY TIER (the action) ---
const COLLECTIBLE: int = 5          ## Coins, potions, keys
const ENEMY: int = 8                ## All enemies
const PLAYER: int = 10              ## The fox - THE ANCHOR POINT
const PROJECTILE: int = 12          ## Player and enemy projectiles
const BOSS: int = 15                ## Bosses (slightly more prominent)

## --- EFFECTS TIER (visual feedback) ---
const EFFECT_BEHIND: int = 8        ## Effects behind actors (shadows)
const EFFECT_MID: int = 18          ## Effects at actor level (hit sparks)
const EFFECT_FRONT: int = 25        ## Effects in front (particles, splashes)
const LIGHT_EFFECT: int = 20        ## Point lights, glows

## --- HUD TIER (in-world UI) ---
const INDICATOR: int = 50           ## Target indicators, health bars
const DAMAGE_NUMBER: int = 55       ## Floating damage numbers

## --- RESERVED FOR UI ---
## Anything above 100 should really be on a CanvasLayer, not z_index
## const UI_OVERLAY: int = 100  # DON'T USE - use CanvasLayer instead


## ============================================================
## VISUAL HIERARCHY EXAMPLES
## ============================================================
##
## SWIMMING IN WATER (side view cross-section):
##   
##   [TERRAIN WALL]  [OPENING]  [TERRAIN WALL]
##        ████                      ████
##        ████   ~~~SURFACE~~~      ████   ← Surface visible through opening
##        ████   ░░░░░░░░░░░░░      ████   ← Body visible through opening
##        ████   ░░░PLAYER░░░░      ████   ← Player in front of fluid
##        ████   ░░░░░░░░░░░░░      ████
##        ████████████████████████████████  ← Bottom terrain covers fluid bottom
##
##   Z-order (back to front):
##   Fluid body (-25) → Fluid surface (-22) → Terrain (-20) → Player (10)
##   Result: Terrain walls MASK fluid edges, player appears to swim in opening
##
## LAVA POOL:
##   Fluid body (-25) → Surface (-22) → Terrain (-20) → Player (10) → Glow (20)
##   Result: Same masking, glow overlays everything for danger feel
##
## COMBAT:
##   Terrain (-20) → Enemy (8) → Player (10) → Projectile (12)
##   Result: Action reads clearly, projectiles pop
##
## WATERFALL INTO POOL:
##   Fall body (-24) → Pool body (-25) → Surfaces (-22,-21) → Terrain (-20) → Player (10)
##   Result: Fluid feels continuous, terrain masks all edges
##
## ============================================================
