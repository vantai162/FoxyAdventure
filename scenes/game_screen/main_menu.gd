extends Control



func _on_start_button_pressed() -> void:
	if GameManager.has_checkpoint():
		show_start_choice_popup()
	else:
		start_new_game()

func _on_options_button_pressed() -> void:
	var remap_scene = preload("res://scenes/game_screen/input_settings_ui.tscn")
	var remap_ui = remap_scene.instantiate()
	
	add_child(remap_ui)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
func show_start_choice_popup():
	print("Creating popup...")
	var popup_scene = preload("res://scenes/game_screen/StartChoicePopup.tscn")
	
	if popup_scene == null:
		print("ERROR: Cannot load popup scene!")
		return
	
	var popup = popup_scene.instantiate()
	
	if popup == null:
		print("ERROR: Cannot instantiate popup!")
		return
	
	print("Popup created successfully")
	popup.continue_game.connect(_on_continue_game)
	popup.new_game.connect(start_new_game)
	add_child(popup)
	print("Popup added to scene tree")


func _on_continue_game():
	GameManager.is_continue_game = true
	GameManager.unpause()
	GameManager.spawnStartfromSavefile()

func start_new_game():
	GameManager.clear_checkpoint_data()
	GameManager.unpause()
	get_tree().change_scene_to_file("res://cut_scene/intro_cutscene/stage_1.tscn")
