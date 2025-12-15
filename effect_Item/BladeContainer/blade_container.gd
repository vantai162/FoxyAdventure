extends Area2D
class_name BladeContainer
## Blade capacity upgrade pickup
## Features: floating, spinning blade, pulsing glow, container ring effect

@export_group("Visual")
@export var float_amplitude: float = 4.0
@export var float_speed: float = 2.0
@export var spin_speed: float = 90.0  ## Blade rotation speed
@export var ring_pulse: bool = true  ## Pulsing container ring

@onready var blade_sprite: Sprite2D = $BladeSprite if has_node("BladeSprite") else null
@onready var container_ring: Sprite2D = $ContainerRing if has_node("ContainerRing") else null
@onready var item_glow: PointLight2D = $ItemGlow if has_node("ItemGlow") else null

var _float_offset: float = 0.0
var _start_y: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_start_y = position.y
	_float_offset = randf() * TAU

func _process(delta: float) -> void:
	## Container is 32×32 px. Ring should be a subtle accent, not a breathing blob.
	_float_offset += delta * float_speed
	
	# Floating animation
	position.y = _start_y + sin(_float_offset) * float_amplitude
	
	# Spinning blade
	if blade_sprite:
		blade_sprite.rotation_degrees += spin_speed * delta
	
	# Pulsing glow - subtle, not dramatic
	if item_glow:
		item_glow.energy = 0.3 + sin(_float_offset * 1.5) * 0.1  # Was 0.6 ± 0.3, now 0.3 ± 0.1
	
	# Pulsing container ring - very subtle scale, not "breathing" blob
	if container_ring and ring_pulse:
		var pulse = 0.95 + sin(_float_offset * 2.0) * 0.05  # Was 0.9 ± 0.15, now 0.95 ± 0.05
		container_ring.scale = Vector2(pulse, pulse)
		container_ring.modulate.a = 0.3 + sin(_float_offset * 1.8) * 0.1  # Was 0.4 ± 0.2, now 0.3 ± 0.1

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Player:
		# Collection effect - satisfying but not blinding
		var tween = create_tween().set_parallel(true)
		if blade_sprite:
			tween.tween_property(blade_sprite, "rotation_degrees", blade_sprite.rotation_degrees + 720, 0.3)
			tween.tween_property(blade_sprite, "scale", Vector2.ZERO, 0.3)
		if container_ring:
			tween.tween_property(container_ring, "scale", Vector2(1.5, 1.5), 0.3)  # Was 2.0 - too expansive
			tween.tween_property(container_ring, "modulate:a", 0.0, 0.3)
		if item_glow:
			tween.tween_property(item_glow, "energy", 0.8, 0.15)  # Was 2.5 - flashbang
		
		# Audio feedback — this is an upgrade, should sound special
		AudioManager.play_sound("power_up", 12.0)
		
		parent.increase_blade_capacity()
		
		await tween.finished
		queue_free()
