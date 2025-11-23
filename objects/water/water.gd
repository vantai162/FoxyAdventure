@tool
extends Node2D
class_name water

@export var water_size: Vector2 = Vector2(8.0,16.0)
@export var surface_pos_y: float = 0.5
@export_range(2,512) var segment_count: int = 64

@export var player_splash_mutiplier: float = 0.12
@export_range(0.0,1000.0) var water_physics_speed: float = 80.0
@export var water_restoring_force: float = 0.02
@export var wave_energy_loss: float = 0.04
@export var wave_strength: float = 0.25
@export_range(1,64) var wave_spread_updates:int = 8
@export var surface_line_thickness: float = 1.0
@export var surface_color: Color = Color("3ce1da")
@export var water_fill_color: Color = Color(0.216, 0.690, 0.773, 0.6)  ## Semi-transparent blue (adjust alpha in editor)

var segment_data: Array = []
var recently_splashed: bool = false

var surface_line: Line2D
var fill_polygon: Polygon2D
var water_area: Area2D  ## Reference to dynamically created Area2D
var water_collision_shape: CollisionShape2D  ## Reference to collision shape for dynamic updates

signal player_entered_water(body)
signal player_exited_water(body)

@export_tool_button("Update Water") var update_water_button: Callable = func():
	_ready()
	update_visuals()

func _ready() -> void:
	add_to_group("water")
	for i in get_children():
		i.queue_free()
	_initiate_water()


func _process(delta:float)->void:
	update_physics(delta)
	update_visuals()
	_update_collision_shape()  # Update collision shape to match water level
	
func _initiate_water() -> void:
	segment_data.clear()
	for i in range(segment_count):
		segment_data.append({
			"height": surface_pos_y,
			"velocity": 0.0,
			"wave_to_left": 0.0,
			"wave_to_right": 0.0
		})
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
	for i in range(segment_count):
		var displacement = segment_data[i]["height"] - surface_pos_y
		var acceleration = -water_restoring_force * displacement - segment_data[i]["velocity"] * wave_energy_loss
		
		segment_data[i]["velocity"] += acceleration * delta * water_physics_speed
		segment_data[i]["height"] += segment_data[i]["velocity"] * delta * water_physics_speed
		
	for updates in range(wave_spread_updates):
		for i in range(segment_count):
			if i > 0:
				segment_data[i]["wave_to_left"] = (segment_data[i]["height"] - segment_data[i-1]["height"]) * wave_strength
				segment_data[i-1]["velocity"] += segment_data[i]["wave_to_left"] * delta * water_physics_speed
			if i < segment_count - 1:
				segment_data[i]["wave_to_right"] = (segment_data[i]["height"] - segment_data[i+1]["height"]) * wave_strength
				segment_data[i+1]["velocity"] += segment_data[i]["wave_to_right"] * delta * water_physics_speed
		for i in range(segment_count):	
			if i > 0:
				segment_data[i-1]["height"] += segment_data[i]["wave_to_left"] * delta * water_physics_speed
			if i < segment_count - 1:
				segment_data[i+1]["height"] += segment_data[i]["wave_to_right"] * delta * water_physics_speed
		
	segment_data[0]["height"] = surface_pos_y
	segment_data[1]["height"] = surface_pos_y
	segment_data[0]["velocity"] = 0.0
	segment_data[1]["velocity"] = 0.0
	
	segment_data[segment_count - 1]["height"] = surface_pos_y
	segment_data[segment_count - 2]["height"] = surface_pos_y
	segment_data[segment_count - 1]["velocity"] = 0.0
	segment_data[segment_count - 2]["velocity"] = 0.0
	
	if !recently_splashed:
		var is_still: bool = true
		for i in surface_line.points:
			if abs(abs(i.y) - abs(surface_pos_y)) > 0.001:
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
		
	var left_static_point: Vector2 = Vector2(points[0].x,surface_pos_y)
	var right_static_point: Vector2 = Vector2(points[points.size()-1].x,surface_pos_y)
	
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
	segment_data[index]["velocity"] = splash_velocity
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
	
	# Position: center the shape between surface and bottom
	# Bottom is at water_size.y, surface is at surface_pos_y
	var center_y = surface_pos_y + new_height / 2.0
	var old_pos = water_collision_shape.position
	water_collision_shape.position = Vector2(water_size.x / 2.0, center_y)
	
	# Debug: Log significant changes
	if abs(old_size.y - new_height) > 1.0:
		print("[Water] Collision updated: size ", old_size.y, "→", new_height, 
			  " pos.y ", old_pos.y, "→", center_y, " (surface_pos_y=", surface_pos_y, ")")

## Water level control for boss fights and scripted events
func raise_water(target_height: float, duration: float = 2.0) -> void:
	## Smoothly raise water surface to target height
	## @param target_height: New surface_pos_y value (negative = higher, positive = lower)
	## @param duration: Time in seconds for transition
	var tween = create_tween()
	tween.tween_property(self, "surface_pos_y", target_height, duration)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	
	# Ensure water physics keep updating during transition
	set_process(true)
	recently_splashed = true

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
