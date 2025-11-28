extends MarginContainer

@onready var music_check_button: CheckButton = $NinePatchRect/MusicCheckButton
@onready var sound_check_button: CheckButton = $NinePatchRect/SoundCheckButton


func _ready():
	sound_check_button.button_pressed = not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))
	music_check_button.button_pressed = not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	GameManager.pause_game()

func _exit_tree() -> void:
	pass	


func _on_sound_check_button_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not toggled_on)



func hide_popup():
	GameManager.unpause()
	queue_free()


func _on_close_texture_button_pressed() -> void:
	hide_popup()


func _on_music_check_button_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not toggled_on)


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_screen/main_menu.tscn")


func _on_restart_button_pressed() -> void:
	hide_popup()
	if GameManager.has_checkpoint():
		await GameManager.respawn_at_checkpoint()
		get_tree().reload_current_scene()
	else:
		# Nếu chưa có checkpoint → reload stage bình thường
		
		get_tree().reload_current_scene()
