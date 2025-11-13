extends EnemyState


func _enter() -> void:
	obj.change_animation("sleep")
	

func _update(delta):
	obj.velocity.x = 0
	
	
	
