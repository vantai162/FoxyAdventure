extends EnemyState

func _enter() -> void:
	obj.change_animation("sleep")
	obj.velocity.x = 0
	
	var stage = obj.get_parent()
	if stage and not stage.is_connected("player_entered", Callable(self, "_on_player_entered")):
		stage.connect("player_entered", Callable(self, "_on_player_entered"))
		
	
func _exit() -> void:
	# Ngắt kết nối khi rời state
	var stage = obj.get_parent()
	if stage and stage.is_connected("player_entered", Callable(self, "_on_player_entered")):
		stage.disconnect("player_entered", Callable(self, "_on_player_entered"))

func _on_player_entered() -> void:
	# Khi người chơi vào vùng, chuyển sang wake_up
	change_state(fsm.states.wakeup)
