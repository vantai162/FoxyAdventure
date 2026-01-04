# Visual Design Doctrine
## FoxyAdventure Visual Standards

> "A visual effect that cannot be seen is not an effect. A visual effect that betrays the art style is a lie."

This document codifies the visual design principles for FoxyAdventure. When in doubt, consult this. When creating new effects, follow this. When something looks wrong, audit against this.

---

## The Sacred Scale

### Game Dimensions
| Element | Size | Reference |
|---------|------|-----------|
| Tile | 16×16 px | Base unit |
| Player (Foxy) | 32×32 px | 2 tiles tall |
| Enemy (small) | 16-32 px | 1-2 tiles |
| Enemy (large) | 48-64 px | 3-4 tiles |

### The Pixel Art Commandment
> "Every visual element must read as PIXELS, not blobs."

**The Rule of Visibility:**
- **Minimum**: 1px (anything smaller is invisible)
- **Sweet Spot**: 2-6px (reads as crisp pixel cluster)
- **Maximum**: 8px (beyond this = cotton ball, not pixel)
- **Forbidden**: 10px+ particles (destroys pixel art aesthetic)

---

## Particle Effect Standards

### Base Texture Size
**Always 4×4 pixels** for procedural GradientTexture2D.

Why 4×4?
- Large enough to have gradient (soft edge)
- Small enough to stay pixelly when scaled
- Scales well: 0.5× = 2px, 1.5× = 6px

### Scale Ranges by Effect Type

| Effect Type | scale_min | scale_max | Final Size | Example |
|-------------|-----------|-----------|------------|---------|
| Tiny specks | 0.5 | 1.0 | 2-4px | dust, sparks |
| Standard debris | 0.6 | 1.3 | 2-5px | wall scrape, rust |
| Medium puffs | 0.6 | 1.5 | 2-6px | dust puff, steam |
| NEVER exceed | - | 2.0 | 8px max | - |

### The Math Check
Before committing any particle effect:
```
final_min_size = texture_width × scale_min
final_max_size = texture_width × scale_max

PASS if: final_min_size >= 2px AND final_max_size <= 8px
FAIL if: final_max_size > 8px (cotton ball alert!)
```

---

## Particle Physics: Drama Within Constraints

### Velocity Guidelines
Particles should MOVE with purpose, not float aimlessly.

| Effect Type | Velocity Range | Feel |
|-------------|---------------|------|
| Debris spray | 35-80 px/s | Energetic scatter |
| Sparks burst | 60-140 px/s | Explosive pop |
| Dust puff | 25-55 px/s | Quick dispersion |
| Slow drift | 8-25 px/s | Atmospheric float |
| Steam rise | 45-90 px/s | Forceful plume |

### Gravity Rules
| Effect | Gravity | Why |
|--------|---------|-----|
| Debris, dust, rust | +45 to +120 | Falls naturally |
| Sparks | -25 to -50 | Rise briefly, then arc down |
| Steam, smoke | -30 to -65 | Rises and dissipates |
| Fire | -40 to -80 | Flames lick upward |

**Negative gravity = rises. Positive gravity = falls.**

### Lifetime Guidelines
| Effect Type | Lifetime | Why |
|-------------|----------|-----|
| Sparks | 0.25-0.4s | Quick flash |
| Debris | 0.4-0.6s | See the arc |
| Dust/Steam | 0.4-0.5s | Disperse naturally |
| Slow drift | 0.7-1.0s | Atmospheric |

---

## Color: Contrast is King

### The Core-to-Edge Principle
Every particle should have:
1. **Bright core** (high alpha, light color)
2. **Fading edge** (low alpha, darker tone)

This creates visual "pop" even at small sizes.

### Color Ramp Structure (GradientTexture1D)
```
Offset 0.0  → Brightest, full alpha (the "pop")
Offset 0.15 → Slightly dimmer, still opaque
Offset 0.5  → Mid-tone, reduced alpha
Offset 1.0  → Dark/transparent (fade out)
```

### Effect-Specific Palettes

| Effect | Core Color | Mid Color | Fade Color |
|--------|------------|-----------|------------|
| **Sparks** | White (1,1,1) | Yellow (1,0.9,0.4) | Orange→Black |
| **Fire/Burn** | White-Yellow | Orange (1,0.6,0.1) | Red→Black |
| **Debris** | Tan (0.95,0.9,0.75) | Brown (0.6,0.5,0.35) | Dark brown |
| **Dust** | Cream (0.95,0.88,0.75) | Tan (0.7,0.6,0.5) | Gray-brown |
| **Rust** | Orange (0.85,0.6,0.35) | Rust (0.55,0.32,0.15) | Dark rust |
| **Steam** | White (1,1,1) | Light gray | Transparent |

---

## Z-Index: Layering Law

All effects must respect `z_layers.gd`:

| Layer | z_index | Use For |
|-------|---------|---------|
| EFFECT_BEHIND | 8 | Trails, shadows, ground effects |
| EFFECT_MID | 18 | Mid-layer effects |
| LIGHT_EFFECT | 20 | PointLight2D, glows |
| EFFECT_FRONT | 25 | Particles, sparks, debris |

### The Rule
**Bake z_index into .tscn files.** Never rely on runtime assignment.

---

## Effect Quantity: More ≠ Better

### Particle Amount Guidelines
| Effect Type | Amount | Why |
|-------------|--------|-----|
| Subtle ambient | 6-10 | Atmosphere, not distraction |
| Standard burst | 12-18 | Visible impact |
| Dramatic moment | 20-32 | Boss hits, big events |
| NEVER exceed | 40 | Performance + visual noise |

### Explosiveness
| Value | Behavior | Use For |
|-------|----------|---------|
| 0.1-0.3 | Continuous stream | Wall scrape, trails |
| 0.4-0.6 | Staggered burst | Rust falling, debris |
| 0.9-1.0 | All at once | Impacts, explosions |

---

## The Spawn Checklist

When instantiating particles at runtime:

```gdscript
# 1. Instantiate
var particles = SCENE.instantiate()

# 2. Set position BEFORE adding to tree
particles.global_position = spawn_position

# 3. z_index should be baked in .tscn (don't set here)

# 4. Add to scene tree (use current_scene, not obj.get_parent())
obj.get_tree().current_scene.add_child(particles)

# 5. NOW emit (after everything is set)
particles.emitting = true
```

**Order matters.** Position before add. Add before emit.

---

## Debugging Invisible Effects

When particles don't show, check in order:

1. **Subpixel?** → Check texture size × scale ≥ 2px
2. **z_index?** → Must be 25 for front effects
3. **Position?** → Set BEFORE adding to tree
4. **emitting?** → Must be true after setup
5. **Alpha?** → Check color gradient isn't all zeros
6. **Lifetime?** → Too short = blink and miss
7. **Parent?** → Use current_scene, not arbitrary parent

---

## Design Principles

> "Fitting showmanship, not impulsive showmanship."

Every effect should:
1. ✅ Be **visible** (2-8px final size)
2. ✅ Be **pixel-crisp** (4×4 base texture)
3. ✅ Have **drama** (velocity, arc, color pop)
4. ✅ Fit the **art style** (pixel art, not soft blur)
5. ✅ Tell a **story** (sparks = friction, dust = impact)

Every effect should NOT:
1. ❌ Be invisible (subpixel rendering)
2. ❌ Be cotton balls (oversized textures)
3. ❌ Float aimlessly (needs physics purpose)
4. ❌ Distract (too many, too bright, too long)
5. ❌ Lie (wrong layer, wrong timing)

---

## Quick Reference Card

```
┌─────────────────────────────────────────┐
│     PIXEL PARTICLE CHEAT SHEET          │
├─────────────────────────────────────────┤
│ Texture:    4×4 px (always)             │
│ Scale:      0.5-1.5 (never > 2.0)       │
│ Final size: 2-6 px (sweet spot)         │
│ z_index:    25 (EFFECT_FRONT)           │
│ Amount:     12-20 (standard)            │
│ Velocity:   30-80 (drama)               │
│ Lifetime:   0.3-0.6s (visible arc)      │
│ Gravity:    +/- 40-80 (physics)         │
└─────────────────────────────────────────┘
```

---

## Revision History

| Date | Change | Reason |
|------|--------|--------|
| 2025-12-16 | Initial doctrine | Established pixel art particle standards after cotton ball incident |

---

*"We make games. We make them visible. We make them pixel-perfect."*
— FoxyAdventure Team
