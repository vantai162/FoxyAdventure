extends EnemyState

## Phase 2: Roll Bounce Attack - bouncy rolling with shockwaves on each landing

# King Crab attacks cannot be interrupted - take damage but keep attacking
# Boss poise handled by stun_immune flag — use super for proper hit feedback
func take_damage(_damage_dir: Vector2, damage: int) -> void:
	super.take_damage(_damage_dir, damage)
## 
## ANIMATION ASSUMPTIONS (create these in SpriteFrames):
##   - "roll_windup" : Curling into ball before launch (loop: false)
##   - "roll"        : Spinning ball mid-air/rolling (loop: true)
##   - "roll_land"   : Uncurling after final bounce (loop: false)

enum AttackPhase { WINDUP, JUMPING, BOUNCING, WINDDOWN }
var attack_phase: AttackPhase = AttackPhase.WINDUP

var phase_timer: float = 0.0
var bounce_count: int = 0
var _was_on_floor: bool = false
var launch_dir: int = 1


func _enter() -> void:
	attack_phase = AttackPhase.WINDUP
	phase_timer = 0.0
	bounce_count = 0
	_was_on_floor = obj.is_on_floor()
	obj.velocity = Vector2.ZERO
	
	# Decide direction toward player
	launch_dir = obj.direction
	if obj.found_player:
		launch_dir = sign(obj.found_player.global_position.x - obj.global_position.x)
		if launch_dir == 0:
			launch_dir = obj.direction
	
	# Face launch direction
	if launch_dir != obj.direction:
		obj.change_direction(launch_dir)
	
	obj.change_animation("roll_windup")


func _update(delta: float) -> void:
	match attack_phase:
		AttackPhase.WINDUP:
			obj.velocity = Vector2.ZERO
			phase_timer += delta
			if phase_timer >= obj.roll_windup_time:
				_start_rolling()
		
		AttackPhase.JUMPING, AttackPhase.BOUNCING:
			_update_rolling()
		
		AttackPhase.WINDDOWN:
			obj.velocity.x = 0
			phase_timer += delta
			if phase_timer >= obj.roll_winddown_time:
				change_state(fsm.states.idle)


func _start_rolling() -> void:
	attack_phase = AttackPhase.JUMPING
	obj.velocity = Vector2(launch_dir * obj.roll_jump_speed_x, obj.roll_jump_speed_y)
	obj.change_animation("roll")
	AudioManager.play_sound("king_spin",12.0)


func _update_rolling() -> void:
	# Detect landing (transition from air to ground)
	var on_floor = obj.is_on_floor()
	
	if on_floor and not _was_on_floor and obj.velocity.y >= 0:
		_on_bounce()
	
	_was_on_floor = on_floor
	
	# Turn around if hitting wall
	if obj.is_touch_wall():
		obj.turn_around()
		obj.velocity.x = obj.direction * obj.roll_jump_speed_x


func _on_bounce() -> void:
	_create_shockwave()
	AudioManager.play_sound("king_land",20.0)
	_shake_camera(obj.dive_land_shake)
	bounce_count += 1
	
	if bounce_count >= obj.roll_max_bounces:
		_start_winddown()
	else:
		attack_phase = AttackPhase.BOUNCING
		# Bounce again with slightly less height each time
		var height_factor = 1.0 - (bounce_count * 0.15)
		obj.velocity.y = obj.roll_bounce_velocity_y * height_factor


func _create_shockwave() -> void:
	if not obj.shockwave_scene:
		return
	var shockwave = obj.shockwave_scene.instantiate()
	obj.get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = obj.global_position + Vector2(0, 20)
	shockwave.gameplay_hit_radius = 60.0


func _start_winddown() -> void:
	attack_phase = AttackPhase.WINDDOWN
	phase_timer = 0.0
	obj.velocity = Vector2.ZERO
	obj.change_animation("roll_land")


func _exit() -> void:
	obj.velocity.x = 0
	
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
