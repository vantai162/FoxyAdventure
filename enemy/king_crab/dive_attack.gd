extends EnemyState

# Dive ground-pound attack with warning indicator

enum Phase { WARNING, RISING, FALLING, LANDING }
var phase: Phase = Phase.WARNING

var warning_time: float = 1.0
var warning_elapsed: float = 0.0
var rise_height: float = 200.0
var rise_speed: float = 300.0
var fall_speed: float = 600.0

var start_y: float = 0.0
var target_x: float = 0.0

# Warning zone factory (set in scene)
@onready var warning_factory: Node2D = $"../../Direction/WarningFactory" if has_node("../../Direction/WarningFactory") else null

func _enter() -> void:
	phase = Phase.WARNING
	warning_elapsed = 0.0
	start_y = obj.global_position.y
	
	# Target player position
	if obj.found_player:
		target_x = obj.found_player.global_position.x
	else:
		target_x = obj.global_position.x
	
	obj.change_animation("idle")
	obj.velocity = Vector2.ZERO
	
	# Spawn warning zone
	if warning_factory and warning_factory.has_method("create"):
		var warning = warning_factory.create()
		if warning:
			# Position at target X, ground Y (approximate or raycast down)
			# Assuming boss is on ground or we want it at player's ground level
			var ground_y = obj.global_position.y 
			if obj.found_player:
				ground_y = obj.found_player.global_position.y
			
			warning.global_position = Vector2(target_x, ground_y)

func _update(delta: float) -> void:
	match phase:
		Phase.WARNING:
			warning_elapsed += delta
			if warning_elapsed >= warning_time:
				phase = Phase.RISING
		
		Phase.RISING:
			obj.velocity.y = -rise_speed
			if obj.global_position.y <= start_y - rise_height:
				phase = Phase.FALLING
				obj.global_position.x = target_x  # Snap to target
		
		Phase.FALLING:
			obj.velocity.y = fall_speed
			if obj.is_on_floor():
				phase = Phase.LANDING
				_create_shockwave()
				obj.can_dive = false
				get_tree().create_timer(6.0).timeout.connect(func(): obj.can_dive = true)
				change_state(fsm.states.idle)

func _create_shockwave() -> void:
	# TODO: Spawn shockwave effect and hitbox
	pass

func _exit() -> void:
	pass
