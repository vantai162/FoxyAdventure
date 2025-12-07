# GDScript Property Existence Checking - Quick Reference

## The Issue
When optimizing the water system, we added `_settled_segments` to the water class. Whirlpool needs to check if this property exists (for backward compatibility with old water instances).

## ❌ WRONG - This Crashes
```gdscript
if water_node.has("_settled_segments"):  # CRASH! Node2D doesn't have .has()
```

**Error:** `Invalid call. Nonexistent function 'has' in base 'Node2D'`

## ✅ CORRECT - GDScript Property Checking

### Method 1: `in` Operator (Recommended)
```gdscript
if "_settled_segments" in water_node:
    # Property exists
    water_node._settled_segments[0] = 1
```

### Method 2: `in` + Size Check (Safest)
```gdscript
if "_settled_segments" in water_node and water_node._settled_segments.size() > 0:
    # Property exists AND is initialized
    water_node._settled_segments[0] = 1
```

### Method 3: Try/Catch (Heavy)
```gdscript
if water_node.get("_settled_segments") != null:
    # Property exists
    water_node._settled_segments[0] = 1
```

## Why This Matters

### Node vs Dictionary
- **Dictionary:** `my_dict.has("key")` ✅ Works
- **Node/Object:** `my_node.has("property")` ❌ Doesn't exist
- **Node/Object:** `"property" in my_node` ✅ Works

### Our Use Case (Whirlpool ↔ Water)
```gdscript
# Whirlpool modifies water's segment rest heights
# But needs to check if water has the optimization variables

# BEFORE (crashes):
if water_node.has("_settled_segments"):
    water_node._settled_segments[i] = 0

# AFTER (works):
if "_settled_segments" in water_node and water_node._settled_segments.size() > 0:
    water_node._settled_segments[i] = 0
```

## Lesson Learned
**Don't rely on memory when working with GDScript APIs.** 

The `has()` method is common in many languages for objects/dictionaries, but GDScript uses `in` for Node properties. Always verify the actual API when doing cross-object property access.

## Applied Fixes

### File: `objects/whirlpool/whirlpool.gd`

**Location 1: Line ~410 (`_apply_water_depression`)**
```gdscript
# Fixed compatibility check
if "_settled_segments" in water_node and water_node._settled_segments.size() > 0:
    for segment_idx in affected_range:
        water_node._settled_segments[segment_idx] = 0
```

**Location 2: Line ~267 (`_restore_water_rest_heights`)**
```gdscript
# Fixed compatibility check
if "_settled_segments" in water_node and water_node._settled_segments.size() > 0:
    for segment_idx in affected_range:
        water_node._settled_segments[segment_idx] = 0
```

## Testing Verification

### Before Fix
```
ERROR: Invalid call. Nonexistent function 'has' in base 'Node2D (water)'.
   at: _apply_water_depression (objects/whirlpool/whirlpool.gd:410)
```

### After Fix
✅ No errors, whirlpool correctly wakes up water segments

## Reference
- GDScript Docs: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html#checking-if-a-key-exists
- Use `in` for Node property checking
- Use `.has()` for Dictionary key checking
