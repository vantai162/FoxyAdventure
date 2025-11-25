extends EnemyState

## Dive ground-pound attack with warning indicator and wind-up
## 
## ANIMATION ASSUMPTIONS (create these in SpriteFrames):
##   - "dive_windup"  : Crouch/prepare before launching (loop: false)
##   - "dive_rise"    : Launching upward, legs tucked (loop: true)
##   - "dive_apex"    : Hovering at top, maybe slight anticipation (loop: true)
##   - "dive_fall"    : Plummeting down, claws forward (loop: true)
##   - "dive_land"    : Impact/slam on ground (loop: false)

enum AttackPhase { WINDUP, RISING, APEX, FALLING, LANDING }
var attack_phase: AttackPhase = AttackPhase.WINDUP

@export var windup_time: float = 0.5  ## How long to crouch before jump
@export var rise_height: float = 450.0  ## Go WAY up, off-screen to hide the teleport
@export var rise_speed: float = 900.0  ## Explosive burst upward
@export var apex_pause: float = 0.25  ## Hang time at peak
@export var fall_speed: float = 800.0  ## Faster fall = more impact
@export var land_time: float = 0.3  ## How long to show landing animation
@export var launch_shake: float = 10.0  ## Camera shake on launch
@export var land_shake: float = 15.0  ## Camera shake on landing

var phase_timer: float = 0.0
var start_y: float = 0.0
var target_x: float = 0.0

const SHOCKWAVE_SCENE = preload("res://enemy/king_crab/projectiles/shockwave.tscn")


func _enter() -> void:
	attack_phase = AttackPhase.WINDUP
	phase_timer = 0.0
	start_y = obj.global_position.y
	
	# Target player position
	if obj.found_player:
		target_x = obj.found_player.global_position.x
	else:
		target_x = obj.global_position.x
	
	# Face the target
	var dir_to_target = sign(target_x - obj.global_position.x)
	if dir_to_target != 0 and dir_to_target != obj.direction:
		obj.change_direction(dir_to_target)
	
	obj.change_animation("dive_windup")
	obj.velocity = Vector2.ZERO
	
	# Spawn warning indicator at landing spot
	_spawn_warning()


func _spawn_warning() -> void:
	if not obj.warning_factory:
		return
	
	var warning = obj.warning_factory.create()
	if warning:
		var ground_y = obj.global_position.y
		if obj.found_player:
			ground_y = obj.found_player.global_position.y
		warning.global_position = Vector2(target_x, ground_y)


func _update(delta: float) -> void:
	match attack_phase:
		AttackPhase.WINDUP:
			obj.velocity = Vector2.ZERO
			phase_timer += delta
			if phase_timer >= windup_time:
				_launch()
		
		AttackPhase.RISING:
			obj.velocity.y = -rise_speed
			obj.velocity.x = 0
			if obj.global_position.y <= start_y - rise_height:
				attack_phase = AttackPhase.APEX
				obj.global_position.x = target_x
				obj.velocity = Vector2.ZERO
				obj.change_animation("dive_apex")
				phase_timer = 0.0
		
		AttackPhase.APEX:
			obj.velocity = Vector2.ZERO
			phase_timer += delta
			if phase_timer >= apex_pause:
				attack_phase = AttackPhase.FALLING
				obj.change_animation("dive_fall")
		
		AttackPhase.FALLING:
			obj.velocity.y = fall_speed
			obj.velocity.x = 0
			if obj.is_on_floor():
				_on_landing()
		
		AttackPhase.LANDING:
			obj.velocity = Vector2.ZERO
			phase_timer += delta
			if phase_timer >= land_time:
				change_state(fsm.states.idle)


func _on_landing() -> void:
	attack_phase = AttackPhase.LANDING
	phase_timer = 0.0
	obj.velocity = Vector2.ZERO
	obj.change_animation("dive_land")
	_create_shockwave()
	_shake_camera(land_shake)


func _launch() -> void:
	## Explosive launch - shake camera and blast off
	attack_phase = AttackPhase.RISING
	phase_timer = 0.0
	obj.change_animation("dive_rise")
	_shake_camera(launch_shake)


func _create_shockwave() -> void:
	var shockwave = SHOCKWAVE_SCENE.instantiate()
	obj.get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = obj.global_position + Vector2(0, 10)
	# Phase 2: bigger shockwave
	if obj.current_phase == 2:
		shockwave.max_radius = 120.0


func _shake_camera(strength: float) -> void:
	## Shake the active camera - works with player camera OR fixed arena cameras
	# Phase 2 gets 1.5x shake
	if obj.current_phase == 2:
		strength *= 1.5
	
	# Try to find any active camera that can shake
	var viewport = obj.get_viewport()
	if not viewport:
		return
	
	var camera = viewport.get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(strength)
	elif obj.found_player and obj.found_player.has_node("Camera2D"):
		# Fallback to player camera
		var player_cam = obj.found_player.get_node("Camera2D")
		if player_cam.has_method("shake"):
			player_cam.shake(strength)


func _exit() -> void:
	obj.velocity = Vector2.ZERO
