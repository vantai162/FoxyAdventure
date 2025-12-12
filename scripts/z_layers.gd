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
##    - Fluid BODY (fill): BEHIND player (player swims IN it)
##    - Fluid SURFACE (line): SAME or slightly ABOVE player (overlaps top)
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
const TERRAIN_MAIN: int = -20       ## Main walkable terrain, walls
const TERRAIN_DETAIL: int = -15     ## Terrain details, moss, cracks

## --- ENVIRONMENT TIER (interactive world elements) ---
const FLUID_BODY: int = -5          ## Water/lava FILL polygon (player swims IN this)
const FLUID_SURFACE: int = 5        ## Water/lava SURFACE line (overlaps player top)
const FLUID_FALL_BODY: int = -3     ## Waterfall/lavafall fill (behind player)
const FLUID_FALL_SURFACE: int = 7   ## Waterfall/lavafall edges (in front)

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
## SWIMMING IN WATER:
##   Water fill (z=-5) → Player (z=10) → Water surface (z=5)
##   Result: Player appears "inside" the water, surface overlaps top
##
## LAVA POOL:
##   Lava fill (z=-5) → Player (z=10) → Lava surface (z=5) → Glow (z=20)
##   Result: Danger feels immersive, glow overlays everything
##
## COMBAT:
##   Terrain (z=-20) → Enemy (z=8) → Player (z=10) → Projectile (z=12)
##   Result: Action reads clearly, projectiles pop
##
## WATERFALL INTO POOL:
##   Fall body (z=-3) → Pool body (z=-5) → Player (z=10) → Fall surface (z=7)
##   Result: Fluid feels continuous, player can walk through/behind
##
## ============================================================
