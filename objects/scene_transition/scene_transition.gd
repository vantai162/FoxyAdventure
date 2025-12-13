@tool
extends Area2D
class_name SceneTransition
## Seamless cross-scene transition with directional wipe effect
## Player walks through edge to transition to another scene file
## 
## SETUP:
## 1. Place at edge of level where player exits
## 2. Set target_scene to the next level's path
## 3. Set target_spawn_name to matching transition's name in target scene
## 4. The wipe direction is automatic based on player movement

signal transition_started
signal transition_completed

enum Direction { LEFT, RIGHT, UP, DOWN }

@export_group("Target Scene")
## Path to the target scene file
@export_file("*.tscn") var target_scene: String = ""
## Name of the SceneTransition in target scene to spawn at
@export var target_spawn_name: String = ""

@export_group("Transition Behavior")
## Direction player is moving when transitioning (auto-detected if AUTO)
@export var exit_direction: Direction = Direction.RIGHT:
	set(value):
		exit_direction = value
		if auto_spawn_offset:
			spawn_offset = _calculate_spawn_offset(value)
## Spawn offset from the target transition position
## Default matches exit_direction=RIGHT: spawn to the LEFT (inside level)
@export var spawn_offset: Vector2 = Vector2(-48, 0)
## Automatically calculate spawn_offset based on exit_direction
@export var auto_spawn_offset: bool = true:
	set(value):
		auto_spawn_offset = value
		if value:
			spawn_offset = _calculate_spawn_offset(exit_direction)
## Minimum velocity to trigger transition
@export var trigger_threshold: float = 10.0

@export_group("Wipe Effect")
## Duration of the wipe transition
## 0.25s = brisk but perceptible (15 frames at 60fps)
## 0.35s = standard cinematic feel
## Below 0.2s becomes a flash, not a flow
@export var wipe_duration: float = 0.25

@export_group("Preloading")
## Distance from transition to start preloading (0 = preload immediately on level start)
## For seamless transitions, use 0 or a large value like 800
@export var preload_distance: float = 800.0
## Start preloading immediately when level loads (guarantees no hitch)
@export var preload_on_ready: bool = true
## Whether preloading has started
var _preload_started: bool = false

@export_group("Editor Preview")
## Show direction indicator in editor
@export var show_indicator: bool = true:
	set(value):
		show_indicator = value
		queue_redraw()
@export var indicator_color: Color = Color(0.9, 0.5, 0.2, 0.9)

@export_group("Visual Indicator")
## Show a visual glow/particles at runtime to help players find exits
@export var show_exit_glow: bool = true
## Color of the exit glow (default: warm light suggesting "way forward")
@export var glow_color: Color = Color(1.0, 0.95, 0.8, 0.8)
## Intensity of the glow light
@export var glow_energy: float = 0.4
## Size of the glow (how far it reaches)
@export var glow_size: float = 1.2
## Show floating particles drifting toward exit
@export var show_exit_particles: bool = true
## Particle color (subtle dust/mist)
@export var particle_color: Color = Color(1.0, 1.0, 0.9, 0.3)

var _exit_light: PointLight2D = null
var _exit_particles: GPUParticles2D = null

var is_transitioning: bool = false
var player_in_zone: bool = false
var _preloaded_scene: PackedScene = null
var _player_ref: Node2D = null  # Cache player reference

@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null

func _ready() -> void:
	# CRITICAL: Ensure spawn_offset is correctly calculated on load.
	# Godot does NOT run setters for default values, only for explicit assignments.
	# So if exit_direction uses default (RIGHT) and auto_spawn_offset is true,
	# the setter never runs and spawn_offset stays at its wrong default (+48, 0).
	# We force recalculation here to guarantee correctness.
	if auto_spawn_offset:
		spawn_offset = _calculate_spawn_offset(exit_direction)
	
	if Engine.is_editor_hint():
		return
	
	# Validate configuration
	if target_scene.is_empty():
		push_warning("SceneTransition '%s': No target_scene set! This transition won't go anywhere." % name)
	if target_spawn_name.is_empty():
		push_warning("SceneTransition '%s': No target_spawn_name set! Player may spawn at origin in target scene." % name)
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Setup collision
	collision_layer = 0
	collision_mask = 2  # Player layer
	
	_setup_collision_shape()
	
	# Setup visual indicators for runtime
	_setup_exit_visuals()
	
	# Preload strategy:
	# - If preload_on_ready is true, start loading immediately (guarantees seamless)
	# - Otherwise, wait until player is within preload_distance
	if preload_on_ready and not target_scene.is_empty():
		# Defer to not block scene initialization
		call_deferred("_start_preload")
	
	set_process(true)  # Enable _process for proximity checking and preload status

func _setup_collision_shape() -> void:
	if collision_shape == null:
		return
	
	var shape = collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()
		collision_shape.shape = shape
	
	# Auto-size based on direction
	match exit_direction:
		Direction.LEFT, Direction.RIGHT:
			shape.size = Vector2(24, 160)
		Direction.UP, Direction.DOWN:
			shape.size = Vector2(160, 24)


func _setup_exit_visuals() -> void:
	## Create runtime visual indicators to help players find the exit
	## This creates environmental hints that feel natural, not "gamey"
	
	# Create exit glow light
	if show_exit_glow:
		_exit_light = PointLight2D.new()
		_exit_light.name = "ExitGlow"
		_exit_light.color = glow_color
		_exit_light.energy = glow_energy
		_exit_light.texture_scale = glow_size
		
		# Create a soft radial gradient texture for the light
		var gradient = Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		
		var grad_tex = GradientTexture2D.new()
		grad_tex.gradient = gradient
		grad_tex.width = 256
		grad_tex.height = 256
		grad_tex.fill = GradientTexture2D.FILL_RADIAL
		grad_tex.fill_from = Vector2(0.5, 0.5)
		grad_tex.fill_to = Vector2(0.5, 0.0)
		_exit_light.texture = grad_tex
		
		# Position the light slightly in the exit direction (beckoning)
		var light_offset := Vector2.ZERO
		match exit_direction:
			Direction.RIGHT: light_offset = Vector2(20, 0)
			Direction.LEFT: light_offset = Vector2(-20, 0)
			Direction.DOWN: light_offset = Vector2(0, 20)
			Direction.UP: light_offset = Vector2(0, -20)
		_exit_light.position = light_offset
		
		add_child(_exit_light)
	
	# Create floating particles drifting toward exit
	if show_exit_particles:
		_exit_particles = GPUParticles2D.new()
		_exit_particles.name = "ExitParticles"
		_exit_particles.amount = 8
		_exit_particles.lifetime = 2.0
		_exit_particles.preprocess = 1.0  # Pre-warm so particles exist immediately
		_exit_particles.emitting = true
		
		# Create particle material
		var mat = ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		
		# Emission box matches the transition zone size
		match exit_direction:
			Direction.LEFT, Direction.RIGHT:
				mat.emission_box_extents = Vector3(4, 60, 0)
			Direction.UP, Direction.DOWN:
				mat.emission_box_extents = Vector3(60, 4, 0)
		
		# Particles drift toward the exit direction
		var drift_dir := Vector2.ZERO
		match exit_direction:
			Direction.RIGHT: drift_dir = Vector2(25, 0)
			Direction.LEFT: drift_dir = Vector2(-25, 0)
			Direction.DOWN: drift_dir = Vector2(0, 25)
			Direction.UP: drift_dir = Vector2(0, -25)
		mat.direction = Vector3(drift_dir.x, drift_dir.y, 0)
		mat.spread = 15.0  # Slight spread for organic feel
		mat.initial_velocity_min = 8.0
		mat.initial_velocity_max = 15.0
		mat.gravity = Vector3.ZERO
		
		# Subtle fade in/out
		mat.scale_min = 0.5
		mat.scale_max = 1.5
		
		# Color: starts visible, fades out
		mat.color = particle_color
		
		var color_curve = Gradient.new()
		color_curve.set_color(0, Color(1, 1, 1, 0))
		color_curve.set_offset(0, 0.0)
		color_curve.add_point(0.2, Color(1, 1, 1, 1))
		color_curve.add_point(0.8, Color(1, 1, 1, 1))
		color_curve.set_color(1, Color(1, 1, 1, 0))
		
		var color_tex = GradientTexture1D.new()
		color_tex.gradient = color_curve
		mat.color_ramp = color_tex
		
		_exit_particles.process_material = mat
		
		# Simple texture - small glowing dot
		var particle_tex = GradientTexture2D.new()
		var particle_grad = Gradient.new()
		particle_grad.set_color(0, Color.WHITE)
		particle_grad.set_color(1, Color(1, 1, 1, 0))
		particle_tex.gradient = particle_grad
		particle_tex.width = 16
		particle_tex.height = 16
		particle_tex.fill = GradientTexture2D.FILL_RADIAL
		particle_tex.fill_from = Vector2(0.5, 0.5)
		particle_tex.fill_to = Vector2(0.5, 0.0)
		_exit_particles.texture = particle_tex
		
		add_child(_exit_particles)


func _start_preload() -> void:
	if target_scene.is_empty() or _preload_started:
		return
	_preload_started = true
	# Low priority background load - doesn't hitch gameplay
	ResourceLoader.load_threaded_request(target_scene, "", false, ResourceLoader.CACHE_MODE_REUSE)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	
	# PROXIMITY-BASED PRELOADING (only if not using preload_on_ready)
	if not _preload_started and not preload_on_ready and preload_distance > 0 and not target_scene.is_empty():
		# Get/cache player reference
		if _player_ref == null or not is_instance_valid(_player_ref):
			_player_ref = _get_player()
		
		if _player_ref != null:
			var distance_to_player = global_position.distance_to(_player_ref.global_position)
			if distance_to_player <= preload_distance:
				_start_preload()
	
	# Check if preload completed
	if _preload_started and _preloaded_scene == null:
		var status = ResourceLoader.load_threaded_get_status(target_scene)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_preloaded_scene = ResourceLoader.load_threaded_get(target_scene)
			# Scene is cached and ready for instant transition

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if not player_in_zone or is_transitioning:
		return
	
	var player = _get_player()
	if player == null:
		return
	
	if _is_player_moving_through(player):
		_trigger_transition(player)


func _get_player() -> Node2D:
	if _player_ref and is_instance_valid(_player_ref):
		return _player_ref
	if GameManager and GameManager.player:
		_player_ref = GameManager.player
		return _player_ref
	var found = get_tree().get_first_node_in_group("player")
	if found:
		_player_ref = found
	return _player_ref

func _is_player_moving_through(player: Node2D) -> bool:
	if not player or not "velocity" in player:
		return false
	
	var vel = player.velocity
	
	match exit_direction:
		Direction.RIGHT:
			return vel.x > trigger_threshold
		Direction.LEFT:
			return vel.x < -trigger_threshold
		Direction.DOWN:
			return vel.y > trigger_threshold
		Direction.UP:
			return vel.y < -trigger_threshold
	
	return false

func _trigger_transition(player: Node2D) -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	transition_started.emit()
	
	# Hide exit visuals during transition (don't want them showing in wipe)
	_hide_exit_visuals()
	
	# DON'T freeze the player! Keep them walking into the wipe.
	# This creates the "whoosh" feeling - player momentum continues
	# The wipe catches up with them mid-stride.
	
	# Store player's exit velocity for the target scene to use
	var exit_velocity = player.velocity if player and "velocity" in player else Vector2.ZERO
	
	# Store player state
	if GameManager and player and player.has_method("save_state"):
		GameManager.save_player_state(player)
	
	# NOTE: We do NOT set target_portal_name here!
	# That system is legacy (used by GameManager.change_stage) and doesn't apply offsets.
	# SceneTransition uses the meta-based "incoming_transition_spawn" system which
	# correctly applies spawn_offset to position players inside level bounds.
	
	# Store transition direction and spawn point for target scene
	_store_transition_direction()
	
	# Perform directional wipe OUT using global TransitionEffects
	# Using the soft shader-based wipe for organic feel
	var wipe_dir = _direction_to_wipe_direction(exit_direction)
	var transition_fx = get_node_or_null("/root/TransitionEffects")
	if transition_fx:
		await transition_fx.wipe_out(wipe_dir, wipe_duration)
	else:
		# Fallback: use GameManager fade
		await _wipe_out()
	
	# CRITICAL: Hold black for a moment to conceal the scene change stutter
	# Even preloaded scenes cause micro-hitches during instantiation.
	# This "breath" makes the transition feel deliberate, not glitchy.
	# 3-4 frames at 60fps = 50-66ms, enough to hide any jank
	await get_tree().create_timer(0.05).timeout
	
	# Change scene
	_change_to_target_scene()


func _hide_exit_visuals() -> void:
	## Hide exit indicators during transition
	if _exit_light:
		_exit_light.visible = false
	if _exit_particles:
		_exit_particles.emitting = false
		_exit_particles.visible = false


func _store_transition_direction() -> void:
	# Store in GameManager for target scene to read
	if GameManager:
		# Use meta to store arbitrary data
		GameManager.set_meta("incoming_transition_direction", exit_direction)
		GameManager.set_meta("incoming_transition_spawn", target_spawn_name)
		# Store wipe duration for symmetric wipe_in
		GameManager.set_meta("incoming_transition_duration", wipe_duration)

func _direction_to_wipe_direction(dir: Direction) -> int:
	# Maps to TransitionEffects.WipeDirection enum
	match dir:
		Direction.RIGHT: return 1  # WipeDirection.RIGHT
		Direction.LEFT: return 0   # WipeDirection.LEFT
		Direction.DOWN: return 3   # WipeDirection.DOWN
		Direction.UP: return 2     # WipeDirection.UP
	return 1

func _wipe_out() -> void:
	# Create wipe overlay
	var wipe = _create_wipe_overlay()
	
	# Animate wipe based on direction
	var tween = create_tween()
	var start_pos: Vector2
	var end_pos: Vector2
	var viewport_size = get_viewport().get_visible_rect().size
	
	match exit_direction:
		Direction.RIGHT:
			# Wipe from right to left
			start_pos = Vector2(viewport_size.x, 0)
			end_pos = Vector2(0, 0)
		Direction.LEFT:
			# Wipe from left to right
			start_pos = Vector2(-viewport_size.x, 0)
			end_pos = Vector2(0, 0)
		Direction.DOWN:
			# Wipe from bottom to top
			start_pos = Vector2(0, viewport_size.y)
			end_pos = Vector2(0, 0)
		Direction.UP:
			# Wipe from top to bottom
			start_pos = Vector2(0, -viewport_size.y)
			end_pos = Vector2(0, 0)
	
	wipe.position = start_pos
	# EASE_OUT: Immediate response, smooth landing (matches shader wipe)
	tween.tween_property(wipe, "position", end_pos, wipe_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished

func _create_wipe_overlay() -> ColorRect:
	# Create canvas layer for wipe
	var canvas = CanvasLayer.new()
	canvas.name = "WipeLayer"
	canvas.layer = 100  # On top of everything
	get_tree().root.add_child(canvas)
	
	# Create oversized color rect
	var wipe = ColorRect.new()
	wipe.name = "WipeRect"
	var viewport_size = get_viewport().get_visible_rect().size
	wipe.size = viewport_size * 2  # Oversized to cover during movement
	wipe.position = Vector2.ZERO
	wipe.color = Color.BLACK
	canvas.add_child(wipe)
	
	return wipe

func _change_to_target_scene() -> void:
	# If preload isn't done yet, wait for it while screen is black
	# This prevents the gray flash from a blocking load
	if _preloaded_scene == null and not target_scene.is_empty():
		# Either preload wasn't started, or it's still in progress
		if not _preload_started:
			_start_preload()
		
		# Wait for the threaded load to complete
		while _preloaded_scene == null:
			var status = ResourceLoader.load_threaded_get_status(target_scene)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_preloaded_scene = ResourceLoader.load_threaded_get(target_scene)
				break
			elif status == ResourceLoader.THREAD_LOAD_FAILED:
				printerr("SceneTransition: Failed to load scene: ", target_scene)
				break
			elif status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				printerr("SceneTransition: Invalid resource: ", target_scene)
				break
			# Wait one frame and check again
			await get_tree().process_frame
	
	if _preloaded_scene != null:
		# Use preloaded scene for instant switch - NO blocking!
		get_tree().change_scene_to_packed(_preloaded_scene)
	elif not target_scene.is_empty():
		# Last resort fallback - this will cause a hitch but at least works
		printerr("SceneTransition: Preload failed, falling back to blocking load")
		get_tree().change_scene_to_file(target_scene)
	else:
		printerr("SceneTransition: No target scene set!")
		is_transitioning = false

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_zone = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_zone = false

## Get the spawn position for incoming players
func get_spawn_position() -> Vector2:
	return global_position + spawn_offset

## Get opposite direction
static func get_opposite_direction(dir: Direction) -> Direction:
	match dir:
		Direction.LEFT: return Direction.RIGHT
		Direction.RIGHT: return Direction.LEFT
		Direction.UP: return Direction.DOWN
		Direction.DOWN: return Direction.UP
	return Direction.RIGHT

## Calculate spawn offset based on exit direction of THIS transition
## 
## CRITICAL UNDERSTANDING:
## - exit_direction describes where THIS transition LEADS (where players EXIT to)
## - spawn_offset describes where INCOMING players should spawn RELATIVE to this transition
## - These are OPPOSITE operations!
##
## Example: A transition with exit_direction=RIGHT
## - Players who USE this exit walk RIGHT and leave the scene
## - Players who SPAWN here came FROM the right (via target scene's left exit)
## - So they should spawn to the LEFT of this transition (inside the level)
##
## The spawn position must be OPPOSITE to the exit direction to place
## players safely inside the level bounds, not outside.
static func _calculate_spawn_offset(dir: Direction) -> Vector2:
	const OFFSET_DISTANCE := 48.0  # Pixels past the transition zone
	match dir:
		Direction.LEFT:
			# This exit leads LEFT (out of left edge)
			# Incoming players came from the left, should spawn to the RIGHT (inside level)
			return Vector2(OFFSET_DISTANCE, 0)
		Direction.RIGHT:
			# This exit leads RIGHT (out of right edge)
			# Incoming players came from the right, should spawn to the LEFT (inside level)
			return Vector2(-OFFSET_DISTANCE, 0)
		Direction.UP:
			# This exit leads UP (out of top edge)
			# Incoming players came from above, should spawn BELOW (inside level)
			return Vector2(0, OFFSET_DISTANCE)
		Direction.DOWN:
			# This exit leads DOWN (out of bottom edge)
			# Incoming players came from below, should spawn ABOVE (inside level)
			return Vector2(0, -OFFSET_DISTANCE)
	return Vector2(-OFFSET_DISTANCE, 0)

## Editor drawing
func _draw() -> void:
	if not Engine.is_editor_hint() or not show_indicator:
		return
	
	# Draw direction arrow
	var arrow_size = 24.0
	var arrow_dir: Vector2
	
	match exit_direction:
		Direction.RIGHT:
			arrow_dir = Vector2.RIGHT
		Direction.LEFT:
			arrow_dir = Vector2.LEFT
		Direction.UP:
			arrow_dir = Vector2.UP
		Direction.DOWN:
			arrow_dir = Vector2.DOWN
	
	var arrow_end = arrow_dir * arrow_size
	var arrow_perp = arrow_dir.rotated(PI / 2)
	
	# Main arrow line
	draw_line(Vector2.ZERO, arrow_end, indicator_color, 3.0)
	
	# Arrow head
	draw_line(arrow_end, arrow_end - arrow_dir * 10 + arrow_perp * 6, indicator_color, 3.0)
	draw_line(arrow_end, arrow_end - arrow_dir * 10 - arrow_perp * 6, indicator_color, 3.0)
	
	# Label
	var font := ThemeDB.fallback_font
	var label := "→ " + target_scene.get_file() if not target_scene.is_empty() else "→ [NO TARGET]"
	draw_string(font, Vector2(-40, -20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, indicator_color)
