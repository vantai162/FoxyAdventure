extends FSMState
class_name EnemyState

## Hit feedback particles — impact puff on damage
const HIT_PARTICLES_SCENE: PackedScene = preload("res://assets/effects/dust_puff.tscn")

## Hitstop duration — brief freeze for impact weight (40ms)
const ENEMY_HITSTOP: float = 0.04


## Take damage with poise system support
## Bosses with knockback_immune/stun_immune flags resist knockback and stun-lock
func take_damage(damage_dir: Vector2, damage: int) -> void:
	# POISE SYSTEM: Check for boss immunity flags (safe access via get())
	var is_knockback_immune: bool = obj.get("knockback_immune") == true
	var is_stun_immune: bool = obj.get("stun_immune") == true
	
	# Apply knockback ONLY if not immune AND property exists
	if not is_knockback_immune:
		var knockback_force: float = obj.get("knockback_force") if obj.get("knockback_force") != null else 0.0
		obj.velocity.x = damage_dir.x * knockback_force
	
	# Apply damage (always)
	obj.take_damage(damage)
	_spawn_hit_feedback(damage_dir)
	
	# Change to hurt state ONLY if not stun immune AND hurt state exists
	if not is_stun_immune and fsm.states.has("hurt"):
		change_state(fsm.states.hurt)


## Spawn hit feedback — particles + hitstop for satisfying combat
func _spawn_hit_feedback(damage_dir: Vector2) -> void:
	# Hitstop — FREEZE THIS ENEMY, not the world
	HitstopManager.freeze_node(obj, ENEMY_HITSTOP)
	
	# Particles — instantiate with unique material to avoid shared resource corruption
	var particles: GPUParticles2D = HIT_PARTICLES_SCENE.instantiate()
	particles.global_position = obj.global_position
	particles.emitting = true
	
	# Set direction on unique material copy
	if particles.process_material:
		var unique_mat: ParticleProcessMaterial = particles.process_material.duplicate()
		unique_mat.direction = Vector3(-damage_dir.x, -0.5, 0)
		particles.process_material = unique_mat
	
	# Add to scene and auto-free after emission
	get_tree().current_scene.add_child(particles)
	particles.finished.connect(particles.queue_free)
	
