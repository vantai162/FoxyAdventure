extends Area2D
class_name HitArea2D

## HitArea2D — Offensive collision that deals damage to HurtArea2D
## 
## DESIGN (Kojima's Law): Every hit must REGISTER.
## - Damage is dealt to victim's HurtArea2D
## - Hitstop freezes the ATTACKER (this scene's owner)
## - Camera shake punctuates the impact
## - The victim handles their own freeze in hurt state

@export var damage: int = 1

@export_group("Hit Feedback")
@export var hitstop_duration: float = 0.06  ## 60ms = perceivable punch
@export var camera_shake_amount: float = 4.0  ## Screen shake intensity (0 = disabled)
@export var enable_hitstop: bool = true

signal hit_landed(area: Area2D)  ## Emitted when damage is dealt
signal hitted(area: Area2D)  ## @deprecated: Use hit_landed instead

func _init() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	_deal_damage(area)
	hit_landed.emit(area)
	hitted.emit(area)  # @deprecated: backwards compatibility


## Deal damage to a HurtArea2D and apply hit feedback
func _deal_damage(hurt_area: Area2D) -> void:
	if not hurt_area.has_method("take_damage"):
		return
	
	var hit_direction: Vector2 = (hurt_area.global_position - global_position).normalized()
	hurt_area.take_damage(hit_direction, damage)
	
	_apply_hit_feedback()


## Hitstop + camera shake — the moment of impact must be FELT
func _apply_hit_feedback() -> void:
	# Camera shake
	if camera_shake_amount > 0.0:
		var player: Node = GameManager.player
		if is_instance_valid(player):
			var camera: Node = player.get_node_or_null("Camera2D")
			if camera and camera.has_method("shake"):
				camera.shake(camera_shake_amount)
	
	# Hitstop — freeze the ATTACKER
	if enable_hitstop and hitstop_duration > 0.0:
		var attacker: Node = _find_attacker()
		if is_instance_valid(attacker):
			HitstopManager.freeze_node(attacker, hitstop_duration)


## Find the entity that owns this HitArea2D
## Priority: owner (scene root) → nearest PhysicsBody2D ancestor → null
func _find_attacker() -> Node:
	# Primary: owner is the scene root (works for editor-placed HitArea2D)
	if is_instance_valid(owner):
		return owner
	
	# Fallback: traverse up to find any PhysicsBody2D (CharacterBody2D, RigidBody2D, etc.)
	var node: Node = get_parent()
	while node:
		if node is PhysicsBody2D:
			return node
		node = node.get_parent()
	
	# No attacker found — hitstop will be skipped (this is normal for some setups)
	return null
