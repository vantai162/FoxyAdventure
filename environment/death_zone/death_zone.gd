extends Area2D

func _on_body_entered(body: Node2D) -> void:
	# Kiểm tra xem vật rớt xuống có phải là Player không
	# (Dựa vào tên class hoặc Group "Player" mà bạn đã gán)
	if body is BaseCharacter: # Hoặc if body.name == "Player"
		print("Rơi vực rồi!")
		
		# Gọi hàm die() của nhân vật
		if body.has_method("die"):
			body.die()
			
	# Mẹo: Nếu quái vật rơi xuống đây thì cũng nên xóa nó đi cho nhẹ máy
	elif body is EnemyCharacter:
		body.queue_free()
