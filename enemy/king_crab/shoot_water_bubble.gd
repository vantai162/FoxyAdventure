extends EnemyState

var _timer := 0.0
var interval := 0.0

func _enter() -> void:
	obj.change_animation("bubble_attack")
	_timer = 0.0
	interval = obj.bubble_attack_interval
	_fire_bubbles()  
	

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= interval:
		_timer = 0
		obj.fsm.change_state(fsm.states.idle)


func _fire_bubbles():
	var left = obj.global_scale.x < 0  
	var dir = Vector2.LEFT if left else Vector2.RIGHT

	var pos1 = obj.upper_claw_pos.global_position
	var pos2 = obj.lower_claw_pos.global_position

	_spawn_bubble_from(pos1, dir)
	_spawn_bubble_from(pos2, dir)


func _spawn_bubble_from(pos: Vector2, dir: Vector2):
	if obj.water_bubble_factory == null:
		return

	var bubble: RigidBody2D = obj.water_bubble_factory.create()
	obj.get_tree().current_scene.add_child(bubble)

	bubble.global_position = pos
	bubble.launch(dir, obj.bubble_speed)
	bubble.trap_duration = obj.bubble_trap_duration
