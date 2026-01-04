@tool  ## Enable script to run in editor for direction preview
class_name BaseCharacter
extends CharacterBody2D

## Base character class that provides common functionality for all characters
##
## DESIGNER NOTE: The 'direction' property now previews in the editor!
## - Set direction = 1 for facing right (sprite flips immediately)
## - Set direction = -1 for facing left (sprite flips immediately)
## No need to run the game to see which way an enemy faces!

## SFX
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

@export var movement_speed: float = 200.0
@export var gravity: float = 700.0

## Direction the character faces: 1 = right, -1 = left
## Changes apply immediately in editor for easy placement!
@export var direction: int = 1:
	set(value):
		direction = value
		_update_direction_visual()
var wind_velocity: Vector2 = Vector2.ZERO
var current_speed
@export var attack_damage: int = 1
@export var max_health: int = 3
@export var max_invincible: float = 2.0

var invincible: bool = false
var invincible_timer: float = 0

var health: int
@onready var floor_ray_cast: RayCast2D = $FloorRayCast2D

## Ice Physics - Designer configurable values
@export_group("Ice Physics")
@export var accelecrationValue: float = 0.08  ## Acceleration rate on ice (higher = more responsive)
@export var slideValue: float = 0.03  ## Deceleration rate when sliding on ice (lower = more slippery)
@export var fullStopValue: float = 15.0  ## Velocity threshold for full stop on ice

var is_in_water: bool = false
@export var max_oxygen := 5.0          # số giây có thể ở dưới nước
@export var oxygen_decrease_rate := 1.0  # mỗi giây giảm bao nhiêu oxy
@export var oxygen_increase_rate := 3.0  # mỗi giây tăng bao nhiêu oxy khi ở trên mặt nước/đất
@export var damage_per_second := 1      # mất HP mỗi giây khi đã hết oxy
var current_oxygen := max_oxygen

var swim_speed: float = 180.0
var jump_speed: float = 320.0
var fsm: FSM = null
var current_animation = null
var animated_sprite: AnimatedSprite2D = null

var _next_animation = null
var _next_direction: int = 1
var _next_animated_sprite: AnimatedSprite2D = null

## Update Direction node visual flip based on direction value
## Works in editor (when designer changes export) AND runtime
func _update_direction_visual() -> void:
	# Check if Direction node exists (may not during initial scene setup)
	if has_node("Direction"):
		$Direction.scale.x = direction

func _ready() -> void:
	# Skip runtime initialization in editor
	if Engine.is_editor_hint():
		return
	
	health = max_health
	current_speed = movement_speed
	_next_direction = direction
	_update_direction_visual()  # Apply initial direction flip
	set_animated_sprite($Direction/AnimatedSprite2D)
	
func _physics_process(delta: float) -> void:
	# Skip game logic in editor
	if Engine.is_editor_hint():
		return
	
	# HITSTOP: If frozen, only do move_and_slide (stay on platforms) — skip all logic
	if HitstopManager.is_frozen(self):
		move_and_slide()
		return
		
	# Animation
	_check_changed_animation()
	if invincible_timer>0:
		invincible_timer-=delta
		invincible=true
		if invincible_timer<=0:
			invincible=false
	if fsm != null:
		fsm._update(delta)
	# Movement
	_update_movement(delta)
	# Direction
	_check_changed_direction()


func _update_movement(delta: float) -> void:
	velocity.y += gravity * delta
	move_and_slide()
	pass

func turn_around() -> void:
	if _next_direction != direction:
		return
	_next_direction = -direction

func is_left() -> bool:
	return direction == -1

func is_right() -> bool:
	return direction == 1

func turn_left() -> void:
	_next_direction = -1

func turn_right() -> void:
	_next_direction = 1

func jump(jump_speed:float) -> void:
	velocity.y = -jump_speed

func stop_move() -> void:
	velocity.x = 0
	velocity.y = 0

func take_damage(damage: int) -> void:
	health -= damage
	AudioManager.play_sound("hurt",20.0)

## Check if character is dead (used by player targeting system)
func is_dead() -> bool:
	return health <= 0

# Change the animation of the character on the next frame
func change_animation(new_animation: String) -> void:
	_next_animation = new_animation

# Change the direction of the character on the last frame
func change_direction(new_direction: int) -> void:
	_next_direction = new_direction

# Get the name of the current animation
func get_animation_name() -> String:
	return current_animation.name

func set_animated_sprite(new_animated_sprite: AnimatedSprite2D) -> void:
	_next_animated_sprite = new_animated_sprite
# Check if the animation or animated sprite has changed and play the new animation
func _check_changed_animation() -> void:
	var need_play: bool = false
	if _next_animation != current_animation:
		current_animation = _next_animation
		need_play = true
	if _next_animated_sprite != animated_sprite:
		if animated_sprite != null:
			animated_sprite.hide()
		animated_sprite = _next_animated_sprite
		animated_sprite.show()
		need_play = true
	if need_play:
		if animated_sprite != null and current_animation != null:
			animated_sprite.play(current_animation)

# Check if the direction has changed and set the new direction
func _check_changed_direction() -> void:
	if _next_direction != direction:
		direction = _next_direction
		_on_changed_direction()
		if direction == -1:
			$Direction.scale.x = -1
		if direction == 1:
			$Direction.scale.x = 1

# On changed direction
func _on_changed_direction() -> void:
	pass

## Surface type detection using TileSet custom data layer

func _is_on_ice() -> bool:
	## Check if standing on an ice surface using TileMap custom data
	var tile_data = _get_floor_tile_data()
	if tile_data:
		if tile_data.has_custom_data("surface_type"):
			var surface_type = tile_data.get_custom_data("surface_type")
			if surface_type == "ice":
				return true
	
	# Fallback: Check if floor collider is in "ice" group (for non-TileMap ice)
	var collider = floor_ray_cast.get_collider()
	if collider and collider.is_in_group("ice"):
		return true
	
	return false

func _is_wall_ice() -> bool:
	## Check if the wall being touched is ice (prevents wall cling)
	## Uses wall collision normal to determine which side to check
	if not is_on_wall():
		return false
	
	# Get wall collision info
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		
		# This is a wall collision (horizontal normal)
		if abs(normal.x) > 0.5:
			# Check TileMapLayer custom data
			if collider is TileMapLayer:
				var tilemap = collider as TileMapLayer
				var collision_point = collision.get_position()
				# Offset slightly into the wall to get the correct tile
				var check_point = collision_point - normal * 4.0
				var local_pos = tilemap.to_local(check_point)
				var tile_coords = tilemap.local_to_map(local_pos)
				var tile_data = tilemap.get_cell_tile_data(tile_coords)
				if tile_data:
					var surface_type = tile_data.get_custom_data("surface_type")
					if surface_type == "ice":
						return true
			
			# Fallback: check if collider is in "ice" group
			if collider and collider.is_in_group("ice"):
				return true
	
	return false

func _get_floor_tile_data() -> TileData:
	## Get the TileData of the tile under the player's feet
	## Returns null if not standing on a TileMapLayer
	if not is_on_floor():
		return null
	
	# Use floor collision to find the TileMapLayer
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		var normal = collision.get_normal()
		
		# This is a floor collision (upward normal)
		if normal.y < -0.5:
			if collider is TileMapLayer:
				var tilemap = collider as TileMapLayer
				var collision_point = collision.get_position()
				# Offset slightly into the tile to ensure we get the right one
				var check_point = collision_point + Vector2(0, 4)
				var local_pos = tilemap.to_local(check_point)
				var tile_coords = tilemap.local_to_map(local_pos)
				var tile_data = tilemap.get_cell_tile_data(tile_coords)
				return tile_data
	
	return null
	
func _is_on_one_way_platform():
	var collider = floor_ray_cast.get_collider()
	if not collider: return false
	
	# Check by group first (preferred), fallback to name
	if collider.is_in_group("one_way_platform"):
		return true
	return collider.name == "OneWayPlatform"

## ============================================================================
## WALL CLING INPUT CHECK (Used by state transitions)
## ============================================================================
## Checks if the player is actively pressing TOWARD the wall they're touching.
## This is the gatekeeper for "active" wall cling - no input toward wall = no cling.

func is_pressing_toward_wall() -> bool:
	## Returns true if player is pressing input toward the wall they're touching
	## Used by state transitions to require active input for wall cling entry
	
	if not is_on_wall():
		return false
	
	# Detect wall direction from collision
	var wall_dir: int = 0
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		
		# Horizontal collision = wall
		if abs(normal.x) > 0.5:
			# Wall normal points AWAY from wall
			# normal.x > 0 → wall is to the LEFT → wall_dir = -1
			# normal.x < 0 → wall is to the RIGHT → wall_dir = 1
			wall_dir = -int(sign(normal.x))
			break
	
	if wall_dir == 0:
		return false
	
	# Check input direction
	var input_dir = Input.get_action_strength("right") - Input.get_action_strength("left")
	
	# Need meaningful input
	if abs(input_dir) < 0.1:
		return false
	
	# Input direction must match wall direction
	return sign(input_dir) == wall_dir
	

func spring():
	## Legacy spring - always launches UP (for backward compatibility)
	velocity.y = -650

func spring_launch(launch_velocity: Vector2) -> void:
	## Directional spring launch - applies velocity in the given direction
	velocity = launch_velocity
	
	# Trigger impulse momentum preservation for horizontal launches (player only)
	if has_method("apply_impulse_momentum"):
		var horizontal_dir = sign(launch_velocity.x) as int
		call("apply_impulse_momentum", horizontal_dir)
		
func drop_down_platform():
	var PLATFORM_LAYER = 1
	set_collision_mask_value(PLATFORM_LAYER, false)
	var tree = get_tree()
	if tree == null:
		return
	await tree.create_timer(0.25).timeout
	# Guard: character may have been freed during await
	if not is_instance_valid(self):
		return
	set_collision_mask_value(PLATFORM_LAYER, true)
	
# Hàm chung để phát âm thanh
func play_sfx(stream: AudioStream, random_pitch: bool = true) -> void:
	if sfx_player == null or stream == null:
		return
	
	# Nếu đang phát đúng bài đó rồi (dành cho loop) thì không reset
	# (Tùy chọn: dòng này giúp tiếng bước chân không bị lặp lại liên tục gây rát tai)
	if sfx_player.playing and sfx_player.stream == stream:
		return

	sfx_player.stream = stream
	
	if random_pitch:
		sfx_player.pitch_scale = randf_range(0.9, 1.1)
	else:
		sfx_player.pitch_scale = 1.0
		
	sfx_player.play()

func stop_sfx() -> void:
	if sfx_player:
		sfx_player.stop()
		
func die() -> void:
	# 1. Chặn chết nhiều lần (Nếu đã chết rồi thì không chết nữa)
	# Kiểm tra xem state hiện tại có phải là dead không (nếu fsm đã setup)
	if fsm.current_state == fsm.states.get("dead"):
		return
		
	# 2. Cập nhật chỉ số
	health = 0
	emit_signal("health_changed") # Để thanh máu tụt về 0
	# 3. Kích hoạt State Chết (Logic chính nằm ở đây)
	# Kiểm tra xem trong danh sách states có "dead" không
	if fsm.states.has("dead"):
		fsm.change_state(fsm.states.dead)
	else:
		# Fallback: Nếu nhân vật này không có DeadState (ví dụ quái vật thường)
		# Thì xóa sổ nó luôn
		queue_free()
	
