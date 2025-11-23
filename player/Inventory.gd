class_name Inventory
@export var KeySkillUnlocked={
	"Dash":false,
	"HasCollectedBlade":false,
	"DoubleJump":false
}

@export var AmountItem={
	"Coin":0,
	"Key":0
}

func add_new_key_skill(skill_name:String):
	if(KeySkillUnlocked.get(skill_name)!=null):
		print("already has the skill in the pool")
	else:
		KeySkillUnlocked[skill_name]=false

func add_new_amount_item(item_name:String):
	if(AmountItem.get(item_name)==null):
		print("already has the item in item pool")
	else:
		AmountItem[item_name]=0

func unlock_a_key_skill(skill_name:String):
	if(KeySkillUnlocked.has(skill_name)):
		KeySkillUnlocked=true
	else:
		print("Key skill not found")
		
func adjust_amount_item(item_name:String,amount:int):
	if(AmountItem.has(item_name)):
		if AmountItem[item_name]+amount>0:
			AmountItem[item_name]+=amount
			print(item_name)
			print(AmountItem[item_name])
		else:
			print("Not enough item")
	else:
		print("Amount item not found")

func _save_inventory()->Dictionary:
	return {
		"AmountItem":AmountItem,
		"KeySkillUnlocked":KeySkillUnlocked
	}

func _load_inventory(data:Dictionary):
	if(data.has("AmountItem")):
		AmountItem=data["AmountItem"]
	if(data.has("KeySkillUnlocked")):
		KeySkillUnlocked=data["KeySkillUnlocked"]
