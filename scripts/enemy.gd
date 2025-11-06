class_name EnemyCharacter
extends BaseCharacter



# Raycast check wall and fall
var front_ray_cast: RayCast2D;
var down_ray_cast: RayCast2D;

# detect player area
var detect_player_area: Area2D;
var found_player: Player = null
var detect_ray_cast:RayCast2D;
var detection_distance: float = 100.0

func _ready() -> void:
	_init_ray_cast()
	_init_detect_player_area()
	_init_hurt_area()
	super._ready()
	pass


#init ray cast to check wall and fall
func _init_ray_cast():
	if has_node("Direction/FrontRayCast2D"):
		front_ray_cast = $Direction/FrontRayCast2D
	if has_node("Direction/DownRayCast2D"):
		down_ray_cast = $Direction/DownRayCast2D
	if has_node("Direction/DetectPlayerRayCast2D"):
		detect_ray_cast = $Direction/DetectPlayerRayCast2D


#init detect player area
func _init_detect_player_area():
	if has_node("Direction/DetectPlayerArea2D"):
		detect_player_area = $Direction/DetectPlayerArea2D
		print("detect_player_area 1")
		detect_player_area.body_entered.connect(_on_body_entered)
		print("detect_player_area 2")
		detect_player_area.body_exited.connect(_on_body_exited)
		


# init hurt area
func _init_hurt_area():
	if has_node("Direction/HurtArea2D"):
		var hurt_area = $Direction/HurtArea2D
		hurt_area.hurt.connect(_on_hurt_area_2d_hurt)

# check touch wall
func is_touch_wall() -> bool:
	if front_ray_cast != null:
		return front_ray_cast.is_colliding()
	return false

# check can fall
func is_can_fall() -> bool:
	if down_ray_cast != null:
		return not down_ray_cast.is_colliding()
	return false

#enable check player in sight
func enable_check_player_in_sight() -> void:
	
	if(detect_player_area != null):
		detect_player_area.get_node("CollisionShape2D").disabled = false

#disable check player in sight
func disable_check_player_in_sight() -> void:
	if(detect_player_area != null):
		detect_player_area.get_node("CollisionShape2D").disabled = true

func _on_body_entered(_body: CharacterBody2D) -> void:
	found_player = _body
	_on_player_in_sight(_body.global_position)

func _on_body_exited(_body: CharacterBody2D) -> void:
	found_player = null
	_on_player_not_in_sight()

func _on_hurt_area_2d_hurt(_direction: Vector2, _damage: float) -> void:
	_take_damage_from_dir(_direction, _damage)

# called when player is in sight
func _on_player_in_sight(_player_pos: Vector2):
	fsm.current_state.change_state(fsm.states.surprise)
	
func is_player_in_sight() -> bool:
	if detect_ray_cast != null:
		return detect_ray_cast.is_colliding()
	return false


# called when player is not in sight
func _on_player_not_in_sight():
	pass

func _take_damage_from_dir(_damage_dir: Vector2, _damage: float):
	fsm.current_state.take_damage(_damage_dir, _damage)
	
func check_player_in_sight(player: Player) -> bool:
	if detect_ray_cast == null:
		return false

	# Hướng ray theo hướng enemy đang nhìn
	var dir = Vector2.RIGHT * (1 if direction > 0 else -1)
	var from = global_position
	var to = from + dir * detection_distance

	# Sử dụng trực tiếp RayCast2D hoặc PhysicsRayQuery
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from, to)
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		return false

	var collider = result["collider"]
	if collider is Player:
		return true

	return false
