extends TextureProgressBar
var player: Player
	
func _ready():
	call_deferred("setup")
	
func setup():
	player = get_tree().get_first_node_in_group("player")

	if player:
		player.health_changed.connect(update)
		update()

func update():
	value = player.health * 100 / player.max_health
