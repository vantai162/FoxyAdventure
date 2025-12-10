class_name Inventory

@export var AmountItem={
	"Coin":0,
	"Key":0,
}
signal item_amount_changed(item_name, new_amount)


func add_new_amount_item(item_name:String):
	if AmountItem.has(item_name):
		print("Already has the item in item pool: ", item_name)
	else:
		AmountItem[item_name] = 0
		print("Added new item to pool: ", item_name)
		
func _save_inventory()->Dictionary:
	return {
		"AmountItem":AmountItem,
	}

func _load_inventory(data:Dictionary):
	if(data.has("AmountItem")):
		AmountItem=data["AmountItem"]

		
func adjust_amount_item(item_name:String, amount:int):
	# Auto-create item slot if it doesn't exist (for keyed items like Key_gold, Key_silver, etc.)
	if not AmountItem.has(item_name):
		if item_name.begins_with("Key_"):
			# Keyed items: auto-register since designers can create unique key IDs
			AmountItem[item_name] = 0
			print("Auto-registered keyed item: ", item_name)
		else:
			print("Amount item not found: ", item_name)
			return
	
	if AmountItem[item_name] + amount >= 0:
		AmountItem[item_name] += amount
		print(item_name, ": ", AmountItem[item_name])
		item_amount_changed.emit(item_name, AmountItem[item_name])
	else:
		print("Not enough item: ", item_name)

## Check if player has ANY generic key (used by doors/chests that don't require specific key IDs)
func has_key() -> bool:
	return AmountItem.get("Key", 0) > 0

## Check if player has a specific keyed key (e.g., "Key_gold", "Key_boss_room")
func has_keyed_key(key_id: String) -> bool:
	if key_id.is_empty():
		return has_key()
	return AmountItem.get("Key_" + key_id, 0) > 0

func use_key(amount: int = 1):
	if AmountItem.get("Key", 0) >= amount:
		AmountItem["Key"] -= amount
		item_amount_changed.emit("Key", AmountItem["Key"])
	else:
		print("Not enough keys to use")

## Use a specific keyed key
func use_keyed_key(key_id: String, amount: int = 1):
	if key_id.is_empty():
		use_key(amount)
		return
	
	var full_key = "Key_" + key_id
	if AmountItem.get(full_key, 0) >= amount:
		AmountItem[full_key] -= amount
		item_amount_changed.emit(full_key, AmountItem[full_key])
	else:
		print("Not enough keyed keys to use: ", full_key)
		
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
	
func get_amount(item_name: String) -> int:
	return AmountItem.get(item_name, 0)
