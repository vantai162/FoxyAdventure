extends EnemyState

## Phase 2: Claw wrap-around attack
## Crab launches claw horizontally, waits for it to wrap around screen and return
## 
## ANIMATION ASSUMPTIONS (create these in SpriteFrames):
##   - "claw_windup"   : Winding up to throw claw (loop: false)
##   - "claw_throw"    : Throwing motion (loop: false)
##   - "claw_waiting"  : Standing with arm extended, waiting (loop: true)
##   - "claw_catch"    : Catching returning claw (loop: false)
##   - "claw_recoil"   : Stunned from claw impact (loop: false)
##   - "claw_recover"  : Getting back up / recovering (loop: false)

# King Crab attacks cannot be interrupted - take damage but keep attacking
func take_damage(_damage_dir, damage: int) -> void:
	obj.take_damage(damage)


enum AttackPhase { WINDUP, THROWING, WAITING, CATCHING, RECOIL, RECOVERY }
var attack_phase: AttackPhase = AttackPhase.WINDUP

var phase_timer: float = 0.0
var active_claw: Node2D = null


func _enter() -> void:
	attack_phase = AttackPhase.WINDUP
	phase_timer = 0.0
	active_claw = null
	
	# Face player before attack
	if obj.found_player:
		var dir_to_player = sign(obj.found_player.global_position.x - obj.global_position.x)
		if dir_to_player != 0 and dir_to_player != obj.direction:
			obj.change_direction(dir_to_player)
	
	obj.change_animation("claw_windup")
	obj.velocity = Vector2.ZERO


func _exit() -> void:
	if active_claw and is_instance_valid(active_claw):
		active_claw.queue_free()
		active_claw = null


func _update(delta: float) -> void:
	phase_timer += delta
	
	match attack_phase:
		AttackPhase.WINDUP:
			if phase_timer >= obj.claw_windup_time:
				_start_throw()
		AttackPhase.THROWING:
			if phase_timer >= obj.claw_throw_time:
				_start_waiting()
		AttackPhase.WAITING:
			pass  # Waiting for claw signal
		AttackPhase.CATCHING:
			if phase_timer >= obj.claw_catch_time:
				_start_recoil()
		AttackPhase.RECOIL:
			if phase_timer >= obj.claw_recoil_time:
				_start_recovery()
		AttackPhase.RECOVERY:
			if phase_timer >= obj.claw_recovery_time:
				change_state(fsm.states.idle)


func _start_throw() -> void:
	attack_phase = AttackPhase.THROWING
	phase_timer = 0.0
	obj.change_animation("claw_throw")
	
	if obj.claw_factory and obj.claw_factory.has_method("create"):
		active_claw = obj.claw_factory.create()
		if active_claw:
			# Pass claw settings from main character
			active_claw.speed = obj.claw_speed
			active_claw.travel_distance = obj.claw_travel_distance
			active_claw.return_threshold = obj.claw_return_threshold
			active_claw.wrap_offset_ratio = obj.claw_wrap_offset_ratio
			active_claw.setup(obj.direction, obj)
			active_claw.returned_to_owner.connect(_on_claw_returned)


func _start_waiting() -> void:
	attack_phase = AttackPhase.WAITING
	phase_timer = 0.0
	obj.change_animation("claw_waiting")


func _on_claw_returned() -> void:
	if fsm.current_state != self:
		return
	active_claw = null
	attack_phase = AttackPhase.CATCHING
	phase_timer = 0.0
	obj.change_animation("claw_catch")


func _start_recoil() -> void:
	attack_phase = AttackPhase.RECOIL
	phase_timer = 0.0
	obj.change_animation("claw_recoil")


func _start_recovery() -> void:
	attack_phase = AttackPhase.RECOVERY
	phase_timer = 0.0
	obj.change_animation("claw_recover")
