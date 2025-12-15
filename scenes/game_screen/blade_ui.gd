extends Control
## Blade UI — Shows current blade count and max capacity
## Format: "2/3" means 2 blades held, 3 max capacity

var player: Player
@onready var blade_label = $Label

func _ready():
	call_deferred("setup")
	
func setup():
	player = GameManager.player
	if player:
		_update_display()
		player.blade_changed.connect(_on_blade_changed)

func _on_blade_changed(_new_amount: int):
	_update_display()

func _update_display():
	if not player:
		return
	# Show current/max for clarity (e.g., "2/3")
	blade_label.text = "%d/%d" % [player.blade_count, player.max_blade_capacity]
