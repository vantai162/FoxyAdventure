extends TextureProgressBar
var boss: EnemyCharacter
	
func _ready():
	call_deferred("setup")
	
func setup():
	boss = get_tree().get_first_node_in_group("boss")

	if boss:
		boss.health_changed.connect(update)
		update()

func update():
	value = boss.health * 100 / (boss.max_health / 2)
