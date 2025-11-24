extends Player_State

var air_slash_timer: float = 0.0
var air_slash_spawned: bool = false

func _enter() -> void:
	super._enter()
	# Change animation to attack
	if obj.is_on_floor():
		obj.change_animation("attack")
	else:
		obj.change_animation("Jump_attack")

	timer = obj.attack_duration
	
	# Stop player on normal ground, but preserve momentum on ice
	if not (obj.is_on_floor() and obj._is_on_ice()):
		obj.velocity.x = 0

	# Enable collision shape of hit area
	obj.get_node("Direction/HitArea2D/CollisionShape2D").disabled = false
	
	# Reset air slash spawn tracking
	air_slash_timer = 0.0
	air_slash_spawned = false


func _exit() -> void:
	# Disable collision shape of hit area
	obj.get_node("Direction/HitArea2D/CollisionShape2D").disabled = true


func _update(delta: float) -> void:
	# Handle delayed air slash spawn
	if not air_slash_spawned:
		air_slash_timer += delta
		if air_slash_timer >= obj.air_slash_spawn_delay:
			obj.spawn_air_slash()
			air_slash_spawned = true
	
	# If attack is finished change to previous state
	if update_timer(delta):
		change_state(fsm.previous_state)
