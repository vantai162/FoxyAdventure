extends EnemyCharacter

@export var boomb_scene: PackedScene
@onready var muzzle = $Direction/Boomb/Muzzle
@onready var muzzle2 = $Direction/Boomb/Muzzle2
func _ready():
	super._ready()
	
	fsm = FSM.new(self, $States, $States/Idle)

func fire_boomb():
	var boomb1 = boomb_scene.instantiate()
	boomb1.global_position = muzzle.global_position
	boomb1.direction =  1
	get_tree().current_scene.add_child(boomb1)

	var boomb2 = boomb_scene.instantiate()
	boomb2.global_position = muzzle2.global_position
	boomb2.direction =  -1
	get_tree().current_scene.add_child(boomb2)
