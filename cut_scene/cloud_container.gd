extends Node2D

@export var cloud_count = 36
@export var area_size = Vector2(1024, 600)
@export var speed_range = Vector2(-36, 36)
@export var water_level_y = 400  # Only spawn above this

var cloud_data = []

func _ready():
	randomize()

	var templates = get_children()

	for i in cloud_count:
		var template = templates[randi() % templates.size()]
		var cloud = template.duplicate()
		cloud.position = Vector2(
			randf_range(0, area_size.x),
			randf_range(0, water_level_y)
		)
		cloud.scale = Vector2.ONE * randf_range(0.8, 1.2)
		cloud.modulate.a = randf_range(0.5, 1.0)
		add_child(cloud)

		var speed = randf_range(speed_range.x, speed_range.y)
		cloud_data.append({ "node": cloud, "speed": speed })
	# Optionally hide the original templates
	for template in templates:
		template.visible = false

func _process(delta):
	for data in cloud_data:
		var cloud = data["node"]
		var speed = data["speed"]

		cloud.position.x += speed * delta

		if cloud.position.x > area_size.x + 100:
			cloud.position.x = -100
