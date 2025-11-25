extends Control

var player: Player
@onready var key_label = $Label

func _ready():
	call_deferred("setup")
	
func setup():
	player = get_tree().get_first_node_in_group("player")
	if player and player.inventory:
		var initial_key = player.inventory.AmountItem.get("Key", 0)
		key_label.text = str(initial_key)
		player.inventory.item_amount_changed.connect(_on_item_amount_changed)

func _on_item_amount_changed(item_name: String, new_amount: int):
	# Chỉ cập nhật Label nếu vật phẩm bị thay đổi là "key"
	$AudioStreamPlayer.play()
	if item_name == "Key":
		key_label.text = str(new_amount)
