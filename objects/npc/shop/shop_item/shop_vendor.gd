extends Area2D

var is_opened: bool = false
var is_collision_with_player: bool = false

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
		
		

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		is_collision_with_player = false
		_close_shop()
		

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
