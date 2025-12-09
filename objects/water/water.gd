@tool
extends Node2D
class_name water

@export var water_size: Vector2 = Vector2(8.0,16.0)
@export var surface_pos_y: float = 0.5
@export_range(2,512) var segment_count: int = 64

@export_group("Visuals")
@export var surface_line_thickness: float = 2.0  ## Thicker for visibility
@export var surface_color: Color = Color("3ce1da")
@export var water_fill_color: Color = Color(0.216, 0.690, 0.773, 0.6)  ## Semi-transparent blue (adjust alpha in editor)
@export var enable_antialiasing: bool = true  ## Smooth surface line

@export_group("Ambient Waves")
@export var ambient_wave_enabled: bool = true  ## Gentle constant wave motion
@export var ambient_wave_amplitude: float = 2.0  ## How high/low waves go (pixels) - more visible
@export var ambient_wave_speed: float = 1.5  ## Wave frequency - slightly faster
@export var ambient_wave_length: float = 0.25  ## Wavelength (0.1-1.0, lower = more waves)

@export_group("Physics Simulation")
@export_range(0.0,1000.0) var water_physics_speed: float = 80.0  ## DEPRECATED: Legacy parameter, no longer used
@export var water_restoring_force: float = 300.0  ## Spring constant pulling toward rest_height (higher = faster response)
@export var wave_energy_loss: float = 35.0  ## Linear damping coefficient (base resistance)
@export var quadratic_damping: float = 0.15  ## Quadratic damping (v²) - prevents overshoot at high velocities
@export var wave_strength: float = 6.0  ## Energy transfer between segments (LOWER = localized, HIGHER = wide spread)
@export_range(1,64) var wave_spread_updates:int = 8

@export_group("Advanced Physics")
@export var critical_damping_threshold: float = 10.0  ## Displacement threshold for critical damping
@export var critical_damping_strength: float = 1.0    ## Critical damping multiplier (1.0 = textbook critical damping)
@export var gradient_damping_threshold: float = 5.0   ## Height diff threshold for wave damping
@export var gradient_damping_factor: float = 0.5      ## Reduce wave propagation on steep gradients

@export_group("Interaction")
@export var player_splash_mutiplier: float = 0.35  ## Stronger splashes for visible impact
@export var swim_disturbance_enabled: bool = true  ## Create ripples while swimming
@export var swim_disturbance_interval: float = 0.12  ## Time between swim ripples (seconds)
@export var swim_disturbance_strength: float = 0.8  ## Ripple intensity (stronger for visibility)
@export var boat_depression_enabled: bool = true  ## Boats push water surface down
@export var boat_depression_depth: float = 4.0  ## How deep boats push water (pixels)
@export var boat_depression_width: float = 48.0  ## Width of depression zone (pixels)

@export_group("Splash Particles")
@export var emit_splash_particles: bool = true  ## Visual splash droplets on entry/exit
@export var splash_droplet_count: int = 8  ## Droplets per splash
@export var splash_droplet_speed: float = 150.0  ## Launch speed
@export var splash_droplet_lifetime: float = 0.8
@export var splash_droplet_gravity: float = 400.0
@export var splash_color: Color = Color(0.8, 0.95, 1.0, 0.9)  ## Light blue-white

@export_group("Glow Light (Optional)")
@export var emit_light: bool = false  ## Water glows (bioluminescent/magical for dark caves)
@export var light_color: Color = Color(0.3, 0.8, 1.0, 0.8)  ## Soft cyan glow
@export var light_energy: float = 0.6  ## Subtle illumination
@export var light_sample_points: int = 4  ## Distributed light sources (1-8)
@export var light_pulse_enabled: bool = true  ## Gentle pulsing
@export var light_pulse_speed: float = 1.5  ## Slower than lava (calm water)
@export var light_pulse_amount: float = 0.2  ## Subtle variation

@export_group("Debug")
@export var enable_debug_diagnostics: bool = false  ## Enable water stability monitoring (prints every second)

var segment_data: Array = []
var segment_rest_height: Array = []  ## Per-segment equilibrium height (allows external depression control)
var recently_splashed: bool = false

## Performance optimization: track settled segments to skip physics
var _settled_segments: PackedByteArray = []  ## 0 = needs update, 1 = at rest
var _settled_count: int = 0
var _last_active_min: int = 0
var _last_active_max: int = 0

## Water raising state tracking
var _water_raise_active: bool = false
var _water_raise_start_heights: Array = []
var _water_raise_target: float = 0.0
var _water_raise_duration: float = 0.0
var _water_raise_elapsed: float = 0.0

## Swim disturbance tracking
var _bodies_in_water: Array = []  ## Track all bodies currently in water
var _swim_disturbance_timers: Dictionary = {}  ## Per-body timers for swim ripples

## Boat depression tracking
var _boats_in_water: Array = []  ## Track boats for weight depression
var _boat_depression_offsets: Array = []  ## Per-segment depression from boats (additive to rest_height)
var _boats_moved: bool = false  ## Dirty flag to skip recalculation when boats are static
var _boat_last_positions: Dictionary = {}  ## Track boat positions to detect movement
var _boat_check_timer: float = 0.0  ## Timer for periodic boat movement check

## Ambient wave phase
var _ambient_wave_time: float = 0.0

## Splash particles
var _splash_droplets: Array[Node2D] = []

## Optional lighting
var _water_lights: Array[PointLight2D] = []  ## Multi-point distributed glow
var _light_pulse_time: float = 0.0

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
	_boat_depression_offsets.clear()
	_bodies_in_water.clear()
	_swim_disturbance_timers.clear()
	_boats_in_water.clear()
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
	
	# Ambient wave animation (always runs for visual life)
	if ambient_wave_enabled:
		_ambient_wave_time += delta
	
	# Swim disturbance: create periodic ripples for bodies in water
	if swim_disturbance_enabled:
		_update_swim_disturbances(delta)
	
	# Boat depression: update segment rest heights based on boat positions
	if boat_depression_enabled:
		_boat_check_timer += delta
		# Check boat movement every 0.1s instead of every frame
		if _boat_check_timer >= 0.1:
			_boat_check_timer = 0.0
			_check_boat_movement()
		_update_boat_depressions()
	
	# Update splash particles
	if emit_splash_particles:
		_update_splash_droplets(delta)
	
	# Update optional lighting (bioluminescent glow)
	if emit_light and _water_lights.size() > 0:
		_update_water_lights(delta)
	
	update_physics(delta)
	update_visuals()
	_update_collision_shape()  # Update collision shape to match water level
	
func _initiate_water() -> void:
	segment_data.clear()
	segment_rest_height.clear()
	_boat_depression_offsets.clear()
	_settled_segments.clear()
	for i in range(segment_count):
		segment_data.append({
			"height": surface_pos_y,
			"velocity": 0.0,
			"wave_to_left": 0.0,
			"wave_to_right": 0.0
		})
		segment_rest_height.append(surface_pos_y)  # Default: all segments rest at surface
		_boat_depression_offsets.append(0.0)  # No boat depression initially
		_settled_segments.append(1)  # Start at rest
	_settled_count = segment_count
	_last_active_min = 0
	_last_active_max = segment_count - 1
	var new_line: Line2D = Line2D.new()
	new_line.width = surface_line_thickness
	new_line.default_color = surface_color
	new_line.antialiased = enable_antialiasing  # Smooth edges
	new_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	new_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	new_line.joint_mode = Line2D.LINE_JOINT_ROUND
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
	
	# Optional lighting setup (bioluminescent/magical water)
	if emit_light and not Engine.is_editor_hint():
		_setup_water_lights()


func update_physics(delta: float) -> void:
	# CRITICAL: Validate delta to prevent catastrophic physics behavior
	# If delta is NaN, Inf, negative, or absurdly large, skip physics this frame
	if not is_finite(delta) or delta <= 0.0 or delta > 1.0:
		push_warning("Water physics: invalid delta %.3f, skipping frame" % delta)
		return
	
	var safe_delta = min(delta, 0.05)  # Cap at 20 FPS worst case
	
	# Lag compensation: if actual delta is larger than safe_delta, add extra damping
	var lag_damping_factor = 1.0
	if delta > 0.03:  # FPS below 33
		var lag_severity = (delta - 0.03) / 0.03
		lag_damping_factor = 1.0 + (lag_severity * lag_severity * 0.5)
	
	# OPTIMIZATION: Track active region to skip settled segments
	var active_min = segment_count
	var active_max = -1
	
	# CRITICAL FIX: Reset settled count each frame and recalculate from scratch
	# Prevents count drift from race conditions and wake-up bugs
	_settled_count = 0
	
	# Expand search window around last active region
	var search_min = max(0, _last_active_min - 2)
	var search_max = min(segment_count - 1, _last_active_max + 2)
	
	# Process segments (only check potentially active ones)
	for i in range(search_min, search_max + 1):
		# Skip if marked as settled
		if _settled_segments[i] == 1:
			_settled_count += 1  # Count during iteration, not during state changes
			continue
		
		var seg = segment_data[i]
		var rest = segment_rest_height[i]
		var displacement = seg["height"] - rest
		
		# Critical displacement: emergency stabilization
		if abs(displacement) > 200.0:
			var emergency_correction = -sign(displacement) * abs(displacement) * 0.5
			seg["height"] += emergency_correction * safe_delta
			seg["velocity"] *= 0.5
			active_min = min(active_min, i)
			active_max = max(active_max, i)
			continue
		
		var velocity = seg["velocity"]
		
		# OPTIMIZATION: Check if segment has settled (before expensive math)
		if abs(displacement) < 0.3 and abs(velocity) < 0.8:
			_settled_segments[i] = 1
			_settled_count += 1  # Safe to increment here since we recalculated at start
			seg["velocity"] = 0.0
			seg["height"] = rest  # Snap to rest
			continue
		
		# Mark as active
		active_min = min(active_min, i)
		active_max = max(active_max, i)
		
		# Physics integration (only for active segments)
		var linear_damping_force = wave_energy_loss * lag_damping_factor * velocity
		var quad_coeff = quadratic_damping if quadratic_damping != null else 0.15
		var quadratic_damping_force = quad_coeff * velocity * abs(velocity)
		var spring_force = -water_restoring_force * displacement
		var acceleration = spring_force - linear_damping_force - quadratic_damping_force
		
		# Velocity integration
		seg["velocity"] += acceleration * safe_delta
		
		# REST-ZONE DAMPING: Kill micro-oscillations near rest
		if abs(displacement) < 1.0 and abs(seg["velocity"]) < 12.0:
			seg["velocity"] *= 0.7
		
		# Velocity clamp
		var max_velocity = 200.0 + abs(displacement) * 2.0
		seg["velocity"] = clamp(seg["velocity"], -max_velocity, max_velocity)
		
		# Position integration
		seg["height"] += seg["velocity"] * safe_delta
	
	# Update active region tracking
	# CRITICAL FIX: If no segments were active this frame, preserve previous region
	# Don't reset to full range - that defeats the optimization
	if active_min < segment_count:
		# Had active segments - update range
		_last_active_min = active_min
		_last_active_max = active_max
	# else: All settled - keep previous active region for next frame's search window
	
	# OPTIMIZATION: Skip wave propagation if no active segments
	if active_min >= segment_count:
		return
	
	# Wave propagation (only in active region)
	var actual_spread_updates = wave_spread_updates
	if delta > 0.025:
		actual_spread_updates = max(4, wave_spread_updates / 2)
	
	for updates in range(actual_spread_updates):
		for i in range(max(1, active_min), min(segment_count - 1, active_max + 1)):
			var seg = segment_data[i]
			var rest = segment_rest_height[i]
			var i_displacement = abs(seg["height"] - rest)
			var i_velocity = abs(seg["velocity"])
			
			# Skip settled or emergency segments
			if i_displacement > 200.0 or (i_displacement < 0.5 and i_velocity < 1.0):
				continue
			
			# Left neighbor
			if i > 0:
				var left_seg = segment_data[i - 1]
				var left_rest = segment_rest_height[i - 1]
				var neighbor_displacement = abs(left_seg["height"] - left_rest)
				
				if neighbor_displacement <= 200.0:
					var rest_diff = abs(rest - left_rest)
					var height_diff = seg["height"] - left_seg["height"]
					
					var wave_multiplier = 1.0
					if abs(height_diff) > gradient_damping_threshold:
						wave_multiplier *= gradient_damping_factor
					if rest_diff > 10.0:
						wave_multiplier *= 0.1
					elif rest_diff > 5.0:
						wave_multiplier *= 0.3
					
					var wave_force = height_diff * wave_strength * wave_multiplier
					left_seg["velocity"] += wave_force * safe_delta
					
					# Wake up left neighbor if significant force applied
					if abs(wave_force) > 5.0 and _settled_segments[i - 1] == 1:
						_settled_segments[i - 1] = 0
						# NOTE: Don't decrement _settled_count here - it's recalculated at frame start
			
			# Right neighbor
			if i < segment_count - 1:
				var right_seg = segment_data[i + 1]
				var right_rest = segment_rest_height[i + 1]
				var neighbor_displacement_right = abs(right_seg["height"] - right_rest)
				
				if neighbor_displacement_right <= 200.0:
					var rest_diff_right = abs(rest - right_rest)
					var height_diff_right = seg["height"] - right_seg["height"]
					
					var wave_multiplier_right = 1.0
					if abs(height_diff_right) > gradient_damping_threshold:
						wave_multiplier_right *= gradient_damping_factor
					if rest_diff_right > 10.0:
						wave_multiplier_right *= 0.1
					elif rest_diff_right > 5.0:
						wave_multiplier_right *= 0.3
					
					var wave_force = height_diff_right * wave_strength * wave_multiplier_right
					right_seg["velocity"] += wave_force * safe_delta
					
					# Wake up right neighbor if significant force applied
					if abs(wave_force) > 5.0 and _settled_segments[i + 1] == 1:
						_settled_segments[i + 1] = 0
						# NOTE: Don't decrement _settled_count here - it's recalculated at frame start
	
	# Edge segments: smooth convergence
	var edge_convergence_strength = 2.0
	for edge_idx in [0, 1, segment_count - 2, segment_count - 1]:
		var seg = segment_data[edge_idx]
		var displacement_from_rest = segment_rest_height[edge_idx] - seg["height"]
		var correction_force = displacement_from_rest * edge_convergence_strength * safe_delta
		seg["velocity"] += correction_force
		seg["velocity"] = clamp(seg["velocity"], -20.0, 20.0)

	
	if !recently_splashed:
		var is_still: bool = true
		for i in range(segment_count):
			# Check if segment is at its rest position (not hardcoded surface)
			if abs(segment_data[i]["height"] - segment_rest_height[i]) > 0.01:
				is_still = false
				break
		# Keep processing if ambient waves are enabled (for visual animation)
		# Also keep processing if there are bodies in water (for swim disturbance)
		var should_stop = is_still and not ambient_wave_enabled and _bodies_in_water.is_empty()
		set_process(!should_stop)
	else:
		recently_splashed = false
	
	# Diagnostic logging (when enabled in editor)
	if enable_debug_diagnostics:
		debug_timer += delta
		if debug_timer >= debug_interval:
			debug_timer = 0.0
			_print_water_diagnostics()
	
	
func update_visuals() -> void:
	var points: Array[Vector2] = []
	var segment_width: float = water_size.x / (segment_count - 1)
	for i in range(segment_count):
		var base_height = segment_data[i]["height"]
		
		# Add ambient wave offset (purely visual, doesn't affect physics)
		var ambient_offset = 0.0
		if ambient_wave_enabled:
			var wave_phase = _ambient_wave_time * ambient_wave_speed + (float(i) / segment_count) * TAU / ambient_wave_length
			ambient_offset = sin(wave_phase) * ambient_wave_amplitude
		
		points.append(Vector2(i * segment_width, base_height + ambient_offset))
		
	#var left_static_point: Vector2 = Vector2(points[0].x,surface_pos_y)
	#var right_static_point: Vector2 = Vector2(points[points.size()-1].x,surface_pos_y)
	var left_static_point = points[0]  # real wave height at segment 0
	var right_static_point = points[points.size() - 1]
	
	var final_points: Array[Vector2] = []
	final_points.append(left_static_point)
	final_points += points
	final_points.append(right_static_point)
	
	surface_line.points = final_points
	
	# Fill polygon: water body from surface down to FIXED bottom
	# Bottom is always at water_size.y (relative to node origin), regardless of surface position
	var bottom_y: float = water_size.y
	final_points.append(Vector2(water_size.x, bottom_y))
	final_points.append(Vector2(0, bottom_y))
	fill_polygon.polygon = final_points

func splash(splash_pos:Vector2, splash_velocity:float) -> void:
	var local_x_pos: float = to_local(splash_pos).x
	var segment_width: float = water_size.x / (segment_count - 1)
	var index: int = int(clamp(local_x_pos / segment_width, 0 , segment_count - 1))
	segment_data[index]["velocity"] += splash_velocity
	
	# Wake up segment and neighbors
	_settled_segments[index] = 0
	if index > 0:
		_settled_segments[index - 1] = 0
	if index < segment_count - 1:
		_settled_segments[index + 1] = 0
	
	recently_splashed = true
	set_process(true)
	
	# Spawn visual splash particles
	if emit_splash_particles and not Engine.is_editor_hint():
		var impact_strength = abs(splash_velocity)
		if impact_strength > 0.5:
			_spawn_splash_particles(splash_pos, impact_strength)
	
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("can_interact_with_water"):
		splash(body.global_position, -body.velocity.y * player_splash_mutiplier)
		
		# Track body for swim disturbance
		if not _bodies_in_water.has(body):
			_bodies_in_water.append(body)
			_swim_disturbance_timers[body] = 0.0
		
		# Track boats separately for weight depression
		if body.is_in_group("platform") and not _boats_in_water.has(body):
			_boats_in_water.append(body)
			_boats_moved = true  # Mark for recalculation
		
		if body.is_in_group("player"):
			body.current_water = self
			emit_signal("player_entered_water", body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("can_interact_with_water"):
		splash(body.global_position, body.velocity.y * player_splash_mutiplier)
		
		# Remove from tracking
		_bodies_in_water.erase(body)
		_swim_disturbance_timers.erase(body)
		if _boats_in_water.has(body):
			_boats_in_water.erase(body)
			_boat_last_positions.erase(body)  # CRITICAL: Clean up position cache
			_boats_moved = true  # Mark for recalculation
		
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
	
	# Wake all segments during water raise
	_settled_segments.fill(0)
	_settled_count = 0
	
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
	
	# OPTIMIZATION: Only calculate metrics if diagnostics are actually enabled
	var max_displacement: float = 0.0
	var max_velocity: float = 0.0
	var total_energy: float = 0.0
	var runaway_count: int = 0
	var max_disp_idx: int = -1
	var max_vel_idx: int = -1
	
	# Only iterate active segments for diagnostics
	for i in range(max(0, _last_active_min - 5), min(segment_count, _last_active_max + 6)):
		var displacement = abs(segment_data[i]["height"] - segment_rest_height[i])
		var velocity = abs(segment_data[i]["velocity"])
		
		if displacement > max_displacement:
			max_displacement = displacement
			max_disp_idx = i
		
		if velocity > max_velocity:
			max_velocity = velocity
			max_vel_idx = i
		
		total_energy += displacement + velocity
		
		if displacement > 200.0 or velocity > 50.0:
			runaway_count += 1
	
	var avg_energy = total_energy / segment_count
	
	# CRITICAL: Validate settled count is sane
	if _settled_count < 0 or _settled_count > segment_count:
		push_error("Water physics: corrupted settled count %d/%d - resetting" % [_settled_count, segment_count])
		# Emergency recovery: recalculate from scratch
		_settled_count = 0
		for i in range(segment_count):
			if _settled_segments[i] == 1:
				_settled_count += 1
	
	print("[WATER AUDIT] settled=%d/%d | max_disp=%.1f (seg %d) | max_vel=%.1f (seg %d) | avg_energy=%.2f | runaways=%d" % 
		[_settled_count, segment_count, max_displacement, max_disp_idx, max_velocity, max_vel_idx, avg_energy, runaway_count])
	
	if runaway_count > 0:
		print("  ⚠️ WARNING: %d segments exhibiting runaway behavior!" % runaway_count)

## ============================================================================
## SWIM DISTURBANCE SYSTEM
## Creates periodic ripples when bodies are swimming in water
## ============================================================================

func _update_swim_disturbances(delta: float) -> void:
	## Create periodic small splashes for bodies actively in water
	var bodies_to_remove: Array = []
	
	for body in _bodies_in_water:
		if not is_instance_valid(body):
			bodies_to_remove.append(body)
			continue
		
		# Update timer for this body
		if not _swim_disturbance_timers.has(body):
			_swim_disturbance_timers[body] = 0.0
		
		_swim_disturbance_timers[body] += delta
		
		# Check if it's time for a ripple
		if _swim_disturbance_timers[body] >= swim_disturbance_interval:
			_swim_disturbance_timers[body] = 0.0
			
			# Only create ripples if body is moving (swimming, not floating still)
			var vel = Vector2.ZERO
			if "velocity" in body:
				vel = body.velocity
			
			var speed = vel.length()
			if speed > 10.0:  # Moving threshold
				# Scale ripple by movement speed (more movement = bigger ripple)
				var ripple_strength = clamp(speed / 200.0, 0.3, 1.0) * swim_disturbance_strength
				
				# Alternate up/down for natural wave pattern
				var direction = 1.0 if randf() > 0.5 else -1.0
				splash(body.global_position, direction * ripple_strength)
	
	# Clean up invalid bodies
	for body in bodies_to_remove:
		_bodies_in_water.erase(body)
		_swim_disturbance_timers.erase(body)

## ============================================================================
## BOAT WEIGHT DEPRESSION SYSTEM
## Boats push the water surface down where they float
## Uses temporary offsets, doesn't interfere with whirlpool's rest_height system
## ============================================================================

func _check_boat_movement() -> void:
	## Periodically check if boats have moved (dirty flag optimization)
	for boat in _boats_in_water:
		if not is_instance_valid(boat):
			continue
		
		var current_pos = boat.global_position
		var last_pos = _boat_last_positions.get(boat, Vector2.INF)
		
		# If boat moved more than 1 pixel, mark dirty (sensitive to slow drift)
		if current_pos.distance_squared_to(last_pos) > 1.0:
			_boats_moved = true
			_boat_last_positions[boat] = current_pos

func _update_boat_depressions() -> void:
	## Calculate and apply boat weight depressions to water surface
	## OPTIMIZATION: Only recalculate when boats move or enter/exit
	
	# Skip if no boats or boats haven't moved
	if _boats_in_water.is_empty():
		# Clear any existing depressions
		if not _boat_depression_offsets.is_empty():
			for i in range(_boat_depression_offsets.size()):
				_boat_depression_offsets[i] = 0.0
		return
	
	# Only recalculate when boats moved (dirty flag)
	if not _boats_moved:
		return
	
	_boats_moved = false
	
	# First, reset all boat depression offsets
	for i in range(_boat_depression_offsets.size()):
		_boat_depression_offsets[i] = 0.0
	
	# Ensure array size matches segment count
	while _boat_depression_offsets.size() < segment_count:
		_boat_depression_offsets.append(0.0)
	
	var segment_width: float = water_size.x / (segment_count - 1)
	var boats_to_remove: Array = []
	
	for boat in _boats_in_water:
		if not is_instance_valid(boat):
			boats_to_remove.append(boat)
			continue
		
		# Get boat position in local water coordinates
		var local_x = to_local(boat.global_position).x
		
		# Skip if boat is outside water bounds
		if local_x < 0 or local_x > water_size.x:
			continue
		
		# Find center segment under boat
		var center_index = int(clamp(local_x / segment_width, 0, segment_count - 1))
		
		# Calculate affected segment range based on boat depression width
		var half_width_segments = int((boat_depression_width / 2.0) / segment_width) + 1
		
		# Apply V-shaped depression under boat
		for offset in range(-half_width_segments, half_width_segments + 1):
			var seg_idx = center_index + offset
			if seg_idx < 2 or seg_idx >= segment_count - 2:  # Avoid edge segments
				continue
			
			# Distance from center (0 to 1)
			var distance_ratio = abs(float(offset)) / float(half_width_segments)
			
			# Smooth falloff (inverse parabolic)
			var falloff = 1.0 - (distance_ratio * distance_ratio)
			falloff = max(0.0, falloff)
			
			# Add depression offset (positive = push down in Godot's Y-down coordinate)
			_boat_depression_offsets[seg_idx] += boat_depression_depth * falloff
	
	# Clean up invalid boats
	for boat in boats_to_remove:
		_boats_in_water.erase(boat)
	
	# Apply boat depressions to segment heights (temporary, each frame)
	# This adds to the physics height, so waves still propagate naturally
	for i in range(segment_count):
		if _boat_depression_offsets[i] > 0.0:
			# Push segment down by depression amount
			# Use velocity injection instead of direct height change for smoother physics
			var seg = segment_data[i]
			var current_depression = seg["height"] - segment_rest_height[i]
			var target_depression = _boat_depression_offsets[i]
			
			# Gentle push toward target depression
			if current_depression < target_depression:
				seg["velocity"] += (target_depression - current_depression) * 0.5
				# Wake up segment
				_settled_segments[i] = 0

## ============================================================================
## SPLASH PARTICLE SYSTEM
## Visual water droplets that fly up when something enters/exits water
## ============================================================================

func _spawn_splash_particles(splash_global_pos: Vector2, impact_strength: float) -> void:
	## Create splash droplets at the splash position
	var local_pos = to_local(splash_global_pos)
	
	# Scale droplet count by impact strength
	var droplet_count = int(splash_droplet_count * clamp(impact_strength / 3.0, 0.5, 1.5))
	
	for i in range(droplet_count):
		var droplet = Node2D.new()
		droplet.name = "Droplet"
		
		# Start at surface
		droplet.position = Vector2(local_pos.x + randf_range(-8, 8), surface_pos_y)
		
		# Random upward velocity with spread
		var angle = randf_range(-PI * 0.7, -PI * 0.3)  # Upward arc (between -126 and -54 degrees)
		var speed = splash_droplet_speed * randf_range(0.6, 1.2) * clamp(impact_strength / 2.0, 0.5, 1.5)
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		
		droplet.set_meta("velocity", velocity)
		droplet.set_meta("age", 0.0)
		
		# Create droplet visual - small elongated shape
		var visual = Polygon2D.new()
		visual.name = "Visual"
		var size = randf_range(1.5, 3.0)
		visual.polygon = PackedVector2Array([
			Vector2(0, -size * 1.5),
			Vector2(size * 0.5, 0),
			Vector2(0, size * 0.5),
			Vector2(-size * 0.5, 0)
		])
		
		# Water color with slight variation
		var color_var = randf_range(-0.05, 0.05)
		visual.color = Color(
			splash_color.r + color_var,
			splash_color.g + color_var,
			splash_color.b,
			splash_color.a
		)
		
		droplet.add_child(visual)
		add_child(droplet)
		_splash_droplets.append(droplet)

func _update_splash_droplets(delta: float) -> void:
	## Update all splash droplets - physics and cleanup
	var to_remove: Array[Node2D] = []
	
	for droplet in _splash_droplets:
		if not is_instance_valid(droplet):
			to_remove.append(droplet)
			continue
		
		var age = droplet.get_meta("age", 0.0) + delta
		droplet.set_meta("age", age)
		
		if age >= splash_droplet_lifetime:
			to_remove.append(droplet)
			continue
		
		# Apply physics
		var velocity = droplet.get_meta("velocity", Vector2.ZERO) as Vector2
		velocity.y += splash_droplet_gravity * delta  # Gravity
		droplet.set_meta("velocity", velocity)
		
		droplet.position += velocity * delta
		
		# Rotate to face movement direction
		if velocity.length() > 10.0:
			droplet.rotation = velocity.angle() + PI / 2.0
		
		# Fade out
		var life_ratio = age / splash_droplet_lifetime
		var visual = droplet.get_node_or_null("Visual") as Polygon2D
		if visual:
			visual.modulate.a = 1.0 - life_ratio
		
		# Remove if fallen back into water
		if droplet.position.y > surface_pos_y + 10.0:
			to_remove.append(droplet)
	
	# Cleanup
	for droplet in to_remove:
		_splash_droplets.erase(droplet)
		if is_instance_valid(droplet):
			droplet.queue_free()

## ============================================================================
## WATER LIGHTING SYSTEM (OPTIONAL - BIOLUMINESCENT/MAGICAL GLOW)
## Multi-point lighting learned from lava, distributed across surface
## Disabled by default for backward compatibility with existing levels
## ============================================================================

func _setup_water_lights() -> void:
	## Create distributed lights along water surface (1-8 configurable)
	## Each light tracks local segment heights for realistic wave illumination
	
	# Validate light count (1-8 for performance)
	var clamped_points = clampi(light_sample_points, 1, 8)
	if clamped_points != light_sample_points:
		push_warning("Water: light_sample_points clamped from %d to %d (valid range 1-8)" % [light_sample_points, clamped_points])
		light_sample_points = clamped_points
	
	# Share texture reference to save memory (all lights use same texture)
	var shared_texture: Texture2D = null
	
	# Create lights distributed evenly across surface width
	for i in range(light_sample_points):
		var light := PointLight2D.new()
		light.enabled = true
		light.energy = light_energy
		light.color = light_color
		light.blend_mode = Light2D.BLEND_MODE_ADD
		light.range_z_min = -100
		light.range_z_max = 100
		light.shadow_enabled = false  # Water doesn't cast shadows
		
		# First light creates texture, others share it
		if i == 0:
			light.texture = _create_water_light_gradient()
			shared_texture = light.texture
		else:
			light.texture = shared_texture
		
		# Position along surface width
		var x_ratio = float(i) / float(max(1, light_sample_points - 1))
		light.position.x = x_ratio * water_size.x
		light.position.y = surface_pos_y  # Start at surface
		
		add_child(light)
		_water_lights.append(light)
	
	print("🌊 Water lighting initialized: %d distributed points, color=%s, energy=%.2f" % 
		[light_sample_points, light_color, light_energy])

func _create_water_light_gradient() -> GradientTexture2D:
	## Creates soft radial gradient for water glow (shared by all lights)
	var gradient := Gradient.new()
	
	# Center bright, fade to transparent edges
	gradient.set_color(0, light_color)
	gradient.set_color(1, Color(light_color.r, light_color.g, light_color.b, 0.0))
	
	var gradient_tex := GradientTexture2D.new()
	gradient_tex.gradient = gradient
	gradient_tex.width = 256
	gradient_tex.height = 256
	gradient_tex.fill_from = Vector2(0.5, 0.5)  # Center
	gradient_tex.fill_to = Vector2(0.0, 0.5)   # Radial outward
	gradient_tex.fill = GradientTexture2D.FILL_RADIAL
	
	return gradient_tex

func _update_water_lights(delta: float) -> void:
	## Update light positions to track surface waves + optional pulsing
	
	# Update pulse animation if enabled
	if light_pulse_enabled:
		_light_pulse_time += delta * light_pulse_speed
		var pulse_factor = 1.0 + sin(_light_pulse_time) * light_pulse_amount
		
		# Apply pulse to all lights
		for light in _water_lights:
			if is_instance_valid(light):
				light.energy = light_energy * pulse_factor
	
	# Track each light to local segment heights (realistic wave illumination)
	var segment_width: float = water_size.x / (segment_count - 1)
	
	for i in range(_water_lights.size()):
		if not is_instance_valid(_water_lights[i]):
			continue
		
		var light := _water_lights[i]
		
		# Find segment indices around this light's X position
		var center_segment_float := (light.position.x / segment_width)
		var seg_left := int(floor(center_segment_float))
		var seg_right := int(ceil(center_segment_float))
		
		# Clamp to valid range
		seg_left = clampi(seg_left, 0, segment_count - 1)
		seg_right = clampi(seg_right, 0, segment_count - 1)
		
		# Interpolate between neighboring segment heights
		var t := center_segment_float - float(seg_left)
		var left_height: float = segment_data[seg_left]["height"] if seg_left < segment_data.size() else surface_pos_y
		var right_height: float = segment_data[seg_right]["height"] if seg_right < segment_data.size() else surface_pos_y
		
		# Apply boat depressions to light tracking
		if seg_left < _boat_depression_offsets.size():
			left_height += _boat_depression_offsets[seg_left]
		if seg_right < _boat_depression_offsets.size():
			right_height += _boat_depression_offsets[seg_right]
		
		var tracked_height: float = lerp(left_height, right_height, t)
		
		# Smooth light movement (avoids jitter)
		light.position.y = lerp(light.position.y, tracked_height, 0.3)
