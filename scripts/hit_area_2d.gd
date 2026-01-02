extends Area2D
class_name HitArea2D

## HitArea2D — Offensive collision that deals damage to HurtArea2D
## Features: damage dealing, hitstop on contact, camera shake

# damage of hit
@export var damage = 1

## Game Feel — hitstop creates weight and impact
@export_group("Hit Feedback")
@export var hitstop_duration: float = 0.04  ## Brief freeze on hit (frames of impact)
@export var camera_shake_amount: float = 4.0  ## Screen shake on hit (0 = disabled)
@export var enable_hitstop: bool = true  ## Toggle for different attack types

# signal when hit area
signal hitted(area)

func _init() -> void:
	area_entered.connect(_on_area_entered)

# called when hit area
func hit(hurt_area):
	if(hurt_area.has_method("take_damage")):
		var hit_dir:Vector2 = hurt_area.global_position - global_position
		hurt_area.take_damage(hit_dir.normalized(), damage)
		
		# === GAME FEEL: Hitstop + Camera Shake ===
		# The moment of impact should REGISTER with the player
		_apply_hit_feedback()
		
# called when area entered
func _on_area_entered(area):
	hit(area)
	hitted.emit(area)

## Apply hitstop and camera shake for satisfying impact
func _apply_hit_feedback() -> void:
	# Camera shake — find player camera
	if camera_shake_amount > 0:
		var player = GameManager.player
		if player and player.has_node("Camera2D"):
			var cam = player.get_node("Camera2D")
			if cam.has_method("shake"):
				cam.shake(camera_shake_amount)
	
	# Hitstop — brief freeze frame
	if enable_hitstop and hitstop_duration > 0:
		Engine.time_scale = 0.0
		# Use a timer that ignores time scale
		get_tree().create_timer(hitstop_duration, true, false, true).timeout.connect(
			func(): Engine.time_scale = 1.0
		)
