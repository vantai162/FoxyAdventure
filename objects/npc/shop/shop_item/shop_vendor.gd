extends Area2D

var is_opened: bool = false
var is_collision_with_player: bool = false

@export var text: String = "Shop (Nhấn [Q] để tương tác)"

@onready var text_panel: Panel = $Panel  # Lấy node Panel
@onready var label: Label = $Panel/Label # Lấy Label con của Panel

var active_tween: Tween # Biến để lưu tween đang chạy

func _ready():
	label.text = text
	
	# Ẩn panel đi khi bắt đầu (và làm nó trong suốt)
	text_panel.visible = false
	text_panel.modulate.a = 0.0

@onready var animated_sprite = $Sprite2D
@onready var shop_ui_scene: PackedScene = preload("res://objects/npc/shop/shop_ui.tscn")
var shop_ui_instance: Control

func _physics_process(delta: float) -> void:
	if is_collision_with_player and Input.is_action_just_pressed("interact"):
		if not is_opened:
			_open_shop()
		else:
			_close_shop()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		is_collision_with_player = true
		if active_tween:
			active_tween.kill()
		
		# Tạo tween mới để fade-in
		active_tween = create_tween()
		text_panel.visible = true # Hiện panel
		# Cho nó mờ dần từ 0.0 -> 1.0 trong 0.3 giây
		active_tween.tween_property(text_panel, "modulate:a", 1.0, 0.3)
		
		

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_collision_with_player = false
		_close_shop()
		# Hủy tween cũ (nếu có)
		if active_tween:
			active_tween.kill()

		# Tạo tween mới để fade-out
		active_tween = create_tween()
		# Mờ dần từ 1.0 -> 0.0 trong 0.3 giây
		active_tween.tween_property(text_panel, "modulate:a", 0.0, 0.3)
		
		# Sau khi mờ xong, thì mới ẩn đi (ĐÃ SỬA)
		active_tween.tween_callback(text_panel.set.bind("visible", false))

# ---------------------------------------------------

func _open_shop():
	if is_opened:
		return

	# Tạo UI và add vào cây  
	shop_ui_instance = shop_ui_scene.instantiate()
	get_parent().get_node("CanvasLayer").add_child(shop_ui_instance)

	is_opened = true
	print("Shop opened")

	# Dừng game nếu muốn (tùy bạn)
	# get_tree().paused = true
	# shop_ui_instance.pause_mode = Node.PAUSE_MODE_PROCESS

func _close_shop():
	if not is_opened:
		return

	if is_instance_valid(shop_ui_instance):
		shop_ui_instance.queue_free()

	is_opened = false
	print("Shop closed")

	# get_tree().paused = false
