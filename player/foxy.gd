class_name Player
extends BaseCharacter

@export var Attack_Speed:int=0
var attack_cooldown=1
@export var Has_Blade:bool=false
@export var Effect={
	"Stun":0,
	"DamAmplify":0
}

func _ready() -> void:
	super._ready()
	fsm=FSM.new(self,$States,$States/Idle)
	if Has_Blade==true:
		_collect_blade()
	
func _collect_blade():
	Has_Blade=true
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
