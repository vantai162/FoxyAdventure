extends Player_State

var ghost_interval: float = 0.05
var ghost_timer: float = 0.0
var active_ghosts: Array[Sprite2D] = []  ## Track active ghosts for cleanup

## Dash dust effect — burst of speed feedback
const DASH_BURST_DUST: PackedScene = preload("res://assets/effects/dust_puff.tscn")

func _enter():
	super._enter()
	_cleanup_ghosts()  # Clear any lingering ghosts from previous dash
	obj.change_animation("run")
	AudioManager.play_sound("player_dash",20.0)
	obj.velocity.x = obj.dash_speed * obj.direction
	obj.velocity.y = 0
	timer = obj.dash_duration
	obj.Effect["Invicibility"] = obj.dash_duration
	
	# Dash feedback: camera shake + dust burst
	_spawn_dash_feedback()

func _exit():
	_cleanup_ghosts()  # Clean up ghosts when leaving dash state

func _update(delta: float):
	obj.velocity.x = obj.dash_speed * obj.direction
	obj.velocity.y = 0
	ghost_timer += delta
	if(ghost_timer>ghost_interval):
		create_ghost_trail()
		ghost_timer=0
	if update_timer(delta):
		obj.set_cool_down("Dash")
		## Tin fix chỗ này lại tí nếu có lỗi thì báo lại XDXD
		change_state(fsm.states.fall)
	# Wall cling: only if not on ice wall AND player is actively pressing toward wall
	# This implements "active" wall cling - no input = just fall past the wall
	if obj.is_on_wall_only() and not obj._is_wall_ice():
		if not obj.wall_cling_requires_input or obj.is_pressing_toward_wall():
			fsm.change_state(fsm.states.wallcling)

## Clean up any active ghost sprites to prevent orphans
func _cleanup_ghosts() -> void:
	for ghost in active_ghosts:
		if is_instance_valid(ghost):
			ghost.queue_free()
	active_ghosts.clear()

func create_ghost_trail():
	# Use the player's current active sprite (normal or blade)
	var original = obj.animated_sprite
	if not original:
		original = $"../../Direction/AnimatedSprite2D"  # Fallback
	
	# Create a simple Sprite2D instead of duplicating
	var ghost = Sprite2D.new()
	ghost.texture = original.sprite_frames.get_frame_texture(
		original.animation,
		original.frame
	)
	
	# Match the original's properties
	ghost.global_position = original.global_position
	ghost.scale = original.get_parent().scale
	ghost.modulate = Color(1, 1, 1, 0.4)
	ghost.z_index = ZLayers.EFFECT_BEHIND  # Ghost trails behind player
	
	# Parent to current scene (not root) — freed on scene change
	get_tree().current_scene.add_child(ghost)
	active_ghosts.append(ghost)
	
	# Fade out and delete — tween owned by GHOST for lifecycle safety
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)  # Faster fade (0.3s vs 1s)
	tween.tween_callback(func():
		active_ghosts.erase(ghost)
		ghost.queue_free()
	)

## Dash feedback: subtle camera shake + dust burst at feet
func _spawn_dash_feedback() -> void:
	# Camera shake — subtle but noticeable
	if obj.has_node("Camera2D"):
		var cam = obj.get_node("Camera2D")
		if cam.has_method("shake"):
			cam.shake(3.0)
	
	# Dust burst behind player (opposite of dash direction)
	var dust = DASH_BURST_DUST.instantiate()
	dust.global_position = obj.global_position + Vector2(-obj.direction * 8, 14)
	dust.emitting = true
	get_tree().current_scene.add_child(dust)
	get_tree().create_timer(0.6).timeout.connect(dust.queue_free)
