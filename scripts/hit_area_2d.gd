extends Area2D
class_name HitArea2D

## HitArea2D — Offensive collision that deals damage to HurtArea2D
## Features: damage dealing, hitstop on contact, camera shake

# damage of hit
@export var damage = 1

## Game Feel — hitstop creates weight and impact
@export_group("Hit Feedback")
@export var hitstop_duration: float = 0.06  ## Brief freeze on hit (60ms = clearly perceivable punch)
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
	
	# Hitstop — freeze the ATTACKER (owner of this hit area)
	# The VICTIM freezes themselves in their hurt state
	if enable_hitstop and hitstop_duration > 0:
		var attacker = get_parent()  # Usually the character with this HitArea2D
		if attacker:
			HitstopManager.freeze_node(attacker, hitstop_duration)
