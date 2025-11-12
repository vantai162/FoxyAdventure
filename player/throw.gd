extends Player_State

@export var blade_projectile_scene: PackedScene = preload("res://projectiles/blade_projectile.tscn")

func _enter() -> void:
	if obj.is_on_floor():
		obj.change_animation("attack")
	else:
		obj.change_animation("Jump_attack")
	
	timer = 0.2
	obj.velocity.x = 0
	
	_throw_blade()

func _exit() -> void:
	pass

func _update(delta: float) -> void:
	if update_timer(delta):
		change_state(fsm.previous_state)

func _throw_blade() -> void:
	if not obj.can_throw_blade():
		return
	
	var blade = blade_projectile_scene.instantiate()
	get_tree().current_scene.add_child(blade)
	
	var throw_offset = Vector2(40 * obj.direction, -10)
	blade.global_position = obj.global_position + throw_offset
	
	blade.launch(obj.direction, obj)
	
	obj.consume_blade()
