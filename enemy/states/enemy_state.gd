extends FSMState
class_name EnemyState

## Hit feedback particles — blood/impact puff on damage
const HIT_PARTICLES_SCENE: PackedScene = preload("res://assets/effects/dust_puff.tscn")

## Hitstop duration for enemy hits — brief freeze for impact weight
const ENEMY_HITSTOP: float = 0.04

func take_damage(_damage_dir, damage: int) -> void:
	# POISE SYSTEM: Check for boss immunity flags
	var is_knockback_immune := obj.get("knockback_immune") == true
	var is_stun_immune := obj.get("stun_immune") == true
	
	# Apply knockback ONLY if not immune
	if not is_knockback_immune:
		obj.velocity.x = _damage_dir.x * obj.knockback_force
	
	# Apply damage (always)
	obj.take_damage(damage)
	_spawn_hit_feedback(_damage_dir)
	
	# Change to hurt state ONLY if not stun immune
	if not is_stun_immune:
		change_state(fsm.states.hurt)

## Spawn hit feedback — particles + hitstop for satisfying combat
func _spawn_hit_feedback(damage_dir: Vector2) -> void:
	# Hitstop for impact weight — FREEZE THIS ENEMY, not the world
	HitstopManager.freeze_node(obj, ENEMY_HITSTOP)
	
	# Hit particles burst — instantiate fresh to avoid shared resource mutation
	var particles = HIT_PARTICLES_SCENE.instantiate()
	particles.global_position = obj.global_position
	# Create a UNIQUE material to avoid shared resource corruption
	if particles.process_material:
		var unique_mat = particles.process_material.duplicate()
		unique_mat.direction = Vector3(-damage_dir.x, -0.5, 0)
		particles.process_material = unique_mat
	particles.emitting = true
	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)
	
