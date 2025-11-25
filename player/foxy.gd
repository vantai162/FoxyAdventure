class_name Player
extends BaseCharacter

@export var runspeed: int = 300
@export var Attack_Speed: int = 0
@export var invi_time: float = 2.0
@export var jump_buffer: float
@export var coyote_time: float
var inventory= Inventory.new()


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
@export var air_slash_spawn_delay: float = 0.05
@export var air_slash_speed: float = 300.0
@export var air_slash_deceleration: float = 500.0
@export var air_slash_fade_in_time: float = 0.1
@export var air_slash_active_time: float = 0.3
@export var air_slash_fade_out_time: float = 0.3
@export var air_slash_total_time: float = 0.8

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

var current_water: Node2D = null  ## Reference to current water body player is in
signal health_changed
signal coin_changed
@export_group("Blade")
@export var blade_projectile_scene: PackedScene
@export var air_slash_scene: PackedScene

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
	"Dash": 2
}

var attack_cooldown: int = 1
var jump_count: int = 0
var dashed_on_air: bool = false
var timeline: float = 0.0
var last_jumppress_onair: float = -1211.0
var last_ground_time: float = -1211.0

var blade_count: int = 0
var max_blade_capacity: int = 1
var has_unlocked_blade: bool = false

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

func can_attack() -> bool:
	return blade_count > 0 and Effect["Stun"] <= 0

func can_throw_blade() -> bool:
	return blade_count > 0 and Effect["Stun"] <= 0

func consume_blade() -> void:
	if blade_count > 0:
		blade_count -= 1

func return_blade() -> void:
	if blade_count < max_blade_capacity:
		blade_count += 1
		
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
	
	var throw_offset = Vector2(40 * direction, -10)
	blade.global_position = global_position + throw_offset
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
	call_deferred("_connect_water_signals")
	emit_signal("health_changed")
	
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
	if invincible:
		var blink_timer
		var sprite
		if has_unlocked_blade:
			sprite = $Direction/BladeAnimatedSprite2D
			
		elif not has_unlocked_blade:
			sprite = $Direction/AnimatedSprite2D
		blink_timer = Timer.new()
		blink_timer.wait_time = 0.1
		blink_timer.one_shot = false
		add_child(blink_timer)
		blink_timer.timeout.connect(func():
			sprite.visible = not sprite.visible
		)
		blink_timer.start()
		await get_tree().create_timer(invincible_timer).timeout
		blink_timer.stop()
		blink_timer.queue_free()

func _collect_blade() -> void:
	if not has_unlocked_blade:
		has_unlocked_blade = true
		set_animated_sprite($Direction/BladeAnimatedSprite2D)
	return_blade()

func _applyeffect(name: String, time: float) -> void:
	Effect[name] = time

func _updateeffect(delta: float) -> void:
	for key in Effect:
		Effect[key] -= delta
		if Effect[key] <= 0:
			Effect[key] = 0

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
		fsm.change_state(fsm.states.hurt)

func _updatecooldown(delta: float) -> void:
	for key in CoolDown:
		CoolDown[key] -= delta
		if CoolDown[key] <= 0:
			CoolDown[key] = 0

func set_cool_down(skillname: String) -> void:
	CoolDown[skillname] = InitCoolDown[skillname]
	
func save_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"blade_count": blade_count,
		"max_blade_capacity": max_blade_capacity,
		"has_unlocked_blade": has_unlocked_blade,
		"health": health
	}

func load_state(data: Dictionary) -> void:
	if data.has("position"):
		var pos_array = data["position"]
		global_position = Vector2(pos_array[0], pos_array[1])
	
	if data.has("blade_count"):
		blade_count = data["blade_count"]
	if data.has("max_blade_capacity"):
		max_blade_capacity = data["max_blade_capacity"]
	if data.has("has_unlocked_blade"):
		has_unlocked_blade = data["has_unlocked_blade"]
		if has_unlocked_blade:
			set_animated_sprite($Direction/BladeAnimatedSprite2D)
	
	if data.has("health"):
		health = data["health"]
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
	if not invincible:
		fsm.current_state.take_damage(damage)
		health_changed.emit()
	
