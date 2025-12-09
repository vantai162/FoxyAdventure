extends Control

@onready var actions_container = $VBoxContainer

func _ready():
	_populate_actions()

func _populate_actions():
	var actions = ["left", "right","up","down","jump", "attack","throw_blade", "dash","interact"]
	for action in actions:
		var row = HBoxContainer.new()
		
		var label = Label.new()
		label.text = action.capitalize()
		row.add_child(label)
		
		var button = Button.new()
		button.text = get_key_name(action)
		button.pressed.connect(func():
			_remap_action(action, button))
		row.add_child(button)
		
		actions_container.add_child(row)

# Lấy tên phím từ action
func get_key_name(action: String) -> String:
	if GameManager.key_manager.KeyDict.has(action):
		var keycode = GameManager.key_manager.KeyDict[action]
		var ev := InputEventKey.new()
		ev.physical_keycode = keycode
		return ev.as_text()   # Ví dụ "Space", "A", "Left"
	return "Unassigned"

func _remap_action(action: String, button: Button):
	button.text = "Listening..."
	var keycode = await GameManager.key_manager.listening_and_set(get_tree(), action)
	if keycode > 0:
		button.text = get_key_name(action)
	else:
		button.text = get_key_name(action)


func _on_button_pressed() -> void:
	queue_free()
