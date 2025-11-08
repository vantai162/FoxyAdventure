extends Area2D
class_name BaseProjectile

# --- Stats ---
var damage: int = 1
var speed: float = 200.0
var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# Connect the body_entered signal to our collision handler
	self.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Check if the body is the player (in group "player")
	if body.is_in_group("player"):
		# The direction is derived from the velocity or direction property
		var damage_direction = sign(direction.x)
		if body.has_method("take_damage"):
			body.take_damage(damage_direction, damage)
		queue_free()
	# Check if the body is the ground (in group "ground")
	elif body.is_in_group("ground"):
		queue_free()
