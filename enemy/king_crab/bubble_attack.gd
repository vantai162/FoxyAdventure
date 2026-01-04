extends EnemyState

## Bubble Attack - Fires two water bubbles that trap the player
##
## ANIMATION ASSUMPTIONS:
##   - "bubble_attack" : Crab opens claws and fires bubbles (loop: false)
##
## King Crab attacks cannot be interrupted - take damage but keep attacking

# Boss poise handled by stun_immune flag — use super for proper hit feedback
func take_damage(_damage_dir: Vector2, damage: int) -> void:
	super.take_damage(_damage_dir, damage)

enum AttackPhase { WINDUP, FIRE_FIRST, FIRE_SECOND, RECOVERY }
var attack_phase: AttackPhase = AttackPhase.WINDUP
var phase_timer: float = 0.0

const WINDUP_TIME: float = 0.2
const BETWEEN_SHOTS_TIME: float = 0.5
const RECOVERY_TIME: float = 0.4


func _enter() -> void:
	obj.change_animation("bubble_attack")
	obj.velocity = Vector2.ZERO
	attack_phase = AttackPhase.WINDUP
	phase_timer = 0.0
	
	# Face player before attack
	if obj.found_player:
		var dir_to_player = sign(obj.found_player.global_position.x - obj.global_position.x)
		if dir_to_player != 0 and dir_to_player != obj.direction:
			obj.change_direction(dir_to_player)


func _update(delta: float) -> void:
	phase_timer += delta
	
	match attack_phase:
		AttackPhase.WINDUP:
			if phase_timer >= WINDUP_TIME:
				_fire_bubble_from_upper()
				attack_phase = AttackPhase.FIRE_FIRST
				phase_timer = 0.0
		
		AttackPhase.FIRE_FIRST:
			if phase_timer >= BETWEEN_SHOTS_TIME:
				_fire_bubble_from_lower()
				attack_phase = AttackPhase.FIRE_SECOND
				phase_timer = 0.0
				
		
		AttackPhase.FIRE_SECOND:
			if phase_timer >= RECOVERY_TIME:
				change_state(fsm.states.idle)


func _fire_bubble_from_upper() -> void:
	if obj.upper_claw_pos:
		_spawn_bubble(obj.upper_claw_pos.global_position)


func _fire_bubble_from_lower() -> void:
	if obj.lower_claw_pos:
		_spawn_bubble(obj.lower_claw_pos.global_position)


func _spawn_bubble(pos: Vector2) -> void:
	if obj.water_bubble_factory == null:
		return
	
	# Use obj.direction (standard codebase pattern)
	var fire_dir = Vector2(obj.direction, 0)
	
	var bubble = obj.water_bubble_factory.create()
	if bubble:
		obj.get_tree().current_scene.add_child(bubble)
		bubble.global_position = pos
		bubble.launch(fire_dir, obj.bubble_speed)
		bubble.trap_duration = obj.bubble_trap_duration
		AudioManager.play_sound("bubble_attack",20.0)
