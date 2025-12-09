extends Node
class_name TimerLeverPuzzle

## Manages multiple timer levers that must all be activated within a time window
## All connected levers must be ON simultaneously to trigger the target

signal puzzle_solved
signal puzzle_failed
signal lever_activated(lever_name: String)
signal time_remaining_changed(time: float)

@export_group("Puzzle Settings")
@export var required_lever_count: int = 3  ## How many levers needed
@export var time_limit: float = 10.0  ## Seconds to activate all levers
@export var reset_on_timeout: bool = true  ## Reset all levers on failure

@export_group("Target")
@export var target_node: NodePath  ## Gate/door to open on success
@export var success_action: String = "open"  ## Method to call on target

@export_group("Visual Feedback")
@export var show_countdown: bool = true

var connected_levers: Array[TimerLever] = []
var active_levers: Array[TimerLever] = []
var puzzle_timer: float = 0.0
var is_puzzle_active: bool = false
var is_solved: bool = false

func _ready() -> void:
	# Auto-find TimerLever children
	_find_connected_levers()

func _find_connected_levers() -> void:
	for child in get_children():
		if child is TimerLever:
			_connect_lever(child)
	
	# Also check for levers in sibling nodes with matching group
	var levers_in_group = get_tree().get_nodes_in_group("puzzle_" + name)
	for lever in levers_in_group:
		if lever is TimerLever and lever not in connected_levers:
			_connect_lever(lever)

func _connect_lever(lever: TimerLever) -> void:
	connected_levers.append(lever)
	lever.lever_activated.connect(_on_lever_activated.bind(lever))
	lever.lever_deactivated.connect(_on_lever_deactivated.bind(lever))

func add_lever(lever: TimerLever) -> void:
	if lever not in connected_levers:
		_connect_lever(lever)

func _on_lever_activated(lever: TimerLever) -> void:
	if is_solved:
		return
	
	if lever not in active_levers:
		active_levers.append(lever)
	
	lever_activated.emit(lever.name)
	
	# Start puzzle timer on first activation
	if not is_puzzle_active and active_levers.size() == 1:
		_start_puzzle_timer()
	
	# Check win condition
	if active_levers.size() >= required_lever_count:
		_solve_puzzle()

func _on_lever_deactivated(lever: TimerLever) -> void:
	if lever in active_levers:
		active_levers.erase(lever)
	
	# If all levers deactivated, reset timer
	if active_levers.is_empty():
		is_puzzle_active = false
		puzzle_timer = 0.0

func _start_puzzle_timer() -> void:
	is_puzzle_active = true
	puzzle_timer = time_limit

func _process(delta: float) -> void:
	if not is_puzzle_active or is_solved:
		return
	
	puzzle_timer -= delta
	time_remaining_changed.emit(puzzle_timer)
	
	if puzzle_timer <= 0:
		_fail_puzzle()

func _solve_puzzle() -> void:
	is_solved = true
	is_puzzle_active = false
	puzzle_solved.emit()
	
	# Trigger target
	if target_node != NodePath(""):
		var target = get_node_or_null(target_node)
		if target != null and target.has_method(success_action):
			target.call(success_action)

func _fail_puzzle() -> void:
	is_puzzle_active = false
	puzzle_timer = 0.0
	puzzle_failed.emit()
	
	if reset_on_timeout:
		active_levers.clear()
		# Levers will auto-deactivate via their own timers

func reset_puzzle() -> void:
	is_solved = false
	is_puzzle_active = false
	puzzle_timer = 0.0
	active_levers.clear()
