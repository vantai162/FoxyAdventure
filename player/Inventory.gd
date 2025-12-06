class_name Inventory

@export var AmountItem={
	"Coin":0,
	"Key":0
}
signal item_amount_changed(item_name, new_amount)


func add_new_amount_item(item_name:String):
	if(AmountItem.get(item_name)==null):
		print("already has the item in item pool")
	else:
		AmountItem[item_name]=0
		
func _save_inventory()->Dictionary:
	return {
		"AmountItem":AmountItem,
	}

func _load_inventory(data:Dictionary):
	if(data.has("AmountItem")):
		AmountItem=data["AmountItem"]

		
func adjust_amount_item(item_name:String,amount:int):
	if(AmountItem.has(item_name)):
		if AmountItem[item_name]+amount>0:
			AmountItem[item_name]+=amount
			print(item_name)
			print(AmountItem[item_name])
			item_amount_changed.emit(item_name, AmountItem[item_name])
		else:
			print("Not enough item")
	else:
		print("Amount item not found")

func has_key():
	return AmountItem["Key"] > 0

func use_key(amount:int):
	if AmountItem.has("Key"):
		if AmountItem["Key"] >= amount:
			AmountItem["Key"] -= amount
			item_amount_changed.emit("Key", AmountItem["Key"])
		else:
			print("Not enough keys to use")
	else:
		print("Key item not found")
		
func use_coin(amount:int):
	if AmountItem.has("Coin"):
		if AmountItem["Coin"] >= amount:
			AmountItem["Coin"] -= amount
			item_amount_changed.emit("Coin", AmountItem["Coin"])
		else:
			print("Not enough coins to use")
	else:
		print("Coin item not found")

func get_coin():
	return AmountItem["Coin"]
