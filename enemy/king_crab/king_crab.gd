extends EnemyCharacter

## King Crab Boss - Uses base class detection, simple phase system
## All tunable values centralized here for easy designer tweaking
##
## POISE SYSTEM: Boss is immune to knockback and stun-lock.
## Takes damage, shows flash feedback, but attacks continue.
## This creates a skill-based fight requiring pattern recognition.

signal health_changed

## Visual feedback state
var _hurt_flash_tween: Tween = null  ## Prevents tween stacking on rapid hits

@export_group("Boss Poise")
@export var knockback_immune: bool = true  ## Boss cannot be pushed by player attacks
@export var stun_immune: bool = true  ## Boss cannot enter hurt state during attacks

@export_group("Phase System")
@export var phase_2_threshold: float = 0.5  ## Health ratio to trigger phase 2
@export var phase_2_speed_multiplier: float = 1.3  ## Speed boost in phase 2

@export_group("Projectile Scenes")
@export var shockwave_scene: PackedScene  ## Used by dive_attack and roll_bounce

@export_group("Idle")
@export var idle_duration: float = 1.5  ## Wait time before choosing attack

@export_group("Dive Attack")
@export var dive_windup_time: float = 0.5
@export var dive_apex_pause: float = 0.25
@export var dive_land_time: float = 0.3
@export var dive_rise_height: float = 450.0
@export var dive_rise_speed: float = 900.0
@export var dive_fall_speed: float = 800.0
@export var dive_launch_shake: float = 10.0
@export var dive_land_shake: float = 15.0

@export_group("Claw Attack")
@export var claw_windup_time: float = 0.4
@export var claw_throw_time: float = 0.2
@export var claw_catch_time: float = 0.2
@export var claw_recoil_time: float = 1.5  ## Long stun window - player's reward for surviving double wrap
@export var claw_recovery_time: float = 0.5  ## Slightly longer recovery
@export var claw_speed: float = 600.0
@export var claw_travel_distance: float = 800.0
@export var claw_return_threshold: float = 50.0
@export var claw_wrap_offset_ratio: float = 0.9
@export var claw_second_wrap_speed_mult: float = 1.4  ## Second wrap is faster
@export var claw_second_wrap_shake: float = 6.0  ## Screen shake on second wrap

@export_group("Roll Bounce")
@export var roll_windup_time: float = 0.4
@export var roll_winddown_time: float = 0.4
@export var roll_jump_speed_x: float = 300.0
@export var roll_jump_speed_y: float = -400.0
@export var roll_bounce_velocity_y: float = -500.0
@export var roll_max_bounces: int = 3

@export_group("Coconut Throw - Phase 1")
@export var coconut_p1_max_throws: int = 4
@export var coconut_p1_interval: float = 0.6
@export var coconut_p1_speed: float = 350.0

@export_group("Coconut Throw - Phase 2")
@export var coconut_p2_max_throws: int = 7
@export var coconut_p2_interval: float = 0.45
@export var coconut_p2_speed: float = 420.0

@export_group("Coconut Throw - Timing")
@export var coconut_interval_variance: float = 0.3
@export var coconut_prediction_factor: float = 0.4

@export_group("Tree Climbing")
@export var climb_duration: float = 1.8
@export var walk_stuck_timeout: float = 1.0

@export_group("Bubble Attack")
@export var bubble_attack_interval: float = 3.5
@export var bubble_speed: float = 300.0
@export var bubble_trap_duration: float = 2.0

@export_group("Summon MiniCrab")
@export var minicrab_scene: PackedScene
@export var minicrab_count: int = 3
@export var minicrab_spawn_interval: float = 1.0
@export var minicrab_spawn_radius: float = 120.0

var current_phase: int = 1
var last_attack: String = ""  ## Tracks last attack to avoid repetition (used by idle.gd)

# Factories (for spawning projectiles)
@onready var coconut_factory = $Direction/CoconutFactory if has_node("Direction/CoconutFactory") else null
@onready var claw_factory = $Direction/ClawFactory if has_node("Direction/ClawFactory") else null
@onready var warning_factory = $Direction/WarningFactory if has_node("Direction/WarningFactory") else null
@onready var water_bubble_factory = $Direction/WaterBubbleFactory if has_node("Direction/WaterBubbleFactory") else null

# Bubble attack spawn positions (Marker2D nodes)
@onready var upper_claw_pos = $Direction/WaterBubbleFactory/Marker2D_UpperClaw if has_node("Direction/WaterBubbleFactory/Marker2D_UpperClaw") else null
@onready var lower_claw_pos = $Direction/WaterBubbleFactory/Marker2D_LowerClaw if has_node("Direction/WaterBubbleFactory/Marker2D_LowerClaw") else null

func _ready() -> void:
	add_to_group("king_crab")
	# "boss" group is set in king_crab.tscn
	# "enemy" group is set by EnemyCharacter base class
	fsm = FSM.new(self, $States, $States/Sleep)  # Boss starts sleeping, wakes on player_entered
	super._ready()  # Calls _init_ray_cast, _init_detect_player_area, _init_hurt_area, add_to_group("enemy")

## Override take_damage to implement POISE system + proper visual feedback
## Boss takes damage but is NOT knocked back or interrupted
func take_damage(damage: int) -> void:
	super.take_damage(damage)  # Handles health -= damage AND plays hurt sound
	health_changed.emit()
	
	# Visual feedback: quick red flash (kill previous tween to prevent stacking)
	if animated_sprite:
		if _hurt_flash_tween and _hurt_flash_tween.is_valid():
			_hurt_flash_tween.kill()
		_hurt_flash_tween = create_tween()
		_hurt_flash_tween.tween_property(animated_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.05)
		_hurt_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)
	
	# Phase transition check
	if current_phase == 1 and health <= max_health * phase_2_threshold:
		_enter_phase_2()
	
	# Death check
	if health <= 0:
		die()

func _enter_phase_2() -> void:
	current_phase = 2
	movement_speed *= phase_2_speed_multiplier
	print("King Crab enters Phase 2!")

# Tree climbing support
func find_nearest_tree() -> Node2D:
	var trees = get_tree().get_nodes_in_group("coconut_tree")
	if trees.is_empty():
		return null
	var nearest: Node2D = null
	var min_dist: float = INF
	for tree in trees:
		var dist = global_position.distance_to(tree.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = tree
	return nearest
