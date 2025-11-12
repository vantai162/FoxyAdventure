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

# Blade inventory system
var blade_count: int = 0
var max_blade_capacity: int = 1
var has_unlocked_blade: bool = false  # Track if player ever collected blade (for sprite switching)



func can_attack():
	return blade_count > 0 && Effect["Stun"] <= 0

func can_throw_blade():
	return blade_count > 0 && Effect["Stun"] <= 0

func consume_blade():
	if blade_count > 0:
		blade_count -= 1

func return_blade():
	if blade_count < max_blade_capacity:
		blade_count += 1

func increase_blade_capacity():
	max_blade_capacity = min(max_blade_capacity + 1, 3)
	# Also grant one blade when capacity increases
	return_blade()
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
	$Direction/HitArea2D/CollisionShape2D.disabled=true
	
func _collect_blade():
	if not has_unlocked_blade:
		has_unlocked_blade = true
		set_animated_sprite($Direction/BladeAnimatedSprite2D)
	return_blade()

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
	if(Effect["Invicibility"]<=0):
		super.take_damage(damage)
		fsm.change_state(fsm.states.hurt)
		
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
		"blade_count": blade_count,
		"max_blade_capacity": max_blade_capacity,
		"has_unlocked_blade": has_unlocked_blade,
		"health": health
	}

func load_state(data: Dictionary) -> void:
	"""Load player state from checkpoint data"""
	if data.has("position"):
		var pos_array = data["position"]
		global_position = Vector2(pos_array[0], pos_array[1])
	
	if data.has("blade_count"):
		blade_count = data["blade_count"]
	if data.has("max_blade_capacity"):
		max_blade_capacity = data["max_blade_capacity"]
	if data.has("has_unlocked_blade"):
		has_unlocked_blade = data["has_unlocked_blade"]
		if has_unlocked_blade:
			set_animated_sprite($Direction/BladeAnimatedSprite2D)
	
	# Legacy support for old save format
	if data.has("has_blade") && data["has_blade"] == true:
		has_unlocked_blade = true
		blade_count = max(blade_count, 1)
		set_animated_sprite($Direction/BladeAnimatedSprite2D)
	
	if data.has("health"):
		health = data["health"]


func _on_hurt_area_2d_hurt(direction: Vector2, damage: float) -> void:
	print("hit")
	fsm.current_state.take_damage(damage)
	pass # Replace with function body.
