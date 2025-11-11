class_name Player
extends BaseCharacter
@export var runspeed=300
@export var Attack_Speed:int=0
@export var invi_time:float=0.5
var attack_cooldown=1
@export var Effect={
	"Stun":0,
	"DamAmplify":0,
	"Slow":0,
	"Invicibility":0
}
@export var KeySkill={
	"HasBlade":false
}

func can_attack():
	return KeySkill["HasBlade"]&& Effect["Stun"]<=0
@export var CoolDown={
	"Dash":0
}
@export var InitCoolDown={
	"Dash":2
}
var jump_count=0
var dashed_on_air=false
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
		_updatecooldown(delta)
		
func take_damage(damage: int) -> void:
	if(Effect["Invicibility"]>0):
		super.take_damage(damage)
		
func _updatecooldown(delta:float):
	for key in CoolDown:	
		CoolDown[key]-=delta
		if CoolDown[key]<=0:
			CoolDown[key]=0

func set_cool_down(skillname:String):
	CoolDown[skillname]=InitCoolDown[skillname]
	
func save_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y],
		"has_blade": KeySkill["HasBlade"],
		"health": health
	}

func load_state(data: Dictionary) -> void:
	"""Load player state from checkpoint data"""
	if data.has("position"):
		var pos_array = data["position"]
		global_position = Vector2(pos_array[0], pos_array[1])
	if data.has("has_blade"):
		if data["has_blade"] == true:
			# GỌI HÀM NÀY ĐỂ HIỂN THỊ LẠI KIẾM
			_collect_blade() 
		else:
			KeySkill["HasBlade"] = false
	if data.has("health"):
		health = data["health"]
