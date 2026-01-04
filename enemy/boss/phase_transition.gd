extends EnemyState

## Phase Transition — THE DRAMATIC ENTRANCE TO PHASE 2
## 
## DESIGN: When the boss hits 50% health, they stagger, power up, and EXPLODE.
## Same shockwave mechanic as the regular Roar attack, but with story context.
## 
## This teaches the player:
## "Phase 2 is dangerous. Respect the distance."
##
## NOTE: Roar is ALSO a regular attack in the boss's rotation.
## This transition version is the STORY moment; the attack version is gameplay.

@export var telegraph_duration: float = 0.5  ## Buildup before shockwave
@export var recovery_duration: float = 0.6   ## Pause after roar, before phase 2 begins

## Shockwave parameters (reuses King Crab's shockwave)
@export var shockwave_scene: PackedScene
@export var shockwave_radius: float = 150.0   ## Large — this is THE moment
@export var shockwave_knockback: float = 450.0  ## Strong push — creates respect
@export var shockwave_damage: int = 1

## Screen shake for IMPACT
@export var telegraph_shake: float = 6.0
@export var release_shake: float = 15.0  ## BIG shake for THE roar

enum Phase { STAGGER, TELEGRAPH, RELEASE, RECOVERY }
var _phase: Phase = Phase.STAGGER
var _timer: float = 0.0


func _enter() -> void:
	obj.velocity = Vector2.ZERO
	obj.invincible = true  ## Can't be interrupted during transformation
	
	_phase = Phase.STAGGER
	_timer = 0.0
	
	## Initial stagger — the hit that broke us
	obj.change_animation("hurt")
	_timer = obj.phase_transition_roar_delay  ## Brief stagger before rage


func _update(delta: float) -> void:
	_timer -= delta
	
	match _phase:
		Phase.STAGGER:
			if _timer <= 0.0:
				_phase = Phase.TELEGRAPH
				_timer = telegraph_duration
				_start_telegraph()
		
		Phase.TELEGRAPH:
			## Continuous shake buildup
			var progress = 1.0 - (_timer / telegraph_duration)
			_apply_camera_shake(telegraph_shake * (1.0 + progress))
			
			if _timer <= 0.0:
				_phase = Phase.RELEASE
				_do_roar_release()
				_timer = recovery_duration
		
		Phase.RELEASE:
			## Immediately transition to recovery (release is instant)
			_phase = Phase.RECOVERY
		
		Phase.RECOVERY:
			if _timer <= 0.0:
				_complete_transition()


func _start_telegraph() -> void:
	## Power up animation — arm raise reads as "charging"
	obj.change_animation("skill1")
	AudioManager.play_sound("warlord_laugh", 25.0)  ## Angry laugh = menace


func _do_roar_release() -> void:
	## THE ROAR — shockwave + big shake
	_apply_camera_shake(release_shake)
	
	## Spawn shockwave
	if shockwave_scene:
		var shockwave = shockwave_scene.instantiate()
		shockwave.global_position = obj.global_position + Vector2(0, -20)
		
		## Override for phase transition intensity
		shockwave.gameplay_hit_radius = shockwave_radius
		shockwave.knockback_force = shockwave_knockback
		shockwave.damage = shockwave_damage
		
		get_tree().current_scene.add_child(shockwave)
	
	## Sound — reuse existing
	AudioManager.play_sound("warlord_roar", 30.0)


func _complete_transition() -> void:
	## Phase 2 is now active
	obj.current_phase = 2
	obj.invincible = false
	print("PHASE 2 ACTIVATED — THE ROAR COMPLETE")
	change_state(fsm.states.idle)


func _exit() -> void:
	obj.invincible = false


func _apply_camera_shake(intensity: float) -> void:
	var player = obj.found_player
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		if camera.has_method("shake"):
			camera.shake(intensity)
