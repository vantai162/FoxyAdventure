extends EnemyCharacter
class_name MiniMushroom
## Mini mushroom spawned by Elite Spawner
## ZOMBIE missile: Walks mindlessly in direction, explodes when NEAR player
## No tracking, no intelligence - pure kamikaze

@export var lifetime: float = 3.5  ## Safety timeout if doesn't hit player
@export var move_speed: float = 160.0  ## Fast zombie walk

var initial_direction: int = 1  ## Set by spawner (1 or -1)
var life_timer: float = 0.0

func _ready() -> void:
	# Start in run state (constant movement)
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	
	# Disable detection (zombie doesn't "detect", it just walks)
	disable_check_player_in_sight()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Lifetime countdown (safety backup)
	life_timer += delta
	if life_timer >= lifetime:
		# Timeout → explode (missed player)
		if fsm.states.has("miniexplode"):
			fsm.change_state(fsm.states.miniexplode)

func _on_explode_area_body_entered(body: Node2D) -> void:
	## Proximity detonation - explodes when player gets close
	## Connected in scene (legacy pattern from OG mushroom)
	if body is Player:
		if fsm.states.has("miniexplode"):
			fsm.change_state(fsm.states.miniexplode)
