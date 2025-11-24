extends Sprite2D

## Temporary placeholder - generates a spiral gradient circle
## Replace with actual whirlpool sprite asset when ready

func _ready() -> void:
	_generate_placeholder_texture()
	rotation_degrees = 0

func _process(delta: float) -> void:
	# Rotate continuously for visual feedback
	rotation += delta * 2.0

func _generate_placeholder_texture() -> void:
	var size = 128
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2.0, size / 2.0)
	var max_radius = size / 2.0
	
	for y in range(size):
		for x in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			var angle = pos.angle_to_point(center)
			
			if dist < max_radius:
				var normalized_dist = dist / max_radius
				var alpha = 1.0 - normalized_dist
				
				# Spiral effect
				var spiral = sin(angle * 3.0 + normalized_dist * 10.0) * 0.3 + 0.7
				
				# Blue water color
				var color = Color(0.2, 0.5 + spiral * 0.3, 0.9, alpha * 0.7)
				image.set_pixel(x, y, color)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	
	var tex = ImageTexture.create_from_image(image)
	texture = tex
