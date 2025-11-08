extends EnemyState

var can_jump: bool = true
var jump_react_range: float = 60.0
var jump_cooldown: float = 1.0

func _enter() -> void:
	obj.face_player()
	obj.change_animation("defend")
	obj.shield.show()
	obj.shield.get_node("CollisionShape2D").disabled = false
	obj.attack_timer.start()
	can_jump = true

func _update(_delta: float) -> void:
	obj.face_player()
	
	if obj.found_player and can_jump:
		var dist = abs(obj.found_player.global_position.x - obj.global_position.x)
		if dist < jump_react_range and obj.found_player.velocity.y < -100:
			_perform_block_jump()

func _perform_block_jump():
	can_jump = false
	obj.jump()
	get_tree().create_timer(jump_cooldown).timeout.connect(func(): can_jump = true)

func _exit() -> void:
	obj.attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	change_state(fsm.states.attack)
