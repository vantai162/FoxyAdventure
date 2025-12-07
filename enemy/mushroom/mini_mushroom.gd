extends EnemyCharacter
class_name MiniMushroom
## Mini mushroom spawned by Elite Spawner
## Instant aggro kamikaze - no surprise state, faster explosion
## Scaled down (0.7) with single gas cloud on death

@export var explosion_time: float = 1.0  ## Faster than base (1.5s)
@export var toxic_gas_scene: PackedScene

func _ready() -> void:
	# Start in run state (no sleep/surprise - instant aggro)
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	
	# Mini mushroom is always active, no sleep phase
	# Player detection immediately triggers explode

func _on_detect_player_area_body_entered(body: Node2D) -> void:
	## Instant kamikaze when player in range
	if body.is_in_group("player"):
		if fsm.states.has("miniexplode"):
			fsm.change_state(fsm.states.miniexplode)

func _on_player_in_sight(_player_pos: Vector2) -> void:
	## Even visual sight triggers explosion (aggressive)
	if fsm.states.has("miniexplode"):
		fsm.change_state(fsm.states.miniexplode)
