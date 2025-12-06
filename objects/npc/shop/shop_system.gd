extends Node2D
enum itemType{skins,Skill}
enum TransactionResult{Successful,NotUnlockedYet,AlreadyBought,NotEnoughMoney,OutofStock,UnknowError}
@export var Stock = {
	"power_up": 5,
	"hp_up": 5
}

@export var Linker={
	"hp_up": preload("res://objects/npc/shop/shop_item/hp_up.tscn"),
	"power_up": preload("res://objects/npc/shop/shop_item/power_up.tscn")
}#link name to PackedScene
var objLinker={}
func BuyItem(money:int,type:itemType,key:String)->TransactionResult:
	if (type==itemType.skins):
		if GameManager.skin_manager._check_skin_status(key,money)==SkinManager.SkinState.CanBuy:
			GameManager.skin_manager.cur_skin_data[key].Buy()
			GameManager.skin_manager._save_skin_data()
			return TransactionResult.Successful
		elif  GameManager.skin_manager._check_skin_status(key,money)==SkinManager.SkinState.AlreadyBought:
			return TransactionResult.AlreadyBought
		elif GameManager.skin_manager._check_skin_status(key,money)==SkinManager.SkinState.TooExpensive:
			return TransactionResult.NotEnoughMoney
		elif GameManager.skin_manager._check_skin_status(key,money)==SkinManager.SkinState.CantBuy:
			return TransactionResult.NotUnlockedYet
		return TransactionResult.UnknowError
	else:
		if money>=objLinker[key].value && Stock[key]>0:
			objLinker[key].conduct_effect()
			Stock[key]=Stock[key]-1
			return TransactionResult.Successful
		elif money<objLinker[key].value:
			return TransactionResult.NotEnoughMoney
		elif Stock[key]<=0:
			return TransactionResult.OutofStock
		return TransactionResult.UnknowError

func _ready() -> void:
	for key in Linker:
		objLinker[key]=Linker[key].instantiate()
		

	
