extends Node2D
## Bioluminescent Mushroom - Decorative light source for dark caves
## Pulses gently to create organic atmosphere

@export_group("Light Settings")
@export var base_energy: float = 0.8  ## Base light brightness
@export var pulse_amount: float = 0.3  ## How much energy varies
@export var pulse_speed: float = 1.5  ## Pulse frequency
@export var light_color: Color = Color(0.4, 0.9, 0.6, 1.0)  ## Cyan-green glow
@export var light_radius: float = 100.0

@export_group("Sprite Settings")
@export var sprite_glow: bool = true  ## Sprite also pulses
@export var glow_color: Color = Color(0.6, 1.0, 0.8, 1.0)

@export_group("Interaction")
@export var react_to_player: bool = false  ## Brighten when player nearby
@export var reaction_radius: float = 60.0
@export var reaction_boost: float = 0.5  ## Extra brightness when triggered

@export_group("Cluster Settings")
@export var is_cluster: bool = false  ## Multiple mushrooms with offset timing
@export var cluster_count: int = 3
@export var cluster_spread: float = 20.0

var time_offset: float = 0.0
var player_nearby: bool = false
var base_modulate: Color

@onready var light: PointLight2D = $PointLight2D if has_node("PointLight2D") else null
@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var detection_area: Area2D = $DetectionArea if has_node("DetectionArea") else null

func _ready() -> void:
	time_offset = randf() * TAU  # Random phase offset
	
	if sprite:
		base_modulate = sprite.modulate
	
	_setup_light()
	
	if react_to_player and detection_area:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
		_setup_detection_area()
	
	if is_cluster:
		_create_cluster()

func _process(delta: float) -> void:
	var time = Time.get_ticks_msec() / 1000.0
	var pulse = sin((time * pulse_speed) + time_offset) * 0.5 + 0.5  # 0 to 1
	
	var target_energy = base_energy + (pulse * pulse_amount)
	if player_nearby:
		target_energy += reaction_boost
	
	if light:
		light.energy = target_energy
	
	if sprite and sprite_glow:
		var glow_intensity = 0.5 + (pulse * 0.5)
		if player_nearby:
			glow_intensity += 0.2
		sprite.modulate = base_modulate.lerp(glow_color, glow_intensity * 0.3)

func _setup_light() -> void:
	if not light:
		return
	
	light.color = light_color
	light.energy = base_energy
	light.texture_scale = light_radius / 128.0  # Assuming 128px base texture
	
	# Create simple radial gradient texture if none exists
	if light.texture == null:
		var gradient = GradientTexture2D.new()
		gradient.fill = GradientTexture2D.FILL_RADIAL
		gradient.fill_from = Vector2(0.5, 0.5)
		gradient.fill_to = Vector2(0.5, 0.0)
		var grad = Gradient.new()
		grad.set_color(0, Color.WHITE)
		grad.set_color(1, Color.TRANSPARENT)
		gradient.gradient = grad
		gradient.width = 256
		gradient.height = 256
		light.texture = gradient

func _setup_detection_area() -> void:
	if not detection_area:
		return
	
	var circle = CircleShape2D.new()
	circle.radius = reaction_radius
	
	if detection_area.has_node("CollisionShape2D"):
		detection_area.get_node("CollisionShape2D").shape = circle

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_nearby = false

func _create_cluster() -> void:
	# Create additional smaller mushrooms around this one
	for i in range(cluster_count - 1):
		var child_mushroom = Node2D.new()
		child_mushroom.name = "ClusterMushroom_%d" % i
		
		# Random position in cluster
		var angle = randf() * TAU
		var distance = randf_range(cluster_spread * 0.5, cluster_spread)
		child_mushroom.position = Vector2(cos(angle), sin(angle)) * distance
		
		# Create child light
		var child_light = PointLight2D.new()
		child_light.color = light_color
		child_light.energy = base_energy * randf_range(0.5, 0.8)
		child_light.texture_scale = (light_radius * randf_range(0.4, 0.7)) / 128.0
		child_light.texture = light.texture if light else null
		
		child_mushroom.add_child(child_light)
		add_child(child_mushroom)
		
		# Animate with offset
		_animate_cluster_child(child_light, randf() * TAU)

func _animate_cluster_child(child_light: PointLight2D, offset: float) -> void:
	# Use tween for independent animation
	var tween = create_tween()
	tween.set_loops()
	var duration = 1.0 / pulse_speed
	tween.tween_method(
		func(t: float): child_light.energy = base_energy * 0.6 + sin(t + offset) * pulse_amount * 0.5,
		0.0, TAU, duration
	)

## Set mushroom color (for variety in caves)
func set_glow_color(new_color: Color) -> void:
	light_color = new_color
	glow_color = new_color.lightened(0.3)
	if light:
		light.color = new_color

## Turn light on/off (for puzzles)
func set_lit(lit: bool) -> void:
	if light:
		var tween = create_tween()
		tween.tween_property(light, "energy", base_energy if lit else 0.0, 0.3)
