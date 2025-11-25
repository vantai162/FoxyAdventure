extends EnemyCharacter

# King Crab Boss - Phase system
@export var phase_2_threshold: float = 0.5  # Transition at 50% health
var current_phase: int = 1

# Movement and targeting
@export var walk_speed: float = 80.0
@export var climb_speed: float = 60.0
var target_tree: Node2D = null

# Attack cooldowns
var can_throw_coconut: bool = true
var can_dive: bool = true
var can_claw: bool = true

# References (set from scene)
@onready var coconut_factory: Node2D = $Direction/CoconutFactory if has_node("Direction/CoconutFactory") else null
@onready var claw_factory: Node2D = $Direction/ClawFactory if has_node("Direction/ClawFactory") else null
@onready var warning_factory: Node2D = $Direction/WarningFactory if has_node("Direction/WarningFactory") else null

func _ready() -> void:
	max_health = 200  # Set boss health (inherited from BaseCharacter)
	_init_ray_cast()
	_init_detect_player_area()
	_init_hurt_area()
	fsm = FSM.new(self, $States, $States/Idle)
	super._ready()

func _init_detect_player_area() -> void:
	if has_node("DetectPlayerArea2D"):
		var detect_area = $DetectPlayerArea2D
		detect_area.body_entered.connect(_on_player_detected)
		detect_area.body_exited.connect(_on_player_lost)

func _on_player_detected(body: Node2D) -> void:
	if body.is_in_group("player"):
		found_player = body

func _on_player_lost(body: Node2D) -> void:
	if body.is_in_group("player") and found_player == body:
		found_player = null

func take_damage(damage: int) -> void:
	super.take_damage(damage)
	_check_phase_transition()

func _check_phase_transition() -> void:
	if current_phase == 1 and health <= max_health * phase_2_threshold:
		enter_phase_2()

func enter_phase_2() -> void:
	current_phase = 2
	# Speed up attacks and movement
	walk_speed *= 1.3
	climb_speed *= 1.3
	# Enable Phase 2 abilities
	print("King Crab enters Phase 2!")

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

func is_at_tree() -> bool:
	if not target_tree:
		return false
	return global_position.distance_to(target_tree.global_position) < 20.0
