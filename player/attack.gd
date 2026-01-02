extends Player_State

## Attack anticipation — quick windup squash for punch
const ATTACK_WINDUP_SCALE: Vector2 = Vector2(1.15, 0.9)  ## Wind back
const ATTACK_SWING_SCALE: Vector2 = Vector2(0.9, 1.1)  ## Swing forward
const NORMAL_SCALE: Vector2 = Vector2(1.0, 1.0)

var air_slash_timer: float = 0.0
var air_slash_spawned: bool = false
var original_gravity: float = 0.0
var is_air_attack: bool = false

func _enter() -> void:
	super._enter()
	AudioManager.play_sound("player_swing",20.0)
	# Change animation to attack
	is_air_attack = not obj.is_on_floor()
	if not is_air_attack:
		obj.change_animation("attack")
		# Ground attack: commitment - stop horizontal movement (unless on ice)
		if not obj._is_on_ice():
			obj.velocity.x = 0
	else:
		obj.change_animation("Jump_attack")
		# Air attack: preserve momentum (physics-consistent), but apply hover effect
		# NOT zeroing velocity - player keeps their arc
		original_gravity = obj.gravity
		obj.gravity = original_gravity * obj.attack_air_gravity_scale

	timer = obj.attack_duration
	
	# Attack anticipation feedback — quick windup-swing
	_apply_attack_anticipation()
	
	# Start attack cooldown
	obj.start_attack_cooldown()

	# Enable collision shape of hit area
	obj.get_node("Direction/HitArea2D/CollisionShape2D").disabled = false
	
	# Reset air slash spawn tracking
	air_slash_timer = 0.0
	air_slash_spawned = false


## Attack windup-swing squash/stretch — anticipation + follow-through
func _apply_attack_anticipation() -> void:
	var direction_node = obj.get_node_or_null("Direction")
	if not direction_node:
		return
	
	var tween = create_tween()
	# Quick windup (pull back)
	tween.tween_property(direction_node, "scale", ATTACK_WINDUP_SCALE, 0.04)
	# Snap to swing (thrust forward)
	tween.tween_property(direction_node, "scale", ATTACK_SWING_SCALE, 0.06)
	# Settle back to normal
	tween.tween_property(direction_node, "scale", NORMAL_SCALE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)


func _exit() -> void:
	# Disable collision shape of hit area
	obj.get_node("Direction/HitArea2D/CollisionShape2D").disabled = true
	
	# Restore normal gravity if this was an air attack
	if is_air_attack:
		obj.gravity = original_gravity


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
