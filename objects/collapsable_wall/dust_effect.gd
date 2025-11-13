# Script này gắn vào node Node2D tên là DustEffect
extends Node2D

# Lấy node con AnimatedSprite2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# 1. Bật animation (tên là "play" mà bạn đã đặt)
	animated_sprite.play("smoke")
	
	# 2. Kết nối tín hiệu "animation_finished" (khi chạy xong)
	# với hàm _on_animation_finished bên dưới
	animated_sprite.animation_finished.connect(_on_animation_finished)

# Hàm này sẽ được gọi TỰ ĐỘNG khi animation "play" chạy xong
func _on_animation_finished() -> void:
	# Xóa scene DustEffect này đi
	queue_free()
