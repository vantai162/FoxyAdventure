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
	_float_offset += delta * float_speed
	
	# Floating animation
	position.y = _start_y + sin(_float_offset) * float_amplitude
	
	# Spinning blade
	if blade_sprite:
		blade_sprite.rotation_degrees += spin_speed * delta
	
	# Pulsing glow
	if item_glow:
		item_glow.energy = 0.6 + sin(_float_offset * 1.5) * 0.3
	
	# Pulsing container ring
	if container_ring and ring_pulse:
		var pulse = 0.9 + sin(_float_offset * 2.0) * 0.15
		container_ring.scale = Vector2(pulse, pulse)
		container_ring.modulate.a = 0.4 + sin(_float_offset * 1.8) * 0.2

func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent is Player:
		# Collection effect
		var tween = create_tween().set_parallel(true)
		if blade_sprite:
			tween.tween_property(blade_sprite, "rotation_degrees", blade_sprite.rotation_degrees + 720, 0.3)
			tween.tween_property(blade_sprite, "scale", Vector2.ZERO, 0.3)
		if container_ring:
			tween.tween_property(container_ring, "scale", Vector2(2.0, 2.0), 0.3)
			tween.tween_property(container_ring, "modulate:a", 0.0, 0.3)
		if item_glow:
			tween.tween_property(item_glow, "energy", 2.5, 0.15)
		
		parent.increase_blade_capacity()
		
		await tween.finished
		queue_free()
