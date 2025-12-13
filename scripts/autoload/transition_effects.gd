extends CanvasLayer
## Global transition effects handler (Autoload)
## Provides soft directional wipes for scene transitions
## 
## Access via: TransitionEffects.wipe_out(...) or get_node("/root/TransitionEffects")
## 
## Visual design notes:
## - Uses shader-based soft wipe with feathered edge (not hard rectangle)
## - Subtle wave on edge for organic feel (matches game's visual language)
## - Player-centric timing (0.2-0.25s, same feel as dash/attack)
## - Darkness sweeps in direction of travel for spatial continuity

signal wipe_completed
signal fade_completed

enum WipeDirection { LEFT, RIGHT, UP, DOWN }

## Timing presets - these match the game's action feel
## OPTIMIZED: 0.15s feels snappier than 0.2s while still being smooth
const WIPE_DURATION_FAST: float = 0.15   ## For quick seamless transitions (butter smooth)
const WIPE_DURATION_NORMAL: float = 0.25 ## Standard transition
const WIPE_DURATION_SLOW: float = 0.4    ## Dramatic moments

## Visual tuning
const FEATHER_SOFT: float = 0.2    ## Soft gradient edge
const FEATHER_MEDIUM: float = 0.12 ## Balanced 
const FEATHER_SHARP: float = 0.06  ## Snappier edge

var _wipe_rect: ColorRect = null
var _wipe_material: ShaderMaterial = null
var _is_wiping: bool = false
var _current_progress: float = 0.0

## Debug logging (disable for production)
var debug_logging: bool = false

## Audio feedback for transitions (optional, enhances feel)
var transition_audio_enabled: bool = true
var _audio_player: AudioStreamPlayer = null

## Performance metrics
var _transition_start_time: int = 0
var _last_transition_duration_ms: int = 0

func _ready() -> void:
	layer = 100  # On top of everything
	_setup_wipe_rect()
	_setup_audio()

func _setup_wipe_rect() -> void:
	_wipe_rect = ColorRect.new()
	_wipe_rect.name = "WipeRect"
	_wipe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# For CanvasLayer children, we need to manually size to viewport
	# Anchors don't work without a parent Control container
	var viewport_size = get_viewport().get_visible_rect().size
	_wipe_rect.position = Vector2.ZERO
	_wipe_rect.size = viewport_size
	
	# Load and apply the wipe shader
	var shader = load("res://scripts/autoload/transition_wipe.gdshader")
	if shader:
		_wipe_material = ShaderMaterial.new()
		_wipe_material.shader = shader
		_wipe_material.set_shader_parameter("progress", 0.0)
		_wipe_material.set_shader_parameter("feather", FEATHER_MEDIUM)
		_wipe_material.set_shader_parameter("wave_amount", 0.015)
		_wipe_material.set_shader_parameter("wave_frequency", 4.0)
		_wipe_rect.material = _wipe_material
		# Make the rect itself transparent - shader handles the color
		_wipe_rect.color = Color(0, 0, 0, 0)
	else:
		push_warning("TransitionEffects: Could not load wipe shader, falling back to solid color")
		_wipe_rect.color = Color.BLACK
	
	add_child(_wipe_rect)
	
	# Start with no wipe visible
	_set_progress(0.0)
	_wipe_rect.visible = false
	
	# Connect to viewport size changes to stay full-screen
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	if _wipe_rect:
		var viewport_size = get_viewport().get_visible_rect().size
		_wipe_rect.size = viewport_size


func _setup_audio() -> void:
	## Setup audio player for transition sounds
	## Using the wind sound as a subtle "whoosh" for transitions
	## If no sound is available, transitions still work silently
	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "TransitionAudio"
	_audio_player.bus = "SFX"
	_audio_player.volume_db = -12.0  # Subtle, not overpowering
	
	# Try to load a wind/whoosh sound for transition
	var sound_path = "res://assets/sounds/675712__craigsmith__s21-11a-phoenix-wind.wav"
	if ResourceLoader.exists(sound_path):
		var stream = load(sound_path) as AudioStream
		if stream:
			_audio_player.stream = stream
	
	add_child(_audio_player)


func _play_transition_sound() -> void:
	## Play subtle audio cue during transition
	if not transition_audio_enabled:
		return
	if _audio_player and _audio_player.stream:
		# Play from a random position for variety
		_audio_player.play(randf_range(0.0, 0.5))
		# Stop after a short time (we only want the attack/beginning of the sound)
		get_tree().create_timer(0.3).timeout.connect(func(): _audio_player.stop())


func _set_progress(value: float) -> void:
	_current_progress = value
	if _wipe_material:
		_wipe_material.set_shader_parameter("progress", value)
	else:
		# Fallback: use modulate alpha
		_wipe_rect.modulate.a = value

func _set_direction(direction: WipeDirection) -> void:
	if _wipe_material:
		_wipe_material.set_shader_parameter("direction", direction)

## Perform a directional wipe IN (revealing the new scene)
## Call this when a new scene loads to reveal the content
## The wipe exits in the specified direction
func wipe_in(direction: WipeDirection = WipeDirection.LEFT, duration: float = WIPE_DURATION_FAST, feather: float = FEATHER_MEDIUM) -> void:
	if _is_wiping:
		return
	
	if debug_logging:
		print("[TransitionFX] wipe_in START dir=", direction, " duration=", duration, "s")
	_is_wiping = true
	_wipe_rect.visible = true
	
	# Set direction and visual parameters
	_set_direction(direction)
	if _wipe_material:
		_wipe_material.set_shader_parameter("feather", feather)
		_wipe_material.set_shader_parameter("wave_amount", 0.015)  # Restore wave
	
	# Start fully covered
	_set_progress(1.0)
	
	# Animate progress from 1.0 to 0.0 (revealing)
	# EASE_OUT: Fast start, gentle end - feels like pulling back a curtain
	var tween = create_tween()
	tween.tween_method(_set_progress, 1.0, 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
	
	_wipe_rect.visible = false
	_is_wiping = false
	
	# Calculate total transition time (wipe_out start → wipe_in complete)
	if _transition_start_time > 0:
		_last_transition_duration_ms = Time.get_ticks_msec() - _transition_start_time
		if debug_logging:
			print("[TransitionFX] wipe_in COMPLETE - Total transition: ", _last_transition_duration_ms, "ms")
		_transition_start_time = 0
	else:
		if debug_logging:
			print("[TransitionFX] wipe_in COMPLETE")
	
	wipe_completed.emit()

## Perform a directional wipe OUT (covering the screen with darkness)
## Call this before changing scenes
## Darkness sweeps in FROM the specified direction
func wipe_out(direction: WipeDirection = WipeDirection.RIGHT, duration: float = WIPE_DURATION_FAST, feather: float = FEATHER_MEDIUM) -> void:
	if _is_wiping:
		return
	
	_transition_start_time = Time.get_ticks_msec()
	if debug_logging:
		print("[TransitionFX] wipe_out START dir=", direction, " duration=", duration, "s")
	_is_wiping = true
	_wipe_rect.visible = true
	
	# Play subtle audio cue
	_play_transition_sound()
	
	# Set direction and visual parameters
	_set_direction(direction)
	if _wipe_material:
		_wipe_material.set_shader_parameter("feather", feather)
		_wipe_material.set_shader_parameter("wave_amount", 0.015)  # Restore wave
	
	# Start fully transparent
	_set_progress(0.0)
	
	# Animate progress from 0.0 to 1.0 (covering)
	# EASE_IN: Builds momentum - feels like darkness rushing toward you
	var tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	await tween.finished
	
	# Stay visible (screen covered) until wipe_in is called
	_is_wiping = false
	if debug_logging:
		print("[TransitionFX] wipe_out COMPLETE (screen covered)")
	wipe_completed.emit()

## Simple fade to black (for doors, death, etc.)
## This is gentler than a wipe - no directional movement
func fade_out(duration: float = 0.3) -> void:
	if _is_wiping:
		return
	
	_is_wiping = true
	_wipe_rect.visible = true
	
	# Disable wave for clean fade, use very soft feather
	if _wipe_material:
		_wipe_material.set_shader_parameter("wave_amount", 0.0)
		_wipe_material.set_shader_parameter("feather", 0.5)
		_set_direction(WipeDirection.RIGHT)
	
	_set_progress(0.0)
	
	var tween = create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	await tween.finished
	
	_is_wiping = false
	fade_completed.emit()

## Simple fade from black
func fade_in(duration: float = 0.3) -> void:
	if _is_wiping:
		return
	
	_is_wiping = true
	_wipe_rect.visible = true
	
	if _wipe_material:
		_wipe_material.set_shader_parameter("wave_amount", 0.0)
		_wipe_material.set_shader_parameter("feather", 0.5)
		_set_direction(WipeDirection.RIGHT)
	
	_set_progress(1.0)
	
	var tween = create_tween()
	tween.tween_method(_set_progress, 1.0, 0.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	await tween.finished
	
	_wipe_rect.visible = false
	_is_wiping = false
	fade_completed.emit()

## Check if screen is currently covered
func is_screen_covered() -> bool:
	return _wipe_rect.visible and _current_progress > 0.9

## Force clear the wipe (emergency use)
func clear_wipe() -> void:
	_wipe_rect.visible = false
	_is_wiping = false
	_set_progress(0.0)
	_transition_start_time = 0

## Get the duration of the last complete transition (wipe_out → wipe_in) in milliseconds
## Useful for performance monitoring and debugging
func get_last_transition_duration_ms() -> int:
	return _last_transition_duration_ms

## Check if a wipe is currently in progress
func is_wiping() -> bool:
	return _is_wiping

## Get opposite wipe direction (for seamless enter/exit pairs)
## When exiting RIGHT, new scene should enter from LEFT
static func get_opposite(dir: WipeDirection) -> WipeDirection:
	match dir:
		WipeDirection.LEFT: return WipeDirection.RIGHT
		WipeDirection.RIGHT: return WipeDirection.LEFT
		WipeDirection.UP: return WipeDirection.DOWN
		WipeDirection.DOWN: return WipeDirection.UP
	return WipeDirection.RIGHT

## Get the wipe direction for player travel direction
## If player is moving right (positive X), wipe should come FROM the right
static func direction_from_travel(travel_x: float, travel_y: float = 0.0) -> WipeDirection:
	if abs(travel_x) > abs(travel_y):
		return WipeDirection.RIGHT if travel_x > 0 else WipeDirection.LEFT
	else:
		return WipeDirection.DOWN if travel_y > 0 else WipeDirection.UP
