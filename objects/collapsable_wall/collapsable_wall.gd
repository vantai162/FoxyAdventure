extends StaticBody2D
class_name BreakableWall

const DUST_EFFECT_SCENE = preload("res://objects/collapsable_wall/dust_effect.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $HitBox
@onready var break_sound: AudioStreamPlayer2D = $BreakSound
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_broken: bool = false

func _ready() -> void:
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)

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
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if hitbox:
		hitbox.set_deferred("monitoring", false)
	
	if sprite:
		sprite.hide()
	
	if break_sound:
		await break_sound.finished
	queue_free()
