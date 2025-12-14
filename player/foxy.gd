class_name Player
extends BaseCharacter

@export var runspeed: int = 300
@export var Attack_Speed: int = 0
@export var invi_time: float = 2.0
@export var jump_buffer: float
@export var coyote_time: float
var inventory= Inventory.new()
var skin

@export_group("Movement Physics")
@export var ground_friction: float = 0.25
@export var min_stop_speed: float = 10.0
@export var slow_effect_multiplier: float = 0.5  ## Speed multiplier when slow effect is active
@export var wind_influence_factor: float = 0.1  ## How quickly player adjusts to wind when not moving

@export_group("Wall Jump")
@export var wall_jump_force: float = 100.0
@export var wall_jump_control_delay: float = 0.15
@export var wall_jump_control_fade_duration: float = 0.4
@export var wall_slide_friction: float = 0.3

@export_group("Abilities")
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.3
@export var hurt_knockback_vertical: float = 250.0
@export var hurt_stun_duration: float = 0.5
@export var dead_delay_before_respawn: float = 0.5
@export var throw_duration: float = 0.2
@export var double_jump_power_multiplier: float = 0.8
@export var run_idle_wait_time: float = 0.1

@export_group("Attack")
@export var attack_duration: float = 0.2
@export var attack_cooldown_time: float = 0.35  ## Cooldown between attacks (prevents spam)
@export var attack_air_gravity_scale: float = 0.3  ## Gravity multiplier during air attack (creates "hang time")
@export var air_slash_spawn_delay: float = 0.05
@export var air_slash_speed: float = 300.0
@export var air_slash_deceleration: float = 500.0
@export var air_slash_fade_in_time: float = 0.1
@export var air_slash_active_time: float = 0.3
@export var air_slash_fade_out_time: float = 0.3
@export var air_slash_total_time: float = 0.8

var attack_cooldown_remaining: float = 0.0  ## Tracks current cooldown countdown

@export_group("Swimming")
@export var swim_gravity: float = 300.0
@export var swim_deceleration: float = 0.1
@export var swim_acceleration: float = 0.15
@export var head_offset_y: float = 8.0  ## Distance from player origin to head, negative in Y-axis (head is above origin)

@export_group("Air Control")
@export var air_acceleration: float = 0.3  ## Air steering responsiveness when actively moving (0.0-1.0, lower = more momentum/inertia visible)
@export var air_deceleration: float = 0.08  ## Air drag when no input (0.0-1.0, lower = longer coast/momentum preservation)
@export var wall_jump_air_acceleration: float = 0.08  ## Restricted air control during wall jump (creates commitment)

## Runtime state for wall jump air restriction (managed by jump state)
var wall_jump_restriction_timer: float = -1.0  ## -1 = not active, >=0 = active countdown

@export_group("Impulse Momentum")
@export var impulse_momentum_duration: float = 0.4  ## Time (seconds) horizontal impulse momentum is preserved without air braking
@export var impulse_momentum_fade_duration: float = 0.3  ## Time to fade from full momentum preservation to normal air control

## Runtime state for impulse momentum preservation (springs, shockwaves, explosions, etc.)
var impulse_momentum_timer: float = -1.0  ## -1 = not active, >=0 = time since impulse applied
var impulse_momentum_direction: int = 0  ## -1 = launched left, 1 = launched right, 0 = no horizontal impulse

var current_water: Node2D = null  ## Reference to current water body player is in
signal health_changed
signal coin_changed
signal blade_changed
signal oxy_changed
signal died
signal max_health_changed

@export_group("Blade")
@export var blade_projectile_scene: PackedScene
@export var air_slash_scene: PackedScene
@export var has_unlocked_flame_blade: bool = false
var blade_count: int = 0
var max_blade_capacity: int = 1
var has_unlocked_blade: bool = false

@export_group("Throw")
@export var throw_offset_x: float = 40.0  ## Horizontal offset from player center
@export var throw_offset_y: float = -14.0  ## Vertical offset (negative = above feet)

@export_group("Targeting")
@export var targeting_enabled: bool = true  ## Enable smart aim-assist for throws

## Targeting system (Area2D in scene under Direction)
@onready var targeting: PlayerTargeting = $Direction/TargetingArea if has_node("Direction/TargetingArea") else null

@onready var stun_ani: = $Direction/Stun_Effect

@export var Effect = {
	"Stun": 0,
	"DamAmplify": 0,
	"Slow": 0,
	"Invicibility": 0
}

enum attack_direction {
	Left, Right, Down, Up
}

@export var CoolDown = {
	"Dash": 0
}

@export var InitCoolDown = {
	"Dash": 1
}

var attack_cooldown: int = 1
var jump_count: int = 0
var dashed_on_air: bool = false
var timeline: float = 0.0
var last_jumppress_onair: float = -1211.0
var last_ground_time: float = -1211.0



## Get current air acceleration value based on wall jump restriction state
func get_current_air_acceleration() -> float:
	if wall_jump_restriction_timer < 0:
		return air_acceleration
	# Wall jump restriction active - check phase
	if wall_jump_restriction_timer < wall_jump_control_delay:
		return wall_jump_air_acceleration  # Locked phase: minimal control
	
	# Fade phase: smooth transition back to full control
	var fade_time = wall_jump_restriction_timer - wall_jump_control_delay
	if fade_time < wall_jump_control_fade_duration:
		var blend = fade_time / wall_jump_control_fade_duration
		return lerp(wall_jump_air_acceleration, air_acceleration, blend)
	
	# Fully restored
	return air_acceleration

## Get the air deceleration multiplier for impulse momentum preservation
## Returns 0.0 = full momentum preservation (no braking)
## Returns 1.0 = normal air deceleration
## Values between = fading from preserved to normal
func get_impulse_momentum_multiplier(input_direction: int) -> float:
	# Not in impulse momentum state
	if impulse_momentum_timer < 0:
		return 1.0
	
	# Player is actively steering AGAINST the impulse direction - allow normal control
	# This lets player "fight" the impulse if they want to
	if input_direction != 0 and input_direction != impulse_momentum_direction:
		return 1.0
	
	# Momentum preservation phase: no air braking at all
	if impulse_momentum_timer < impulse_momentum_duration:
		return 0.0
	
	# Fade phase: gradually restore normal air deceleration
	var fade_time = impulse_momentum_timer - impulse_momentum_duration
	if fade_time < impulse_momentum_fade_duration:
		return fade_time / impulse_momentum_fade_duration
	
	# Fully expired - reset timer and return normal deceleration
	impulse_momentum_timer = -1.0
	impulse_momentum_direction = 0
	return 1.0

## Apply impulse momentum preservation (called by springs, shockwaves, explosions, etc.)
## This prevents air deceleration from immediately braking externally-applied velocity
func apply_impulse_momentum(horizontal_direction: int) -> void:
	if horizontal_direction != 0:
		impulse_momentum_timer = 0.0
		impulse_momentum_direction = horizontal_direction

func can_attack() -> bool:
	return blade_count > 0 and Effect["Stun"] <= 0 and attack_cooldown_remaining <= 0

func start_attack_cooldown() -> void:
	attack_cooldown_remaining = attack_cooldown_time

func can_throw_blade() -> bool:
	return blade_count > 0 and Effect["Stun"] <= 0

#Hàm này được gọi ngay khi ném (trong throw_blade_projectile)
func consume_blade() -> void:
	if blade_count > 0:
		# 1. Trừ biến nội bộ (để chặn không cho ném tiếp)
		blade_count -= 1
		blade_changed.emit(blade_count)
		# 2. [THÊM DÒNG NÀY] Trừ trong Inventory để UI biết mà nhảy số
		#inventory.use_blade(1)
		# Hoặc: inventory.adjust_amount_item("Blade", -1)

func return_blade() -> void:
	if blade_count < max_blade_capacity:
		blade_count += 1
		#inventory.adjust_amount_item("Blade", 1) 
		blade_changed.emit(blade_count)
		# Switch back to blade sprite when getting a blade back
		if has_unlocked_blade and blade_count > 0:
			set_animated_sprite($Direction/BladeAnimatedSprite2D)

func increase_blade_capacity() -> void:
	max_blade_capacity = min(max_blade_capacity + 1, 3)
	return_blade()

func throw_blade_projectile() -> void:
	if not can_throw_blade() or not blade_projectile_scene:
		return
	
	var blade = blade_projectile_scene.instantiate()
	get_tree().current_scene.add_child(blade)
	
	var throw_offset := Vector2(throw_offset_x * direction, throw_offset_y)
	blade.global_position = global_position + throw_offset
	
	# Check if we have a locked target for aimed throw
	if targeting != null and targeting.has_locked_target():
		# Aimed throw - clamped angle toward target (±25° prevents ground ricochet)
		var throw_angle := targeting.get_throw_angle(direction)
		blade.launch_aimed(throw_angle, self)
	else:
		# Mindless throw - straight horizontal in facing direction
		blade.launch(direction, self)
	
	consume_blade()
	
	# Switch back to unarmed sprite when out of blades
	if blade_count == 0:
		set_animated_sprite($Direction/AnimatedSprite2D)

func spawn_air_slash() -> void:
	if not air_slash_scene:
		return
	
	var air_slash = air_slash_scene.instantiate()
	get_tree().current_scene.add_child(air_slash)
	
	# Configure air slash with player settings
	air_slash.initial_speed = air_slash_speed
	air_slash.deceleration = air_slash_deceleration
	air_slash.fade_in_time = air_slash_fade_in_time
	air_slash.active_time = air_slash_active_time
	air_slash.fade_out_time = air_slash_fade_out_time
	air_slash.total_time = air_slash_total_time
	
	# Spawn at HitArea2D position
	var hit_area = $Direction/HitArea2D
	air_slash.global_position = hit_area.global_position
	
	# Launch in facing direction
	air_slash.launch(direction)

func _ready() -> void:
	super._ready()
	fsm = FSM.new(self, $States, $States/Idle)
	$Direction/HitArea2D/CollisionShape2D.disabled = true
	stun_ani.visible=false
	call_deferred("_connect_water_signals")
	emit_signal("health_changed")
	
	# Setup targeting system (Area2D already in scene under Direction)
	if targeting_enabled and targeting != null:
		targeting.setup(self)
	
	# Sync sprite to blade inventory state after base initialization
	# This handles respawn scenarios where blade state persists but sprite resets
	if has_unlocked_blade and blade_count > 0:
		set_animated_sprite($Direction/BladeAnimatedSprite2D)
	# else: already using unarmed sprite from super._ready()
	
func _connect_water_signals():
	for water in get_tree().get_nodes_in_group("water"):
		if not water.player_entered_water.is_connected(_on_enter_water):
			water.player_entered_water.connect(_on_enter_water)
		if not water.player_exited_water.is_connected(_on_exit_water):
			water.player_exited_water.connect(_on_exit_water)

		
func _on_enter_water(body):
	if body == self:
		is_in_water = true
		gravity = 300
		# Only enter swim state if head is actually underwater (handles whirlpool air pockets)
		if is_head_underwater():
			fsm.change_state(fsm.states.swim)

func _on_exit_water(body):
	if body == self:
		is_in_water = false
		gravity = 700

func is_head_underwater(threshold: float = 0.0) -> bool:
	## Check if player's head is submerged in current water body
	## Uses centralized water height check (handles waves/whirlpools)
	if current_water == null:
		return false
	
	# Head Y position (subtracting offset because Y increases downward in Godot)
	var head_y = global_position.y - head_offset_y
	var water_surface_y = current_water.get_water_surface_global_y()
	
	# Use exact water height if available (handles whirlpools/waves)
	if current_water.has_method("get_water_height_at_global_x"):
		water_surface_y = current_water.get_water_height_at_global_x(global_position.x)
	
	# If head_y > water_surface_y, head is deeper (further down = more positive Y)
	return head_y > (water_surface_y + threshold)

func _process(delta: float) -> void:
	_updateeffect(delta)
	_update_timeline(delta)
	_updatecooldown(delta)
	_update_impulse_momentum(delta)
	oxy_changed.emit()

func _update_impulse_momentum(delta: float) -> void:
	# Update impulse momentum timer if active
	if impulse_momentum_timer >= 0:
		impulse_momentum_timer += delta
		# Cancel impulse momentum when landing on floor (momentum transfer complete)
		if is_on_floor():
			impulse_momentum_timer = -1.0
			impulse_momentum_direction = 0
	
		

# is_upgrade_item = true: Dành cho vật phẩm đặt trên map (Tăng giới hạn/Mở khóa)
# is_upgrade_item = false (mặc định): Dành cho dao ném ra nhặt lại (Chỉ hồi đạn)
func _collect_blade(is_upgrade_item: bool = false) -> void:
	
	# --- TRƯỜNG HỢP 1: CHƯA MỞ KHÓA KỸ NĂNG ---
	if not has_unlocked_blade:
		print("Player: Mở khóa Blade lần đầu!")
		has_unlocked_blade = true
		blade_count = 1
		
		# Set sprite
		set_animated_sprite($Direction/BladeAnimatedSprite2D)
		
		# Đồng bộ Inventory & UI
		#inventory.adjust_amount_item("Blade", 1)
		blade_changed.emit(blade_count)
		return

	# --- TRƯỜNG HỢP 2: ĐÃ CÓ KỸ NĂNG ---
	
	# Nếu là Item trên map -> Tăng giới hạn túi đồ (Max Capacity)
	if is_upgrade_item:
		max_blade_capacity = min(max_blade_capacity + 1, 3) # Ví dụ max là 3
		print("Player: Đã nâng cấp túi đạn lên ", max_blade_capacity)
		# Tăng giới hạn xong thì hồi đầy đạn luôn (hoặc +1 tùy bạn)
		blade_count = max_blade_capacity
		# Lưu ý: Cần xử lý logic cộng inventory tương ứng để khớp số
		# (Đoạn này hơi phức tạp nếu inventory không có biến max, 
		# nhưng tạm thời ta cứ cho là cộng thêm blade cho đầy túi)
		var needed = max_blade_capacity - blade_count
		if needed > 0:
			blade_count += needed
			
	# Nếu là Dao ném ra -> Chỉ hồi đạn (+1)
	else:
		if blade_count < max_blade_capacity:
			blade_count += 1
			#inventory.adjust_amount_item("Blade", 1)
		else:
			return # Đầy rồi thì thôi không nhặt, không cộng

	# --- CẬP NHẬT CUỐI CÙNG ---
	# Đảm bảo hiển thị đúng sprite nếu có đạn
	if blade_count > 0:
		set_animated_sprite($Direction/BladeAnimatedSprite2D)
		
	# Báo cho UI biết
	blade_changed.emit(blade_count)

func _applyeffect(name: String, time: float) -> void:
	Effect[name] = time
	if Effect["Invicibility"] > 0:
		var blink_timer 
		# Use the current active sprite (supports both normal and blade sprite)
		var sprite = animated_sprite
		if not sprite:
			sprite = $Direction/AnimatedSprite2D  # Fallback
		blink_timer = Timer.new()
		blink_timer.wait_time = 0.1
		blink_timer.one_shot = false
		add_child(blink_timer)
		blink_timer.timeout.connect(func():
			sprite.visible = not sprite.visible
		)
		blink_timer.start()
		
		# Guard: tree may become null if player dies during blink
		var tree = get_tree()
		if tree == null:
			blink_timer.stop()
			blink_timer.queue_free()
			return
		
		await tree.create_timer(time).timeout
		
		# Guard: player may have been freed during await
		if not is_instance_valid(self) or not is_instance_valid(blink_timer):
			return
		
		blink_timer.stop()
		blink_timer.queue_free()
		sprite.visible = true

func _updateeffect(delta: float) -> void:
	for key in Effect:
		Effect[key] -= delta
		if Effect[key] <= 0:
			Effect[key] = 0
	if Effect["Stun"] > 0 and fsm.current_state != fsm.states.stun:
		fsm.change_state(fsm.states.stun)

func _update_timeline(delta: float) -> void:
	timeline += delta
	if is_on_floor():
		last_ground_time = timeline
	elif fsm.current_state == fsm.states.fall and Input.is_action_pressed("jump"):
		last_jumppress_onair = timeline

func _checkcoyotea() -> bool:
	return timeline - last_ground_time < coyote_time

func _checkbuffer() -> bool:
	return timeline - last_jumppress_onair < jump_buffer

func take_damage(damage: int) -> void:
	if Effect["Invicibility"] <= 0:
		if has_node("Camera2D"):
			$Camera2D.shake(8.0)
		super.take_damage(damage)
		_applyeffect("Invicibility",0.7)
		fsm.change_state(fsm.states.hurt)

func _updatecooldown(delta: float) -> void:
	for key in CoolDown:
		CoolDown[key] -= delta
		if CoolDown[key] <= 0:
			CoolDown[key] = 0
	
	# Attack cooldown (separate from skill cooldowns)
	if attack_cooldown_remaining > 0:
		attack_cooldown_remaining -= delta

func set_cool_down(skillname: String) -> void:
	CoolDown[skillname] = InitCoolDown[skillname]
	
func save_state() -> Dictionary:
	print("DEBUG save_state health:", health)
	return {
		"position": [global_position.x, global_position.y],
		"blade_count": blade_count,
		"max_blade_capacity": max_blade_capacity,
		"has_unlocked_blade": has_unlocked_blade,
		"health": health,
		"Inventory":inventory._save_inventory(),
		"max_health": max_health,
		"has_unlocked_flame_blade": has_unlocked_flame_blade
	}

func load_state(data: Dictionary) -> void:
	if data.has("position"):
		var pos_array = data["position"]
		global_position = Vector2(pos_array[0], pos_array[1])
	
	if data.has("blade_count"):
		#blade_count = inventory.get_amount("Blade")
		blade_count = data["blade_count"]
	if data.has("max_blade_capacity"):
		max_blade_capacity = data["max_blade_capacity"]
	if data.has("has_unlocked_blade"):
		has_unlocked_blade = data["has_unlocked_blade"]
		if has_unlocked_blade:
			set_animated_sprite($Direction/BladeAnimatedSprite2D)
	if data.has("health"):
		print("DEBUG load_state health:", data["health"])
		health = data["health"]
	else:
		print("DEBUG load_state health missing, current:", health)
	if data.has("Inventory"):
		inventory._load_inventory(data["Inventory"])
	if data.has("max_health"):
		max_health = data["max_health"]
	if data.has("has_unlocked_flame_blade"):
		has_unlocked_flame_blade = data["has_unlocked_flame_blade"]
	# Đã loại bỏ logic: if data.has("has_blade") and data["has_blade"] == true:
	

func heal(amount:int): # Giữ: func heal
	if(amount+health>max_health):
		health=max_health
	else:
		health=amount+health
	health_changed.emit()

func checkfullhealth()->bool: # Giữ: func checkfullhealth
	return health==max_health

func _on_hurt_area_2d_hurt(direction: Vector2, damage: float) -> void:
	fsm.current_state.take_damage(damage)
	health_changed.emit()
	
func heal_max_health():
	heal(max_health)
	
func set_max_health(new_max:int) -> void:
	max_health = new_max
	# giữ current health <= max
	health = min(health, max_health)

func get_max_health() -> int:
	return max_health

func get_health() -> int:
	return health
	
