extends Control



func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://test/levels/level_1.tscn")
	GameManager.unpause()

func _on_options_button_pressed() -> void:
	var remap_scene = preload("res://scenes/game_screen/input_settings_ui.tscn")
	var remap_ui = remap_scene.instantiate()
	
	# Thêm vào cây node, thường là dưới CanvasLayer hoặc root
	add_child(remap_ui)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
