extends Control

var player: Player
@onready var blade_label = $Label

func _ready():
	call_deferred("setup")
	
func setup():
	player = GameManager.player
	if player:
		var initial_blade = player.blade_count
		blade_label.text = str(initial_blade)
		player.blade_changed.connect(_on_item_amount_changed)

func _on_item_amount_changed(new_amount: int):
	# Chỉ cập nhật Label nếu vật phẩm bị thay đổi là "blade"
	blade_label.text = str(new_amount)
