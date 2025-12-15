extends StatItem
## Flame Blade Upgrade — Shop Item
## Unlocks fire effect on the fox's blade, causing enemies to burn.
## This is a permanent upgrade that persists across saves.

## Called when purchase is successful
func conduct_effect() -> void:
	var player = GameManager.player
	if not player:
		printerr("Flame Blade: Player not found!")
		return
	
	# Already unlocked? Don't waste player's coins (shop should prevent this)
	if player.has_unlocked_flame_blade:
		print("Flame Blade: Already unlocked!")
		return
	
	# Unlock the flame blade
	player.has_unlocked_flame_blade = true
	
	# Celebration feedback — this is a BIG upgrade
	AudioManager.play_sound("power_up", 15.0)
	
	# Visual feedback: screen flash (if available)
	if has_node("/root/TransitionEffects"):
		var effects = get_node("/root/TransitionEffects")
		if effects.has_method("flash"):
			effects.flash(Color(1.0, 0.6, 0.2, 0.3), 0.3)  # Orange flash

## Check if this item can be purchased (for shop validation)
func can_purchase() -> bool:
	var player = GameManager.player
	if not player:
		return false
	# Can't buy if already unlocked
	return not player.has_unlocked_flame_blade