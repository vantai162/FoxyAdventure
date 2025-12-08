extends Control

var player: Player
@onready var blade_label = $Label

func _ready():
	call_deferred("setup")
	
func setup():
	player = get_tree().get_first_node_in_group("player")
	if player and player.inventory:
		var initial_blade = player.inventory.AmountItem.get("Blade", 0)
		blade_label.text = str(initial_blade)
		player.inventory.item_amount_changed.connect(_on_item_amount_changed)

func _on_item_amount_changed(item_name: String, new_amount: int):
	# Chỉ cập nhật Label nếu vật phẩm bị thay đổi là "blade"
	if item_name == "Blade":
		blade_label.text = str(new_amount)
