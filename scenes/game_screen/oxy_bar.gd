extends TextureProgressBar
var player: Player
	
func _ready():
	call_deferred("setup")
	
func setup():
	player = GameManager.player

	if player:
		player.oxy_changed.connect(update)
		update()

func update():
	value = player.current_oxygen * 100 / player.max_oxygen
