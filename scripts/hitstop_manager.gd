extends Node
## HitstopManager — Targeted Character Freeze (THE GODOT-NATIVE WAY v2)
## 
## DESIGN PHILOSOPHY:
## Hitstop should freeze CHARACTERS visually while keeping physics coherent.
## 
## THE PROBLEM WITH process_mode = DISABLED:
## - CharacterBody2D stops calling move_and_slide()
## - If on a moving platform, character "falls off" because it's not updating
## - The node becomes a physics ghost
##
## THE CORRECT APPROACH:
## 1. Keep _physics_process RUNNING (so move_and_slide() tracks platforms)
## 2. Zero velocity (character doesn't move on its own)
## 3. Pause AnimatedSprite2D (visual freeze)
## 4. Set a "frozen" flag the FSM respects (no state transitions, no input)
##
## Characters check `is_frozen()` to skip their update logic.

## Track frozen nodes to restore them
var _frozen_nodes: Dictionary = {}  # node -> freeze_data


## Check if a node is currently frozen
func is_frozen(node: Node) -> bool:
	return _frozen_nodes.has(node)


## Freeze a specific node for hitstop effect.
## The node should check is_frozen() in its _physics_process to skip logic.
func freeze_node(node: Node, duration: float) -> void:
	if not is_instance_valid(node):
		return
	if duration <= 0:
		return
	if _frozen_nodes.has(node):
		return  # Already frozen
	
	var freeze_data := {
		"original_velocity": Vector2.ZERO,
		"animated_sprites": [] as Array[AnimatedSprite2D],
	}
	
	# Store and zero velocity for CharacterBody2D
	if node is CharacterBody2D:
		freeze_data.original_velocity = node.velocity
		node.velocity = Vector2.ZERO
	
	# Find and pause all AnimatedSprite2D nodes
	_collect_animated_sprites(node, freeze_data.animated_sprites)
	for sprite: AnimatedSprite2D in freeze_data.animated_sprites:
		sprite.pause()
	
	_frozen_nodes[node] = freeze_data
	
	# Schedule unfreeze with REAL TIME timer
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_unfreeze_node.bind(node))


## Unfreeze a specific node
func _unfreeze_node(node: Node) -> void:
	if not _frozen_nodes.has(node):
		return
	
	var freeze_data: Dictionary = _frozen_nodes[node]
	_frozen_nodes.erase(node)
	
	if not is_instance_valid(node):
		return
	
	# Restore velocity (NOT process mode — we never disabled it)
	if node is CharacterBody2D:
		node.velocity = freeze_data.original_velocity
	
	# Resume animations
	for sprite: AnimatedSprite2D in freeze_data.animated_sprites:
		if is_instance_valid(sprite):
			sprite.play()


## Recursively collect AnimatedSprite2D nodes
func _collect_animated_sprites(node: Node, sprites: Array[AnimatedSprite2D]) -> void:
	for child in node.get_children():
		if child is AnimatedSprite2D:
			sprites.append(child)
		_collect_animated_sprites(child, sprites)


## LEGACY API: For backwards compatibility
func request_hitstop(duration: float) -> bool:
	if duration <= 0:
		return false
	var player = GameManager.player
	if is_instance_valid(player):
		freeze_node(player, duration)
	return true


## Force end all hitstops
func cancel_hitstop() -> void:
	for node in _frozen_nodes.keys():
		_unfreeze_node(node)
