extends Node
@export var skinDict:Dictionary={}# use skin_name:PackedScene
var cur_skin_data:Dictionary#used skin_name:Skin
enum SkinState{CantBuy,AlreadyBought,CanBuy,TooExpensive}
func _load_skin_data_from_save(data:Dictionary):
	for skin_name in skinDict:
		cur_skin_data[skin_name]=skinDict[skin_name].instantiate()
		if(data.has(skin_name)):
			cur_skin_data[skin_name].load_skin_status(data[skin_name])

func _save_skin_data()->Dictionary:
	var saveDict:Dictionary
	for skin_name in cur_skin_data:
		saveDict[skin_name]=cur_skin_data[skin_name].save_skin_status()#skin_name:savedict
	return saveDict
	
func _check_skin_status(skin_name:String,value:int)->SkinState:
	if(!cur_skin_data[skin_name].SaveDict["Unlocked_To_Buy"]):
		return SkinState.CantBuy
	if(cur_skin_data[skin_name].SaveDict["Bought"]):
		return SkinState.AlreadyBought
	if(value<cur_skin_data[skin_name].value):
		return SkinState.TooExpensive
	return SkinState.CanBuy
