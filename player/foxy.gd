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
var timeline=0
@export var jump_buffer:float
var last_jumppress_onair=-1211
@export var coyote_time:float
var last_ground_time=-1211
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
			
func _update_timeline(delta:float):
	timeline+=delta
	if(is_on_floor()):
		last_ground_time=timeline
	elif(fsm.current_state==fsm.states.fall && Input.is_action_pressed("jump")):
		last_jumppress_onair=timeline
		
func _checkcoyotea()->bool:
	if(timeline-last_ground_time<coyote_time):#check coyote_time
		return true
	return false

func _checkbuffer()->bool:
	if(timeline-last_jumppress_onair<jump_buffer):
		return true
	return false

func _process(delta: float) -> void:
		_updateeffect(delta)
		_update_timeline(delta)
