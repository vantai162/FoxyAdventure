@tool
extends CanvasLayer
class_name CaveAtmosphere

## Subtle Cave Atmosphere System
##
## Creates organic, atmospheric darkness for cave levels:
## - Soft vignette darkening toward screen edges
## - Gradual fog that doesn't block visibility
## - Works WITH existing PointLight2D lights (doesn't block them)
## - Player can see the whole camera area, just with mood lighting
##
## This is ATMOSPHERE, not fog-of-war. Lights shine through walls.

@export_group("Atmosphere")
@export var enabled: bool = true
@export var darkness_color: Color = Color(0.0, 0.0, 0.05, 1.0)  ## Base fog tint
@export var center_opacity: float = 0.0  ## Darkness at screen center (0 = clear)
@export var edge_opacity: float = 0.6  ## Darkness at screen edges (0.6 = noticeable)
@export var vignette_size: float = 0.4  ## How much of screen is clear (0.4 = 40% clear center)

@export_group("Player Glow")
@export var player_glow_enabled: bool = true
@export var player_glow_radius: float = 150.0  ## Extra clear area around player
@export var player_glow_softness: float = 100.0  ## Gradient falloff

@export_group("Depth Effect")  
@export var depth_fog_enabled: bool = false  ## Fog gets thicker lower in level
@export var depth_fog_start: float = 500.0  ## Y position where fog starts thickening
@export var depth_fog_max: float = 0.3  ## Max additional opacity from depth

# Internals
var _player: CharacterBody2D
var _vignette_rect: ColorRect
var _vignette_material: ShaderMaterial
var _screen_size: Vector2

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	layer = 90  # Below lights (PointLight2D renders on higher layers)
	
	if enabled:
		call_deferred("_initialize")

func _initialize() -> void:
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_screen_size = get_viewport().get_visible_rect().size
	
	_create_vignette()
	print("CaveAtmosphere: Initialized with vignette effect")

func _create_vignette() -> void:
	# Create a full-screen ColorRect with vignette shader
	_vignette_rect = ColorRect.new()
	_vignette_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create shader material for smooth vignette
	var shader = Shader.new()
	shader.code = _get_vignette_shader_code()
	
	_vignette_material = ShaderMaterial.new()
	_vignette_material.shader = shader
	_vignette_material.set_shader_parameter("darkness_color", darkness_color)
	_vignette_material.set_shader_parameter("center_opacity", center_opacity)
	_vignette_material.set_shader_parameter("edge_opacity", edge_opacity)
	_vignette_material.set_shader_parameter("vignette_size", vignette_size)
	_vignette_material.set_shader_parameter("player_screen_pos", Vector2(0.5, 0.5))
	_vignette_material.set_shader_parameter("player_glow_radius", player_glow_radius / _screen_size.x)
	_vignette_material.set_shader_parameter("player_glow_softness", player_glow_softness / _screen_size.x)
	_vignette_material.set_shader_parameter("player_glow_enabled", player_glow_enabled)
	
	_vignette_rect.material = _vignette_material
	add_child(_vignette_rect)

func _get_vignette_shader_code() -> String:
	return """
shader_type canvas_item;

uniform vec4 darkness_color : source_color = vec4(0.0, 0.0, 0.05, 1.0);
uniform float center_opacity : hint_range(0.0, 1.0) = 0.0;
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.6;
uniform float vignette_size : hint_range(0.0, 1.0) = 0.4;
uniform vec2 player_screen_pos = vec2(0.5, 0.5);
uniform float player_glow_radius : hint_range(0.0, 1.0) = 0.15;
uniform float player_glow_softness : hint_range(0.0, 0.5) = 0.1;
uniform bool player_glow_enabled = true;

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	
	// Distance from screen center (for vignette)
	float dist_from_center = distance(uv, center);
	
	// Smooth vignette falloff
	float vignette = smoothstep(vignette_size, 1.0, dist_from_center * 2.0);
	
	// Base opacity from vignette
	float opacity = mix(center_opacity, edge_opacity, vignette);
	
	// Player glow - reduces darkness near player
	if (player_glow_enabled) {
		float dist_from_player = distance(uv, player_screen_pos);
		float player_light = 1.0 - smoothstep(player_glow_radius - player_glow_softness, player_glow_radius, dist_from_player);
		opacity *= (1.0 - player_light * 0.7);  // Reduce opacity near player
	}
	
	// Apply darkness with calculated opacity
	COLOR = vec4(darkness_color.rgb, opacity * darkness_color.a);
}
"""

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	
	if not _vignette_material:
		return
	
	# Update player position for glow effect
	if player_glow_enabled and _player and is_instance_valid(_player):
		var camera = get_viewport().get_camera_2d()
		if camera:
			var camera_center = camera.get_screen_center_position()
			var zoom = camera.zoom
			var half_screen = _screen_size / 2.0
			
			# Convert player world pos to screen UV (0-1)
			var screen_pos = (_player.global_position - camera_center) * zoom + half_screen
			var uv_pos = screen_pos / _screen_size
			
			_vignette_material.set_shader_parameter("player_screen_pos", uv_pos)
	
	# Update depth fog if enabled
	if depth_fog_enabled and _player and is_instance_valid(_player):
		var depth_factor = clamp((_player.global_position.y - depth_fog_start) / 500.0, 0.0, 1.0)
		var extra_opacity = depth_factor * depth_fog_max
		_vignette_material.set_shader_parameter("edge_opacity", edge_opacity + extra_opacity)

## Call this to update settings at runtime
func set_atmosphere(new_edge_opacity: float, new_center_opacity: float = 0.0) -> void:
	edge_opacity = new_edge_opacity
	center_opacity = new_center_opacity
	if _vignette_material:
		_vignette_material.set_shader_parameter("edge_opacity", edge_opacity)
		_vignette_material.set_shader_parameter("center_opacity", center_opacity)

## Temporarily intensify darkness (for dramatic moments)
func pulse_darkness(intensity: float = 0.8, duration: float = 0.5) -> void:
	if not _vignette_material:
		return
	var original_edge = edge_opacity
	var tween = create_tween()
	tween.tween_method(func(val): _vignette_material.set_shader_parameter("edge_opacity", val), edge_opacity, intensity, duration * 0.3)
	tween.tween_method(func(val): _vignette_material.set_shader_parameter("edge_opacity", val), intensity, original_edge, duration * 0.7)
