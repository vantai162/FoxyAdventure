extends EnemyCharacter
@export var toxic_gas_scene: PackedScene


func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Run)
	$States/Surprise.toxic_gas_scene = toxic_gas_scene
	super._ready()


func _on_area_2d_body_entered(body: Node2D) -> void:
	pass
