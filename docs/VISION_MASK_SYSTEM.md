# Cave Darkness System - How Light Blocking Works

## The Simple Truth

Godot's 2D lighting system DOES work for "can't see behind walls":

1. **CanvasModulate** → Darkens everything uniformly
2. **PointLight2D** → Creates illuminated circle around player
3. **LightOccluder2D** → Blocks light rays = creates shadows

When a wall blocks light, the area behind it is **dark** (in shadow).
Player can't see into dark areas = effective "fog of war".

---

## Your Setup (Already Mostly Done!)

### ✅ Player Torch (Working)
- `PlayerTorch` node on Foxy
- `shadow_enabled = true`
- Creates light circle with shadows

### ✅ Wall.tscn (Working)
- Has `LightOccluder2D` node
- Walls will block light when used

### ❌ TileSet Tiles (MISSING!)
**This is the problem.** Your levels use `TileMapLayer` with tiles, not wall.tscn.

Tiles need **occlusion polygons** added to the TileSet to block light.

---

## How to Fix: Add Occlusion to TileSet

1. Open `assets/island/terrain/ice_tile_set.tres` in editor
2. Select the **TileSet** panel at bottom
3. Click on a tile that should block light (walls, ground)
4. In the **Physics** section, find **Occlusion**
5. Click **+ Add Occlusion Layer**
6. Draw a polygon covering the solid area of the tile
7. Repeat for ALL tiles that should block light

**Current state:** Only tile 2:6 has occlusion. All other tiles let light through!

---

## VisionMaskSystem (Simple Version)

Now just a CanvasModulate wrapper with documentation:

```gdscript
# It's just CanvasModulate with a custom color
# Add to level for overall darkness tint
# The REAL work is done by:
# - PlayerTorch (PointLight2D with shadows)
# - Tile occlusion polygons (in TileSet)
```

### Properties
| Property | Default | Description |
|----------|---------|-------------|
| `darkness_color` | (0.1, 0.1, 0.15) | Overall darkness tint |

---

## Quick Test

After adding occlusion to tiles:
1. Run level_3_1
2. Fox's torch should illuminate surroundings
3. Walls/ground should cast shadows
4. Areas behind walls should be dark (in shadow)

If light still passes through walls → those tiles don't have occlusion polygons.

---

## Files

| File | Purpose |
|------|---------|
| `environment/cave/vision_mask_system.gd` | CanvasModulate with docs |
| `environment/cave/vision_mask_system.tscn` | Ready-to-use darkness |
| `player/player_torch.gd` | Torch with shadows |
| `assets/island/terrain/ice_tile_set.tres` | **Needs occlusion on tiles!** |
