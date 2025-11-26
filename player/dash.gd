extends Player_State

var ghost_interval: float = 0.05
var ghost_timer: float = 0.0

func _enter():
	super._enter()
	obj.change_animation("run")
	obj.velocity.x = obj.dash_speed * obj.direction
	obj.velocity.y = 0
	timer = obj.dash_duration
	obj.Effect["Invicibility"] = obj.dash_duration

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
	if obj.is_on_wall_only():
		fsm.change_state(fsm.states.wallcling)

func create_ghost_trail():
	var original = $"../../Direction/AnimatedSprite2D"
	
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
	
	# Add to the scene root so it doesn't move with the player
	get_tree().root.add_child(ghost)
	
	# Fade out and delete
	var tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 1)
	tween.tween_callback(ghost.queue_free)
