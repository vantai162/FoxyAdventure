# Pre-Level-Design Optimization Checklist

**Status:** Ready for level design with minor optimizations recommended  
**Priority:** Medium - Not blocking, but improves workflow and quality

---

## ✅ Already Optimized (No Action Needed)

### 1. Elite Eye Trail System
- ✅ Scene-based (not runtime creation)
- ✅ Shared resources (92% memory reduction)
- ✅ GPU particles (zero CPU cost)
- ✅ UNSHADED + ADDITIVE (darkness penetration + bloom)
- ✅ Shrinking trail effect (scale curve)

### 2. Effect Item Particles
- ✅ All use GPUParticles2D (not CPU)
- ✅ Auto-cleanup implemented
- ✅ One-shot emissions

### 3. Water System
- ✅ Settled segment tracking
- ✅ Active region culling
- ✅ Boat depression dirty tracking
- ✅ Optional lighting system (off by default)

---

## 🔧 Recommended Optimizations

### HIGH IMPACT - Do Before Level Design

#### 1. Float Animation → AnimationPlayer
**Current:** CPU `_process()` updates position every frame  
**Better:** GPU AnimationPlayer with looped track

**Files to update:**
- `effect_Item/key/key.gd`
- `effect_Item/coin/coin.gd`
- `effect_Item/heal_potion/health_potion.gd`

**Benefits:**
- Zero CPU cost (GPU interpolation)
- Designers can edit curves in editor
- Consistent timing across framerates

**Implementation:**
```gdscript
# Before (CPU):
func _process(delta: float):
    _time += delta * float_speed
    position.y = _start_y + sin(_time) * float_amplitude

# After (GPU):
# Add AnimationPlayer to scene with:
# - Track: position:y
# - Keyframes: sine wave
# - Loop: true
# No _process() needed!
```

**Estimated time:** 30 minutes per file = 90 minutes total

---

#### 2. Elite State Validation
**Current:** Crashes with unclear error if state node missing  
**Better:** Clear error messages on startup

**Files to update:** All 6 elite enemy .gd files

**Implementation:**
```gdscript
func _ready() -> void:
    fsm = FSM.new(self, $States, $States/Run)
    super._ready()
    
    # Validate required states exist
    _validate_states(["hunt", "jump"])  # per elite type
    enable_check_player_in_sight()

func _validate_states(required: Array[String]) -> void:
    for state_name in required:
        if not fsm.states.has(state_name):
            push_error("[%s] Missing required FSM state: '%s'. Add States/%s node to scene." 
                % [name, state_name, state_name.capitalize()])
```

**Benefits:**
- Catch configuration errors immediately
- Clear error messages for level designers
- No runtime crashes

**Estimated time:** 15 minutes per elite = 90 minutes total

---

#### 3. Export Dependency Validation
**Current:** Push warnings (easy to miss)  
**Better:** Validate exports with clear errors

**Files:**
- `enemy/aggressive_tribe/elite_bombardier.gd` (special_coconut_scene)
- `enemy/turtle/elite_spiny_turtle.gd` (spike_projectile_scene)
- `enemy/mushroom/elite_spawner_mushroom.gd` (mini_mushroom_scene)

**Implementation:**
```gdscript
func _ready() -> void:
    super._ready()
    
    if not mini_mushroom_scene:
        push_error("[%s] Export 'mini_mushroom_scene' not assigned! Assign mini_mushroom.tscn in inspector." % name)
        set_physics_process(false)  # Disable to prevent further errors
        return
```

**Benefits:**
- Immediate feedback on misconfiguration
- Prevents broken enemy behavior in levels
- Better error messages than crashes

**Estimated time:** 10 minutes per file = 30 minutes total

---

### MEDIUM IMPACT - Nice to Have

#### 4. Ricochet Starfish Cooldown Visual
**Current:** No indicator when starfish can attack  
**Better:** Eye pulse or particle effect during cooldown

**Files:**
- `enemy/starfish/elite_ricochet_starfish.gd`
- `enemy/elite_eye_trail.tscn` (optional shader variant)

**Implementation Options:**
A. **Simple:** Dim eye trail during cooldown
```gdscript
func _physics_process(delta: float):
    if attack_cooldown_timer > 0.0:
        attack_cooldown_timer -= delta
        # Dim eyes during cooldown
        $Direction/EliteEyeTrail.modulate.a = 0.3
    else:
        $Direction/EliteEyeTrail.modulate.a = 1.0
```

B. **Advanced:** Pulse effect
- Add AnimationPlayer to elite_eye_trail.tscn
- Trigger "cooldown" animation
- Pulse between 0.3-1.0 alpha

**Benefits:**
- Better player telegraphing
- Reduces frustration (players know when it's safe)
- Visual polish

**Estimated time:** 20 minutes (simple) or 60 minutes (advanced)

---

#### 5. Key Particle Texture
**Current:** Particles have no texture (white blobs)  
**Better:** Use actual sparkle texture

**Files:**
- `effect_Item/key/key.gd` line 73-83

**Implementation:**
```gdscript
func _spawn_pickup_particles() -> void:
    var particles = GPUParticles2D.new()
    # ... existing setup ...
    
    # Add texture (create 8×8 sparkle image or reuse existing)
    particles.texture = preload("res://textures/sparkle.png")  # Create this
    
    # ... rest of code ...
```

**Benefits:**
- Visual polish
- Clearer feedback to player

**Estimated time:** 30 minutes (if texture exists) or 60 minutes (create texture)

---

### LOW IMPACT - Polish Pass

#### 6. Spawner Mushroom Minion Tracking
**Current:** Manual array cleanup  
**Better:** WeakRef or group-based tracking

**Files:**
- `enemy/mushroom/elite_spawner_mushroom.gd`

**Current implementation is fine.** Cleanup loop is efficient. Only optimize if profiling shows hotspot (unlikely).

**Estimated time:** 30 minutes (if needed)

---

#### 7. Elite Shader Edge Detection
**Current:** 4 texture samples per pixel in shader  
**Better:** Pre-bake edge glow in texture alpha channel

**Files:**
- `enemy/elite_enemy.gdshader`
- All elite sprite textures

**Analysis:**
- Current: ~4 samples/pixel × 32×32 avg sprite = 4K samples/frame/enemy
- With 8 elites = 32K samples (negligible on GPU)
- Pre-bake: 0 samples, but requires texture edits

**Recommendation:** **Don't optimize.** GPUs handle this trivially. Pre-baking removes artist flexibility.

**Estimated time:** N/A - Not recommended

---

## 📊 Optimization Priority Matrix

| Optimization | Impact | Effort | Priority | Status |
|--------------|--------|--------|----------|--------|
| Float → AnimationPlayer | High | 90min | 🔴 HIGH | Recommended |
| Elite State Validation | High | 90min | 🔴 HIGH | Recommended |
| Export Validation | High | 30min | 🔴 HIGH | Recommended |
| Cooldown Visual | Medium | 20-60min | 🟡 MEDIUM | Nice to have |
| Key Sparkle Texture | Medium | 30-60min | 🟡 MEDIUM | Nice to have |
| Minion Tracking | Low | 30min | 🟢 LOW | Skip unless profiling shows issue |
| Shader Edge Detect | Low | N/A | 🟢 LOW | Don't optimize |

---

## ⏱️ Time Estimates

### Minimum Viable (HIGH priority only):
- Float animations: 90 minutes
- State validation: 90 minutes
- Export validation: 30 minutes
- **Total: 3.5 hours**

### Recommended (HIGH + MEDIUM):
- Above + Cooldown visual: +20 minutes
- Above + Key sparkle: +30 minutes
- **Total: 4 hours 20 minutes**

### Complete Polish:
- Above + All optimizations
- **Total: 5-6 hours**

---

## 🎯 Recommendation

**Do HIGH priority before level design:**
- Prevents designer frustration (clear errors)
- Removes CPU bottlenecks (float animations)
- Improves workflow (immediate validation feedback)

**Do MEDIUM during level design:**
- As time permits between level iterations
- Ricochet visual after first starfish encounter designed

**Skip LOW priority:**
- Profile first, optimize only if needed
- Current performance is acceptable

---

## ✅ Definition of "Production Ready"

### Minimum Bar (HIGH priority complete):
- ✅ No CPU graphics processing
- ✅ Clear error messages for misconfigurations
- ✅ No silent failures
- ✅ Stable 60fps with 10+ enemies

### Ideal Bar (HIGH + MEDIUM complete):
- ✅ Visual polish (sparkles, pulses)
- ✅ Good player telegraphing
- ✅ Designer-friendly (edit animations in editor)
- ✅ Stable 60fps with 15+ enemies

---

## 🚀 Action Plan

### Week 1 (Before level design):
**Day 1:** Float animations → AnimationPlayer (90min)  
**Day 2:** Elite state validation (90min)  
**Day 3:** Export validation (30min) + Testing (60min)

**Deliverable:** All HIGH priority complete, system stable

### Week 2-3 (During level design):
**As needed:** Add cooldown visual, key sparkles  
**Ongoing:** Profile, test, iterate

**Deliverable:** Polished, production-ready

---

## 📝 Notes for Future You

### What NOT to optimize:
- ❌ Elite shader (GPU handles easily)
- ❌ Tween usage (lightweight, standard pattern)
- ❌ Audio node creation (necessary, minimal cost)
- ❌ GPUParticles (already optimal)

### When to optimize:
- ✅ If profiler shows specific hotspot
- ✅ If framerate drops below 60fps
- ✅ If designer workflow is painful

### Philosophy:
**"Make it work, make it right, make it fast."**  
We're at "make it right" phase. Most systems are fast enough.  
Focus on workflow quality, not premature optimization.
