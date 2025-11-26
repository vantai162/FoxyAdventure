class_name BaseCharacter
extends CharacterBody2D

## Base character class that provides common functionality for all characters

## SFX
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

@export var movement_speed: float = 200.0
@export var gravity: float = 700.0
@export var direction: int = 1
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
@export var oxygen_increase_rate := 1.5  # mỗi giây tăng bao nhiêu oxy khi ở trên mặt nước/đất
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

func _ready() -> void:
	health = max_health
	current_speed = movement_speed
	_next_direction = direction
	$Direction.scale.x = direction
	set_animated_sprite($Direction/AnimatedSprite2D)
	
func _physics_process(delta: float) -> void:
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
	
func _is_on_ice():
	var collider = floor_ray_cast.get_collider()
	if not collider: return false
	
	# Check if the collider has a PhysicsMaterial2D with low friction (ice-like)
	if collider is StaticBody2D or collider is CharacterBody2D or collider is RigidBody2D:
		var physics_material = collider.physics_material_override
		if physics_material and physics_material.friction < 0.3:  # Ice threshold
			return true
	
	# Fallback to name check for backward compatibility
	return collider.name == "IceBlock"
	
func _is_on_one_way_platform():
	var collider = floor_ray_cast.get_collider()
	if not collider: return false
	
	return collider.name == "OneWayPlatform"
	

func spring():
	velocity.y = -400
	
		
func drop_down_platform():
	var PLATFORM_LAYER = 1
	set_collision_mask_value(PLATFORM_LAYER, false)
	await get_tree().create_timer(0.25).timeout
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
	
