@tool
extends Node2D
class_name water

@export var water_size: Vector2 = Vector2(8.0,16.0)
@export var surface_pos_y: float = 0.5
@export_range(2,512) var segment_count: int = 64

@export_group("Visuals")
@export var surface_line_thickness: float = 1.0
@export var surface_color: Color = Color("3ce1da")
@export var water_fill_color: Color = Color(0.216, 0.690, 0.773, 0.6)  ## Semi-transparent blue (adjust alpha in editor)

@export_group("Physics Simulation")
@export_range(0.0,1000.0) var water_physics_speed: float = 80.0
@export var water_restoring_force: float = 0.02
@export var wave_energy_loss: float = 0.04
@export var wave_strength: float = 0.25
@export_range(1,64) var wave_spread_updates:int = 8

@export_group("Advanced Physics")
@export var critical_damping_threshold: float = 10.0  ## Displacement threshold for critical damping
@export var critical_damping_strength: float = 0.3    ## Extra damping for large displacements
@export var gradient_damping_threshold: float = 5.0   ## Height diff threshold for wave damping
@export var gradient_damping_factor: float = 0.5      ## Reduce wave propagation on steep gradients

@export_group("Interaction")
@export var player_splash_mutiplier: float = 0.12

@export_group("Debug")
@export var enable_debug_diagnostics: bool = false  ## Enable water stability monitoring (prints every second)

var segment_data: Array = []
var segment_rest_height: Array = []  ## Per-segment equilibrium height (allows external depression control)
var recently_splashed: bool = false

## Water raising state tracking
var _water_raise_active: bool = false
var _water_raise_start_heights: Array = []
var _water_raise_target: float = 0.0
var _water_raise_duration: float = 0.0
var _water_raise_elapsed: float = 0.0

var surface_line: Line2D
var fill_polygon: Polygon2D
var water_area: Area2D  ## Reference to dynamically created Area2D
var water_collision_shape: CollisionShape2D  ## Reference to collision shape for dynamic updates

signal player_entered_water(body)
signal player_exited_water(body)

## Debug monitoring
var debug_timer: float = 0.0
var debug_interval: float = 1.0

@export_tool_button("Update Water") var update_water_button: Callable = func():
	_ready()
	update_visuals()

func _ready() -> void:
	for i in get_children():
		i.queue_free()
	segment_data.clear()
	segment_rest_height.clear()
	_initiate_water()
	if not Engine.is_editor_hint():
		set_process(true)


func _process(delta:float)->void:
	if enable_debug_diagnostics:
		debug_timer += delta
		if debug_timer >= debug_interval:
			_print_water_diagnostics()
			debug_timer = 0.0
	
	# Update water raising animation
	if _water_raise_active:
		_update_water_raise(delta)
	
	update_physics(delta)
	update_visuals()
	_update_collision_shape()  # Update collision shape to match water level
	
func _initiate_water() -> void:
	segment_data.clear()
	segment_rest_height.clear()
	for i in range(segment_count):
		segment_data.append({
			"height": surface_pos_y,
			"velocity": 0.0,
			"wave_to_left": 0.0,
			"wave_to_right": 0.0
		})
		segment_rest_height.append(surface_pos_y)  # Default: all segments rest at surface
	var new_line: Line2D = Line2D.new()
	new_line.width = surface_line_thickness
	new_line.default_color = surface_color
	add_child(new_line)
	surface_line = new_line
	
	var new_polygon: Polygon2D = Polygon2D.new()
	new_polygon.color = water_fill_color
	# Don't use show_behind_parent - we want water to overlay the player
	surface_line.add_child(new_polygon)
	fill_polygon = new_polygon
	
	var new_area: Area2D = Area2D.new()
	new_area.monitoring = true     # <--- QUAN TRỌNG
	new_area.monitorable = true    # <--- QUAN TRỌNG
	new_area.collision_layer = 1   # layer nước
	new_area.collision_mask = 2    # mask bắt player (layer 2)
	new_area.body_entered.connect(_on_body_entered)
	new_area.body_exited.connect(_on_body_exited)
	
	new_area.visible = false
	add_child(new_area)
	water_area = new_area  # Store reference
	
	var new_collisionshape : CollisionShape2D = CollisionShape2D.new()
	var new_shape: RectangleShape2D = RectangleShape2D.new()
	new_shape.size = water_size
	new_collisionshape.shape = new_shape
	new_collisionshape.position = water_size / 2.0 + Vector2(0, surface_pos_y / 2.0)
	new_area.add_child(new_collisionshape)
	water_collision_shape = new_collisionshape  # Store reference


func update_physics(delta: float) -> void:
	# Safety: Clamp delta to prevent physics explosion on lag spikes
	var safe_delta = min(delta, 0.05)  # Cap at 20 FPS worst case
	
	for i in range(segment_count):
		var displacement = segment_data[i]["height"] - segment_rest_height[i]
		
		# Critical damping for extreme displacements (runaway prevention)
		if abs(displacement) > 200.0:
			# Emergency stabilization: force back toward rest
			var emergency_correction = -sign(displacement) * abs(displacement) * 0.5
			segment_data[i]["height"] += emergency_correction * safe_delta
			segment_data[i]["velocity"] *= 0.5  # Heavy damping
			continue  # Skip normal physics for this segment
		
		var damping = wave_energy_loss
		if abs(displacement) > 10.0:
			var excess = abs(displacement) - 10.0
			damping += excess * 0.04
		
		var acceleration = -water_restoring_force * displacement - segment_data[i]["velocity"] * damping
		
		segment_data[i]["velocity"] += acceleration * safe_delta * water_physics_speed
		
		var max_velocity = 5.0 + abs(displacement) * 0.2
		segment_data[i]["velocity"] = clamp(segment_data[i]["velocity"], -max_velocity, max_velocity)
		
		segment_data[i]["height"] += segment_data[i]["velocity"] * safe_delta * water_physics_speed
		
	for updates in range(wave_spread_updates):
		for i in range(segment_count):
			# Skip segments in emergency mode
			var i_displacement = abs(segment_data[i]["height"] - segment_rest_height[i])
			if i_displacement > 200.0:
				continue
			
			if i > 0:
				var neighbor_displacement = abs(segment_data[i-1]["height"] - segment_rest_height[i-1])
				if neighbor_displacement > 200.0:
					continue  # Don't spread from unstable neighbors
				
				var rest_diff = abs(segment_rest_height[i] - segment_rest_height[i-1])
				if rest_diff < 5.0:
					var height_diff = segment_data[i]["height"] - segment_data[i-1]["height"]
					var wave_multiplier = 1.0
					if abs(height_diff) > gradient_damping_threshold:
						wave_multiplier = gradient_damping_factor
					segment_data[i]["wave_to_left"] = height_diff * wave_strength * wave_multiplier
					segment_data[i-1]["velocity"] += segment_data[i]["wave_to_left"] * safe_delta * water_physics_speed
				else:
					segment_data[i]["wave_to_left"] = 0.0
			if i < segment_count - 1:
				var neighbor_displacement_right = abs(segment_data[i+1]["height"] - segment_rest_height[i+1])
				if neighbor_displacement_right > 200.0:
					continue
				
				var rest_diff_right = abs(segment_rest_height[i] - segment_rest_height[i+1])
				if rest_diff_right < 5.0:
					var height_diff_right = segment_data[i]["height"] - segment_data[i+1]["height"]
					var wave_multiplier_right = 1.0
					if abs(height_diff_right) > gradient_damping_threshold:
						wave_multiplier_right = gradient_damping_factor
					segment_data[i]["wave_to_right"] = height_diff_right * wave_strength * wave_multiplier_right
					segment_data[i+1]["velocity"] += segment_data[i]["wave_to_right"] * safe_delta * water_physics_speed
				else:
					segment_data[i]["wave_to_right"] = 0.0
		for i in range(segment_count):	
			if i > 0:
				segment_data[i-1]["height"] += segment_data[i]["wave_to_left"] * safe_delta * water_physics_speed
			if i < segment_count - 1:
				segment_data[i+1]["height"] += segment_data[i]["wave_to_right"] * safe_delta * water_physics_speed
		
	# Lock edges to their rest heights (not hardcoded surface)
	segment_data[0]["height"] = segment_rest_height[0]
	segment_data[1]["height"] = segment_rest_height[1]
	segment_data[0]["velocity"] = 0.0
	segment_data[1]["velocity"] = 0.0
	
	segment_data[segment_count - 1]["height"] = segment_rest_height[segment_count - 1]
	segment_data[segment_count - 2]["height"] = segment_rest_height[segment_count - 2]
	segment_data[segment_count - 1]["velocity"] = 0.0
	segment_data[segment_count - 2]["velocity"] = 0.0
	
	if !recently_splashed:
		var is_still: bool = true
		for i in range(segment_count):
			# Check if segment is at its rest position (not hardcoded surface)
			if abs(segment_data[i]["height"] - segment_rest_height[i]) > 0.01:
				is_still = false
				break
		set_process(!is_still)
	else:
		recently_splashed = false
	
	
func update_visuals() -> void:
	var points: Array[Vector2] = []
	var segment_width: float = water_size.x / (segment_count - 1)
	for i in range(segment_count):
		points.append(Vector2(i * segment_width, segment_data[i]["height"]))
		
	#var left_static_point: Vector2 = Vector2(points[0].x,surface_pos_y)
	#var right_static_point: Vector2 = Vector2(points[points.size()-1].x,surface_pos_y)
	var left_static_point = points[0]  # real wave height at segment 0
	var right_static_point = points[points.size() - 1]
	
	var final_points: Array[Vector2] = []
	final_points.append(left_static_point)
	final_points += points
	final_points.append(right_static_point)
	
	surface_line.points = final_points
	
	var bottom_y: float = surface_pos_y + water_size.y
	final_points.append(Vector2(water_size.x,bottom_y))
	final_points.append(Vector2(0,bottom_y))
	fill_polygon.polygon = final_points

func splash(splash_pos:Vector2, splash_velocity:float) -> void:
	var local_x_pos: float = to_local(splash_pos).x
	var segment_width: float = water_size.x / (segment_count - 1)
	var index: int = int(clamp(local_x_pos / segment_width, 0 , segment_count - 1))
	segment_data[index]["velocity"] += splash_velocity  # Additive mixing for multiple sources
	recently_splashed = true
	set_process(true)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("can_interact_with_water"):
		splash(body.global_position, -body.velocity.y * player_splash_mutiplier)
		if body.is_in_group("player"):
			body.current_water = self
			emit_signal("player_entered_water", body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("can_interact_with_water"):
		splash(body.global_position, body.velocity.y * player_splash_mutiplier)
		if body.is_in_group("player"):
			body.current_water = null
			emit_signal("player_exited_water", body)

func get_water_surface_global_y() -> float:
	return global_position.y + surface_pos_y

func get_water_height_at_global_x(global_x: float) -> float:
	## Get the exact water surface Y position at a specific global X coordinate
	## Takes waves, splashes, and whirlpool depressions into account (now physical, not virtual)
	var local_x = to_local(Vector2(global_x, 0)).x
	var segment_width = water_size.x / (segment_count - 1)
	var index = int(clamp(local_x / segment_width, 0, segment_count - 1))
	
	# Return actual physical height (includes whirlpool depressions via rest_height modifications)
	return global_position.y + segment_data[index]["height"]

func _update_collision_shape() -> void:
	## Dynamically update collision shape SIZE and POSITION to match water level
	## The water should expand from bottom up, not move as a whole
	if not water_collision_shape or not water_collision_shape.shape:
		return
	
	var shape = water_collision_shape.shape as RectangleShape2D
	if not shape:
		return
	
	# Calculate new size: from bottom (water_size.y) to current surface (surface_pos_y)
	# surface_pos_y is offset from origin, negative = higher up
	var new_height = water_size.y - surface_pos_y  # Total height from surface to bottom
	var old_size = shape.size
	shape.size = Vector2(water_size.x, new_height)
	
	var center_y = surface_pos_y + new_height / 2.0
	water_collision_shape.position = Vector2(water_size.x / 2.0, center_y)

## Water level control for boss fights and scripted events
func raise_water(target_height: float, duration: float = 2.0) -> void:
	## Smoothly raise water surface to target height
	## @param target_height: New surface_pos_y value (negative = higher, positive = lower)
	## @param duration: Time in seconds for transition
	if segment_rest_height.size() != segment_count:
		_initiate_water()
	print("🌊 Water raise_water() called: target=%.2f, duration=%.1f" % [target_height, duration])
	
	# Store initial rest heights for smooth interpolation
	_water_raise_start_heights.clear()
	for i in range(segment_count):
		var h
		if i < segment_rest_height.size(): 
			h = segment_rest_height[i] 
		else: 
			h = surface_pos_y
		_water_raise_start_heights.append(h)
	
	_water_raise_target = target_height
	_water_raise_duration = duration
	_water_raise_elapsed = 0.0
	_water_raise_active = true
	
	# Tween surface_pos_y for visual reference
	var tween = create_tween()
	tween.tween_property(self, "surface_pos_y", target_height, duration)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Ensure water physics keep updating during transition
	set_process(true)
	recently_splashed = true
	
	print("Initial rest heights range: %.2f to %.2f" % [_water_raise_start_heights.min(), _water_raise_start_heights.max()])

func _update_water_raise(delta: float) -> void:
	_water_raise_elapsed += delta
	var progress = clamp(_water_raise_elapsed / _water_raise_duration, 0.0, 1.0)
	
	# Cubic easing to match the tween (smoothstep)
	var eased_progress = progress * progress * (3.0 - 2.0 * progress)
	
	# Smoothly interpolate all segment rest heights
	for i in range(segment_count):
		segment_rest_height[i] = lerp(_water_raise_start_heights[i], _water_raise_target, eased_progress)
	
	if progress >= 1.0:
		_water_raise_active = false
		print("🌊 Water raise complete! Final rest heights at: %.2f" % _water_raise_target)

func lower_water(target_height: float, duration: float = 2.0) -> void:
	## Smoothly lower water surface to target height
	## @param target_height: New surface_pos_y value (negative = higher, positive = lower)
	## @param duration: Time in seconds for transition
	raise_water(target_height, duration)  # Same implementation

func set_water_level_instant(target_height: float) -> void:
	## Instantly set water level without animation
	## Useful for initial setup in boss arenas
	surface_pos_y = target_height
	
	# Reset all segments to new height
	for segment in segment_data:
		segment["height"] = surface_pos_y
		segment["velocity"] = 0.0
	
	update_visuals()

func _print_water_diagnostics() -> void:
	if Engine.is_editor_hint():
		return
	
	var max_displacement: float = 0.0
	var max_velocity: float = 0.0
	var total_energy: float = 0.0
	var runaway_count: int = 0
	
	for i in range(segment_count):
		var displacement = abs(segment_data[i]["height"] - segment_rest_height[i])
		var velocity = abs(segment_data[i]["velocity"])
		
		max_displacement = max(max_displacement, displacement)
		max_velocity = max(max_velocity, velocity)
		total_energy += displacement + velocity
		
		if displacement > 200.0 or velocity > 50.0:
			runaway_count += 1
	
	var avg_energy = total_energy / segment_count
	
	print("[WATER AUDIT] segments=%d | max_disp=%.1f | max_vel=%.1f | avg_energy=%.2f | runaways=%d" % 
		[segment_count, max_displacement, max_velocity, avg_energy, runaway_count])
	
	if runaway_count > 0:
		print("  ⚠️ WARNING: %d segments exhibiting runaway behavior!" % runaway_count)
	if max_displacement > 300.0:
		print("  🔥 CRITICAL: Water displacement exceeding 300px threshold!")
