class_name StateManager
extends Node2D
func _enter_tree() -> void:
	GameManager.current_stage=self
func _process(delta: float) -> void:
	if(Input.is_action_just_pressed("pause")):
		if(GameManager.paused):
			GameManager.unpause()
		else:
			GameManager.pause_game()

func _ready() -> void:
	GameManager.key_manager._set_key("kill",81)
#KeyManager

		
