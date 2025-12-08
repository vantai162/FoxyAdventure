extends EnemyState
## Elite Spawner Mushroom Death State
## Spawn 3 final minis (2 front, 1 back), fade out, no explosion

func _enter():
	obj.velocity.x = 0
	
	# Disable hurt area
	if obj.has_node("Direction/HurtArea2D/CollisionShape2D"):
		obj.get_node("Direction/HurtArea2D/CollisionShape2D").disabled = true
	
	# Spawn 3 death minis (short-lived replacements for explosion)
	_spawn_death_minions()
	
	# Fade out sprite over 1s
	var sprite = obj.get_node("Direction/AnimatedSprite2D")
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0)
	tween.tween_callback(obj.queue_free)

func _spawn_death_minions():
	if not obj.mini_factory:
		push_warning("EliteSpawnerMushroom: MiniMushroomFactory not found for death spawn!")
		return
	
	# Death burst: 2 forward (threaten player who killed us), 1 backward (coverage)
	var directions = [obj.direction, obj.direction, -obj.direction]
	# Horizontal spread: 30px apart for good spacing (not tight, not too wide)
	var offsets = [Vector2(-30, 0), Vector2(30, 0), Vector2(0, 0)]
	
	var original_pos = obj.mini_factory.global_position
	
	for i in range(3):
		# Temporarily offset factory position for spawn location
		obj.mini_factory.global_position = original_pos + offsets[i]
		
		var mini = obj.mini_factory.create()
		mini.initial_direction = directions[i]
		mini.lifetime = 1.0  ## Very short death burst (160px travel at 160px/s)
	
	# Restore factory position
	obj.mini_factory.global_position = original_pos

