extends Area2D

@export var instruction_text: String = "Nhấn [Phím cách] để nhảy!"

@onready var text_panel: Panel = $Panel  # Lấy node Panel
@onready var label: Label = $Panel/Label # Lấy Label con của Panel

var active_tween: Tween # Biến để lưu tween đang chạy

func _ready():
	label.text = instruction_text
	
	# Ẩn panel đi khi bắt đầu (và làm nó trong suốt)
	text_panel.visible = false
	text_panel.modulate.a = 0.0


func _on_body_entered(body):
	if body.is_in_group("player"):
		# Hủy tween cũ (nếu có)
		if active_tween:
			active_tween.kill()
		
		# Tạo tween mới để fade-in
		active_tween = create_tween()
		text_panel.visible = true # Hiện panel
		# Cho nó mờ dần từ 0.0 -> 1.0 trong 0.3 giây
		active_tween.tween_property(text_panel, "modulate:a", 1.0, 0.3)


func _on_body_exited(body):
	if body.is_in_group("player"):
		# Hủy tween cũ (nếu có)
		if active_tween:
			active_tween.kill()

		# Tạo tween mới để fade-out
		active_tween = create_tween()
		# Mờ dần từ 1.0 -> 0.0 trong 0.3 giây
		active_tween.tween_property(text_panel, "modulate:a", 0.0, 0.3)
		
		# Sau khi mờ xong, thì mới ẩn đi (ĐÃ SỬA)
		active_tween.tween_callback(text_panel.set.bind("visible", false))
