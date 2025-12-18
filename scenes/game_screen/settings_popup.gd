extends MarginContainer

@onready var music_check_button: CheckButton = $NinePatchRect/MusicCheckButton
@onready var sound_check_button: CheckButton = $NinePatchRect/SoundCheckButton
@onready var music_volume_slider: HSlider = $NinePatchRect/MusicVolumeSlider
@onready var sound_volume_slider: HSlider = $NinePatchRect/SoundVolumeSlider

func _ready():
	sound_check_button.button_pressed = not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX"))
	music_check_button.button_pressed = not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music"))
	
	music_volume_slider.min_value = -40
	music_volume_slider.max_value = 0
	music_volume_slider.step = 1
	sound_volume_slider.min_value = -40
	sound_volume_slider.max_value = 0
	sound_volume_slider.step = 1
	
	var music_bus = AudioServer.get_bus_index("Music")
	var sfx_bus = AudioServer.get_bus_index("SFX")
	music_volume_slider.value = AudioServer.get_bus_volume_db(music_bus)
	sound_volume_slider.value = AudioServer.get_bus_volume_db(sfx_bus)
	
	GameManager.pause_game()

func _exit_tree() -> void:
	pass	

func _on_sound_check_button_toggled(toggled_on: bool) -> void:
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var sfx_cave_bus = AudioServer.get_bus_index("SFX_Cave")
	
	# Nếu người dùng tắt check button thì mute cả hai bus
	AudioServer.set_bus_mute(sfx_bus, not toggled_on)
	AudioServer.set_bus_mute(sfx_cave_bus, not toggled_on)
	sound_volume_slider.editable = toggled_on

func _on_music_check_button_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not toggled_on)
	music_volume_slider.editable = toggled_on

func _on_music_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),value)
	#if music_check_button.button_pressed == false:
		#music_check_button.button_pressed = true

func _on_sound_volume_slider_value_changed(value: float) -> void:
	var sfx_bus = AudioServer.get_bus_index("SFX")
	var sfx_cave_bus = AudioServer.get_bus_index("SFX_Cave")
	
	AudioServer.set_bus_volume_db(sfx_bus, value)
	AudioServer.set_bus_volume_db(sfx_cave_bus, value)
	#if sound_check_button.button_pressed == false:
		#sound_check_button.button_pressed = true

func hide_popup():
	GameManager.unpause()
	queue_free()

func _on_close_texture_button_pressed() -> void:
	hide_popup()

func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game_screen/main_menu.tscn")

func _on_restart_button_pressed() -> void:
	var player = GameManager.player
	hide_popup()
	player.die()
	
func _on_control_button_pressed() -> void:
	var remap_scene = preload("res://scenes/game_screen/input_settings_ui.tscn")
	var remap_ui = remap_scene.instantiate()
	add_child(remap_ui)
func fade_bus(bus_name: String, target_db: float, duration := 0.5):
	var bus = AudioServer.get_bus_index(bus_name)
	var tween = create_tween()
	tween.tween_method(
		func(value): AudioServer.set_bus_volume_db(bus, value),
		AudioServer.get_bus_volume_db(bus),
		target_db,
		duration
	)
