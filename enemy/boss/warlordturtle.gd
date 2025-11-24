extends EnemyCharacter

@export var boomb_scene: PackedScene
@export var rocket_scene: PackedScene
@onready var muzzle = $Direction/BoomAndRocket/MuzzleBoom1
@onready var muzzle2 = $Direction/BoomAndRocket/MuzzleBoom2
@onready var muzzlerocket1 =  $Direction/BoomAndRocket/MuzzleRocket1
@onready var muzzlerocket2 =  $Direction/BoomAndRocket/MuzzleRocket2
@onready var node =$Direction/BoomAndRocket/WariningRocket
@onready var node1 = $Direction/BoomAndRocket/WariningRocket2
@onready var node2 = $Direction/BoomAndRocket/WariningRocket3
@onready var node3 = $Direction/BoomAndRocket/WariningRocket4
func _ready():
	super._ready()
	invincible_timer = max_invincible
	fsm = FSM.new(self, $States, $States/Idle)

func fire_boomb():
	var boomb1 = boomb_scene.instantiate()
	boomb1.global_position = muzzle.global_position
	boomb1.set_speed(350.0)
	boomb1.direction =  -1
	get_tree().current_scene.add_child(boomb1)
	await get_tree().create_timer(0.2).timeout
	var boomb2 = boomb_scene.instantiate()
	boomb2.global_position = muzzle2.global_position
	boomb2.set_speed(250.0)
	boomb2.direction =  1
	get_tree().current_scene.add_child(boomb2)

func fire_rocket():
	var rocket1 = rocket_scene.instantiate()
	rocket1.global_position = muzzlerocket1.global_position
	get_tree().current_scene.add_child(rocket1)
	node.show_animation()
	print("node",node.global_position)
	rocket1.shoot(rocket1.global_position,node.global_position,1.5)
	await get_tree().create_timer(0.2).timeout
	var rocket2 = rocket_scene.instantiate()
	rocket2.global_position = muzzlerocket2.global_position
	get_tree().current_scene.add_child(rocket2)
	node1.show_animation()
	print("node2",node1.global_position)
	rocket2.shoot(rocket2.global_position,node1.global_position,1.5)
	await get_tree().create_timer(0.5).timeout
	var rocket3 = rocket_scene.instantiate()
	rocket3.global_position = muzzlerocket1.global_position
	get_tree().current_scene.add_child(rocket3)
	node2.show_animation()
	rocket3.shoot(rocket3.global_position,node2.global_position,1.5)
	await get_tree().create_timer(0.2).timeout
	var rocket4 = rocket_scene.instantiate()
	rocket4.global_position = muzzlerocket2.global_position
	get_tree().current_scene.add_child(rocket4)
	node3.show_animation()
	rocket4.shoot(rocket4.global_position,node3.global_position,1.5)
	
