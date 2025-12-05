extends CanvasModulate
class_name VisionMaskSystem

## Cave Darkness System - Use with PointLight2D and LightOccluder2D
##
## HOW IT WORKS:
## 1. This CanvasModulate darkens everything
## 2. Player's PointLight2D (PlayerTorch) illuminates around them
## 3. Walls with LightOccluder2D block light = create shadows
## 4. Result: Player can't see behind walls (light blocked = dark)
##
## REQUIREMENTS:
## - Player needs PointLight2D with shadow_enabled = true
## - Walls need LightOccluder2D (for wall.tscn, already done!)
## - TileSet tiles need occlusion_layer configured (this is the missing piece!)
##
## TILESET OCCLUSION SETUP:
## 1. Open your TileSet in editor
## 2. Select tile(s) that should block light
## 3. In Physics section, add Occlusion Layer
## 4. Draw polygon matching tile shape
## 5. Now those tiles will cast shadows!

@export var darkness_color: Color = Color(0.1, 0.1, 0.15, 1.0):
	set(value):
		darkness_color = value
		color = value

func _ready() -> void:
	color = darkness_color
