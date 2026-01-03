@tool
extends StaticBody2D
class_name BreakableWall
## Destructible wall that breaks when attacked
## Useful for secrets and shortcuts

const DUST_EFFECT_SCENE = preload("res://objects/collapsable_wall/dust_effect.tscn")

@export_group("Editor Preview")
## Show "BREAKABLE" indicator in editor
@export var show_indicator: bool = true:
	set(value):
		show_indicator = value
		queue_redraw()
@export var indicator_color: Color = Color(1.0, 0.6, 0.2, 0.9)

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var hitbox: Area2D = $HitBox if has_node("HitBox") else null
@onready var break_sound: AudioStreamPlayer2D = $BreakSound if has_node("BreakSound") else null

var is_broken: bool = false

func _ready() -> void:
	# Skip gameplay in editor
	if Engine.is_editor_hint():
		return
	
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)

## Editor draw - show breakable indicator
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if not show_indicator:
		return
	
	# Draw "BREAKABLE" label
	var font := ThemeDB.fallback_font
	var label_text := "BREAKABLE"
	var font_size := 10
	var text_size := font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var label_pos := Vector2(-text_size.x / 2, -8)
	
	# Background for readability
	var bg_rect := Rect2(label_pos - Vector2(4, font_size), text_size + Vector2(8, 4))
	draw_rect(bg_rect, Color(0.1, 0.1, 0.1, 0.7))
	
	# Draw text
	draw_string(font, label_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, indicator_color)
	
	# Draw crack icon (simple X)
	var crack_offset := Vector2(0, 8)
	draw_line(crack_offset + Vector2(-6, -6), crack_offset + Vector2(6, 6), indicator_color, 2.0)
	draw_line(crack_offset + Vector2(6, -6), crack_offset + Vector2(-6, 6), indicator_color, 2.0)

func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_broken:
		return
	
	if area.is_in_group("player_attack"):
		break_wall()

func break_wall() -> void:
	if is_broken:
		return
	is_broken = true
	
	if break_sound:
		break_sound.play()
	
	var dust_effect = DUST_EFFECT_SCENE.instantiate()
	get_parent().add_child(dust_effect)
	dust_effect.global_position = global_position
	if dust_effect.has_method("play_effect"):
		dust_effect.play_effect()
	
	# Camera shake for satisfying destruction feel
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var camera = player.get_node_or_null("Camera2D")
		if camera and camera.has_method("shake"):
			camera.shake(5.0)
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	
	if sprite:
		sprite.hide()
	
	if break_sound:
		await break_sound.finished
	queue_free()
