extends EnemyCharacter
class_name EliteRicochetStarfish
## Elite Starfish: "The Ricochet"
## Pinball enemy: Pursues player, then bounces off surfaces in chaotic dash attacks
## Visual: Hue-shifted colors + red glowing eye trail

@export var attack_cooldown: float = 1.5  ## Cooldown between dash attacks (shorter for aggressive mob)
var attack_cooldown_timer: float = 0.0  ## Time remaining before can attack again
var is_in_sequence: bool = false  ## Tracks if currently executing dash sequence

## Ricochet sequence state (centralized to persist across frames)
var current_dash: int = 0  ## Which dash in sequence (0-2)
var dash_timer: float = 0.0  ## Total time in sequence
var prepare_timer: float = 0.0  ## Prepare phase countdown
var pause_timer: float = 0.0  ## Pause between dashes countdown
var is_preparing: bool = false  ## In prepare phase
var is_pausing: bool = false  ## In pause phase
var dash_start_position: Vector2 = Vector2.ZERO  ## Start position of current dash
var dash_direction: Vector2 = Vector2.ZERO  ## Direction of current dash
var last_collision_normal: Vector2 = Vector2.ZERO  ## Last collision normal for smart bouncing

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
	# COMMITMENT: Only trigger if NOT in sequence AND cooldown expired
	# Once sequence starts, this signal is ignored until sequence completes + cooldown
	if is_in_sequence or attack_cooldown_timer > 0.0:
		return
	
	# Face player ONCE before committing to sequence
	if found_player:
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	# Trigger ricochet dash (state will set flags on entry)
	if fsm and fsm.current_state:
		if fsm.states.has("ricochetdash") and fsm.current_state != fsm.states.ricochetdash:
			fsm.change_state(fsm.states.ricochetdash)

func _on_player_not_in_sight() -> void:
	# Ricochet state will timeout back to run automatically
	# Don't change behavior mid-sequence
	pass

# Called by ricochet_dash state when sequence completes
func on_sequence_complete() -> void:
	is_in_sequence = false
	# Detection will be re-enabled when cooldown expires (in _physics_process)
