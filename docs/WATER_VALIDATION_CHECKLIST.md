# Water System Optimization - Validation Checklist

## Pre-Merge Validation Checklist

### Code Review
- [x] All optimizations implemented in `water.gd`
- [x] Critical whirlpool fix applied (`whirlpool.gd` line 394-406)
- [x] Boat sensitivity adjustment applied (`water.gd` line 691)
- [x] No syntax errors in modified files
- [x] Compatibility checks added (`.has("_settled_segments")`)
- [x] Documentation created (3 comprehensive docs)

### Functional Testing
- [ ] **Test 1: Whirlpool on Settled Water**
  - [ ] Load `test/levels/level_3/level_3_1.tscn`
  - [ ] Wait 5 seconds for water to settle
  - [ ] Verify whirlpool forms V-depression
  - [ ] Enable diagnostics, check settled count drops
  - [ ] Screenshot/video: Before and after whirlpool spawn

- [ ] **Test 2: Cascading Interactions**
  - [ ] Place boat on water
  - [ ] Wait for water to settle
  - [ ] Spawn whirlpool under boat (if dynamic spawn available)
  - [ ] Player jumps onto boat from above
  - [ ] Verify splash propagates
  - [ ] Player jumps off boat
  - [ ] Verify boat depression + whirlpool both work
  - [ ] No visual glitches or stuck segments

- [ ] **Test 3: Player Swimming in Whirlpool**
  - [ ] Player enters water at whirlpool edge
  - [ ] Swim toward whirlpool center
  - [ ] Verify pulled toward center
  - [ ] Verify underwater state triggers correctly
  - [ ] Verify swim ripples appear
  - [ ] Jump out of whirlpool
  - [ ] Verify splash on exit

- [ ] **Test 4: Boat Slow Drift**
  - [ ] Create test scene with boat `drift_speed = 15.0`
  - [ ] Enable water diagnostics
  - [ ] Observe boat depression tracking
  - [ ] Verify no jitter or lag in depression movement
  - [ ] Check console: boat movement detection firing

### Performance Validation
- [ ] **Frame Time Measurement**
  - [ ] Open Godot Profiler (Debug > Profiler)
  - [ ] Run `level_3_1.tscn` for 60 seconds
  - [ ] Record average `_process()` time for water node
  - [ ] Expected: <0.5ms average, ~0ms when idle
  - [ ] Screenshot profiler results

- [ ] **Settled Segment Metrics**
  - [ ] Enable `enable_debug_diagnostics = true` on water
  - [ ] Run level for 30 seconds
  - [ ] Check console output: `[WATER AUDIT] settled=X/64`
  - [ ] Expected during idle: settled ≥ 60/64
  - [ ] Expected during activity: settled drops to 40-50/64
  - [ ] Screenshot console output

- [ ] **Memory Leak Check**
  - [ ] Open Godot Memory tab (Debug > Profiler > Memory)
  - [ ] Spawn/despawn whirlpools 10 times
  - [ ] Check total memory usage
  - [ ] Expected: <10KB growth over 10 spawn/despawn cycles
  - [ ] Screenshot memory graph

### Visual Regression Testing
- [ ] **Whirlpool V-Formation**
  - [ ] Compare whirlpool appearance to baseline
  - [ ] Verify depth reaches ~90px at center
  - [ ] Verify smooth V-shape (not choppy)
  - [ ] Verify foam particles rotate correctly

- [ ] **Boat Buoyancy**
  - [ ] Boat floats at correct height above water
  - [ ] Boat sinks when player lands
  - [ ] Boat rises when player jumps off
  - [ ] Boat bobbing motion smooth

- [ ] **Water Splash Response**
  - [ ] Player jump into water creates splash
  - [ ] Splash propagates as waves
  - [ ] Waves dampen naturally
  - [ ] No perpetual oscillation

- [ ] **Swim Ripples**
  - [ ] Player swimming creates periodic ripples
  - [ ] Ripples spaced ~0.12s apart
  - [ ] Ripples proportional to swim speed

### Edge Case Testing
- [ ] **Multiple Water Bodies**
  - [ ] Level with 2+ separate water areas
  - [ ] Each maintains independent settled state
  - [ ] No cross-contamination of segment flags

- [ ] **Rapid State Changes**
  - [ ] Player rapidly entering/exiting water (jump spam)
  - [ ] Boat landing then immediately player landing
  - [ ] Whirlpool spawn then immediate despawn
  - [ ] No crashes or stuck states

- [ ] **Extreme Physics**
  - [ ] Player falls from very high height into water
  - [ ] Verify splash doesn't cause runaway
  - [ ] Check console: no "runaway" warnings

- [ ] **Long-Running Stability**
  - [ ] Leave level running for 5 minutes idle
  - [ ] Periodically create disturbances
  - [ ] Verify no gradual performance degradation
  - [ ] Check memory usage stays constant

### Backward Compatibility
- [ ] **Old Scene Files**
  - [ ] Load level created before optimization
  - [ ] Verify water initializes correctly
  - [ ] Verify no errors about missing properties
  - [ ] Save and reload scene

- [ ] **Mixed Versions**
  - [ ] Scene with old water + new whirlpool
  - [ ] Verify compatibility check works
  - [ ] Verify no errors in console
  - [ ] Verify degraded gracefully (no optimization, but still works)

### Documentation Validation
- [ ] **Code Comments**
  - [ ] Critical sections have explanatory comments
  - [ ] Optimization rationale documented in-line
  - [ ] Wake-up logic clearly explained

- [ ] **External Docs**
  - [ ] `WATER_PHYSICS_OPTIMIZATION.md` accurate
  - [ ] `WATER_ECOSYSTEM_AUDIT.md` complete
  - [ ] `WATER_OPTIMIZATION_SUMMARY.md` matches implementation

### Integration Checks
- [ ] **Git Status**
  - [ ] All changes committed to `feat/level-3` branch
  - [ ] Commit message descriptive
  - [ ] No unintended files modified

- [ ] **Build Verification**
  - [ ] Project exports without errors
  - [ ] Test build runs on target platform
  - [ ] No new warnings in export log

---

## Sign-Off

### Developer
- [ ] All code changes reviewed and tested
- [ ] Performance improvements validated
- [ ] No known bugs or regressions
- **Signed:** _________________ **Date:** _________

### QA
- [ ] All test cases passed
- [ ] Visual quality maintained
- [ ] Performance meets targets
- **Signed:** _________________ **Date:** _________

### Tech Lead
- [ ] Architecture review approved
- [ ] Documentation sufficient
- [ ] Ready for merge to main
- **Signed:** _________________ **Date:** _________

---

## Issues Found During Validation

| Issue | Severity | Description | Status | Notes |
|-------|----------|-------------|--------|-------|
| | | | | |
| | | | | |
| | | | | |

---

## Performance Metrics (Fill During Testing)

### Frame Time
- **Idle water average:** _______ ms
- **Active water average:** _______ ms
- **Peak during cascading interactions:** _______ ms

### Settled Segments
- **Idle percentage:** _______ % (X/64 segments)
- **During whirlpool:** _______ % (X/64 segments)
- **During player swim:** _______ % (X/64 segments)

### Memory
- **Baseline:** _______ MB
- **After 10 whirlpool spawn/despawn:** _______ MB
- **Growth:** _______ KB

---

## Approval for Merge

**All critical tests passed:** [ ] YES [ ] NO

**Performance targets met:** [ ] YES [ ] NO

**No blocking issues:** [ ] YES [ ] NO

**Ready to merge:** [ ] YES [ ] NO

**Merge date:** _________________
