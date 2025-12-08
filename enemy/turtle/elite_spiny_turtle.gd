extends EnemyCharacter
class_name EliteSpinyTurtle
## Elite Turtle: "The Spiny"
## Aggressive charger with spike burst counterattack
## Balanced: Same speed as elite crab, moderate attack frequency, area detection

@export var spike_projectile_scene: PackedScene  ## Assign SpikeProjectile scene
@export var burst_cooldown: float = 2.5  ## Balanced: Between crab (2.0s) and cautious (3.0s)

var last_burst_time: float = -999.0  ## Track last burst (can burst immediately on first trigger)

func _ready() -> void:
	# Initialize FSM with offensive_hide as the hide state
	# NOTE: Scene must have States/OffensiveHide and States/AggressivePursue nodes
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	
	# Enable player detection for pursuit behavior
	enable_check_player_in_sight()

func can_burst() -> bool:
	## Check if enough time has passed since last burst
	var time_since_burst = Time.get_ticks_msec() / 1000.0 - last_burst_time
	return time_since_burst >= burst_cooldown

func mark_burst_used() -> void:
	## Called when offensive_hide fires spikes
	last_burst_time = Time.get_ticks_msec() / 1000.0

# Override to use aggressive pursue
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if found_player:
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	# Elite behavior: Charge toward player
	if fsm.current_state == fsm.states.run:
		if fsm.states.has("aggressivepursue"):
			fsm.change_state(fsm.states.aggressivepursue)

func _on_player_not_in_sight() -> void:
	# Return to patrol when player lost
	if fsm.current_state == fsm.states.aggressivepursue:
		fsm.change_state(fsm.states.run)
