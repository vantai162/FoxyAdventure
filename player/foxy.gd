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
@export var air_drag_multiplier: float = 0.5

@export_group("Wall Jump")
@export var wall_jump_force: float = 100.0
@export var wall_jump_air_control: float = 0.05
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

var air_control: float = 1.0
signal health_changed
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

@export var KeySkillUnlocked={ 
	"Dash":false,
	"HasCollectedBlade":false,
	"DoubleJump":false
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
	print("Player SetUp")
	fsm = FSM.new(self, $States, $States/Idle)
	$Direction/HitArea2D/CollisionShape2D.disabled = true
	GameManager.player=self
	call_deferred("_connect_water_signals")
	emit_signal("health_changed")
	
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
		fsm.change_state(fsm.states.swim)

func _on_exit_water(body):
	if body == self:
		is_in_water = false
		gravity = 700

func _process(delta: float) -> void:
	_updateeffect(delta)
	_update_timeline(delta)
	_updatecooldown(delta)

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
		"health": health,
		"Inventory":inventory._save_inventory()
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
	if data.has("Inventory"):
		inventory._load_inventory(data["Inventory"])
	# Đã loại bỏ logic: if data.has("has_blade") and data["has_blade"] == true:

func heal(amount:int): # Giữ: func heal
	print(health)
	if(amount+health>max_health):
		health=max_health
	else:
		health=amount+health
	print(health)

func checkfullhealth()->bool: # Giữ: func checkfullhealth
	return health==max_health

func _on_hurt_area_2d_hurt(direction: Vector2, damage: float) -> void:
	fsm.current_state.take_damage(damage)
	health_changed.emit()
