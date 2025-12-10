extends Area2D
class_name PlayerTargeting
## Directional targeting for Foxy's throws.
## Shows which enemy is locked and provides clamped throw angle.
##
## MUST be placed under Direction node to flip with player facing.
## Uses forward-facing detection shape - enemies behind are never detected.

signal target_acquired(enemy: Node2D)
signal target_lost()

## --- Editor Configuration ---
@export_group("Acquisition")
@export var acquisition_time: float = 0.15  ## Time enemy must be visible before lock
@export var lock_persistence: float = 0.1  ## Grace period after target leaves view

@export_group("Throw Angle")
@export var max_angle_degrees: float = 25.0  ## Max up/down throw angle (prevents ground ricochet)

@export_group("Visual Feedback")
@export var indicator_scene: PackedScene  ## TargetIndicator scene to spawn

## --- Runtime State ---
var _player: Node2D = null
var _enemies_in_range: Array[Node2D] = []
var _current_target: Node2D = null
var _potential_target: Node2D = null
var _acquisition_timer: float = 0.0
var _lock_timer: float = 0.0
var _indicator: Node2D = null

## --- Public API ---

func has_locked_target() -> bool:
	return is_instance_valid(_current_target)

func get_current_target() -> Node2D:
	return _current_target

## Returns clamped throw angle toward current target (radians)
## Direction: 1 = facing right, -1 = facing left
func get_throw_angle(facing_direction: int = 1) -> float:
	if _current_target == null or _player == null:
		return 0.0 if facing_direction == 1 else PI
	if not is_instance_valid(_current_target):
		return 0.0 if facing_direction == 1 else PI
	
	var to_target := _current_target.global_position - _player.global_position
	var angle := to_target.angle()
	var limit := deg_to_rad(max_angle_degrees)
	
	if facing_direction == 1:
		# Facing right: clamp around 0° (horizontal right)
		return clampf(angle, -limit, limit)
	else:
		# Facing left: clamp around π (horizontal left)
		# angle_difference(PI, angle) = angle - PI, normalized to [-π, π]
		# Positive = target above horizontal, Negative = target below horizontal
		var deviation := angle_difference(PI, angle)
		var clamped_deviation := clampf(deviation, -limit, limit)
		# Add deviation to PI to get final angle (not subtract!)
		return PI + clamped_deviation

func release_target() -> void:
	_clear_indicator()
	_current_target = null
	_potential_target = null
	_acquisition_timer = 0.0
	_lock_timer = 0.0
	target_lost.emit()

func setup(player: Node2D) -> void:
	_player = player

## --- Indicator Management ---

func _spawn_indicator(target: Node2D) -> void:
	_clear_indicator()
	if indicator_scene == null:
		return
	_indicator = indicator_scene.instantiate()
	get_tree().current_scene.add_child(_indicator)
	if _indicator.has_method("attach_to"):
		_indicator.attach_to(target)


func _clear_indicator() -> void:
	if _indicator != null and is_instance_valid(_indicator):
		if _indicator.has_method("detach"):
			_indicator.detach()
		else:
			_indicator.queue_free()
		_indicator = null

## --- Lifecycle ---

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy") and body not in _enemies_in_range:
		_enemies_in_range.append(body)


func _on_body_exited(body: Node2D) -> void:
	_enemies_in_range.erase(body)

## --- Per-Frame Update ---

func _process(delta: float) -> void:
	if _player == null:
		return
	
	# Clean dead/freed enemies
	_enemies_in_range = _enemies_in_range.filter(
		func(e): return is_instance_valid(e) and not e.is_dead()
	)
	
	var best := _find_closest()
	_update_acquisition(best, delta)


func _find_closest() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for enemy in _enemies_in_range:
		var dist := _player.global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _update_acquisition(candidate: Node2D, delta: float) -> void:
	if _current_target != null:
		if not is_instance_valid(_current_target) or _current_target.is_dead():
			_clear_indicator()
			_current_target = null
			target_lost.emit()
		elif candidate == _current_target:
			_lock_timer = lock_persistence
		else:
			_lock_timer -= delta
			if _lock_timer <= 0:
				_clear_indicator()
				_current_target = null
				target_lost.emit()
		return
	
	if candidate == null:
		_potential_target = null
		_acquisition_timer = 0.0
		return
	
	if candidate == _potential_target:
		_acquisition_timer += delta
		if _acquisition_timer >= acquisition_time:
			_current_target = candidate
			_lock_timer = lock_persistence
			_spawn_indicator(_current_target)
			target_acquired.emit(_current_target)
	else:
		_potential_target = candidate
		_acquisition_timer = 0.0
