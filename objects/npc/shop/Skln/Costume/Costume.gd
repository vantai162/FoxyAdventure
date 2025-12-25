class_name Costume
extends skin
var NormalAni:AnimatedSprite2D=null
var BladeAni:AnimatedSprite2D=null

func _ready() -> void:
	if $AnimatedSprite2D!=null:
		NormalAni=$AnimatedSprite2D
	if $BladeAnimatedSprite2D!=null:
		BladeAni=$BladeAnimatedSprite2D
	
func get_normal_Ani()->AnimatedSprite2D:
	return $AnimatedSprite2D
	
func get_blade_Ani()->AnimatedSprite2D:
	return $BladeAnimatedSprite2D
	
func get_sprite_set_for_preview()->Array[Texture2D]:
	var spriteframe:SpriteFrames=$AnimatedSprite2D.sprite_frames
	var textureAnim:Array[Texture2D]=[]
	if !spriteframe.has_animation("idle"):
		print("NotFoundIdleAnimForPreview")
		return []
	for i in spriteframe.get_frame_count("idle"):
		textureAnim.append(spriteframe.get_frame_texture("idle",i))
	return textureAnim
	
