extends EnemyCharacter

## King Crab Boss - Uses base class detection, simple phase system

# Phase system
@export var phase_2_threshold: float = 0.5
var current_phase: int = 1

# Factories (for spawning projectiles)
@onready var coconut_factory = $Direction/CoconutFactory if has_node("Direction/CoconutFactory") else null
@onready var claw_factory = $Direction/ClawFactory if has_node("Direction/ClawFactory") else null
@onready var warning_factory = $Direction/WarningFactory if has_node("Direction/WarningFactory") else null

func _ready() -> void:
	add_to_group("king_crab")
	add_to_group("enemy")
	max_health = 200
	fsm = FSM.new(self, $States, $States/Idle)
	super._ready()  # Calls _init_ray_cast, _init_detect_player_area, _init_hurt_area

func take_damage(damage: int) -> void:
	super.take_damage(damage)
	if current_phase == 1 and health <= max_health * phase_2_threshold:
		_enter_phase_2()

func _enter_phase_2() -> void:
	current_phase = 2
	movement_speed *= 1.3
	print("King Crab enters Phase 2!")

# Tree climbing support
func find_nearest_tree() -> Node2D:
	var trees = get_tree().get_nodes_in_group("coconut_tree")
	if trees.is_empty():
		return null
	var nearest: Node2D = null
	var min_dist: float = INF
	for tree in trees:
		var dist = global_position.distance_to(tree.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest = tree
	return nearest
