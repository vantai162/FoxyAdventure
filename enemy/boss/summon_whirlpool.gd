extends EnemyState

## Phase 2 whirlpool summoning attack
## Spawns 1-3 whirlpools at random positions within the water when water is raised
## Only usable when water is in raised state

@export var min_whirlpools: int = 1
@export var max_whirlpools: int = 3
@export var spawn_depth_below_surface: float = 90.0  ## Distance below water surface
@export var edge_margin: float = 200.0                ## Keep away from water edges
@export var min_spacing: float = 250.0                ## Minimum distance between whirlpools

var whirlpool_scene: PackedScene = preload("res://objects/whirlpool/whirlpool.tscn")

func _enter():
	obj.change_animation("summon")
	_summon_whirlpools()

func _update(delta):
	pass

func _summon_whirlpools() -> void:
	# Verify water is raised before spawning
	if not obj.water_raised:
		push_warning("WarlordTurtle: Cannot summon whirlpools - water not raised")
		change_state(fsm.states.idle)
		return
	
	var water_node = obj.get_water_node()
	if not water_node:
		push_warning("WarlordTurtle: Cannot find water node for whirlpool spawning")
		change_state(fsm.states.idle)
		return
	
	# Calculate spawn area bounds
	var water_global_pos = water_node.global_position
	var water_width = water_node.water_size.x
	var water_surface_y = water_node.get_water_surface_global_y()
	
	var spawn_min_x = water_global_pos.x + edge_margin
	var spawn_max_x = water_global_pos.x + water_width - edge_margin
	var spawn_y = water_surface_y + spawn_depth_below_surface
	
	# Determine number of whirlpools to spawn
	var whirlpool_count = randi_range(min_whirlpools, max_whirlpools)
	
	# Generate spawn positions with spacing
	var spawn_positions: Array[Vector2] = []
	for i in range(whirlpool_count):
		var attempts = 0
		var valid_position = false
		var spawn_pos: Vector2
		
		while not valid_position and attempts < 20:
			var random_x = randf_range(spawn_min_x, spawn_max_x)
			spawn_pos = Vector2(random_x, spawn_y)
			
			# Check spacing from existing positions
			valid_position = true
			for existing_pos in spawn_positions:
				if spawn_pos.distance_to(existing_pos) < min_spacing:
					valid_position = false
					break
			
			attempts += 1
		
		if valid_position:
			spawn_positions.append(spawn_pos)
			_spawn_whirlpool(spawn_pos)
	
	# Wait for animation, then return to idle
	await get_tree().create_timer(1.0).timeout
	change_state(fsm.states.idle)

func _spawn_whirlpool(position: Vector2) -> void:
	var whirlpool = whirlpool_scene.instantiate()
	whirlpool.global_position = position
	get_tree().current_scene.add_child(whirlpool)
