extends EnemyState

var spawned := 0

func _enter() -> void:
	spawned = 0
	obj.velocity = Vector2.ZERO
	obj.change_animation("summon") 

	await get_tree().create_timer(0.5).timeout
	_spawn_next()

func _spawn_next():
	if spawned >= obj.minicrab_count:
		obj.fsm.change_state(fsm.states.idle)
		return

	if obj.minicrab_scene == null:
		push_warning("minicrab scene is not assigned!")
		obj.fsm.change_state(fsm.states.idle)
		return

	var minicrab = obj.minicrab_scene.instantiate()
	obj.get_tree().current_scene.add_child(minicrab)

	var forward := Vector2(obj.direction, 0)
	minicrab.global_position = obj.global_position + forward * obj.minicrab_spawn_radius

	spawned += 1

	await get_tree().create_timer(obj.minicrab_spawn_interval).timeout
	_spawn_next()
