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

## Swim disturbance tracking
var _bodies_in_water: Array = []  ## Track all bodies currently in water
var _swim_disturbance_timers: Dictionary = {}  ## Per-body timers for swim ripples

## Boat depression tracking
var _boats_in_water: Array = []  ## Track boats for weight depression
var _boat_depression_offsets: Array = []  ## Per-segment depression from boats (additive to rest_height)

## Ambient wave phase
var _ambient_wave_time: float = 0.0

## Splash particles
var _splash_droplets: Array[Node2D] = []

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
		_update_boat_depressions()
	
	# Update splash particles
	if emit_splash_particles:
		_update_splash_droplets(delta)
	
	update_physics(delta)
	update_visuals()
	_update_collision_shape()  # Update collision shape to match water level
	
func _initiate_water() -> void:
	segment_data.clear()
	segment_rest_height.clear()
	_boat_depression_offsets.clear()
	for i in range(segment_count):
		segment_data.append({
			"height": surface_pos_y,
			"velocity": 0.0,
			"wave_to_left": 0.0,
			"wave_to_right": 0.0
		})
		segment_rest_height.append(surface_pos_y)  # Default: all segments rest at surface
		_boat_depression_offsets.append(0.0)  # No boat depression initially
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


func update_physics(delta: float) -> void:
	# CRITICAL: Delta clamping must account for energy scaling!
	# At 60fps: delta=0.016, energy per frame = small
	# At 15fps: delta=0.066, if we clamp to 0.05, we get 3× energy injection!
	# 
	# The issue: water_physics_speed is multiplied TWICE (velocity then position)
	# So energy scales as: (safe_delta × speed)²
	# 
	# Solution: Add adaptive damping when delta is large (indicating lag/low FPS)
	
	var safe_delta = min(delta, 0.05)  # Cap at 20 FPS worst case
	
	# Lag compensation: if actual delta is larger than safe_delta, add extra damping
	var lag_damping_factor = 1.0
	if delta > 0.03:  # FPS below 33
		# Quadratic increase in damping as lag gets worse
		var lag_severity = (delta - 0.03) / 0.03  # 0.0 at 33fps, 1.0 at 16fps, 2.0+ at worse
		lag_damping_factor = 1.0 + (lag_severity * lag_severity * 0.5)  # Up to 1.5× damping at bad lag
	
	for i in range(segment_count):
		var displacement = segment_data[i]["height"] - segment_rest_height[i]
		
		# Critical damping for extreme displacements (runaway prevention)
		if abs(displacement) > 200.0:
			# Emergency stabilization: force back toward rest
			var emergency_correction = -sign(displacement) * abs(displacement) * 0.5
			segment_data[i]["height"] += emergency_correction * safe_delta
			segment_data[i]["velocity"] *= 0.5  # Heavy damping
			continue  # Skip normal physics for this segment
		
		var velocity = segment_data[i]["velocity"]
		
		# LINEAR DAMPING: Base resistance (responsive at low speeds)
		var linear_damping_force = wave_energy_loss * lag_damping_factor * velocity
		
		# QUADRATIC DAMPING: Fluid drag (F ∝ v²) - naturally stronger at high velocities
		# This prevents overshoot without threshold logic:
		#   vel=50  → quadratic adds ~375   (modest)
		#   vel=300 → quadratic adds ~13,500 (dominant)
		# Null safety: Use 0.15 default if parameter not set in scene instances
		var quad_coeff = quadratic_damping if quadratic_damping != null else 0.15
		var quadratic_damping_force = quad_coeff * velocity * abs(velocity)
		
		# TOTAL FORCE: Spring restoring + linear damping + quadratic damping
		# acceleration = -k×x - c₁×v - c₂×v×|v|
		var spring_force = -water_restoring_force * displacement
		var acceleration = spring_force - linear_damping_force - quadratic_damping_force
		
		# VERBOSE DEBUG for segment 37 (whirlpool center)
		if i == 37 and enable_debug_diagnostics and debug_timer <= 0 and not Engine.is_editor_hint():
			print("  [PHYSICS DEBUG] Seg 37 [Instance: %s]:" % get_instance_id())
			print("    disp=%.1f, vel=%.2f" % [displacement, velocity])
			print("    spring_force=%.1f, linear_damp=%.1f, quad_damp=%.1f" % [spring_force, linear_damping_force, quadratic_damping_force])
			print("    acceleration=%.1f" % acceleration)
		
		# Velocity integration (NO speed multiplier - causes exponential energy growth)
		segment_data[i]["velocity"] += acceleration * safe_delta
		
		# REST-ZONE DAMPING: Kill micro-oscillations (like static friction)
		# When segment is very close to rest with low velocity, aggressively damp to prevent shivering
		# This creates a "dead zone" where the system settles completely instead of oscillating forever
		if abs(displacement) < 1.0 and abs(segment_data[i]["velocity"]) < 12.0:
			segment_data[i]["velocity"] *= 0.7  # Strong damping (30% energy loss per frame)
		
		# Velocity clamp: prevent extreme runaway (but allow fast whirlpool response)
		var max_velocity = 200.0 + abs(displacement) * 2.0  # Much higher limit for whirlpool effects
		segment_data[i]["velocity"] = clamp(segment_data[i]["velocity"], -max_velocity, max_velocity)
		
		# Position integration (velocity already contains all forces)
		var old_height = segment_data[i]["height"]
		segment_data[i]["height"] += segment_data[i]["velocity"] * safe_delta
		
		# DEBUG: Log significant rest_height deviations (whirlpool effect)
		if abs(segment_rest_height[i] - surface_pos_y) > 5.0 and i % 4 == 0:  # Every 4th affected segment
			var height_change = segment_data[i]["height"] - old_height
			if enable_debug_diagnostics and debug_timer <= 0 and not Engine.is_editor_hint():
				print("  [WATER] Seg %d: disp=%.1f, rest=%.1f, accel=%.2f, vel=%.2f, Δheight=%.3f" % [
					i, displacement, segment_rest_height[i], acceleration, 
					segment_data[i]["velocity"], height_change
				])
	
	# Adaptive wave spread: reduce iterations during lag to prevent zigzag artifacts
	var actual_spread_updates = wave_spread_updates
	if delta > 0.025:  # FPS below 40
		actual_spread_updates = max(4, wave_spread_updates / 2)  # Half iterations during lag
	
	for updates in range(actual_spread_updates):
		for i in range(segment_count):
			# Skip segments in emergency mode
			var i_displacement = abs(segment_data[i]["height"] - segment_rest_height[i])
			if i_displacement > 200.0:
				continue
			
			# WAVE PROPAGATION CUTOFF: Don't propagate waves from segments at rest
			# This prevents perpetual oscillation at whirlpool centers
			# A resting segment (small displacement, low velocity) shouldn't disturb neighbors
			var i_velocity = abs(segment_data[i]["velocity"])
			if i_displacement < 0.5 and i_velocity < 1.0:
				continue  # Segment is settled, don't propagate waves
			
			if i > 0:
				var neighbor_displacement = abs(segment_data[i-1]["height"] - segment_rest_height[i-1])
				if neighbor_displacement > 200.0:
					continue  # Don't spread from unstable neighbors
				
				# FIXED: Allow wave propagation even across rest_height gradients (whirlpool V-depressions)
				# Old logic blocked propagation when rest_diff >= 5.0, causing energy accumulation
				# New logic: always propagate, but dampen waves proportional to rest_height gradient steepness
				var rest_diff = abs(segment_rest_height[i] - segment_rest_height[i-1])
				var height_diff = segment_data[i]["height"] - segment_data[i-1]["height"]
				
				# Gradient damping: steeper rest_height slopes reduce wave transmission (not block it entirely)
				var wave_multiplier = 1.0
				if abs(height_diff) > gradient_damping_threshold:
					wave_multiplier *= gradient_damping_factor
				
				# Additional damping for steep rest_height gradients (whirlpool V-walls)
				# Allows energy to flow but prevents reflection amplification
				if rest_diff > 10.0:
					wave_multiplier *= 0.1  # Heavily damp transmission across steep V-walls
				elif rest_diff > 5.0:
					wave_multiplier *= 0.3  # Moderate damping for gentle slopes
				
				segment_data[i]["wave_to_left"] = height_diff * wave_strength * wave_multiplier
				# CRITICAL FIX: Wave energy transfer should NOT multiply by water_physics_speed
				# That speed factor is already in main integration (applied to velocity → position)
				# Double application causes (80)² = 6400x energy amplification!
				segment_data[i-1]["velocity"] += segment_data[i]["wave_to_left"] * safe_delta
				
				# DEBUG: Log wave propagation for segments near whirlpool
				if i == 37 and enable_debug_diagnostics and debug_timer <= 0 and not Engine.is_editor_hint():
					print("  [WAVE DEBUG] Seg 37→36: rest_diff=%.1f, height_diff=%.1f, multiplier=%.3f, wave_force=%.2f" % [
						rest_diff, height_diff, wave_multiplier, segment_data[i]["wave_to_left"]
					])
			
			if i < segment_count - 1:
				var neighbor_displacement_right = abs(segment_data[i+1]["height"] - segment_rest_height[i+1])
				if neighbor_displacement_right > 200.0:
					continue
				
				# Same fix for right neighbor
				var rest_diff_right = abs(segment_rest_height[i] - segment_rest_height[i+1])
				var height_diff_right = segment_data[i]["height"] - segment_data[i+1]["height"]
				
				var wave_multiplier_right = 1.0
				if abs(height_diff_right) > gradient_damping_threshold:
					wave_multiplier_right *= gradient_damping_factor
				
				if rest_diff_right > 10.0:
					wave_multiplier_right *= 0.1
				elif rest_diff_right > 5.0:
					wave_multiplier_right *= 0.3
				
				segment_data[i]["wave_to_right"] = height_diff_right * wave_strength * wave_multiplier_right
				# CRITICAL FIX: Same as above - no water_physics_speed multiplication here
				segment_data[i+1]["velocity"] += segment_data[i]["wave_to_right"] * safe_delta
		
		# REMOVED: Direct height application (was causing double energy injection!)
		# Wave energy is now applied ONLY to velocity, which naturally updates position via integration
		# This prevents exponential energy growth that caused runaway behavior
	
	# REMOVED: Preemptive velocity clamping loop (was overriding main loop's velocity limits)
	# Velocity clamping now handled in main integration loop only (lines 243-245)
	
	# Edge segments: smoothly approach rest_height with ADDITIVE velocity correction
	# CRITICAL FIX: ADD to velocity instead of REPLACE (was causing runaway when whirlpool modifies rest_height)
	var edge_convergence_strength = 2.0  # Restoring force coefficient (LOWER = allows sharp V near edges)
	
	for edge_idx in [0, 1, segment_count - 2, segment_count - 1]:
		var displacement_from_rest = segment_rest_height[edge_idx] - segment_data[edge_idx]["height"]
		# Apply smooth correction via ADDITIVE velocity (like a spring force)
		var correction_force = displacement_from_rest * edge_convergence_strength * safe_delta
		segment_data[edge_idx]["velocity"] += correction_force
		# Clamp edge velocity to prevent violent snaps
		segment_data[edge_idx]["velocity"] = clamp(segment_data[edge_idx]["velocity"], -20.0, 20.0)
		# Position update happens in main integration loop (NO DOUBLE UPDATE!)

	
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
	segment_data[index]["velocity"] += splash_velocity  # Additive mixing for multiple sources
	recently_splashed = true
	set_process(true)
	
	# Spawn visual splash particles
	if emit_splash_particles and not Engine.is_editor_hint():
		var impact_strength = abs(splash_velocity)
		if impact_strength > 0.5:  # Only splash for meaningful impacts
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
		
		if body.is_in_group("player"):
			body.current_water = self
			emit_signal("player_entered_water", body)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("can_interact_with_water"):
		splash(body.global_position, body.velocity.y * player_splash_mutiplier)
		
		# Remove from tracking
		_bodies_in_water.erase(body)
		_swim_disturbance_timers.erase(body)
		_boats_in_water.erase(body)
		
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
	var max_disp_idx: int = -1
	var max_vel_idx: int = -1
	
	for i in range(segment_count):
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
	
	print("[WATER AUDIT] segments=%d | max_disp=%.1f (seg %d) | max_vel=%.1f (seg %d) | avg_energy=%.2f | runaways=%d" % 
		[segment_count, max_displacement, max_disp_idx, max_velocity, max_vel_idx, avg_energy, runaway_count])
	
	if runaway_count > 0:
		print("  ⚠️ WARNING: %d segments exhibiting runaway behavior!" % runaway_count)
	
	if max_displacement > 300.0:
		print("  🔥 CRITICAL: Water displacement exceeding 300px threshold!")
	
	# Detailed segment analysis for worst offenders
	if max_disp_idx >= 0 and max_displacement > 250.0:
		print("  📊 Segment %d: height=%.1f, rest=%.1f, disp=%.1f, vel=%.1f" % [
			max_disp_idx,
			segment_data[max_disp_idx]["height"],
			segment_rest_height[max_disp_idx],
			segment_data[max_disp_idx]["height"] - segment_rest_height[max_disp_idx],
			segment_data[max_disp_idx]["velocity"]
		])
		
		# Check neighbors for wave propagation analysis
		if max_disp_idx > 0:
			print("    Left neighbor (seg %d): disp=%.1f, vel=%.1f" % [
				max_disp_idx - 1,
				segment_data[max_disp_idx - 1]["height"] - segment_rest_height[max_disp_idx - 1],
				segment_data[max_disp_idx - 1]["velocity"]
			])
		
		if max_disp_idx < segment_count - 1:
			print("    Right neighbor (seg %d): disp=%.1f, vel=%.1f" % [
				max_disp_idx + 1,
				segment_data[max_disp_idx + 1]["height"] - segment_rest_height[max_disp_idx + 1],
				segment_data[max_disp_idx + 1]["velocity"]
			])

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

func _update_boat_depressions() -> void:
	## Calculate and apply boat weight depressions to water surface
	## This modifies segment heights temporarily (per-frame) without changing rest_height
	
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
			var current_depression = segment_data[i]["height"] - segment_rest_height[i]
			var target_depression = _boat_depression_offsets[i]
			
			# Gentle push toward target depression
			if current_depression < target_depression:
				segment_data[i]["velocity"] += (target_depression - current_depression) * 0.5

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
