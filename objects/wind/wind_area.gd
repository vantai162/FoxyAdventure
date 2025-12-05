extends Area2D
class_name WindArea
## Wind zone that pushes entities
## Affects player, enemies, and optionally projectiles

@export_group("Wind Settings")
@export var wind_force: Vector2 = Vector2(-150, 0)  ## Force applied per frame
@export var affect_enemies: bool = true  ## Push enemies too
@export var affect_projectiles: bool = false  ## Push projectiles
@export var enemy_force_multiplier: float = 0.5  ## Enemies resist wind more

var _bodies_in_wind: Array[Node2D] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	## Apply wind to all tracked bodies
	for body in _bodies_in_wind:
		if not is_instance_valid(body):
			continue
		_apply_wind_to_body(body, delta)

func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	
	# Player - use wind_velocity property for smooth integration
	if body.is_in_group("player") and "wind_velocity" in body:
		body.wind_velocity = wind_force
		return
	
	# Track body for physics_process application
	if _should_affect_body(body):
		if not _bodies_in_wind.has(body):
			_bodies_in_wind.append(body)

func _on_body_exited(body: Node2D) -> void:
	if body == null:
		return
	
	# Player - clear wind_velocity
	if body.is_in_group("player") and "wind_velocity" in body:
		body.wind_velocity = Vector2.ZERO
		return
	
	# Remove from tracking
	_bodies_in_wind.erase(body)

func _should_affect_body(body: Node2D) -> bool:
	## Determine if this body should be affected by wind
	if body.is_in_group("player"):
		return false  # Player handled separately via wind_velocity
	
	if body.is_in_group("enemy") and affect_enemies:
		return true
	
	if body.is_in_group("projectile") and affect_projectiles:
		return true
	
	return false

func _apply_wind_to_body(body: Node2D, delta: float) -> void:
	## Apply wind force directly to body velocity
	var force = wind_force * delta
	
	# Enemies resist wind more
	if body.is_in_group("enemy"):
		force *= enemy_force_multiplier
	
	# Apply to velocity if it exists
	if "velocity" in body:
		if body.velocity is Vector2:
			body.velocity += force
		return
	
	# Fallback: move position directly (for non-CharacterBody nodes)
	body.global_position += force
