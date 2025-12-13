extends StatItem
@export var icon:CompressedTexture2D

# conduct_effect sẽ được gọi khi mua thành công
func conduct_effect() -> void:
	var gm = GameManager
	if not gm.player:
		return
	
	gm.player.has_unlocked_flame_blade = true
