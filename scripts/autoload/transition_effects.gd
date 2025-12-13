extends CanvasLayer
## Global transition effects handler (Autoload)
## Provides directional wipes and fades for scene transitions
## 
## Access via: TransitionEffects.wipe_out(...) or get_node("/root/TransitionEffects")
## NOTE: No class_name here - autoloads don't need it and it causes conflicts

signal wipe_completed
signal fade_completed

enum WipeDirection { LEFT, RIGHT, UP, DOWN }

var _wipe_rect: ColorRect = null
var _is_wiping: bool = false

func _ready() -> void:
	layer = 100  # On top of everything
	_setup_wipe_rect()

func _setup_wipe_rect() -> void:
	_wipe_rect = ColorRect.new()
	_wipe_rect.name = "WipeRect"
	_wipe_rect.color = Color.BLACK
	_wipe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wipe_rect)
	
	# Start hidden
	_wipe_rect.visible = false

## Perform a directional wipe IN (clearing the screen)
## Call this when a new scene loads to reveal the content
func wipe_in(direction: WipeDirection, duration: float = 0.18, color: Color = Color.BLACK) -> void:
	if _is_wiping:
		return
	
	_is_wiping = true
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Setup rect to cover screen
	_wipe_rect.color = color
	_wipe_rect.size = viewport_size * 1.5
	_wipe_rect.visible = true
	
	# Position based on direction (starts covering screen)
	var start_pos: Vector2
	var end_pos: Vector2
	
	match direction:
		WipeDirection.LEFT:
			# Wipe exits to the left
			start_pos = Vector2(0, -viewport_size.y * 0.25)
			end_pos = Vector2(-viewport_size.x * 1.5, -viewport_size.y * 0.25)
		WipeDirection.RIGHT:
			# Wipe exits to the right
			start_pos = Vector2(0, -viewport_size.y * 0.25)
			end_pos = Vector2(viewport_size.x * 1.5, -viewport_size.y * 0.25)
		WipeDirection.UP:
			# Wipe exits upward
			start_pos = Vector2(-viewport_size.x * 0.25, 0)
			end_pos = Vector2(-viewport_size.x * 0.25, -viewport_size.y * 1.5)
		WipeDirection.DOWN:
			# Wipe exits downward
			start_pos = Vector2(-viewport_size.x * 0.25, 0)
			end_pos = Vector2(-viewport_size.x * 0.25, viewport_size.y * 1.5)
	
	_wipe_rect.position = start_pos
	
	# WHOOSH! Fast, snappy reveal - decelerate at end
	var tween = create_tween()
	tween.tween_property(_wipe_rect, "position", end_pos, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	
	await tween.finished
	
	_wipe_rect.visible = false
	_is_wiping = false
	wipe_completed.emit()

## Perform a directional wipe OUT (covering the screen)
## Call this before changing scenes - this is the WHOOSH
func wipe_out(direction: WipeDirection, duration: float = 0.18, color: Color = Color.BLACK) -> void:
	if _is_wiping:
		return
	
	_is_wiping = true
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Setup rect
	_wipe_rect.color = color
	_wipe_rect.size = viewport_size * 1.5
	_wipe_rect.visible = true
	
	# Position based on direction
	var start_pos: Vector2
	var end_pos: Vector2
	
	match direction:
		WipeDirection.RIGHT:
			# Wipe comes from the right
			start_pos = Vector2(viewport_size.x, -viewport_size.y * 0.25)
			end_pos = Vector2(-viewport_size.x * 0.25, -viewport_size.y * 0.25)
		WipeDirection.LEFT:
			# Wipe comes from the left
			start_pos = Vector2(-viewport_size.x * 1.5, -viewport_size.y * 0.25)
			end_pos = Vector2(-viewport_size.x * 0.25, -viewport_size.y * 0.25)
		WipeDirection.DOWN:
			# Wipe comes from bottom
			start_pos = Vector2(-viewport_size.x * 0.25, viewport_size.y)
			end_pos = Vector2(-viewport_size.x * 0.25, -viewport_size.y * 0.25)
		WipeDirection.UP:
			# Wipe comes from top
			start_pos = Vector2(-viewport_size.x * 0.25, -viewport_size.y * 1.5)
			end_pos = Vector2(-viewport_size.x * 0.25, -viewport_size.y * 0.25)
	
	_wipe_rect.position = start_pos
	
	# WHOOSH! Fast snap in - accelerate hard
	var tween = create_tween()
	tween.tween_property(_wipe_rect, "position", end_pos, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
	
	await tween.finished
	
	# Stay visible (screen covered) until wipe_in is called
	_is_wiping = false
	wipe_completed.emit()

## Quick check if screen is currently covered by wipe
func is_screen_covered() -> bool:
	return _wipe_rect.visible and _wipe_rect.position.length() < 100

## Force hide the wipe (for edge cases)
func clear_wipe() -> void:
	_wipe_rect.visible = false
	_is_wiping = false

## Get opposite wipe direction (for seamless enter/exit)
static func get_opposite(dir: WipeDirection) -> WipeDirection:
	match dir:
		WipeDirection.LEFT: return WipeDirection.RIGHT
		WipeDirection.RIGHT: return WipeDirection.LEFT
		WipeDirection.UP: return WipeDirection.DOWN
		WipeDirection.DOWN: return WipeDirection.UP
	return WipeDirection.RIGHT
