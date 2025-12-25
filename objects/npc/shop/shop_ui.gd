extends Control

@onready var items_grid = $TabContainer/ItemPanel/GridContainer
@onready var skins_grid = $TabContainer/SkinPanel/GridContainer
@onready var shop_item_scene = preload("res://objects/npc/shop/shop_item/shop_item.tscn")

func _ready():
	_load_skill_items()
	_load_skin_items()

func _load_skill_items():
	#items_grid.remove_children()# nếu có hàm clear; nếu không thì remove_children()
	for key in ShopSystem.Linker.keys():
		var ui = shop_item_scene.instantiate()
		ui.key = key
		ui.item_type = ShopSystem.itemType.Skill
		var item_data = ShopSystem.objLinker[key]
		# lấy price từ objLinker
		ui.price = item_data.value
		ui.stock = ShopSystem.Stock.get(key, 0)
		ui.call_deferred("set_icon", ShopSystem.objLinker[key].icon)
		items_grid.add_child(ui)

func _load_skin_items():
	for key in GameManager.skin_manager.cur_skin_data.keys():
		var ui = shop_item_scene.instantiate()
		ui.key = key
		ui.item_type = ShopSystem.itemType.skins
		var skin_data = GameManager.skin_manager.cur_skin_data[key]
		ui.price = skin_data.value
		ui.stock = 1
		ui.call_deferred("set_icon", skin_data.icon)
		skins_grid.add_child(ui)
