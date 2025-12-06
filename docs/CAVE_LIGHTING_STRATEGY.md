# Cave Lighting Strategy - Performance vs Quality Balance

## The Goal

**"Player can't see what's obscured UNLESS illuminated by light"**

This creates atmospheric exploration where:
- Dark areas hide geometry
- Lights reveal surroundings
- Walls block light (create shadows)
- Player discovers areas as they explore

---

## How It Works (Technical)

### Component 1: Dark Ambient (CanvasModulate)
```gdscript
# In level scene
[node name="CanvasModulate" type="CanvasModulate"]
color = Color(0.08, 0.06, 0.10, 1.0)  # Very dark for Level 3-3+
```
**Effect:** Everything starts pitch black

### Component 2: Lights with Shadows (PointLight2D)
```gdscript
# On light source
var light = PointLight2D.new()
light.shadow_enabled = true  # Expensive!
light.energy = 1.0
light.texture_scale = 2.5
```
**Effect:** Creates illuminated circle, respects occlusion

### Component 3: Tile Occlusion (TileSet)
**Setup in Godot Editor:**
1. Open `assets/tileset.tres`
2. Add Occlusion Layer (if not exists)
3. For tile 2:6 (and any solid tile):
   - Select tile → Rendering tab
   - Add occlusion polygon: `(-16,-16), (16,-16), (16,16), (-16,16)`
4. Save

**Effect:** Light rays blocked at tile edges

---

## The Performance Problem

**Shadow rendering is EXPENSIVE:**

| Configuration | Shadow Maps/Frame | Expected FPS | Quality |
|--------------|------------------|--------------|---------|
| **All Lights (25+)** | 25+ | 15 FPS | ⭐⭐⭐⭐⭐ Perfect |
| **Strategic (5-7)** | 5-7 | 40-50 FPS | ⭐⭐⭐⭐ Great |
| **Player Only (1)** | 1 | 60+ FPS | ⭐⭐⭐ Good |
| **No Shadows (0)** | 0 | 60+ FPS | ⭐ Lights glow through walls |

**Why?** Each `shadow_enabled = true` light renders scene geometry into a shadow map texture every frame. With 18+ crystals + campfires + flames = GPU death.

---

## The Solution: Strategic Lighting

### Tier 1: Gameplay-Critical (SHADOWS ON)
**Use `cast_shadows = true` for 3-5 lights per level that:**
- Mark critical paths (entry, exit, lever locations)
- Illuminate puzzle areas
- Highlight danger zones
- Create dramatic "reveal" moments

**Example in level_3_1:**
```
✅ Crystal at spawn (orients player)
✅ Crystal near first lever (puzzle hint)
✅ Crystal at commitment drop (stakes marker)
✅ Crystal at lake entrance (progress indicator)
✅ Player torch (always on)
Total: 5 shadow casters = 40-50 FPS
```

### Tier 2: Atmospheric (SHADOWS OFF)
**Use `cast_shadows = false` for decorative lights:**
- Background ambiance crystals
- Campfires in safe areas
- Flame hazards (already dangerous, don't need perfect shadows)
- Decorative mushrooms

**Example:**
```
❌ 13 decorative crystals scattered around
❌ 3 campfires in spawn area
❌ 2 flame hazards
Total: 0 shadow casters from these = no cost
```

---

## How to Configure

### For GlowingCrystal Instances

In level scene, select crystal instance and check Inspector:

```
GlowingCrystal
├── Performance
│   └── Cast Shadows: [✓] or [ ]  ← Toggle this!
```

**Default:** `false` (performance mode)
**Enable for:** 3-5 hero crystals per level

### For Player Torch

Already configured in `player/player_torch.gd`:
```gdscript
@export var cast_shadows: bool = true  # Keep enabled for gameplay
```
Player torch ALWAYS casts shadows (critical for navigation).

### For CampFire

Shadows already disabled (campfires are decorative).

### For FlameHazard

Shadows already disabled (hazards don't need perfect lighting).

---

## Level-by-Level Strategy

| Level | CanvasModulate | Hero Crystals | Strategy |
|-------|---------------|---------------|----------|
| 3-1 Twilight | (0.15, 0.12, 0.18) | 4-5 shadows | Introduce darkness, teach torch use |
| 3-2 Depths | (0.10, 0.08, 0.12) | 5-7 shadows | Path choice - crystals mark routes |
| 3-3 Ruins | (0.08, 0.06, 0.10) | 5-6 shadows | Puzzle lighting - crystals reveal levers |
| 3-4 Gauntlet | (0.06, 0.05, 0.08) | 3-4 shadows | Minimal light - tension builder |
| 3-5 Boss Arena | (0.08, 0.06, 0.10) | 4 shadows | Arena corners + pillars |

---

## Testing Checklist

### 1. Tile Occlusion
- [ ] Open `assets/tileset.tres` in Godot
- [ ] Verify Occlusion Layer exists (Physics/Rendering/Navigation panel)
- [ ] Select tile 2:6 → Rendering → Check occlusion polygon exists
- [ ] If missing: Add polygon `(-16,-16), (16,-16), (16,16), (-16,16)`

### 2. Crystal Configuration
For each level:
- [ ] Count total crystals (should be 15-20)
- [ ] Mark 3-5 as "hero" crystals (critical positions)
- [ ] Set `cast_shadows = true` on hero crystals only
- [ ] Leave remaining crystals with `cast_shadows = false`

### 3. Performance Test
Run level and check:
- [ ] FPS stays above 40 with crystals visible
- [ ] Player torch casts shadows correctly
- [ ] Hero crystals illuminate and block at walls
- [ ] Decorative crystals provide ambient glow
- [ ] Areas behind walls are dark (not illuminated)

### 4. Visual Verification
Walk through level:
- [ ] Can't see geometry in unlit areas
- [ ] Light reveals walls/floors gradually
- [ ] Shadows look correct at wall edges
- [ ] Decorative lights add atmosphere without distraction

---

## What You Get

✅ **60fps gameplay** (or 40-50fps with strategic shadows)
✅ **Atmospheric darkness** - player explores with limited vision
✅ **Strategic lighting** - important areas properly illuminated
✅ **Performance budget** for other effects (water, particles, enemies)
✅ **Gameplay clarity** - player knows where to go via hero crystals

❌ **Perfect realism** - decorative lights glow through walls (minor, unnoticeable in darkness)
❌ **Shadow everywhere** - only 5-7 lights cast shadows per level

---

## Common Issues

### "Light passes through walls!"
- **Check:** Tile 2:6 has occlusion polygon in TileSet
- **Check:** Light has `shadow_enabled = true`
- **Remember:** Only hero crystals should have shadows

### "FPS still low!"
- **Check:** Count crystals with `cast_shadows = true` (should be ≤7)
- **Check:** Player torch is only other shadow caster
- **Check:** Decorative lights have `cast_shadows = false`

### "Too dark - can't see anything!"
- **Check:** CanvasModulate color not too dark (>0.05 on all channels)
- **Check:** Hero crystals placed at key navigation points
- **Check:** Player torch working (always visible around Foxy)

### "Decorative lights look weird without shadows"
- **Answer:** In near-darkness, players don't notice! They're focused on navigation
- **Solution:** Place decorative lights away from walls (reduces "glow through" visibility)

---

## Technical Notes

### Shadow Map Rendering
Each `shadow_enabled = true` light:
1. Renders scene geometry from light's perspective
2. Creates shadow map texture (GPU memory + computation)
3. Applies shadow map as mask to light
4. Repeats EVERY FRAME

**Cost:** ~2-4ms per shadow light on mid-range GPU
**Budget:** 60fps = 16.67ms per frame total
- 7 shadow lights = 14-28ms just for shadows (oof!)
- 5 shadow lights = 10-20ms (acceptable)
- 3 shadow lights = 6-12ms (comfortable)

### Occlusion vs Shadow Rendering
**Occlusion polygons (TileSet):**
- Define geometry that blocks light
- No runtime cost (baked into tiles)
- Used by shadow rendering system

**Shadow rendering (PointLight2D):**
- Actually computes and draws shadows
- Expensive GPU operation
- Requires occlusion polygons to work correctly

**You need BOTH:**
- Occlusion = "what blocks light"
- Shadow rendering = "draw the blocking"

---

## Quick Reference Commands

### Count shadow-casting lights in level:
```powershell
# PowerShell
Select-String -Path "test/levels/level_3/level_3_1.tscn" -Pattern "cast_shadows.*true" | Measure-Object
```

### Find all crystal instances:
```powershell
Select-String -Path "test/levels/level_3/level_3_1.tscn" -Pattern "GlowingCrystal"
```

### Performance profiling:
In Godot: Debug → Profiler → Monitor "Rendering → 2D Shadow Atlas"

---

## Summary

**The magic formula:**
1. Dark ambient (CanvasModulate) - everything starts black
2. Tile occlusion (TileSet) - walls block light
3. Player torch (always shadows) - see around yourself
4. 3-5 hero crystals (shadows) - mark critical areas
5. 10-15 decorative crystals (no shadows) - atmosphere

**Result:** Atmospheric exploration at 40-60 FPS with strategic visibility!
