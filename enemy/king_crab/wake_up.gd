extends EnemyState

func _enter() -> void:
	obj.change_animation("wake_up")
	obj.velocity.x = 0
	var anim_sprite = obj.get_node("Direction/AnimatedSprite2D")
	if anim_sprite and not anim_sprite.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		anim_sprite.connect("animation_finished", Callable(self, "_on_animation_finished"))
		
		
func _exit() -> void:
	var anim_sprite = obj.get_node("Direction/AnimatedSprite2D")
	if anim_sprite and anim_sprite.is_connected("animation_finished", Callable(self, "_on_animation_finished")):
		anim_sprite.disconnect("animation_finished", Callable(self, "_on_animation_finished"))

func _on_animation_finished() -> void:
	# AnimatedSprite2D không truyền tên animation, nên chỉ cần check animation hiện tại
	var anim_sprite = obj.get_node("Direction/AnimatedSprite2D")
	if anim_sprite and anim_sprite.animation == "wake_up":
		AudioManager.play_sound("king_crab_roar",20.0)
		
		var player = GameManager.player
		var cam = player.get_node("Camera2D")
		
		# Rung liên tục trong 4.8 giây
		var duration = 4.8
		var interval = 0.2
		var elapsed = 0.0

		while elapsed < duration:
			# GUARD: Check we're still in this state (boss might die during intro)
			if fsm.current_state != self or not is_instance_valid(obj):
				return
			if cam and cam.has_method("shake_tsunami"):
				cam.shake_tsunami(20.0, 0.2)  # rung ngắn mỗi lần
			await get_tree().create_timer(interval).timeout
			elapsed += interval
		
		# GUARD: Final check before state transition
		if fsm.current_state != self or not is_instance_valid(obj):
			return
		player.input_locked = false
		AudioManager.play_music("theme_1",15.0,0)
		change_state(fsm.states.idle)
		print("finished")
