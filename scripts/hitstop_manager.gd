extends Node
## HitstopManager — Targeted Node Freeze (Godot-Native)
## 
## DESIGN PHILOSOPHY (Kojima's Law):
## "If the player can't see it, they can't feel it."
## Hitstop = VISUAL WEIGHT. The moment of impact must REGISTER.
##
## TECHNICAL APPROACH:
## - Freeze INDIVIDUAL nodes, not Engine.time_scale
## - Keep _physics_process running (platform tracking works)
## - Zero velocity + pause animations = visual freeze
## - Scripts check is_frozen() to skip their movement logic
##
## WHY NOT Engine.time_scale = 0?
## - Breaks moving platforms (character falls off)
## - Breaks Timer nodes (unless process_always)
## - All-or-nothing: can't freeze attacker while victim recoils
##
## SUPPORTED NODE TYPES:
## - CharacterBody2D: Velocity stored/zeroed/restored ✓
## - RigidBody2D: Physics frozen via freeze property ✓
## - Area2D/Other: Registered; script must check is_frozen() ✓
## - AnimatedSprite2D children: Animations paused ✓

## Frozen nodes registry: node -> FreezeData
var _frozen_nodes: Dictionary = {}


## Query: Is this node currently frozen?
func is_frozen(node: Node) -> bool:
	return _frozen_nodes.has(node)


## Freeze a specific node for hitstop effect.
## CharacterBody2D/RigidBody2D: Automatic freeze.
## Area2D/other: Script must check is_frozen() in _physics_process.
func freeze_node(node: Node, duration: float) -> void:
	# Guard clauses — fail fast, fail loud (in debug)
	if not is_instance_valid(node):
		push_warning("HitstopManager.freeze_node: Invalid node")
		return
	if duration <= 0.0:
		return
	if _frozen_nodes.has(node):
		return  # Already frozen — no stacking
	
	# Capture state before freeze
	var freeze_data: Dictionary = {
		"original_velocity": Vector2.ZERO,
		"original_linear_velocity": Vector2.ZERO,
		"original_angular_velocity": 0.0,
		"was_rigid_frozen": false,
		"animated_sprites": [] as Array[AnimatedSprite2D],
	}
	
	# CharacterBody2D: Store and zero velocity
	if node is CharacterBody2D:
		freeze_data.original_velocity = node.velocity
		node.velocity = Vector2.ZERO
	
	# RigidBody2D: Use Godot's built-in freeze (stops physics simulation)
	if node is RigidBody2D:
		freeze_data.original_linear_velocity = node.linear_velocity
		freeze_data.original_angular_velocity = node.angular_velocity
		freeze_data.was_rigid_frozen = node.freeze
		node.freeze = true
	
	# Pause all AnimatedSprite2D descendants
	_collect_animated_sprites(node, freeze_data.animated_sprites)
	for sprite: AnimatedSprite2D in freeze_data.animated_sprites:
		sprite.pause()
	
	_frozen_nodes[node] = freeze_data
	
	# Schedule unfreeze — use REAL TIME so it works even if time_scale is 0 elsewhere
	# Args: duration, process_always=true, process_in_physics=false, ignore_time_scale=true
	var timer: SceneTreeTimer = get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_unfreeze_node.bind(node))


## Internal: Restore node to pre-freeze state
func _unfreeze_node(node: Node) -> void:
	if not _frozen_nodes.has(node):
		return
	
	var freeze_data: Dictionary = _frozen_nodes[node]
	_frozen_nodes.erase(node)
	
	if not is_instance_valid(node):
		return  # Node was freed during freeze — nothing to restore
	
	# Restore CharacterBody2D velocity
	if node is CharacterBody2D:
		node.velocity = freeze_data.original_velocity
	
	# Restore RigidBody2D physics
	if node is RigidBody2D:
		node.freeze = freeze_data.was_rigid_frozen
		# Restore velocity after unfreeze (next physics frame)
		node.linear_velocity = freeze_data.original_linear_velocity
		node.angular_velocity = freeze_data.original_angular_velocity
	
	# Resume animations
	for sprite: AnimatedSprite2D in freeze_data.animated_sprites:
		if is_instance_valid(sprite):
			sprite.play()


## Internal: Recursively collect AnimatedSprite2D descendants
func _collect_animated_sprites(node: Node, sprites: Array[AnimatedSprite2D]) -> void:
	for child in node.get_children():
		if child is AnimatedSprite2D:
			sprites.append(child)
		_collect_animated_sprites(child, sprites)


## Emergency: Cancel ALL active freezes (scene transitions, pause menu)
func cancel_all_freezes() -> void:
	# Copy keys to avoid modification during iteration
	var nodes_to_unfreeze: Array = _frozen_nodes.keys().duplicate()
	for node in nodes_to_unfreeze:
		_unfreeze_node(node)
