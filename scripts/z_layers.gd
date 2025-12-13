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
##   [UI/HUD]           z = 50+      Indicators, damage numbers
##        ↑
##   [EFFECTS]          z = 20-30    Particles, glows, splashes
##        ↑
##   [TERRAIN FRONT]    z = 18       Foreground terrain (player hides behind)
##        ↑
##   [TERRAIN MAIN]     z = 15       Walkable terrain - MASKS fluid edges
##        ↑
##   [FLUID BODY]       z = 12       Water/lava fill - IN FRONT of player (submerged look)
##        ↑
##   [FLUID SURFACE]    z = 11       Surface ripple line
##        ↑
##   [PLAYER]           z = 10       Foxy - BEHIND water when swimming
##        ↑
##   [ENEMIES]          z = 8        Enemies - also behind water
##        ↑
##   [OBJECTS]          z = 0-5      Interactive objects, collectibles
##        ↑
##   [TERRAIN BACK]     z = -30      Background terrain layer
##        ↑
##   [BACKGROUND]       z = -100--50 Parallax, atmosphere, distant
##
##   BACKSTAGE (hidden from audience)
##   ─────────────────────────────────
##
## ============================================================
## THE GOLDEN RULES
## ============================================================
##
## 1. WATER IN FRONT OF PLAYER
##    - Water body at z=12, player at z=10
##    - Player appears BEHIND water = submerged look
##    - Simple. No overlay nonsense.
##
## 2. TERRAIN IN FRONT OF WATER
##    - Terrain at z=15, water at z=12
##    - Terrain tiles OVERLAP water rectangle edges
##    - Creates non-rectangular pool shapes
##
## 3. THE STACKING ORDER
##    Back → Front:
##    Player (10) → Water (12) → Terrain (15)
##    
##    Result: Player submerged, terrain masks water edges. Done.
##
## 4. ENEMIES ALSO BEHIND WATER
##    - Enemies at z=8, water at z=12
##    - They look submerged too
##
## 5. EFFECTS FLOAT ON TOP
##    - Particles, lights above everything
##
## ============================================================

## --- BACKGROUND TIER (far behind everything) ---
const PARALLAX_FAR: int = -100      ## Distant mountains, sky
const PARALLAX_MID: int = -80       ## Mid-distance scenery
const PARALLAX_NEAR: int = -60      ## Near background elements
const BACKGROUND_DECOR: int = -50   ## Decorative cave walls, vines

## --- TERRAIN BACK (background caves, decorative) ---
const TERRAIN_BACK: int = -30       ## Back layer of terrain (caves behind caves)

## --- OBJECTS TIER (things in the world) ---
const OBJECT_BEHIND: int = -2       ## Objects player walks in front of
const OBJECT_GROUND: int = 0        ## Ground-level objects (spikes, springs)
const OBJECT_FRONT: int = 3         ## Objects that overlay slightly

## --- GAMEPLAY TIER (the action) ---
const COLLECTIBLE: int = 5          ## Coins, potions, keys
const ENEMY: int = 8                ## All enemies - BEHIND water (submerged)
const PLAYER: int = 10              ## The fox - BEHIND water when swimming

## --- FLUID TIER (water/lava - IN FRONT of player for submersion) ---
## Water is IN FRONT of player so player looks submerged.
## Terrain is IN FRONT of water to mask rectangle edges.
const FLUID_SURFACE: int = 11       ## Water/lava surface ripple line
const FLUID_BODY: int = 12          ## Water/lava fill polygon - player behind this
const FLUID_FALL_SURFACE: int = 11  ## Waterfall surface line (same as pool)
const FLUID_FALL_BODY: int = 12     ## Waterfall fill (same as pool)

## --- TERRAIN MAIN (masks fluid edges) ---
const TERRAIN_MAIN: int = 15        ## Main walkable terrain - IN FRONT of water
const TERRAIN_DETAIL: int = 16      ## Terrain details, moss, cracks

## --- FOREGROUND TERRAIN (player hides behind) ---
const TERRAIN_FOREGROUND: int = 18  ## Foreground bushes, pillars

const PROJECTILE: int = 14          ## Player and enemy projectiles
const BOSS: int = 13                ## Bosses (above water, prominent)

## --- EFFECTS TIER (visual feedback) ---
const EFFECT_BEHIND: int = 8        ## Effects behind actors (shadows)
const EFFECT_MID: int = 18          ## Effects at actor level (hit sparks)
const LIGHT_EFFECT: int = 20        ## Point lights, glows
const EFFECT_FRONT: int = 25        ## Effects in front (particles, splashes)

## --- HUD TIER (in-world UI) ---
const INDICATOR: int = 50           ## Target indicators, health bars
const DAMAGE_NUMBER: int = 55       ## Floating damage numbers


## ============================================================
## VISUAL HIERARCHY EXAMPLES
## ============================================================
##
## SWIMMING IN WATER:
##   
##   Simple stacking: Player → Water → Terrain
##   Player is BEHIND water, so they look submerged.
##   Terrain is IN FRONT of water, masking the rectangle edges.
##   
##   Z-order (back to front):
##   Player (10) → Water body (12) → Terrain (15)
##   
##   CROSS-SECTION VIEW:
##   
##        ████████████████████████████████  ← Terrain IN FRONT (masks edges)
##        ████   ░░░░░░░░░░░░░░░░░   ████   ← Water body visible in "hole"
##        ████   ░░░░░░░░░░░░░░░░░   ████   ← Player BEHIND water (submerged)
##        ████   ░░░░░░░░░░░░░░░░░   ████
##        ████████████████████████████████  ← Terrain floor covers water bottom
##   
##   Result: Non-rectangular pool! Player submerged! No overlay needed!
##
## LAVA POOL:
##   Same system - lava body in front of player, terrain masks edges.
##   Player dies on contact anyway.
##
## COMBAT ON LAND:
##   Terrain back (-30) → Enemy (8) → Player (10) → Terrain (15)
##   Action reads clearly, terrain frames the scene.
##
## ============================================================
