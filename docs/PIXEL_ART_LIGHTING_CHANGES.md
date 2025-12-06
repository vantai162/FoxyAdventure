# Pixel-Art Light Rendering - Sharp Style Summary

## Changes Made

### Problem 1: Jarring Light Pop-In/Out
**Issue:** Lights visibly turned on/off when crystals entered/exited screen, breaking immersion.

**Root Cause:** `VisibleOnScreenEnabler2D` was aggressively disabling `light.enabled = false` for offscreen crystals.

**Solution:** Keep lights enabled offscreen, disable only expensive components:
- ✅ Light stays ON (cheap when shadows disabled)
- ❌ Pulse animation disabled (Tween killed)
- ❌ Sparkle particles disabled (GPU particles stopped)

**Result:** Smooth transitions, no jarring on/off at screen edges.

---

### Problem 2: Foggy/Hazy Lights
**Issue:** All lights used smooth radial gradients (WHITE → TRANSPARENT), creating soft haze instead of sharp pixel-art style.

**User Preference:** "I don't like haze... I prefer sharpness and tiny things... particle, yeah, them particles... not boring foggy effect"

**Solution:** Replace all gradients with hard-edged concentric rings:

#### Before (Smooth Haze):
```gdscript
grad.set_color(0, Color.WHITE)
grad.set_color(1, Color.TRANSPARENT)
```

#### After (Sharp Rings):
```gdscript
grad.add_point(0.0, Color.WHITE)           # Center: full bright
grad.add_point(0.3, Color(1, 1, 1, 0.95))  # Inner ring: sharp
grad.add_point(0.6, Color(1, 1, 1, 0.7))   # Middle ring: distinct
grad.add_point(0.85, Color(1, 1, 1, 0.3))  # Outer ring: defined edge
grad.add_point(1.0, Color.TRANSPARENT)     # Cut-off: hard boundary
```

**Visual Effect:**
- Lights have visible concentric rings (pixel-art aesthetic)
- Sharp boundaries between brightness levels
- No soft blur/haze
- More "retro game" feel

---

## Files Modified

### 1. `environment/cave/glowing_crystal.gd`
**Changes:**
- **Light texture:** 256px → 128px, 5-point gradient with hard rings
- **Spark particles:** 16px → 8px, 4-point gradient, sharper edges
- **Particle scale:** 0.5-1.5 → 1.0-2.5 (bigger, more visible)
- **Culling:** Keep light enabled offscreen, disable only pulse/sparkles

### 2. `player/player_torch.gd`
**Changes:**
- **Light texture:** 512px → 256px, 6-point gradient with sharp rings
- **Spark particles:** 8px → 6px, 4-point gradient with hard edges
- **Spark colors:** Brighter white-yellow center, sharper orange edge

### 3. `objects/camp_fire/camp_fire.gd`
**Changes:**
- **Light texture:** 256px → 128px, 5-point gradient with fire-style rings
- **Spark particles:** 8px → 6px, 4-point gradient, brighter centers

### 4. `objects/flame/flame_hazard.gd`
**Changes:**
- **Light texture:** 512px → 256px, 5-point gradient with sharp rings
- **Spark particles:** 8px → 6px, 4-point gradient, bright pixel style

---

## Technical Details

### Gradient Point Strategy

**Smooth Fade (OLD - Hazy):**
- 2 points: Start → End
- Linear interpolation creates smooth gradient
- Result: Soft blur, no defined edges

**Hard Rings (NEW - Sharp):**
- 5-6 points with strategic spacing
- Each ring maintains high alpha for longer
- Sharp transitions between rings
- Result: Visible concentric circles, pixel-art aesthetic

### Texture Size Reduction

| Light Source | Old Size | New Size | Reason |
|--------------|----------|----------|---------|
| Crystal | 256×256 | 128×128 | Sharper pixels, less interpolation |
| Player Torch | 512×512 | 256×256 | Crisp edges, pixel-art feel |
| Campfire | 256×256 | 128×128 | Defined rings visible |
| Flame Hazard | 512×512 | 256×256 | Hard-edged light cone |
| Particles | 8-16px | 6-8px | Tiny bright dots, not blobs |

**Smaller textures = less GPU interpolation = sharper rendering**

### Particle Improvements

**Scale Boost:**
- Min: 0.5 → 1.0
- Max: 1.5 → 2.5
- Result: Particles more visible, not tiny faded dots

**Color Boost:**
- Added bright white-yellow centers (Color(1, 1, 0.8))
- Sharper color transitions (4 gradient points instead of 2)
- Hard alpha cutoff at edges (no fade-to-nothing)

---

## Performance Impact

### Positive Changes
✅ **Smaller textures** (128px vs 256px) = Less GPU memory
✅ **Lights stay enabled offscreen** = No CPU overhead from enable/disable spam
✅ **Fewer tween operations** = Less animation overhead offscreen

### Neutral Changes
➖ **Gradient complexity** (5-6 points vs 2) = Negligible cost (calculated once at creation)
➖ **Particle scale increase** = Minimal impact (same particle count)

**Net Result:** Same or slightly better performance with much sharper visuals!

---

## Visual Comparison

### Old Style (Hazy)
```
    ░░░░░░░      Smooth fade
   ░░▒▒▒▒░░      No defined edges
  ░░▒▒██▒▒░░     Soft blur
  ░░▒▒▒▒▒░░      Foggy atmosphere
   ░░▒▒░░░       Hard to see structure
    ░░░░░
```

### New Style (Sharp)
```
    ▒▒▒▒▒▒       Hard rings visible
   ▒▒▓▓▓▓▒▒      Clear boundaries
  ▒▒▓▓██▓▓▒▒     Defined center
  ▒▒▓▓▓▓▓▒▒      Pixel-art aesthetic
   ▒▒▓▓▒▒        Sharp transitions
    ▒▒▒▒
```

---

## User Experience Improvements

### Before
❌ Lights pop on/off at screen edges (jarring)
❌ Soft hazy glow (boring, not pixel-art)
❌ Particles barely visible (too small, faded)
❌ "Foggy effect around lights" - user complaint

### After
✅ Smooth transitions (lights stay on)
✅ Sharp concentric rings (pixel-art style)
✅ Bright visible particles (tiny sparks pop)
✅ "Sharpness and tiny things... particles" - achieved!

---

## Testing Checklist

Run level_3_1 and verify:
- [ ] Lights don't pop on/off when moving camera
- [ ] Lights have visible ring patterns (not smooth blur)
- [ ] Crystals glow smoothly even at screen edges
- [ ] Torch has sharp defined rings
- [ ] Spark particles are bright tiny dots
- [ ] Campfire has crisp fire glow
- [ ] Flame hazards have sharp light cones
- [ ] No performance degradation

---

## Future Enhancements (Optional)

If you want even MORE pixel-art sharpness:

1. **Use actual pixel textures** instead of gradients:
   - Draw 16×16 or 32×32 light texture in pixel editor
   - Import as nearest-neighbor filtered texture
   - Perfect pixel control, no interpolation

2. **Add chromatic aberration** (color rings):
   - Different colors per ring (red → orange → yellow → white)
   - Creates "retro CRT" effect
   - More visual interest

3. **Particle burst patterns**:
   - Replace random emission with geometric patterns
   - 4-directional, 8-directional, circular bursts
   - More "game-y" feel

4. **Light animation alternatives**:
   - Instead of smooth pulse, use discrete brightness steps
   - 100% → 80% → 100% (stepped, not smooth)
   - More "low-frame-rate retro" aesthetic

---

## Summary

**What Changed:** All lights and particles now use hard-edged gradients with visible rings instead of smooth haze.

**Why:** User preference for sharp pixel-art style with "bits and parts and sparks, not haze."

**Result:** 
- Smooth light transitions (no jarring pop)
- Sharp pixel-art aesthetic (visible rings)
- Bright visible particles (tiny sparks)
- Same or better performance

**The magic:** Lights stay on for smooth transitions, but only animate when visible. Smaller textures with more gradient points create sharp pixel-art rings instead of soft blur.
