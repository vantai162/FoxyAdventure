class_name StateManager
extends Node2D
func _ready() -> void:
	print("Call change stage	")
	GameManager.current_stage=self
	GameManager.key_manager._set_key("kill",81)
	if (GameManager.player==null):
		GameManager.spawn_player(GameManager.checkpoint_data[GameManager.current_checkpoint_id]["player_state"])
	else:
		GameManager.respawn_at_checkpoint()
func _process(delta: float) -> void:
	if(Input.is_action_just_pressed("pause")):
		if(GameManager.paused):
			GameManager.unpause()
		else:
			GameManager.pause_game()

	
#KeyManager

		
