extends Control

@onready var actions_container = $TextureRect/GridContainer
var style_normal 
func _ready():
	# Tạo giao diện cho nút phím
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("4b3d33") # Màu nâu đậm
	style_normal.set_border_width_all(2)
	style_normal.border_color = Color("2d221a") # Viền đậm hơn tạo độ khối
	style_normal.corner_radius_top_left = 2
	style_normal.corner_radius_bottom_right = 2
	
	# Sau đó khi tạo Button ở trên, bạn áp dụng:
	
	_populate_actions()

func _populate_actions():
	# Giả sử bạn đổi actions_container sang GridContainer trong Editor
	actions_container.columns = 2 
	# Khoảng cách giữa các hàng và cột
	actions_container.add_theme_constant_override("h_separation", 40)
	actions_container.add_theme_constant_override("v_separation", 7)

	var actions = ["left", "right","up","down","jump", "attack","throw_blade", "dash","interact"]
	for action in actions:
		# 1. Label cho tên hành động
		var label = Label.new()
		label.text = action.capitalize()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT # Căn phải cho đẹp
		# Thêm font pixel nếu bạn có
		label.add_theme_font_size_override("font_size", 12) 
		actions_container.add_child(label)
		
		# 2. Button cho phím bấm
		var button = Button.new()
		button.text = get_key_name(action)
		# Đặt kích thước tối thiểu để nút phím nhìn cân đối
		button.custom_minimum_size = Vector2(80, 24) 
		button.add_theme_stylebox_override("normal", style_normal)
		button.pressed.connect(func():
			_remap_action(action, button))
		actions_container.add_child(button)

# Lấy tên phím từ action
func get_key_name(action: String) -> String:
	if GameManager.key_manager.KeyDict.has(action):
		var keycode = GameManager.key_manager.KeyDict[action]
		return OS.get_keycode_string(keycode)
	return "Unassigned"

func _remap_action(action: String, button: Button):
	button.text = "Listening..."
	button.modulate = Color.YELLOW # Làm nút sáng lên khi đang chờ
	var keycode = await GameManager.key_manager.listening_and_set(get_tree(), action)
	button.modulate = Color.WHITE # Trả về màu bình thường
	if keycode > 0:
		button.text = get_key_name(action)
	else:
		button.text = get_key_name(action)


func _on_button_pressed() -> void:
	queue_free()
