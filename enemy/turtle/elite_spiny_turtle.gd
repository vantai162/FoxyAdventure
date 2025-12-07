extends EnemyCharacter
class_name EliteSpinyTurtle
## Elite Turtle: "The Spiny"
## Uses defensive_hide state (shoots 8 spikes) instead of normal hide
## ACTIVELY PURSUES player - charges and triggers spike burst at close range

@export var spike_projectile_scene: PackedScene  ## Assign SpikeProjectile scene

func _ready() -> void:
	# Initialize FSM with defensive_hide as the hide state
	# NOTE: Scene must have States/DefensiveHide and States/AggressivePursue nodes
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	
	# Enable player detection for pursuit behavior
	enable_check_player_in_sight()

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

# Override hurt transition to use defensive_hide
func _on_hurt_area_2d_hurt(_direction: Vector2, _damage: float) -> void:
	if _direction.x != 0:
		var attacker_side = -sign(_direction.x)
		if attacker_side != direction:
			change_direction(attacker_side)
	
	take_damage(_damage)
	
	# Transition to defensive_hide instead of normal hide
	if fsm.states.has("defensive_hide"):
		fsm.change_state(fsm.states.defensivehide)
	elif fsm.states.has("hide"):
		fsm.change_state(fsm.states.hide)  # Fallback to normal hide
	else:
		push_warning("EliteSpinyTurtle: No hide or defensive_hide state found!")
