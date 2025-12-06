# TileMap Light Occlusion Setup Guide

## Overview
For Level 3's darkness mechanic to work properly, **solid terrain tiles must block light**. This is done through the TileSet's **Occlusion Layer** feature in Godot 4.

Light Occlusion System:
- **CanvasModulate** dims everything uniformly
- **PointLight2D** creates illuminated circles
- **Occlusion Layer** on tiles blocks light rays (creates shadows)
- Result: Atmospheric darkness with walls blocking light

## The Problem
Without occlusion, light from crystals/torches passes through walls, letting Foxy see into areas that should be dark. We need tiles that block light to create true darkness.

---

## Setup Steps (In Godot Editor)

### Step 1: Add Occlusion Layer to TileSet

1. Open your TileSet resource (`assets/tileset.tres` or `assets/island/terrain/ice_tile_set.tres`)
2. In the TileSet panel, click on **"Rendering"** section
3. Click the **"+"** button next to **"Occlusion Layers"**
4. This adds `occlusion_layer_0`

### Step 2: Configure Occlusion for Each Solid Tile

For each tile that should block light (solid terrain, walls):

1. Select the tile in the TileSet editor
2. Go to the **"Rendering"** tab
3. Under **"Occlusion"**, click to add an occlusion polygon
4. Draw a polygon covering the solid area (for full tiles: just the 32x32 square)

**Quick Method for Full Solid Tiles:**
- Select tile → Rendering → Occlusion Layer 0 → Add polygon
- Points: `(-16, -16), (16, -16), (16, 16), (-16, 16)`

### Step 3: Tiles That Should NOT Occlude

- One-way platforms (player needs to see through)
- Decorative tiles (grass, flowers)
- Background tiles
- Semi-transparent tiles

---

## Automated Script (Optional)

You can run this script to batch-add occlusion to tiles that have physics:

```gdscript
# Run in Godot's script editor or as a @tool script
@tool
extends EditorScript

func _run():
    var tileset = load("res://assets/tileset.tres") as TileSet
    if tileset == null:
        print("Could not load tileset!")
        return
    
    # Ensure occlusion layer exists
    if tileset.get_occlusion_layers_count() == 0:
        tileset.add_occlusion_layer()
        print("Added occlusion layer")
    
    # Iterate all atlas sources
    for source_id in tileset.get_source_count():
        var source = tileset.get_source(tileset.get_source_id(source_id))
        if not source is TileSetAtlasSource:
            continue
        
        var atlas = source as TileSetAtlasSource
        # Iterate all tiles
        for tile_idx in atlas.get_tiles_count():
            var coords = atlas.get_tile_id(tile_idx)
            var tile_data = atlas.get_tile_data(coords, 0)
            
            if tile_data == null:
                continue
            
            # Check if tile has physics (solid)
            if tile_data.get_collision_polygons_count(0) > 0:
                # Add occlusion polygon matching physics
                var physics_polygon = tile_data.get_collision_polygon_points(0, 0)
                if physics_polygon.size() > 0:
                    tile_data.set_occluder(0, _create_occluder(physics_polygon))
                    print("Added occlusion to tile: ", coords)
    
    ResourceSaver.save(tileset, "res://assets/tileset.tres")
    print("Done! Tileset saved.")

func _create_occluder(points: PackedVector2Array) -> OccluderPolygon2D:
    var occluder = OccluderPolygon2D.new()
    occluder.polygon = points
    return occluder
```

---

## Quick Test

1. Add a `CanvasModulate` node to your level with color `Color(0.2, 0.2, 0.25, 1.0)` (dark)
2. Add a `GlowingCrystal` or `PointLight2D` with `shadow_enabled = true`
3. Place solid tiles between the light and camera
4. **Expected**: Light stops at wall edges
5. **If light passes through**: Tiles need occlusion polygons

---

## TileMapLayer Configuration

When using TileMapLayer in your level:

```
TileMapLayer (Terrain)
├── tile_set = your_tileset.tres  (with occlusion layer)
├── rendering_quadrant_size = 16  (default)
└── (tiles placed with occlusion will block light automatically)
```

The TileMapLayer automatically uses the TileSet's occlusion data.

---

## Elements That Cast Shadows

These light sources have `shadow_enabled = true`:
- `GlowingCrystal` - Cave light source
- `PlayerTorch` - Player's torch
- `FlameHazard` (when `emit_light = true`) - Flame hazards

For shadows to work:
1. Light source needs `shadow_enabled = true`
2. Blocking object needs `LightOccluder2D` OR tiles with occlusion layer

---

## Troubleshooting

### "Light passes through tilemap walls"
→ Tileset missing occlusion layer. Add as described above.

### "Everything is dark, can't see anything"
→ CanvasModulate too dark. Try `Color(0.3, 0.3, 0.35, 1.0)` for dim but visible.

### "Shadows look jagged"
→ Increase light's `shadow_filter` property or texture resolution.

### "Performance issues with many lights"
→ Reduce number of shadow-casting lights. Use `cast_shadows = false` on decorative lights.

---

## Cave Tileset Recommendation

For Level 3 cave tiles, you'll want:

| Tile Type | Has Physics | Has Occlusion | Blocks Light |
|-----------|-------------|---------------|--------------|
| Solid wall | ✅ | ✅ | Yes |
| Cave floor | ✅ | ✅ | Yes |
| Cave ceiling | ✅ | ✅ | Yes |
| One-way platform | ✅ | ❌ | No |
| Background decor | ❌ | ❌ | No |
| Crystals (deco) | ❌ | ❌ | No |
| Water surface | ❌ | ❌ | No |
