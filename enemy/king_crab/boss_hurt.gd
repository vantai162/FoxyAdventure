extends EnemyState
class_name BossHurtState

## Boss-specific hurt state with POISE system
## Kojima's Law: A boss that can be stun-locked is not a boss — it's a punching bag.
##
## POISE SYSTEM:
## - Boss does NOT get knocked back by player attacks
## - Boss does NOT have attack animations cancelled by damage
## - Boss takes damage and shows hurt feedback, but CONTINUES attacking
## - This creates a skill-based fight: you can't cheese, you must learn patterns

## Duration of hurt visual feedback (flash) without interrupting attack
@export var hurt_flash_duration: float = 0.15

## Minimum time between hurt state entries (prevents stun-lock)
@export var hurt_cooldown: float = 0.5

var can_enter_hurt: bool = true
var cooldown_timer: float = 0.0

func _enter() -> void:
	## Boss takes damage but does NOT stop attacking
	## This is a VISUAL-ONLY state transition for feedback
	
	# Quick flash feedback to show damage registered
	if obj.animated_sprite:
		var tween = obj.create_tween()
		tween.tween_property(obj.animated_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.05)
		tween.tween_property(obj.animated_sprite, "modulate", Color.WHITE, hurt_flash_duration)
	
	# Camera shake for impact (if reference exists)
	if obj.has_method("shake_camera"):
		obj.shake_camera(5.0)
	
	# Play hurt sound
	AudioManager.play_sound("boss_hit", 12.0)
	
	# CRITICAL: Return to previous state immediately
	# Boss does NOT stay in hurt — poise means attacks continue
	timer = hurt_flash_duration

func _update(delta: float) -> void:
	if update_timer(delta):
		# Check for death
		if obj.health <= 0:
			change_state(fsm.states.dead)
		else:
			# Return to previous state (attack continues)
			# If no previous state recorded, go to idle
			if fsm.previous_state != null and fsm.previous_state != self:
				change_state(fsm.previous_state)
			else:
				change_state(fsm.states.idle)

## Override take_damage to implement poise
func take_damage(_damage_dir: Vector2, damage: int) -> void:
	## POISE: Boss takes damage but is NOT knocked back
	## velocity.x is NOT modified — boss maintains position
	
	# Apply damage through proper system
	obj.take_damage(damage)
	
	# Only enter hurt state if cooldown allows
	if can_enter_hurt:
		can_enter_hurt = false
		cooldown_timer = hurt_cooldown
		# Note: We still change state for the flash effect
		# but the flash duration is so short it doesn't interrupt attacks
	
	# Do NOT call change_state(fsm.states.hurt) here
	# The current attack state will handle the visual flash

