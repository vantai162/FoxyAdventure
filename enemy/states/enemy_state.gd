extends FSMState
class_name EnemyState

## Hit feedback particles — blood/impact puff on damage
const HIT_PARTICLES_SCENE: PackedScene = preload("res://assets/effects/dust_puff.tscn")

## Hitstop duration for enemy hits — brief freeze for impact weight
const ENEMY_HITSTOP: float = 0.025

func take_damage(_damage_dir, damage: int) -> void:
	obj.velocity.x = _damage_dir.x * obj.knockback_force
	obj.take_damage(damage)
	_spawn_hit_feedback(_damage_dir)
	change_state(fsm.states.hurt)

## Spawn hit feedback — particles + hitstop for satisfying combat
func _spawn_hit_feedback(damage_dir: Vector2) -> void:
	# Hitstop for impact weight
	Engine.time_scale = 0.0
	get_tree().create_timer(ENEMY_HITSTOP, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0
	)
	
	# Hit particles burst
	var particles = HIT_PARTICLES_SCENE.instantiate()
	particles.global_position = obj.global_position
	# Particles fly opposite to damage direction
	if particles.process_material:
		particles.process_material.direction = Vector3(-damage_dir.x, -0.5, 0)
	particles.emitting = true
	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)
	
