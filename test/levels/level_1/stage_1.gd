class_name StateManager
extends Node2D

func _process(delta: float) -> void:
	if(Input.is_action_just_pressed("pause")):
		if(GameManager.paused):
			GameManager.unpause()
		else:
			GameManager.pause_game()
