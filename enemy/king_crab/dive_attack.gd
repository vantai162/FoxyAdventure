extends EnemyState

## Dive ground-pound attack with warning indicator and wind-up

# King Crab attacks cannot be interrupted - take damage but keep attacking
func take_damage(_damage_dir, damage: int) -> void:
	obj.take_damage(damage)
## 
## ANIMATION ASSUMPTIONS (create these in SpriteFrames):
##   - "dive_windup"  : Crouch/prepare before launching (loop: false)
##   - "dive_rise"    : Launching upward, legs tucked (loop: true)
##   - "dive_apex"    : Hovering at top, maybe slight anticipation (loop: true)
##   - "dive_fall"    : Plummeting down, claws forward (loop: true)
##   - "dive_land"    : Impact/slam on ground (loop: false)

enum AttackPhase { WINDUP, RISING, APEX, FALLING, LANDING }
var attack_phase: AttackPhase = AttackPhase.WINDUP

var phase_timer: float = 0.0
var start_y: float = 0.0  ## Ground level where crab started
var target_x: float = 0.0
var target_ground_y: float = 0.0  ## Ground level where player is (where we SHOULD land)


func _enter() -> void:
	attack_phase = AttackPhase.WINDUP
	phase_timer = 0.0
	start_y = obj.global_position.y
	
	# Target player position and their ground level
	if obj.found_player:
		target_x = obj.found_player.global_position.x
		target_ground_y = obj.found_player.global_position.y
	else:
		target_x = obj.global_position.x
		target_ground_y = start_y
	
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
			if phase_timer >= obj.dive_windup_time:
				_launch()
		
		AttackPhase.RISING:
			obj.velocity.y = -obj.dive_rise_speed
			obj.velocity.x = 0
			
			var risen_distance = start_y - obj.global_position.y
			
			# Hit ceiling? Only count it if we've risen at least 100 pixels
			# This prevents false triggers from enemies landing on us
			if obj.is_on_ceiling() and risen_distance > 100:
				_start_falling()
			elif risen_distance >= obj.dive_rise_height:
				# Reached target height
				attack_phase = AttackPhase.APEX
				obj.global_position.x = target_x
				obj.velocity = Vector2.ZERO
				obj.change_animation("dive_apex")
				phase_timer = 0.0
		
		AttackPhase.APEX:
			obj.velocity = Vector2.ZERO
			phase_timer += delta
			if phase_timer >= obj.dive_apex_pause:
				_start_falling()
		
		AttackPhase.FALLING:
			obj.velocity.y = obj.dive_fall_speed
			obj.velocity.x = 0
			
			if obj.is_on_floor():
				# Check if we landed on a ledge (above where player was)
				# Give some tolerance (~50 pixels) for slight height differences
				if obj.global_position.y < target_ground_y - 50:
					# We're on a ledge above the player - slide off toward target
					_slide_off_ledge()
				else:
					# Good landing on proper ground
					_on_landing()
		
		AttackPhase.LANDING:
			obj.velocity = Vector2.ZERO
			phase_timer += delta
			if phase_timer >= obj.dive_land_time:
				change_state(fsm.states.idle)


func _start_falling() -> void:
	attack_phase = AttackPhase.FALLING
	obj.change_animation("dive_fall")
	# Make sure we're at target X when falling
	obj.global_position.x = target_x


func _slide_off_ledge() -> void:
	## We landed on a ledge above the player - walk off it toward the target
	## This prevents the crab from awkwardly landing on platforms above the player
	var dir_to_target = sign(target_x - obj.global_position.x)
	if dir_to_target == 0:
		dir_to_target = obj.direction
	
	# Push crab slightly off the ledge and let gravity take over
	obj.global_position.x += dir_to_target * 30
	# Stay in falling state - we'll land properly on next floor check
	change_state(fsm.states.idle)


func _on_landing() -> void:
	attack_phase = AttackPhase.LANDING
	phase_timer = 0.0
	obj.velocity = Vector2.ZERO
	obj.change_animation("dive_land")
	_create_shockwave()
	_shake_camera(obj.dive_land_shake)


func _launch() -> void:
	## Explosive launch - shake camera and blast off
	attack_phase = AttackPhase.RISING
	phase_timer = 0.0
	obj.change_animation("dive_rise")
	_shake_camera(obj.dive_launch_shake)


func _create_shockwave() -> void:
	if not obj.shockwave_scene:
		return
	var shockwave = obj.shockwave_scene.instantiate()
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
