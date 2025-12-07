extends EnemyCharacter
class_name EliteRicochetStarfish
## Elite Starfish: "The Ricochet"
## Pinball enemy: Pursues player, then bounces off surfaces in chaotic dash attacks
## Visual: Hue-shifted colors + red glowing eye trail

@export var attack_cooldown: float = 3.0  ## Cooldown between dash attacks
var attack_cooldown_timer: float = 0.0  ## Time remaining before can attack again

func _ready() -> void:
	# Initialize FSM with ricochet_dash state
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	
	# Enable player detection for pursuit behavior
	enable_check_player_in_sight()

func _physics_process(delta: float) -> void:
	# Tick down attack cooldown
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	
	super._physics_process(delta)

# Override player detection to use ricochet attack instead of base attack
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if found_player:
		# Face player
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	# Trigger ricochet dash when player in sight (replaces base attack state)
	# Only trigger if NOT already in ricochet dash AND cooldown expired
	if fsm and fsm.current_state:
		if fsm.states.has("ricochetdash") and fsm.current_state != fsm.states.ricochetdash and attack_cooldown_timer <= 0.0:
			# Disable detection during dash sequence
			disable_check_player_in_sight()
			# Start cooldown
			attack_cooldown_timer = attack_cooldown
			fsm.change_state(fsm.states.ricochetdash)

func _on_player_not_in_sight() -> void:
	# Ricochet state will timeout back to run automatically
	pass
