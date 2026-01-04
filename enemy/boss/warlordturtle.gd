extends EnemyCharacter

## BOSS POISE SYSTEM — Warlord Turtle cannot be knocked back or stun-locked
## This creates a skill-based fight requiring pattern recognition.
@export_group("Boss Poise")
@export var knockback_immune: bool = true  ## Boss cannot be pushed by player attacks
@export var stun_immune: bool = true  ## Boss cannot enter hurt state during attacks

@export var boomb_scene: PackedScene
@export var rocket_scene: PackedScene
@export var whirlpool_scene: PackedScene  ## Used by summon_whirlpool state

@export_group("Phase Transition")
@export var phase_transition_pause: float = 1.5  ## Pause duration before phase 2 begins
@export var phase_transition_roar_delay: float = 0.3  ## Delay before roar animation

@export_group("Phase 2 - Water Mechanics")
@export var water_raise_duration: float = 4.0    ## Duration for water to raise/lower (seconds)
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

var laugh_timer := 0.0
var laugh_interval := 15.0

## Phase 2 system
var current_phase: int = 1
var water_raised: bool = false
var last_water_action_time: float = 0.0
var cached_water_node: water = null

## Visual feedback state
var _invincibility_tween: Tween = null

signal health_changed

func _ready():
	add_to_group("boss")  # Mark as boss for special handling
	add_to_group("enemy")
	super._ready()
	fsm = FSM.new(self, $States, $States/Idle)

func fire_boomb():
	var boomb1 = boomb_scene.instantiate()
	boomb1.global_position = muzzle.global_position
	boomb1.set_speed(350.0)
	boomb1.roll_dir =  direction
	get_tree().current_scene.add_child(boomb1)
	boomb1.launch(-1)  # Launch left
	#bombs_launch_sound.play()
	AudioManager.play_sound("warlord_bomb_launch",20.0)
	await get_tree().create_timer(0.2).timeout
	var boomb2 = boomb_scene.instantiate()
	boomb2.global_position = muzzle2.global_position
	boomb2.set_speed(250.0)
	boomb2.roll_dir =  -direction
	get_tree().current_scene.add_child(boomb2)
	boomb2.launch(1)  # Launch right
	#bombs_launch_sound.play()
	AudioManager.play_sound("warlord_bomb_launch",20.0)

func fire_rocket():
	var rocket1 = rocket_scene.instantiate()
	rocket1.global_position = muzzlerocket1.global_position
	rocket1.scale = Vector2(1.5, 1.5)
	get_tree().current_scene.add_child(rocket1)
	warning_marker.show_animation()
	rocket1.shoot(rocket1.global_position, warning_marker.global_position, 1.5)
	#missles_launch_sound.play()
	AudioManager.play_sound("warlord_missle_launch",20.0)
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
	#missles_launch_sound.play()
	AudioManager.play_sound("warlord_missle_launch",20.0)
	await get_tree().create_timer(0.2).timeout
	var rocket4 = rocket_scene.instantiate()
	rocket4.global_position = muzzlerocket2.global_position
	get_tree().current_scene.add_child(rocket4)
	warning_marker4.show_animation()
	rocket4.shoot(rocket4.global_position, warning_marker4.global_position, 1.5)

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
	if health >= 2:
		_update_laugh(delta)
	

func _update_laugh(delta: float) -> void:
	laugh_timer += delta
	if laugh_timer >= laugh_interval:
		#laugh_sound.play()
		AudioManager.play_sound("warlord_laugh",20.0)
		laugh_timer = 0.0

## Override take_damage to implement POISE system + proper visual feedback
## Boss takes damage but is NOT knocked back or interrupted
## MUST match King Crab's pattern for consistency!
func take_damage(damage: int) -> void:
	super.take_damage(damage)  # Handles health -= damage AND plays hurt sound
	health_changed.emit()
	
	# Visual feedback: quick red flash without state change (matches King Crab)
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.05)
		tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)
	
	# NOTE: Sound already played by super.take_damage() via BaseCharacter
	
	# Phase transition at 50% health
	if current_phase == 1 and health <= max_health / 2:
		_enter_phase_2()
	
	# Vulnerable state at 1 HP
	if health == 1:
		become_vulnerable()
	
	# Death check
	if health <= 0:
		die()

func _enter_phase_2() -> void:
	current_phase = 2
	# Use phase transition state if available
	if fsm.states.has("phasetransition"):
		fsm.change_state(fsm.states.phasetransition)
	else:
		print("Warlord Turtle enters Phase 2!")
		
func become_vulnerable():
	if fsm.current_state != fsm.states.vulnerable:
		fsm.change_state(fsm.states.vulnerable)

func die() -> void:
	if fsm.states.has("dead"):
		fsm.change_state(fsm.states.dead)
	else:
		queue_free()

## Enable hurt area for a limited time with VISUAL FEEDBACK
## Kojima's Law: If the player can't hurt the boss, SHOW THEM WHY
func enable_hurt_for(seconds: float) -> void:
	HurtArea.disabled = false
	hurt_timer.start(seconds)
	_stop_invincibility_visual()

func _on_hurt_timer_timeout() -> void:
	HurtArea.disabled = true
	_start_invincibility_visual()

## VISUAL FEEDBACK: Pulsing transparency when invincible
## Per VISUAL_DESIGN_DOCTRINE: "Every visual element must read as PIXELS, not blobs"
## This uses a subtle alpha pulse, not a shader blur
func _start_invincibility_visual() -> void:
	if _invincibility_tween and _invincibility_tween.is_valid():
		_invincibility_tween.kill()
	
	_invincibility_tween = create_tween()
	_invincibility_tween.set_loops()  # Loop forever until stopped
	# Pulse between semi-transparent and slightly-less-transparent
	_invincibility_tween.tween_property(animated_sprite, "modulate", Color(0.7, 0.7, 0.9, 0.6), 0.4)
	_invincibility_tween.tween_property(animated_sprite, "modulate", Color(0.9, 0.9, 1.0, 0.85), 0.4)

func _stop_invincibility_visual() -> void:
	if _invincibility_tween and _invincibility_tween.is_valid():
		_invincibility_tween.kill()
		_invincibility_tween = null
	# Restore full opacity
	if animated_sprite:
		animated_sprite.modulate = Color.WHITE
