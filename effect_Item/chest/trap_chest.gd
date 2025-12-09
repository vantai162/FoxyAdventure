extends Chest
class_name TrapChest
## Trickster Chest - Looks normal, triggers trap effect when opened
##
## Design Philosophy (Valorant-style telegraphing):
## - Subtle visual "off" hint for observant players
## - Opens like normal chest (builds false security)
## - Trap triggers AFTER open animation (not instant)
## - Non-lethal effects: stun, confuse, slow - mischievous, not murderous
## - Clear visual/audio feedback when trap springs
##
## Pairs with TrapCoin in the Trickster set

@export_group("Trap Effect")
@export_enum("Stun", "Slow") var trap_effect: String = "Stun"  ## Effect to apply (matches Foxy's Effect dict)
@export var effect_duration: float = 1.5  ## How long trap effect lasts
@export var trap_delay: float = 0.3  ## Delay after opening before trap springs

@export_group("Disguise")
@export var subtle_evil_hint: bool = true  ## Slight color shift to warn observant players
@export var evil_tint: Color = Color(0.92, 1.0, 0.88, 1.0)  ## Slightly greenish/sickly

@export_group("Trap Feedback")
@export var trap_sound: AudioStream
@export var shake_screen: bool = true
@export var screen_shake_intensity: float = 4.0
@export var screen_shake_duration: float = 0.3


func _chest_ready() -> void:
	# Trap chests don't require keys - easy bait!
	requires_key = false
	
	# No coin reward - it's a trap!
	coin_reward = 0
	
	# Apply subtle evil tint
	if subtle_evil_hint:
		call_deferred("_apply_evil_tint")
	
	super._chest_ready()


func _apply_evil_tint() -> void:
	if animated_sprite:
		animated_sprite.modulate = evil_tint


## Override reward giving - instead of rewards, spring the trap!
func _give_rewards() -> void:
	# Small delay for dramatic effect - player thinks they got loot
	await get_tree().create_timer(trap_delay).timeout
	
	# SPRING THE TRAP!
	_spring_trap()


func _spring_trap() -> void:
	# Visual feedback - flash red/evil
	if animated_sprite:
		var original_modulate := animated_sprite.modulate
		animated_sprite.modulate = Color.RED
		
		var tween := create_tween()
		tween.tween_property(animated_sprite, "modulate", original_modulate, 0.3)
	
	# Play trap sound
	_play_sound(trap_sound)
	
	# Screen shake for impact
	if shake_screen:
		_do_screen_shake()
	
	# Create evil particle burst
	_spawn_trap_particles()
	
	# Apply effect to player
	if player and player.has_method("_applyeffect"):
		player._applyeffect(trap_effect, effect_duration)
	elif player and player.has_method("apply_effect"):
		player.apply_effect(trap_effect, effect_duration)


func _do_screen_shake() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera and camera.has_method("shake"):
		camera.shake(screen_shake_intensity, screen_shake_duration)
	elif camera:
		# Fallback: manual shake via offset
		var original_offset := camera.offset
		var tween := create_tween()
		tween.set_loops(int(screen_shake_duration / 0.05))
		tween.tween_property(camera, "offset", original_offset + Vector2(screen_shake_intensity, 0), 0.025)
		tween.tween_property(camera, "offset", original_offset - Vector2(screen_shake_intensity, 0), 0.025)
		tween.tween_callback(func(): camera.offset = original_offset)


func _spawn_trap_particles() -> void:
	var burst := GPUParticles2D.new()
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = 12
	burst.lifetime = 0.5
	burst.emitting = true
	
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 12.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 120.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 200, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.0
	
	# Evil purple/red color
	mat.color = Color(0.7, 0.1, 0.3, 1.0)
	
	burst.process_material = mat
	burst.global_position = global_position + Vector2(0, -8)
	get_parent().add_child(burst)
	
	# Auto-cleanup
	get_tree().create_timer(2.0).timeout.connect(burst.queue_free)
