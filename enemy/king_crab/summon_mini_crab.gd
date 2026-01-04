extends EnemyState

## Summon Mini Crabs - Phase 2 attack
## Spawns mini crabs in a timed sequence using proper FSM pattern (no await!)

# King Crab attacks cannot be interrupted - take damage but keep attacking
# Boss poise handled by stun_immune flag — use super for proper hit feedback
func take_damage(_damage_dir: Vector2, damage: int) -> void:
	super.take_damage(_damage_dir, damage)


enum SpawnPhase { WINDUP, SPAWNING, RECOVERY }
var spawn_phase: SpawnPhase = SpawnPhase.WINDUP

var spawned: int = 0
var spawn_timer: float = 0.0

const WINDUP_TIME: float = 0.5
const RECOVERY_TIME: float = 0.4


func _enter() -> void:
	spawn_phase = SpawnPhase.WINDUP
	spawned = 0
	spawn_timer = 0.0
	obj.velocity = Vector2.ZERO
	obj.change_animation("summon")


func _update(delta: float) -> void:
	spawn_timer += delta
	
	match spawn_phase:
		SpawnPhase.WINDUP:
			if spawn_timer >= WINDUP_TIME:
				spawn_phase = SpawnPhase.SPAWNING
				spawn_timer = 0.0
				_spawn_one()  # First spawn immediately
		
		SpawnPhase.SPAWNING:
			if spawn_timer >= obj.minicrab_spawn_interval:
				spawn_timer = 0.0
				_spawn_one()
		
		SpawnPhase.RECOVERY:
			if spawn_timer >= RECOVERY_TIME:
				change_state(fsm.states.idle)


func _spawn_one() -> void:
	if obj.minicrab_scene == null:
		push_warning("minicrab_scene is not assigned!")
		change_state(fsm.states.idle)
		return
	
	var minicrab = obj.minicrab_scene.instantiate()
	obj.get_tree().current_scene.add_child(minicrab)
	
	var forward := Vector2(obj.direction, 0)
	minicrab.global_position = obj.global_position + forward * obj.minicrab_spawn_radius
	
	spawned += 1
	
	if spawned >= obj.minicrab_count:
		spawn_phase = SpawnPhase.RECOVERY
		spawn_timer = 0.0
		obj.change_animation("idle")
