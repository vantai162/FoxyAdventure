extends TextureProgressBar
var player: Player
	
func _ready():
	call_deferred("setup")
	
func setup():
	player = GameManager.player

	if player:
		player.health_changed.connect(update)
		player.max_health_changed.connect(update)
		update()

func update():
	value = player.health * 100 / player.max_health
