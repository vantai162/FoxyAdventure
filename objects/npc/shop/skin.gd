class_name skin
extends Node
enum Rarity{COMMON,UNCOMMON,RARE,EPIC,LEGEND}
@export var rarity:Rarity
@export var value:int
@export var Name:String
var SaveDict={
	"Unlocked_To_Buy":false,
	"Bought":false
}
func UnlockToBuy():
	SaveDict["Unlocked_To_Buy"]=true

func Buy():
	SaveDict["Bought"]=true

func load_skin_status(data:Dictionary):
	if(!data.has("Unlocked_To_Buy")||!data.has("Bought")):
		print("May be you use wrong save file or wrong field")
	else:
		SaveDict["Unlocked_To_Buy"]=data["Unlocked_To_Buy"]
		SaveDict["Bought"]=data["Bought"]

func save_skin_status():
	return SaveDict
