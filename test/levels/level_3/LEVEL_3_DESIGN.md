# LEVEL 3: THE SUNKEN DEPTHS
## Complete Experience Design Document
*Last Updated: 32px Tile Grid Validation*

---

## ⚠️ CRITICAL: TILEMAPPING REFERENCE (32px GRID)

### Tileset Unit
**1 TILE = 32×32 PIXELS** (from `assets/tileset.tres`)

### Wall Primitive (wall.tscn)
- **Base collision size**: 128×128 pixels = **4×4 tiles**
- **Position = CENTER of wall** (not corner!)

### Wall Scale Reference
| Scale | Pixel Size | Tile Size | Use For |
|-------|------------|-----------|---------|
| `(1, 1)` | 128×128 | 4×4 | Standard blocks |
| `(2, 0.5)` | 256×64 | 8×2 | Wide floor/ceiling |
| `(0.5, 2)` | 64×256 | 2×8 | Tall pillars/walls |
| `(0.5, 0.5)` | 64×64 | 2×2 | Small blocks |
| `(2, 1)` | 256×128 | 8×4 | Wide thick platforms |
| `(1, 0.5)` | 128×64 | 4×2 | Floor segments |

### Wall Position Math
Wall at position `(X, Y)` with scale `(sX, sY)` covers:
- X range: `X - (64×sX)` to `X + (64×sX)`
- Y range: `Y - (64×sY)` to `Y + (64×sY)`

**Example**: Wall at `(352, 240)` with scale `(0.5, 1)`:
- X: 352 - 32 = 320 to 352 + 32 = 384 → **tiles 10-11**
- Y: 240 - 64 = 176 to 240 + 64 = 304 → **tiles 5.5-9.5** (centered)

### Player Physics (for gap/height validation)
| Ability | Value | In Tiles (32px) |
|---------|-------|-----------------|
| Jump velocity | 320 | ~2.3 tiles height |
| Double jump | +256 (80%) | ~1.5 tiles more |
| **Total max height** | - | **~3.8 tiles** |
| Run speed | 300 px/s | ~9.4 tiles/s |
| Dash | 120 px burst | 3.75 tiles |
| Max gap (running double jump) | ~320px | **~10 tiles** |

### Validation Checklist
- [ ] Can player jump to reach platform? (gap ≤ 10 tiles, height ≤ 3.8 tiles)
- [ ] Are spike walls blocking wall-cling? (2+ tiles continuous)
- [ ] Is floor under spawn position? (player Y should be ABOVE floor Y)
- [ ] Are one-way platforms jumpable through? (check Y positions)

---

## HOW TO NAVIGATE (Wayfinding Guide)

### COLOR CODE (in-scene labels)
| Color | Meaning |
|-------|---------|
| 🟢 **Green** | Start point / Safe path / Exit |
| 🟡 **Yellow** | Key junction / Checkpoint / Important |
| 🟠 **Orange** | Warning / Challenge ahead |
| 🔴 **Red** | Danger / Point of no return |
| 🔵 **Blue** | Water zone / Special path |
| 🟣 **Purple** | Secret / Optional reward |

---

### LEVEL 3-1: "THE DESCENT"
**SIZE: 1024×896 pixels = 32×28 tiles (32px grid)**

```
32px TILE GRID (Y increases downward, X increases right):

	 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
	 0       64     128     192     256     320     384     448      512     X→
   ┌─────────────────────────────────────────────────────────────────┐
 0 │████████████████████████████████████████████████████████████████│ Y=0
 1 │████████████████████████████████████████████████████████████████│ 
 2 │████░░░░░░░░████████████████████████████████████████████████████│ Y=64  SPAWN
 3 │████░S░░░░░░████████████████████████████████████████████████████│       (tile 4,3)
 4 │████████████████····················████████████████████████████│ Y=128 
 5 │████████████████····················████████████████████████████│
 6 │████████████▲▲▲▲····················▲▲▲▲████████████████████████│ Y=192 THROAT
 7 │████████████▲▲▲▲····················▲▲▲▲████████████████████████│       (spike walls)
 8 │████████████▲▲▲▲····················▲▲▲▲████████████████████████│ Y=256 
 9 │████████████▲▲▲▲····················▲▲▲▲████████████████████████│
10 │████··················································██████████│ Y=320 CAVERN  
11 │████··················································██████████│
12 │████░░░░────────────────░░░░░░░░░░░░░░░░░░░░░░░░░░████████████│ Y=384 (bridge+floor)
13 │████░🦀░░░░░░░░░░░░░░░░░░🦀░░░░░░░░░░░░░░░░░░░░░░░████████████│
14 │████████████████████████████████████████····················████│ Y=448 
15 │████████████████████████████████████████····················████│
16 │████····████████████████████████████████····≈≈≈≈············████│ Y=512 BRANCH
17 │████▲💰▲████████████████████████████████····≈≈≈≈············████│       (water/trap)
18 │████████████████████████████████████████····≈≈≈≈············████│ Y=576
19 │████████████████████████████████████████····≈≈≈≈············████│
20 │████████████████████████████████████████░░░░░░░░░░░░░░░░░░██████│ Y=640 EXIT
21 │████████████████████████████████████████░░░░░░░░░░░░░░░░░░██████│
22 │████████████████████████████████████████████████████████░→░█████│ Y=704 (exit door)
23 │████████████████████████████████████████████████████████████████│
24 │████████████████████████████████████████████████████████████████│ Y=768
25 │████████████████████████████████████████████████████████████████│
26 │████████████████████████████████████████████████████████████████│ Y=832
27 │████████████████████████████████████████████████████████████████│
   └─────────────────────────────────────────────────────────────────┘

LEGEND:
  ████ = SOLID WALL (player cannot pass)
  ░░░░ = WALKABLE FLOOR (player walks here)  
  ···· = AIR (player falls/jumps through)
  ≈≈≈≈ = WATER (player swims)
  ▲▲▲▲ = SPIKES (damage on touch - prevents wall-cling cheese!)
  ──── = ONE-WAY PLATFORM (can jump through from below)
  
MARKERS:
  S   = Spawn point (tile 4,3 = pixel 128,96)
  🦀  = Crab enemy
  💰  = Trap coins (in dead end - bait!)
  →   = Exit to 3-2

CRITICAL GAMEPLAY NOTES:
  - Throat gap: 6 tiles wide (192px) = EASILY JUMPABLE (max ~10 tiles)
  - Spike walls: 4 tiles tall = BLOCKS WALL-CLING CHEESE
  - Cavern floor: Y=416 = safe landing after throat drop
  - Water tunnel: tiles 20-23, rows 16-19 = swim through to exit
  - Dead end trap: tiles 2-5, row 17 = floor spikes (don't be greedy!)
```

**Design Intent:**
- Throat has SPIKE WALLS = cannot wall-cling, must commit to drop
- Dead end has coins = bait for greedy players, spikes punish
- Water passage = forced underwater section, teaches swim
- Linear funnel teaches COMMITMENT before giving choices

---

### LEVEL 3-2: "THE DEPTHS"
**NEW FUNNELED LAYOUT - 768×1600 pixels (12×25 cells) - VERTICAL**

```
COORDINATE GRID (each cell = 64px):

	   0   1   2   3   4   5   6   7   8   9  10  11
	   0  64 128 192 256 320 384 448 512 576 640 704 768
	 ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
  0  │███│███│███│███│███│███│███│███│███│███│███│███│ Y=0-64
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  1  │███│ S │░░░│░░░│░░░│░░░│███│███│███│███│███│███│ Y=64-128  OVERLOOK
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  2  │███│███│███│███│ · │ · │███│███│███│███│███│███│ Y=128-192
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  3  │███│███│███│███│ · │ · │███│███│███│███│███│███│ Y=192-256
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  4  │███│███│▲▲▲│▲▲▲│ · │ · │▲▲▲│▲▲▲│███│███│███│███│ Y=256-320
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ SPIKE SHAFT
  5  │███│███│▲▲▲│───│ · │ · │───│▲▲▲│███│███│███│███│ Y=320-384
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  6  │███│███│▲▲▲│ · │───│ · │ · │▲▲▲│███│███│███│███│ Y=384-448
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  7  │███│███│▲▲▲│───│ · │ · │───│▲▲▲│███│███│███│███│ Y=448-512
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  8  │███│███│▲▲▲│ · │───│ · │ · │▲▲▲│███│███│███│███│ Y=512-576
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  9  │███│███│▲▲▲│───│ · │ · │───│▲▲▲│███│███│███│███│ Y=576-640
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 10  │███│░░░│░░░│░✓░│░░░│░░░│░░░│░░░│░░░│███│███│███│ Y=640-704 SHRINE
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ (checkpoint)
 11  │███│███│███│███│███│███│███│ · │ · │███│███│███│ Y=704-768
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 12  │███│███│███│███│███│███│███│▲▲▲│ · │███│███│███│ Y=768-832
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 13  │███│███│███│███│███│███│███│▲▲▲│ · │███│███│███│ Y=832-896
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 14  │███│███│███│███│███│███│███│▲▲▲│ · │███│███│███│ Y=896-960
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 15  │███│░░░│░░░│░░░│░🛡️│░░░│░░░│▲▲▲│ · │███│███│███│ Y=960-1024 CORRIDOR
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ (low ceiling)
 16  │███│███│███│░░░│░░░│░░░│░░░│░░░│ · │███│███│███│ Y=1024-1088
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 17  │███│███│███│███│███│███│███│███│ · │███│███│███│ Y=1088-1152
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 18  │███│███│███│███│███│███│███│▲▲▲│ · │▲▲▲│███│███│ Y=1152-1216
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ LOWER SHAFT
 19  │███│███│███│███│███│███│███│▲▲▲│───│▲▲▲│███│███│ Y=1216-1280
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 20  │███│███│███│███│███│███│███│▲▲▲│ · │▲▲▲│███│███│ Y=1280-1344
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 21  │███│███│███│███│███│███│███│▲▲▲│───│▲▲▲│███│███│ Y=1344-1408
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 22  │███│███│░░░│░░░│░░░│≈≈≈│≈≈≈│≈≈≈│≈≈≈│░░░│░✓░│███│ Y=1408-1472 LAKE
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 23  │███│███│███│███│███│███│███│███│███│███│→3-3│███│ Y=1472-1536
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 24  │███│███│███│███│███│███│███│███│███│███│███│███│ Y=1536-1600
	 └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

LEGEND:
  ███ = SOLID WALL       ▲▲▲ = SPIKE WALL (no wall-cling!)
  ░░░ = FLOOR            ─── = ONE-WAY PLATFORM
  · · = AIR              ≈≈≈ = WATER
  ✓   = CHECKPOINT       🛡️  = SHIELD TRIBE ENEMY
  →   = EXIT

FLOW:
  OVERLOOK → See the shaft below, one-way drop
  SPIKE SHAFT → Alternating platforms, spike walls prevent cheese
  SHRINE → Checkpoint, safe zone
  CORRIDOR → LOW CEILING, Shield Tribe, MUST FIGHT (can't jump over)
  LOWER SHAFT → More spike wall descent
  LAKE → Water area, exit to 3-3
```

**Design Intent:**
- VERTICAL level = feels like descent into depths
- Spike walls on BOTH sides of shaft = no wall-cling escape
- Low ceiling corridor = forces ground combat with Shield Tribe
- Staggered one-way platforms = controlled fall, must use them

---

### LEVEL 3-3: "THE RUINS"
**NEW FUNNELED LAYOUT - 1280×960 pixels (20×15 cells) - HUB PUZZLE**

```
COORDINATE GRID (each cell = 64px):

	   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19
	   0  64 128 192 256 320 384 448 512 576 640 704 768 832 896 960 1024 1088 1152 1216 1280
	 ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
  0  │███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  1  │███│ S │░░░│░░░│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│ ANTECHAMBER
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  2  │███│░░░│░░░│░░░│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  3  │███│███│ · │███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  4  │███│ · │ · │ · │███│███│ · │ · │ · │ · │ · │ · │ · │ · │███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  5  │███│ · │🔒│ · │ · │ · │ · │ · │ · │ · │ · │ · │ · │ · │███│███│███│███│███│███│ CENTRAL HALL
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ (LOCKED DOOR)
  6  │███│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  7  │███│███│ · │███│███│███│███│███│███│███│███│███│ · │███│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  8  │███│ · │ · │ · │██│███│███│███│███│███│███│███│ · │ · │ · │███│███│███│███│███│ ←WEST     EAST→
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤  WING     WING
  9  │███│🥥│ · │⚙A│███│███│███│███│███│███│███│███│≈≈│≈🌀│⚙B│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 10  │███│░░░│░░░│░░░│███│███│███│███│███│███│███│███│░░░│░░░│░░░│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 11  │███│███│███│███│███│███│███│ · │ · │███│███│███│███│███│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 12  │███│███│███│███│███│███│░✓░│░░░│░░░│███│███│███│███│███│███│███│███│███│███│███│ EXIT
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 13  │███│███│███│███│███│███│███│→3-4│███│███│███│███│███│███│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 14  │███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│
	 └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

LEGEND:
  ███ = SOLID WALL       🔒 = LOCKED DOOR (needs both levers)
  ░░░ = FLOOR            ⚙A = LEVER A (West Wing)
  · · = AIR              ⚙B = LEVER B (East Wing)
  ≈≈≈ = WATER            🥥 = AGGRESSIVE TRIBE (throws!)
  🌀  = WHIRLPOOL        ✓  = CHECKPOINT
  →   = EXIT

FLOW:
  ANTECHAMBER → Safe entry, catch breath
  CENTRAL HALL → See LOCKED DOOR, need both levers
  WEST WING → Combat path, Aggressive Tribe, LEVER A
  EAST WING → Water puzzle, Whirlpool, LEVER B
  Both levers → Door opens → EXIT
```

**Design Intent:**
- Two-wing puzzle = player choice, both required
- West = combat challenge (dodge coconuts, hit lever)
- East = water puzzle (drain/navigate whirlpool, hit lever)
- Central hub = see the goal (locked door) before paths
- Forced exploration of BOTH sides

---

### LEVEL 3-4: "THE GAUNTLET"
**NEW FUNNELED LAYOUT - 1024×768 pixels (16×12 cells) - LINEAR INTENSITY**

```
COORDINATE GRID (each cell = 64px):

	   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
	   0  64 128 192 256 320 384 448 512 576 640 704 768 832 896 960 1024
	 ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
  0  │███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  1  │███│ S │░░░│███│███│███│███│███│███│███│███│███│███│███│███│███│ ENTRY
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ "no return"
  2  │███│░░░│░░░│░░░│▲·│·▲│·▲│·▲│·▲│▲·│·▲│░░░│░░░│░░░│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ SPIKE CORRIDOR
  3  │███│███│███│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│███│███│███│ (retractable)
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  4  │███│🦀│ · │ · │ · │ · │ · │ · │ · │ · │ · │ · │ · │ · │🦀│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ CROSSFIRE
  5  │███│ · │ · │ · │▓▓│ · │ · │ · │▓▓│ · │ · │ · │▓▓│ · │ · │███│ (use cover!)
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  6  │███│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  7  │▓▓▓│▓▓▓│←←│←←│←←│←←│←←│←←│░░░│░░░│░░░│░░░│░░░│░░░│███│███│ WIND TUNNEL
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ (fight wind!)
  8  │███│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  9  │███│░✓░│░░░│░░░│███│███│███│███│███│███│███│███│███│███│███│███│ CHECKPOINT
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
 10  │███│███│███│ · │▲▲▲│───│───│───│▲▲▲│███│███│███│███│███│███│███│ FINAL CLIMB
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ (spike walls)
 11  │███│███│███│░░░│░░░│░░░│→3-5│░░░│░░░│███│███│███│███│███│███│███│
	 └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

LEGEND:
  ███ = SOLID WALL       ▲▲▲ = SPIKE (damage)
  ░░░ = FLOOR            ▲· = RETRACTABLE SPIKE (timing!)
  · · = AIR              ▓▓▓ = SPIKE WALL (no wall-cling)
  ←← = WIND (pushes left) 🦀 = SEAHORSE (shoots across!)
  ▓▓ = COVER BLOCK       ✓  = CHECKPOINT
  ─── = ONE-WAY PLATFORM  →  = EXIT

FLOW:
  ENTRY → "Point of no return" sign
  SPIKE CORRIDOR → Retractable spikes, timing challenge
  CROSSFIRE ROOM → Seahorses on BOTH sides, use cover blocks!
  WIND TUNNEL → Wind pushes left, spike wall on left = MUST fight wind
  CHECKPOINT → Mercy before final climb
  FINAL CLIMB → Spike walls, platforms, exit to boss
```

**Design Intent:**
- LINEAR = escalating tension, no backtracking
- Spike corridor = rhythm platforming
- Crossfire = two enemies, player in middle, cover blocks = strategy
- Wind tunnel = environmental + hazard combo (blown into spikes!)
- Final climb = spike walls prevent cheese

---

### LEVEL 3-5: "THE HEART" (BOSS)
**NEW FUNNELED LAYOUT - 896×640 pixels (14×10 cells) - BOSS ARENA**

```
COORDINATE GRID (each cell = 64px):

	   0   1   2   3   4   5   6   7   8   9  10  11  12  13
	   0  64 128 192 256 320 384 448 512 576 640 704 768 832 896
	 ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
  0  │███│███│███│███│███│███│███│███│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  1  │███│ S │░░░│░░░│░░░│███│███│███│███│███│███│███│███│███│ ENTRY
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ (door closes!)
  2  │███│███│███│🚪│███│███│███│███│███│███│███│███│███│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  3  │███│ · │ · │ · │ · │ · │ · │ · │ · │ · │ · │ · │ · │███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  4  │███│ · │ · │▓▓│ · │ · │🐢│ · │ · │▓▓│ · │ · │ · │███│ BOSS ARENA
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ (pillars for cover)
  5  │███│ · │ · │▓▓│ · │≈≈≈│≈≈≈│≈≈≈│ · │▓▓│ · │ · │ · │███│ (water = hazard)
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  6  │███│ · │ · │▓▓│ · │ · │ · │ · │ · │▓▓│ · │ · │ · │███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  7  │███│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│░░░│███│
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  8  │███│███│███│███│███│███│🔒│🔒│███│███│███│███│███│███│ EXIT
	 ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤ (locked until
  9  │███│███│███│███│███│░✓░│░★░│░░░│███│███│███│███│███│███│  boss dead)
	 └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘

LEGEND:
  ███ = SOLID WALL       🚪 = ENTRY DOOR (closes behind!)
  ░░░ = FLOOR            🔒 = EXIT DOOR (locked until victory)
  · · = AIR              🐢 = BOSS (Warlord Turtle)
  ≈≈≈ = WATER (hazard!)  ▓▓ = PILLAR (cover during fight)
  ✓  = CHECKPOINT        ★  = VICTORY (chest appears)

FLOW:
  ENTRY → Walk in, door SLAMS SHUT behind you
  BOSS ARENA → Fight Warlord Turtle!
	- Use pillars for cover from projectiles
	- Avoid water (slows you, he's faster there)
	- Phase 1: Basic attacks
	- Phase 2 (50% HP): Faster, more aggressive
  VICTORY → Boss dies, exit door opens, checkpoint + reward
```

**Design Intent:**
- Compact arena = intimate, intense boss fight
- Door closes behind = NO ESCAPE, commitment
- Pillars = tactical cover, not hiding spots
- Water in center = positioning matters (boss can use it)
- Exit locked = must defeat boss to proceed

---

## DESIGN PHILOSOPHY

**Core Principle:** Every element serves the EXPERIENCE, not just fills space.

**Emotional Arc:** CURIOSITY → UNEASE → FEAR → MASTERY → TRIUMPH

**What Makes This Level Memorable:**
- Multiple enemy types used in COMBINATION
- Environmental hazards that INTERACT with combat
- Route choices that TEST player agency
- Puzzle systems that reward THINKING
- A boss fight that VALIDATES everything learned

---

## INVENTORY AUDIT: What We Have to Work With

### ENEMIES (By Complexity Tier)

| Enemy | Behavior | Difficulty | Best Used For |
|-------|----------|------------|---------------|
| **Crab** | Basic patrol | ★☆☆ | Introductions, filler |
| **Turtle** | Patrol, hide when hit | ★★☆ | Timing challenges |
| **Starfish** | Static/slow patrol | ★☆☆ | Platform hazards |
| **Mushroom** | Patrol + spore release | ★★☆ | Area denial, timing |
| **Tribe** | Patrol, flee when spotted | ★★☆ | Tension building |
| **Aggressive Tribe** | Throws coconuts (burst, predictive) | ★★★ | Ranged pressure |
| **Shield Tribe** | Blocks front, spear thrust, back-attack vulnerable | ★★★★ | Skill tests, positioning puzzles |
| **Seahorse** | Ranged shooter, bullet projectiles | ★★★☆ | Water zones, sniping threats |
| **King Crab** | BOSS - dive, claw, roll, coconuts, phases | ★★★★★ | Boss arena |

### ENVIRONMENTAL HAZARDS

| Hazard | Mechanic | Best Used For |
|--------|----------|---------------|
| **Flame** | Cyclic damage (start→active→end) | Timing corridors |
| **Spike Static** | Instant damage | Death pits, precision |
| **Spike Retractable** | Tween up/down cycle | Rhythm platforming |
| **Spike Wall Moving** | Horizontal threat | Escape sequences |
| **Whirlpool** | Pulls player, damages at center, affects water | Water terror |
| **Wind Area** | Applies force vector to player | Precision disruption |
| **Death Zone** | Instant kill | Stakes, no-fall areas |
| **Water** | Swim mechanics, slower | Pace change, seahorse home |

### INTERACTIVE OBJECTS

| Object | Mechanic | Best Used For |
|--------|----------|---------------|
| **Timer Lever** | Temporary gate open | Timed puzzles |
| **Lever** | Permanent toggle | Progression gates |
| **Gate** | Blocks passage | Puzzle locks |
| **Collapsable Wall** | Breaks with player_attack | Secrets, shortcuts |
| **Spring** | Launch player upward | Vertical traversal |
| **One-Way Platform** | Drop-through | Layered vertical play |
| **Checkpoint** | Respawn point | Pacing, mercy |
| **Camp Fire** | Light source + atmosphere | Safe zones |

### COLLECTIBLES & ITEMS

| Item | Effect | Best Used For |
|------|--------|---------------|
| **Coin** | Currency/score | Breadcrumbs |
| **Trap Coin** | Triggers ambush/stun | Paranoia teaching |
| **Key** | Opens specific locks | Progression |
| **Heal Potion** | Restore health | Mercy before hard sections |
| **Blade Item** | Weapon/ability unlock | Power spikes |
| **Chest** | Contains rewards | Exploration goals |

---

## THE FIVE-ACT STRUCTURE

### ═══════════════════════════════════════════════════════════════
### ACT 1: "THE TWILIGHT DESCENT" (Level 3-1)
### ═══════════════════════════════════════════════════════════════
**Theme:** Curiosity → Unease  
**Lighting:** Dim twilight (0.75, 0.7, 0.85)  
**Duration:** ~3-4 minutes  
**Size:** ~3200x2800 (massive cave system)

#### THE EXPERIENCE:
Player enters cave mouth. Light dims gradually. This world is different - 
vertical, dark, mysterious. Basic enemies introduce cave combat. Hidden paths
reward exploration. The descent begins.

#### ZONE BREAKDOWN:

**Zone A: Entry Cavern (Y: 64-500)**
```
PURPOSE: Safe introduction, teach "this is a cave"
TERRAIN: Wide open, stalactite decorations above
ENEMIES: 2-3 Crabs patrolling platforms
HAZARDS: None - pure learning
ITEMS: Coins as breadcrumbs, Sign ("The old mines run deep...")
CHECKPOINT: Yes, at entry
```

**Zone B: Upper Passage (Y: 500-1000)**
```
PURPOSE: First tension, introduce timing
TERRAIN: Narrower corridors, one-way platforms down
ENEMIES: 2 Turtles (teaches patience - they hide!)
HAZARDS: 2 Flames cycling (timing lesson)
SECRETS: Collapsable Wall → coin cache
```

**Zone C: The Central Shaft (X: 1000-2000, Y: 700-1800)**
```
PURPOSE: Vertical challenge, establish stakes
TERRAIN: Tall shaft with platforms on walls
ENEMIES: 1-2 Mushrooms on ledges (spore timing!)
HAZARDS: 
  - Wind Area blowing horizontally (disrupts jumps)
  - Retractable Spikes on walls (rhythm)
CHECKPOINT: Mid-shaft platform
SPRING: At bottom for recovery
```

**Zone D: Lower Cavern (Y: 1600-2200)**
```
PURPOSE: Enemy density increases
TERRAIN: Wide area, multiple platform levels
ENEMIES:
  - 2 Mushrooms (area denial with spores)
  - 1 Tribe (flees when spotted - what is it running from?)
HAZARDS: Flame corridor
ITEMS: Heal Potion (guarded by Mushroom)
```

**Zone E: Underground Lake (Y: 2000-2600, right side)**
```
PURPOSE: Introduce water, pace shift
TERRAIN: Large water pool with platforms above
ENEMIES: 2 Crabs in shallows
HAZARDS: Water (swim mechanics)
ITEMS: Coins underwater (exploration reward)
EXIT: Transition to 3-2
```

**Zone F: Crystal Grotto (secret area, left side)**
```
PURPOSE: Reward exploration
ACCESS: Collapsable Wall from Zone D
TERRAIN: Glittering cave chamber
ENEMIES: 2 Starfish
ITEMS: Blade Item OR bonus coins
FEELING: Discovery! Hidden treasure!
```

#### ENEMY TOTAL: 8-10
- Crabs: 4-5
- Turtles: 2
- Mushrooms: 2
- Tribe: 1 (flees - foreshadowing)
- Starfish: 2 (secret only)

---

### ═══════════════════════════════════════════════════════════════
### ACT 2: "THE STALACTITE GAUNTLET" (Level 3-2)
### ═══════════════════════════════════════════════════════════════
**Theme:** Fear → Survival  
**Lighting:** Darker purple (0.55, 0.5, 0.65)  
**Duration:** ~4-5 minutes  
**Size:** ~2560x4800 (enormous vertical climb)

#### THE EXPERIENCE:
Massive vertical climb. Death waits below (Death Zone visible). Player must
ascend through multiple paths - LEFT (easy), CENTRAL (hard), RIGHT (water).
First truly threatening enemies appear: Aggressive Tribe throws from above,
Seahorse snipes from water, Shield Tribe blocks the exit.

#### KEY MOMENT: "THE PATH CHOICE"
Player sees THREE routes upward. Each visible from the junction.
This is PLAYER AGENCY - choose your challenge.

#### ZONE BREAKDOWN:

**Zone A: The Entry Pit (Y: 4400-4800)**
```
PURPOSE: Establish stakes - death below
TERRAIN: Wide floor, Death Zone visible beneath
VISUAL: Red glow from abyss, "☠ THE ABYSS ☠" label
CHECKPOINT: At entry - mercy before climb
FEELING: "If I fall... I die."
```

**Zone B: Opening Cavern (Y: 4000-4400)**
```
PURPOSE: Route choice presentation
TERRAIN: Three visible climbing paths branch off
  - LEFT SHAFT visible: Wider, more platforms
  - CENTRAL SHAFT visible: Narrow, spikes visible
  - RIGHT SHAFT visible: Water pools visible
SIGN: "Choose your path wisely..."
```

**Zone C: Left Shaft - "The Winding Way" (X: 0-700)**
```
PURPOSE: Easier route, less reward
TERRAIN: Wide shaft, many platforms, forgiving gaps
ENEMIES: 
  - 2 Crabs on ledges
  - 1 Turtle (timing challenge)
HAZARDS: 
  - 2 Flames at intervals
  - Static spikes (minor)
ITEMS: Fewer coins (safety tax)
```

**Zone D: Central Shaft - "The Gauntlet" (X: 900-1600)**
```
PURPOSE: HARD MODE - skill test
TERRAIN: Narrow, fewer platforms, precision required
ENEMIES:
  - 1 Aggressive Tribe on high platform (throws coconuts DOWN!)
HAZARDS:
  - Retractable Spikes everywhere (rhythm!)
  - Wind Area near top (one brutal section)
ITEMS: LOTS of coins (risk/reward)
SECRETS: Collapsable Wall → shortcut to Zone F
```

**Zone E: Right Shaft - "The Flooded Path" (X: 1800-2500)**
```
PURPOSE: Unique water challenge
TERRAIN: Water-filled vertical sections, swim + platforms
ENEMIES:
  - 1-2 Seahorses in water (FIRST APPEARANCE!)
  - They shoot while you swim = PANIC
HAZARDS:
  - Whirlpool in middle section (pulls you down!)
  - Water itself slows movement
ITEMS: Moderate coins, Heal Potion at top
```

**Zone F: Triple Junction (Y: 2000-2400)**
```
PURPOSE: All paths converge, rest
TERRAIN: Wide platform, safe zone feel
CHECKPOINT: Yes (mercy after difficulty)
SIGN: "The old king's lair lies above..."
ITEMS: Coins as exhale moment
```

**Zone G: The Stalactite Forest (Y: 800-2000)**
```
PURPOSE: Elite enemy debut
TERRAIN: Narrow passages, stalactite visuals above
ENEMIES:
  - 1-2 Shield Tribes (FIRST APPEARANCE!)
  - Player MUST figure out back-attack
  - Can't just run past in narrow space
HAZARDS: Retractable Spikes (forces positioning)
ITEMS: Heal Potion after gauntlet
```

**Zone H: Exit Chamber (Y: 64-800)**
```
PURPOSE: Relief, prep for darkness
TERRAIN: Safe area, wide platforms
CHECKPOINT: Before exit
ITEMS: Coins
EXIT: Transition to 3-3
```

#### ENEMY TOTAL: 8-10
- Crabs: 2-3 (Left Shaft)
- Turtle: 1 (Left Shaft)
- Aggressive Tribe: 1 (Central Shaft - HIGH IMPACT)
- Seahorses: 1-2 (Right Shaft water)
- Shield Tribes: 1-2 (Stalactite Forest)

---

### ═══════════════════════════════════════════════════════════════
### ACT 3: "THE LOCKED DEPTHS" (Level 3-3)
### ═══════════════════════════════════════════════════════════════
**Theme:** Mastery → Puzzle Solving  
**Lighting:** VERY DARK (0.12, 0.1, 0.18) - Near pitch black  
**Duration:** ~5-6 minutes  
**Size:** ~3200x2400

#### THE EXPERIENCE:
The darkness closes in. Player can barely see. Complex timer-lever puzzle
system - 5 levers, 4 gates, Master Gate at end. Some gates open others,
creating a sequence. Shield Tribe guards key levers. Mushroom spores GLOW
in the dark (visible threat!). This is the THINKING section.

#### THE PUZZLE SYSTEM:
```
╔═══════════════════════════════════════════════════════════════╗
║                    LEVER NETWORK DIAGRAM                      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║   [ENTRY] ─────► [Gate1] ◄──── [TimerLever_A1]               ║
║                     │          (easy access, 8 sec)           ║
║                     ▼                                         ║
║                [Zone_A] ────► [TimerLever_A2]                ║
║                     │              │                          ║
║                     │              ▼                          ║
║                     │         [Gate2]                         ║
║                     │              │                          ║
║     ┌───────────────┴──────────────┘                          ║
║     │                                                         ║
║     ▼                                                         ║
║ [Zone_B_Upper] ─► [TimerLever_B1] ─────────────┐              ║
║     │              (guarded by Mushrooms)      │              ║
║     │                                          ▼              ║
║     └─────────► [Zone_B_Lower] ◄───────── [Gate3]            ║
║                      │                                        ║
║                      ▼                                        ║
║              [TimerLever_B2] ◄─── (Flooded Tunnel)           ║
║                      │                                        ║
║                      ▼                                        ║
║                  [Gate4]                                      ║
║                      │                                        ║
║                      ▼                                        ║
║              [Zone_C: The Crypts]                             ║
║                      │                                        ║
║                      ▼                                        ║
║           [TimerLever_B3] ◄─── (Shield Tribe!)               ║
║                      │                                        ║
║                      ▼                                        ║
║              [MASTER GATE] ────────► [EXIT → 3-4]            ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

SEQUENCE REQUIREMENTS:
1. Gate1: Hit A1, run through (simple tutorial)
2. Gate2: Hit A2 while A1 still counting
3. Gate3: Hit B1 from upper path (opens lower)
4. Gate4: Hit B2 in flooded tunnel (Seahorse!)
5. Master Gate: Hit B3 (Shield Tribe guards it!)
   Must sprint to gate before timer expires!
```

#### ZONE BREAKDOWN:

**Zone A: Entry Hall (X: 0-800)**
```
PURPOSE: Darkness introduction, Gate1 puzzle
TERRAIN: Narrow corridor, Gate1 visible
ENEMIES: None (learning zone)
HAZARDS: The darkness itself
PUZZLE: TimerLever_A1 nearby, simple hit-and-run
CHECKPOINT: At entry with torch marker
SIGN: "Without light, you cannot see the path..."
```

**Zone B: The Lever Chamber (X: 800-2000, multi-level)**
```
PURPOSE: Complex vertical lever puzzle
TERRAIN: Open room with upper/lower layers
ENEMIES: 
  - 2-3 Mushrooms (spore clouds GLOW in dark - visible!)
  - 1 Tribe (fleeing through - still running!)
UPPER LEVEL:
  - TimerLever_A2 + TimerLever_B1
  - One-way platforms to drop down
LOWER LEVEL:
  - Gate2, Gate3
  - Path to Flooded Tunnel
```

**Zone C: The Flooded Tunnel (X: 1600-2400, Y: 1200-1600)**
```
PURPOSE: Water + Darkness = TERROR
TERRAIN: Waist-deep water slowing movement
ENEMIES:
  - 1 Seahorse in water (shoots in darkness!)
HAZARDS:
  - Water slows you
  - Darkness
  - Seahorse bullets
PUZZLE: TimerLever_B2 on far side
  - Must swim fast, dodge seahorse, hit lever, swim back!
```

**Zone D: The Crypts (X: 2000-3000)**
```
PURPOSE: Final puzzle, skill gate
TERRAIN: Narrow corridors, ancient feel
ENEMIES:
  - 1 Shield Tribe guarding TimerLever_B3
  - MUST defeat or outmaneuver to hit lever
HAZARDS:
  - Retractable Spikes near lever
PUZZLE: 
  - Once B3 hit, SPRINT to Master Gate
  - Tight timing - demands mastery
```

**Zone E: Exit Antechamber (X: 2800-3200)**
```
PURPOSE: Relief, prep for 3-4
TERRAIN: Safe area
CHECKPOINT: Before exit (mercy)
ITEMS: Heal Potion
SECRET: Collapsable Wall → bonus coins/blade
EXIT: Transition to 3-4
```

#### ENEMY TOTAL: 6-7
- Mushrooms: 2-3 (Zone B, spores glow in dark!)
- Tribe: 1 (fleeing - building dread)
- Seahorse: 1 (Flooded Tunnel - terrifying)
- Shield Tribe: 1 (guarding final lever)

---

### ═══════════════════════════════════════════════════════════════
### ACT 4: "THE FUNGAL MAZE" (Level 3-4)
### ═══════════════════════════════════════════════════════════════
**Theme:** Tension → Combat Mastery  
**Lighting:** Dim blue-green (0.45, 0.5, 0.55)  
**Duration:** ~4-5 minutes  
**Size:** ~2560x2000

#### THE EXPERIENCE:
A twisting maze filled with fungal enemies and traps. The King Crab's lair
is close - his minions are everywhere. TRAP COINS teach paranoia. Multiple
enemy types in COMBINATION (Seahorse + Aggressive Tribe crossfire!). 
Shield Tribe GAUNTLET before boss key = combat mastery test.

#### KEY MOMENT: "THE CROSSFIRE"
Corridor with water pool. Seahorse shoots FROM water. Aggressive Tribe
throws coconuts FROM above. Player caught in middle. Must use terrain
and springs to eliminate threats. THIS TESTS EVERYTHING.

#### ZONE BREAKDOWN:

**Zone A: Entry Labyrinth (X: 0-600, Y: 0-800)**
```
PURPOSE: Maze introduction, teach trap coins
TERRAIN: Twisting corridors, T-junctions
ENEMIES: None yet
HAZARDS: 
  - First TRAP COIN! (grab → 2 Mushrooms spawn = AMBUSH)
  - Teaches: not all coins are safe
CHECKPOINT: At entry
```

**Zone B: The Spore Gardens (X: 600-1400, Y: 0-1000)**
```
PURPOSE: Mushroom area denial mastery
TERRAIN: Open area with platforms at different heights
ENEMIES:
  - 3-4 Mushrooms on multiple levels
  - Spore clouds OVERLAP - timing crucial!
HAZARDS:
  - Mushroom spores (area denial)
  - Retractable Spikes (rhythm layer)
ITEMS: Coins scattered along safe paths
SECRET: Collapsable Wall → shortcut to Zone E
```

**Zone C: The Sniper's Perch (X: 1200-2000, Y: 800-1400)**
```
PURPOSE: CROSSFIRE MOMENT - multi-enemy combo
TERRAIN: Long corridor with water pools
ENEMIES:
  - 1 Seahorse in water (shoots at player on land)
  - 1 Aggressive Tribe on HIGH platform (throws coconuts)
HAZARDS:
  - Crossfire from TWO directions!
  - Water slows escape
SOLUTION:
  - Springs to reach high platform
  - Eliminate Aggressive Tribe first
  - Then deal with Seahorse from safety
ITEMS: Heal Potion reward for clearing
```

**Zone D: Shield Tribe Gauntlet (X: 1600-2400, Y: 1400-2000)**
```
PURPOSE: COMBAT MASTERY TEST
TERRAIN: Narrow corridor leading to key chamber
ENEMIES:
  - TWO Shield Tribes patrolling
  - Player MUST use back-attack strategy
  - Can use terrain to separate them
HAZARDS:
  - Flames (timing while fighting)
THIS IS THE GATE: 
  - Can't just run past
  - Can't just mash attack
  - Must THINK and POSITION
```

**Zone E: The Key Chamber (X: 1800-2560, Y: 1600-2000)**
```
PURPOSE: Boss key acquisition
TERRAIN: Chamber with multiple approaches
ITEM: BOSS KEY CHEST (required for 3-5!)
HAZARDS:
  - Whirlpool in water approach
MULTIPLE PATHS:
  - Direct (through Shield Tribe gauntlet)
  - Water route (through Whirlpool + Seahorse risk)
  - Secret (Collapsable Wall from Zone B)
CHECKPOINT: After obtaining key
```

**Zone F: Exit Passage (X: 2200-2560, Y: 0-400)**
```
PURPOSE: Exhale, ominous prep
TERRAIN: Calm corridor
ENEMIES: None (rest)
ITEMS: Coins
SIGNS: "BEWARE THE KING", "Turn back..."
EXIT: Transition to 3-5
```

#### ENEMY TOTAL: 9-11
- Mushrooms: 3-4 (Spore Gardens) + 2 (Trap Coin ambush)
- Seahorse: 1 (Sniper's Perch water)
- Aggressive Tribe: 1 (Sniper's Perch high)
- Shield Tribes: 2 (Gauntlet - mastery test)

---

### ═══════════════════════════════════════════════════════════════
### ACT 5: "THE KING'S ARENA" (Level 3-5)
### ═══════════════════════════════════════════════════════════════
**Theme:** Triumph → Boss Victory  
**Lighting:** Dramatic purple (0.5, 0.4, 0.5)  
**Duration:** ~3-5 minutes (boss fight)  
**Size:** ~1280x800 (compact arena)

#### THE EXPERIENCE:
The culmination. King Crab's throne room. The gate CLOSES behind player
(point of no return). Multi-phase boss fight uses everything player learned:
dodging (from 3-2), timing (from 3-3), positioning (from 3-4). 
Victory = Level 3 COMPLETE. Triumph earned.

#### KEY MOMENT: "THE GATE CLOSES"
Player enters arena. Pause. Gate SLAMS shut behind them.
No escape. This is it.

#### ARENA DESIGN:

**Entry Section (X: 0-200)**
```
PURPOSE: Final preparation, point of no return
TERRAIN: Entry corridor with checkpoint
ITEMS: 
  - CHECKPOINT (before boss gate)
  - Heal Potion (last chance!)
TRIGGER:
  - Boss Trigger Zone at X:192
  - When entered: Boss Gate CLOSES
  - Boss spawns / awakens
FEELING: "No turning back now."
```

**Main Arena (X: 200-1100, Y: 100-700)**
```
TERRAIN: Large rectangular room
FEATURES:
  - Water pools on sides (King Crab's territory)
  - One-Way Platforms at different heights (player escape routes)
  - Springs on walls (vertical dodge options)
  - Stalactites above (atmosphere, future: could fall in phase 2?)

DIMENSIONS: ~900x600 active fight space
  
PLATFORM LAYOUT:
		___          ___          ___
	   |   |        |   |        |   |
  [Plat1]      [Plat2]      [Plat3]
	   
  ═══════════════════════════════════════  FLOOR
  
  ~~~WATER~~~              ~~~WATER~~~
```

**Boss: KING CRAB**
```
SPAWN POSITION: (X: 900, Y: 600) - Right side of arena
HEALTH: High (designed for extended fight)

PHASE 1 (100-50% HP):
  - Coconut Throws (player dodges or platforms)
  - Ground Pound → Shockwave (jump to avoid)
  - Walk toward player (pressure)
  - Uses: Basic lessons from Level 3

PHASE 2 (50-0% HP - Enrage):
  - Faster movement (phase_2_speed_multiplier)
  - Claw Attack added (reach danger!)
  - Roll Bounce (crosses arena fast)
  - Summon small Crabs? (optional)
  - Whirlpool spawns in water (water now dangerous!)
  - Uses: Advanced lessons, multi-threat
```

**Victory Zone (appears after boss death)**
```
REWARD:
  - Gold Chest spawns (or Victory Reward)
  - Contains: Key to Level 4? Treasure?
  - Exit door UNLOCKS
  
EXIT:
  - Right side (X: 1248)
  - "→ LEVEL 4 or VICTORY!"
```

#### BOSS MECHANICS DETAIL:

**King Crab Abilities (from king_crab.gd):**
1. **Dive Attack**: Rises up, pauses, crashes down → shockwave
2. **Coconut Throw**: Predictive throws at player, burst pattern
3. **Claw Attack**: Throws claw projectile, wraps around
4. **Roll Bounce**: Jumps, rolls into ball, bounces off walls

**Phase Transition:**
- At 50% HP: "King Crab enters Phase 2!"
- Speed increases
- Attack patterns intensify

**Environmental Synergy:**
- Water pools: King Crab can enter water freely
- Whirlpools in Phase 2: Water becomes hazard
- Platforms: Player refuge, but can't hide forever
- Springs: Emergency vertical escape

#### ENEMY TOTAL: 1 (+ potential summons)
- King Crab: 1 (BOSS)
- Crabs: 2-4 (Phase 2 summons, optional)

---

## DIFFICULTY CURVE VISUALIZATION

```
DIFFICULTY
	▲
	│                                         ╔═════════╗
	│                                         ║ BOSS    ║
	│                                    ┌────║  3-5    ║
	│                                    │    ╚═════════╝
	│                           ┌────────┤
	│                  ┌────────┤ Shield │
	│         ┌────────┤ Puzzle │ Gauntlet
	│    ─────┤ Climb  │ Dark   │  3-4   │
	│ Entry   │  3-2   │  3-3   ├────────┘
	│  3-1    ├────────┴────────┘
	└─────────┴────────────────────────────────────────► TIME
		 ACT1      ACT2      ACT3      ACT4      ACT5
```

---

## ENEMY DISTRIBUTION MATRIX

| Level | Crabs | Turtles | Mushrooms | Tribe | Agg.Tribe | Seahorse | Shield Tribe | BOSS |
|-------|-------|---------|-----------|-------|-----------|----------|--------------|------|
| 3-1   | 4-5   | 2       | 2         | 1     | 0         | 0        | 0            | -    |
| 3-2   | 2-3   | 1       | 0         | 0     | 1         | 1-2      | 1-2          | -    |
| 3-3   | 0     | 0       | 2-3       | 1     | 0         | 1        | 1            | -    |
| 3-4   | 0     | 0       | 5-6       | 0     | 1         | 1        | 2            | -    |
| 3-5   | 2-4*  | 0       | 0         | 0     | 0         | 0        | 0            | 1    |

*Phase 2 summons

**TOTAL ENEMIES ACROSS LEVEL 3:** ~35-40

---

## HAZARD DISTRIBUTION

| Level | Flames | Spikes (Ret.) | Wind | Water | Whirlpool | Death Zone |
|-------|--------|---------------|------|-------|-----------|------------|
| 3-1   | ★★☆    | ★★☆           | ★☆☆  | ★★☆   | ☆☆☆       | ☆☆☆        |
| 3-2   | ★☆☆    | ★★★           | ★★☆  | ★★★   | ★☆☆       | ★★★        |
| 3-3   | ★☆☆    | ★★☆           | ☆☆☆  | ★★☆   | ☆☆☆       | ☆☆☆        |
| 3-4   | ★★☆    | ★★☆           | ☆☆☆  | ★★☆   | ★★☆       | ☆☆☆        |
| 3-5   | ☆☆☆    | ☆☆☆           | ☆☆☆  | ★★★   | ★★☆       | ☆☆☆        |

---

## KEY MOMENTS (The Experience Beats)

### 1. "THE FIRST DARKNESS" (3-1 → 3-2 transition)
**What Happens:** Light dims as player descends through 3-1
**Emotional Beat:** "Oh no, it's getting dark..."
**Design:** CanvasModulate gradually darkens zone by zone

### 2. "THE ABYSS REVEAL" (3-2 opening)
**What Happens:** Player sees Death Zone below, red glow, skull symbol
**Emotional Beat:** Pure fear. Stakes are REAL.
**Design:** Death Zone with visual indicator + label

### 3. "THE PATH CHOICE" (3-2 early)
**What Happens:** Three paths visible - player chooses
**Emotional Beat:** Agency! MY choice!
**Design:** All three routes visible from junction

### 4. "THE SEAHORSE AMBUSH" (3-2 water route OR 3-3)
**What Happens:** First ranged water enemy shoots at swimming player
**Emotional Beat:** PANIC! Can't fight while swimming!
**Design:** Seahorse positioned for maximum terror

### 5. "THE SHIELD TRIBE WALL" (3-2 late)
**What Happens:** Enemy player CANNOT just hit from front
**Emotional Beat:** "I have to THINK about this..."
**Design:** Narrow passage, can't bypass

### 6. "THE LEVER RACE" (3-3)
**What Happens:** Final lever hit, timer counting, sprint to gate
**Emotional Beat:** TENSION! Will I make it?!
**Design:** Tight timing, clear path, visible gate

### 7. "THE TRAP COIN" (3-4)
**What Happens:** Player grabs coin → Mushrooms spawn
**Emotional Beat:** Betrayal! "Not all that glitters..."
**Design:** First trap coin, obvious lesson

### 8. "THE CROSSFIRE" (3-4)
**What Happens:** Seahorse + Aggressive Tribe from two directions
**Emotional Beat:** Chaos! Multi-threat! SKILL CHECK!
**Design:** Long corridor, water pool, high platform

### 9. "THE GATE CLOSES" (3-5 boss start)
**What Happens:** Player enters arena, gate slams shut
**Emotional Beat:** Point of no return. THIS IS IT.
**Design:** Audio cue, visual gate closing, dramatic pause

### 10. "THE KING FALLS" (3-5 victory)
**What Happens:** Boss defeated, reward spawns, music shift
**Emotional Beat:** TRIUMPH! I DID IT!
**Design:** Gold chest appears, exit unlocks, possible fanfare

---

## RESOURCE DISTRIBUTION (Mercy Pacing)

### Checkpoints
| Level | Count | Placement Philosophy |
|-------|-------|---------------------|
| 3-1   | 3     | Entry, mid-descent, lake |
| 3-2   | 4     | Entry pit, junction, stalactite, exit |
| 3-3   | 3     | Entry, mid-puzzle, exit |
| 3-4   | 2     | Entry, after key (harder = fewer) |
| 3-5   | 1     | Before boss ONLY (high stakes) |

### Health Potions
| Level | Count | Placement |
|-------|-------|-----------|
| 3-1   | 1     | Guarded by Mushroom (rewards combat) |
| 3-2   | 2     | Right shaft top + after Shield Tribe |
| 3-3   | 1     | Before exit (prep for 3-4) |
| 3-4   | 1     | After Sniper's Perch (reward for crossfire) |
| 3-5   | 1     | Before boss gate (LAST CHANCE) |

### Secrets (Collapsable Walls)
| Level | Count | Contents |
|-------|-------|----------|
| 3-1   | 2     | Coin cache + Crystal Grotto (Blade?) |
| 3-2   | 1     | Shortcut in Central Shaft |
| 3-3   | 1     | Bonus coins before exit |
| 3-4   | 1     | Shortcut to Key Chamber |
| 3-5   | 0     | Boss arena has no secrets |

---

## COMBO ENCOUNTERS (The Special Sauce)

These are the encounters that make Level 3 MEMORABLE:

### Combo 1: "The Ambush" (3-4)
```
TRIGGER: Player grabs Trap Coin
SPAWNS: 2 Mushrooms from hidden positions
LESSON: Not all that glitters is gold
```

### Combo 2: "The Crossfire" (3-4)
```
SETUP: Long corridor with water pool
ENEMIES:
  - Seahorse IN water (shoots horizontally)
  - Aggressive Tribe ON platform (throws down)
PLAYER: Caught in middle
SOLUTION: 
  - Use springs to reach high platform
  - Eliminate Aggressive Tribe first
  - Then deal with Seahorse from safety
```

### Combo 3: "The Dark Gauntlet" (3-3)
```
SETUP: Near-black darkness
ENEMIES:
  - Mushrooms (spores GLOW = visible threat!)
  - Shield Tribe guarding lever
HAZARD: Retractable spikes during fight
TENSION: Timer running on puzzle
```

### Combo 4: "Water Terror" (3-3)
```
SETUP: Flooded tunnel in darkness
ENEMIES: 
  - Seahorse in water
HAZARD: 
  - Water slows movement
  - Darkness limits vision
  - Timer pressure from puzzle
EMOTIONAL: Pure dread
```

### Combo 5: "The Shield Wall" (3-2)
```
SETUP: Narrow stalactite passage
ENEMIES:
  - 2 Shield Tribes patrolling
TERRAIN:
  - Can't run past (too narrow)
  - Must fight or lure and backstab
LESSON: Positioning matters
```

---

## IMPLEMENTATION CHECKLIST

### Phase 1: Core Terrain
- [x] 3-1 terrain expanded (~3200x2800)
- [x] 3-2 terrain expanded (~2560x4800)
- [x] 3-3 terrain expanded (~3200x2400)
- [x] 3-4 terrain (~1280x1024)
- [x] 3-5 boss arena (~1280x800)

### Phase 2: Experience Sketching (Markers/Labels)
- [x] 3-1: Enemy markers (Crab x2, Turtle x1, Mushroom x3), Hazard markers (Flame x2, Water), Zone labels
- [x] 3-2: Path choice labels (LEFT/CENTRAL/RIGHT), Enemy markers (Crab, Turtle, AggressiveTribe, Seahorse, ShieldTribe x2), Hazard markers (Flames, Spikes x4, Wind, Water, Whirlpool), Collectibles (coins, potions, secret shortcut)
- [x] 3-3: Lever puzzle hints (A1, A2, B1, B2, B3 labels), Zone labels (Hub, Vault, Drain), Enemy markers (Crab, Turtle, Mushroom x3, ShieldTribe, Seahorse, AggressiveTribe), Hazard markers (Flames, Spikes), Collectibles (Chest with Blade)
- [x] 3-4: Trap Coin markers (x3 with spawn descriptions), Crossfire zone label, Enemy markers (Mushroom x4, AggressiveTribe, ShieldTribe), Hazard markers (Whirlpool, Flames x2, Spikes, Retractable spikes), Boss Key chest
- [x] 3-5: Boss arena labels (Phase 1/2 descriptions), Combat tips, Stalactite hints, Boss trigger zone, Gate mechanics

### Phase 3: Actual Enemy/Hazard Instantiation
- [ ] Flame instantiation (3-1, 3-3, 3-4)
- [ ] Spike instantiation (all levels)
- [ ] Water zones (3-1, 3-2, 3-3, 3-5)
- [ ] Wind areas (3-1, 3-2)
- [ ] Death zone (3-2)
- [ ] Whirlpools (3-4, 3-5)

### Phase 4: Actual Enemies
- [ ] Basic: Crab, Turtle, Starfish
- [ ] Mid-tier: Mushroom, Tribe  
- [ ] Advanced: Aggressive Tribe, Seahorse
- [ ] Elite: Shield Tribe
- [ ] Boss: King Crab integration

### Phase 5: Puzzles & Interactives
- [ ] Timer lever network (3-3) - 5 levers, 4 gates
- [ ] Gate connections and logic
- [ ] Collapsable wall secrets (all levels)
- [ ] Trap coin setup (3-4) - spawn triggers

### Phase 6: Resources
- [ ] Checkpoint placement (done in scenes)
- [ ] Health Potion instantiation
- [ ] Coin distribution (marked but not instantiated)
- [ ] Key/Blade/Chest instantiation

### Phase 7: Polish
- [ ] CanvasModulate lighting per zone (partially done)
- [ ] Sign text instantiation
- [ ] Transition connections between levels
- [ ] Playtest balance

---

## TECHNICAL REFERENCE

### CanvasModulate Lighting Values
```gdscript
# 3-1: Twilight cave (gentle)
Color(0.75, 0.7, 0.85, 1)

# 3-2: Darker depths
Color(0.55, 0.5, 0.65, 1)

# 3-3: Near pitch black (torch essential)
Color(0.12, 0.1, 0.18, 1)

# 3-4: Dim blue-green (fungal)
Color(0.45, 0.5, 0.55, 1)

# 3-5: Dramatic purple (boss)
Color(0.5, 0.4, 0.5, 1)
```

### Scene UIDs (for reference)
```
wall.tscn:           uid://bn3w2ymt5pkh7
checkpoint.tscn:     uid://bmic0j4cnluey
one_way_platform:    uid://mikmney07ycb
sign.tscn:           uid://bg3bfewcihuv0
icon.svg:            uid://dkta2oq0nm1o0
```

### Collision Layers Reminder
- Layer 1: Ground/static environment
- Layer 2: Player and enemy bodies  
- Layer 4: HurtArea2D (can be damaged)
- Layer 8: Enemy bodies + shields/blocking
- Layer 16: Enemy HurtArea2D
- Layer 32: Projectile bodies

---

## FINAL NOTES

### What We're NOT Adding (Scope Control)
- ❌ New enemy types (ice/fire creatures) - requires new assets
- ❌ Complex new mechanics - stick to existing systems
- ❌ Deep story/dialogue - game jam scope

### What We ARE Maximizing
- ✅ Enemy COMBINATIONS (existing enemies together)
- ✅ Hazard LAYERING (flames + platforms + enemies)
- ✅ Spatial PRESSURE (narrow spaces, high stakes)
- ✅ Timing CHALLENGES (lever puzzles, retractable spikes)
- ✅ Route CHOICES (multiple paths, different difficulties)
- ✅ EMOTIONAL BEATS (fear, triumph, discovery)

---

*This document is the master blueprint for Level 3.*
*Build to this spec. Playtest. Iterate.*
*Make it FUN.*
