extends Chest
class_name GoldChest
## Premium Chest - Requires key, better rewards
##
## Design Philosophy:
## - Gold chests are locked by default - creates anticipation
## - Higher coin reward to justify key investment
## - Visually distinct (gold sprites)
## - Can still use spawn_items for special loot


func _chest_ready() -> void:
	# Gold chests require keys by default
	requires_key = true
	
	# Higher default coin reward (can be overridden in inspector)
	if coin_reward == 5:  # Only override if using Chest's default
		coin_reward = 15
	
	# Call parent setup
	super._chest_ready()
