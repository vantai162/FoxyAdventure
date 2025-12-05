@tool
extends Node2D
## Cave Section - Pre-configured dark cave room with ambience
## Combines LevelSection, CanvasModulate, and ambient effects

@export_group("Darkness")
@export var is_dark: bool = true:
	set(value):
		is_dark = value
		_update_darkness()
@export var darkness_color: Color = Color(0.08, 0.05, 0.12, 1.0):  ## Deep purple-black
	set(value):
		darkness_color = value
		_update_darkness()
@export var ambient_light: float = 0.1:  ## Base visibility (0 = pitch black)
	set(value):
		ambient_light = clamp(value, 0.0, 1.0)
		_update_darkness()

@export_group("Bounds")
@export var section_size: Vector2 = Vector2(1920, 1080):
	set(value):
		section_size = value
		_update_bounds()
@export var auto_detect_bounds: bool = false  ## Use TileMapLayer if present

@export_group("Ambience")
@export var drip_count: int = 3  ## Number of drip sources
@export var mushroom_count: int = 5  ## Number of glowing mushrooms
@export var auto_place_ambience: bool = false  ## Randomly place on ready

@export_group("Camera")
@export var camera_margin: Vector2 = Vector2(50, 50)

var bounds: Rect2

@onready var canvas_modulate: CanvasModulate = $CanvasModulate if has_node("CanvasModulate") else null
@onready var ambience_container: Node2D = $Ambience if has_node("Ambience") else null

signal player_entered(section: Node2D)
signal player_exited(section: Node2D)

func _ready() -> void:
	if not Engine.is_editor_hint():
		_calculate_bounds()
		_update_darkness()
		if auto_place_ambience:
			_auto_place_ambience()

func _update_darkness() -> void:
	if not canvas_modulate:
		return
	
	if is_dark:
		var adjusted_color = darkness_color.lerp(Color.WHITE, ambient_light)
		canvas_modulate.color = adjusted_color
	else:
		canvas_modulate.color = Color.WHITE

func _update_bounds() -> void:
	bounds = Rect2(global_position - section_size / 2, section_size)

func _calculate_bounds() -> void:
	if auto_detect_bounds:
		# Try to find TileMapLayer
		for child in get_children():
			if child is TileMapLayer:
				var used_rect = child.get_used_rect()
				var tile_size = child.tile_set.tile_size if child.tile_set else Vector2(16, 16)
				bounds = Rect2(
					child.global_position + Vector2(used_rect.position) * tile_size,
					Vector2(used_rect.size) * tile_size
				)
				return
	
	# Use manual size
	_update_bounds()

func get_camera_bounds() -> Rect2:
	return Rect2(
		bounds.position + camera_margin,
		bounds.size - camera_margin * 2
	)

func _auto_place_ambience() -> void:
	if not ambience_container:
		return
	
	# Would load and instantiate dripping_water and glowing_mushroom scenes
	# at random positions within bounds
	# Left as stub - designer can manually place for control
	pass

## Call when player enters this section
func on_player_enter() -> void:
	if is_dark and canvas_modulate:
		canvas_modulate.visible = true
	player_entered.emit(self)

## Call when player exits this section  
func on_player_exit() -> void:
	if canvas_modulate:
		canvas_modulate.visible = false
	player_exited.emit(self)

## Gradually reveal the cave (for dramatic moments)
func reveal_light(duration: float = 1.0) -> void:
	if not canvas_modulate:
		return
	
	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color", Color.WHITE, duration)
	is_dark = false

## Gradually darken the cave
func fade_to_dark(duration: float = 1.0) -> void:
	if not canvas_modulate:
		return
	
	var adjusted_color = darkness_color.lerp(Color.WHITE, ambient_light)
	var tween = create_tween()
	tween.tween_property(canvas_modulate, "color", adjusted_color, duration)
	is_dark = true
