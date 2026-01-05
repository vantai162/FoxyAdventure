extends StatItem

@export var icon:CompressedTexture2D
@export var description: String = "Tăng máu tối đa của Foxy thêm 1."
# conduct_effect sẽ được gọi khi mua thành công
func conduct_effect() -> void:

	var gm = GameManager
	if not gm.player:
		return
	# Tăng max health
	var prev_max = gm.player.max_health if gm.player.has_method("get_max_health") == false and gm.player.has_meta("max_health") == false else 0
	# Prefer direct properties; try best-effort:
	if "max_health" in gm.player:
		gm.player.max_health += 1
		print(gm.player.max_health)
	else:
		# nếu player dùng getter/setter
		if gm.player.has_method("set_max_health") and gm.player.has_method("get_max_health"):
			var cur = gm.player.get_max_health()
			gm.player.set_max_health(cur + 1)
			print(gm.player.max_health,"hey")
	gm.player.max_health_changed.emit()

	# Heal current health up to new max (tùy ý)
	if "health" in gm.player:
		gm.player.health = max(gm.player.health, gm.player.max_health)
	elif gm.player.has_method("set_health") and gm.player.has_method("get_health"):
		var cur_h = gm.player.get_health()
		gm.player.set_health(max(cur_h, gm.player.get_max_health()))
	gm.player.health_changed.emit()
	AudioManager.play_sound("heal",20.0)
	gm.save_checkpoint_data()
	# Optional: ghi log
	print("HPUp applied: +", 1, " to player.max_health -> ", gm.player.max_health)
