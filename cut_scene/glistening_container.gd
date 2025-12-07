extends Node2D

@export var glisten_count = 30
@export var area_size = Vector2(1024, 600)
@export var water_level_y = 400  # Only spawn below this

var glisten_data = []

func _ready():
	randomize() 

	var templates = get_children()

	for i in glisten_count:
		var template = templates[randi() % templates.size()]
		var glisten = template.duplicate()
		glisten.position = Vector2(
			randf_range(0, area_size.x),
			randf_range(water_level_y, area_size.y)
		)
		glisten.scale = Vector2.ONE * randf_range(0.8, 1.2)
		glisten.modulate.a = randf_range(0.5, 1.0)

		# Random animation and frame
		glisten.animation = glisten.sprite_frames.get_animation_names()[randi() % glisten.sprite_frames.get_animation_names().size()]
		glisten.frame = randi() % glisten.sprite_frames.get_frame_count(glisten.animation)
		glisten.play()

		add_child(glisten)
		glisten_data.append(glisten)
	# Optionally hide the original templates
	for template in templates:
		template.visible = false
