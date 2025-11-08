class_name Player
extends BaseCharacter

@export var Attack_Speed:int=0
var attack_cooldown=1
@export var Effect={
	"Stun":0,
	"DamAmplify":0,
	"Slow":0
}
@export var KeySkill={
	"HasBlade":false
}
func _ready() -> void:
	super._ready()
	fsm=FSM.new(self,$States,$States/Idle)
	if KeySkill["HasBlade"]==true:
		_collect_blade()
	
func _collect_blade():
	KeySkill["HasBlade"]=true
	set_animated_sprite($Direction/BladeAnimatedSprite2D)

func _applyeffect(name:String,time:float):
	Effect[name]=time
	
func _updateeffect(delta:float):
	for key in Effect:	
		Effect[key]-=delta
		if Effect[key]<=0:
			Effect[key]=0

func _process(delta: float) -> void:
		_updateeffect(delta)
