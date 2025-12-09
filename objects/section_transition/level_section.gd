extends Node2D
class_name LevelSection

## A section/room within a level
## Defines camera bounds and can contain all section-specific content

@export_group("Section Bounds")
@export var bounds_size: Vector2 = Vector2(640, 360)  ## Size of this section
@export var use_custom_bounds: bool = false  ## Override automatic bounds detection

@export_group("Visual")
@export var section_name: String = ""  ## Optional display name
@export var show_debug_bounds: bool = false  ## Show bounds in editor

@export_group("Lighting")
@export var ambient_light: Color = Color.WHITE  ## Section ambient light color
@export var is_dark_section: bool = false  ## If true, uses darkness system

var _bounds: Rect2

func _ready() -> void:
	_calculate_bounds()
	
	# Apply section lighting
	if is_dark_section:
		_setup_darkness()
	else:
		_apply_ambient_light()

func _calculate_bounds() -> void:
	if use_custom_bounds:
		_bounds = Rect2(global_position, bounds_size)
	else:
		# Auto-detect from TileMapLayer if present
		var tilemap = find_child("*", false, false)
		for child in get_children():
			if child is TileMapLayer:
				var used_rect = child.get_used_rect()
				var cell_size = child.tile_set.tile_size if child.tile_set else Vector2(16, 16)
				_bounds = Rect2(
					child.global_position + Vector2(used_rect.position) * cell_size,
					Vector2(used_rect.size) * cell_size
				)
				return
		
		# Fallback to manual bounds
		_bounds = Rect2(global_position, bounds_size)

func get_camera_bounds() -> Rect2:
	return _bounds

func _setup_darkness() -> void:
	# Add CanvasModulate for darkness
	var modulate = CanvasModulate.new()
	modulate.name = "DarknessModulate"
	modulate.color = Color(0.1, 0.1, 0.15, 1.0)  # Dark blue-black
	add_child(modulate)

func _apply_ambient_light() -> void:
	if ambient_light != Color.WHITE:
		var modulate = CanvasModulate.new()
		modulate.name = "AmbientModulate"
		modulate.color = ambient_light
		add_child(modulate)

## Called when player enters this section
func on_section_entered() -> void:
	# Override in section-specific scripts
	pass

## Called when player exits this section
func on_section_exited() -> void:
	# Override in section-specific scripts
	pass

func _draw() -> void:
	if show_debug_bounds and Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, bounds_size), Color(0, 1, 0, 0.3), false, 2.0)
