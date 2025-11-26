extends EnemyCharacter

@export var boomb_scene: PackedScene
@export var rocket_scene: PackedScene
@export var whirlpool_scene: PackedScene  ## Used by summon_whirlpool state

@export_group("Phase 2 - Water Mechanics")
@export var water_raise_target_y: float = -80.0  ## Global Y position for raised water (negative = higher)
@export var water_raise_duration: float = 6.0    ## Duration for water to raise/lower (seconds)
@export var water_action_cooldown: float = 8.0   ## Cooldown between water raises/lowers (seconds)

@onready var muzzle = $Direction/BoomAndRocket/MuzzleBoom1
@onready var muzzle2 = $Direction/BoomAndRocket/MuzzleBoom2
@onready var muzzlerocket1 =  $Direction/BoomAndRocket/MuzzleRocket1
@onready var muzzlerocket2 =  $Direction/BoomAndRocket/MuzzleRocket2
@onready var warning_marker = $Direction/BoomAndRocket/WarningRocket
@onready var warning_marker2 = $Direction/BoomAndRocket/WarningRocket2
@onready var warning_marker3 = $Direction/BoomAndRocket/WarningRocket3
@onready var warning_marker4 = $Direction/BoomAndRocket/WarningRocket4
@onready var HurtArea = $Direction/HurtArea2D/CollisionShape2D
@onready var hurt_timer = $Direction/HurtArea2D/Timer

#Sound-related
@onready var missles_launch_sound = $MisslesLaunchSound
@onready var bombs_launch_sound = $BombsLaunchSound
@onready var laugh_sound = $LaughSound
var laugh_timer := 0.0
var laugh_interval := 15.0

## Phase 2 system
var current_phase: int = 1
var water_raised: bool = false
var last_water_action_time: float = 0.0
var cached_water_node: water = null


func _ready():
	super._ready()
	invincible_timer = max_invincible
	fsm = FSM.new(self, $States, $States/Idle)

func fire_boomb():
	var boomb1 = boomb_scene.instantiate()
	boomb1.global_position = muzzle.global_position
	boomb1.set_speed(350.0)
	boomb1.direction =  -1
	get_tree().current_scene.add_child(boomb1)
	bombs_launch_sound.play()
	await get_tree().create_timer(0.2).timeout
	var boomb2 = boomb_scene.instantiate()
	boomb2.global_position = muzzle2.global_position
	boomb2.set_speed(250.0)
	boomb2.direction =  1
	get_tree().current_scene.add_child(boomb2)
	bombs_launch_sound.play()

func fire_rocket():
	var rocket1 = rocket_scene.instantiate()
	rocket1.global_position = muzzlerocket1.global_position
	rocket1.scale = Vector2(1.5, 1.5)
	get_tree().current_scene.add_child(rocket1)
	warning_marker.show_animation()
	rocket1.shoot(rocket1.global_position, warning_marker.global_position, 1.5)
	await get_tree().create_timer(0.2).timeout
	var rocket2 = rocket_scene.instantiate()
	rocket2.global_position = muzzlerocket2.global_position
	get_tree().current_scene.add_child(rocket2)
	warning_marker2.show_animation()
	rocket2.shoot(rocket2.global_position, warning_marker2.global_position, 1.5)
	await get_tree().create_timer(0.5).timeout
	var rocket3 = rocket_scene.instantiate()
	rocket3.global_position = muzzlerocket1.global_position
	get_tree().current_scene.add_child(rocket3)
	warning_marker3.show_animation()
	rocket3.shoot(rocket3.global_position, warning_marker3.global_position, 1.5)
	await get_tree().create_timer(0.2).timeout
	var rocket4 = rocket_scene.instantiate()
	rocket4.global_position = muzzlerocket2.global_position
	get_tree().current_scene.add_child(rocket4)
	warning_marker4.show_animation()
	rocket4.shoot(rocket4.global_position, warning_marker4.global_position, 1.5)
	
func enable_hurt_for(seconds: float):
	HurtArea.disabled = false
	hurt_timer.start(seconds)


func _on_hurt_timer_timeout():
	HurtArea.disabled = true

func get_water_node() -> water:
	## Find and cache the water node in the scene
	if cached_water_node != null and is_instance_valid(cached_water_node):
		return cached_water_node
	
	var water_nodes = get_tree().get_nodes_in_group("water")
	if water_nodes.size() > 0:
		cached_water_node = water_nodes[0]
		return cached_water_node
	
	return null

func can_use_water_action() -> bool:
	## Check if enough time has passed since last water manipulation
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_since_last = current_time - last_water_action_time
	return time_since_last >= water_action_cooldown
	
func _process(delta):
	_update_laugh(delta)

func _update_laugh(delta: float) -> void:
	laugh_timer += delta
	if laugh_timer >= laugh_interval:
		laugh_sound.play()
		laugh_timer = 0.0
