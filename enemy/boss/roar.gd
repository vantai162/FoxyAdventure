extends EnemyState
## Warlord Turtle ROAR — Close-range shockwave attack
##
## DESIGN: A regular attack in the boss's arsenal.
## - Telegraphed: Clear visual + audio warning (escapable if you read it)
## - Creates space: Knockback pushes melee players away
## - Punishing but fair: Damage + knockback, but readable
##
## Also used by phase_transition.gd for the dramatic phase 2 entrance.
##
## ANIMATION: Uses skill1 (arm raise = power up)

## Timing parameters (all tunable)
@export var telegraph_duration: float = 0.4  ## Warning time before shockwave
@export var recovery_duration: float = 0.5   ## Pause after shockwave

## Shockwave parameters
@export var shockwave_scene: PackedScene  ## Assign King Crab's shockwave
@export var shockwave_radius: float = 120.0  ## Larger than King Crab's dive
@export var shockwave_knockback: float = 400.0  ## Strong push
@export var shockwave_damage: int = 1

## Screen shake for IMPACT
@export var telegraph_shake: float = 4.0   ## Building tension
@export var release_shake: float = 12.0    ## The ROAR itself

var _phase: int = 0  # 0=telegraph, 1=release, 2=recovery
var _timer: float = 0.0


func _enter() -> void:
	_phase = 0
	_timer = 0.0
	
	# Play "powering up" animation (skill1 works well)
	obj.change_animation("skill1")
	obj.velocity = Vector2.ZERO
	
	# Start building shake
	_apply_camera_shake(telegraph_shake)
	
	# Play roar sound
	AudioManager.play_sound("warlord_laugh", 25.0)


func _update(delta: float) -> void:
	_timer += delta
	
	match _phase:
		0:  # TELEGRAPH
			# Continuous shake buildup
			if int(_timer * 10) % 2 == 0:
				_apply_camera_shake(telegraph_shake * (1.0 + _timer))
			
			if _timer >= telegraph_duration:
				_phase = 1
				_timer = 0.0
				_do_roar_release()
		
		1:  # RELEASE (instant, move to recovery)
			_phase = 2
			_timer = 0.0
		
		2:  # RECOVERY
			if _timer >= recovery_duration:
				change_state(fsm.states.idle)


func _do_roar_release() -> void:
	## The actual ROAR — spawn shockwave, big shake
	
	# BIG shake
	_apply_camera_shake(release_shake)
	
	# Spawn shockwave
	if shockwave_scene:
		var shockwave = shockwave_scene.instantiate()
		shockwave.global_position = obj.global_position + Vector2(0, -20)  # Center on body
		
		# Override shockwave parameters for roar-specific tuning
		shockwave.gameplay_hit_radius = shockwave_radius
		shockwave.knockback_force = shockwave_knockback
		shockwave.damage = shockwave_damage
		
		get_tree().current_scene.add_child(shockwave)
	else:
		push_warning("Roar: No shockwave_scene assigned!")
	
	# Sound effect for the release
	AudioManager.play_sound("warlord_bomb_launch", 20.0)  # Reuse explosion-like sound


func _apply_camera_shake(intensity: float) -> void:
	## Apply camera shake via the player's camera
	var player = obj.found_player
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		if camera.has_method("shake"):
			camera.shake(intensity)

