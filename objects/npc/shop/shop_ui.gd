extends Control

@onready var items_grid = $TabContainer/ItemPanel/GridContainer
@onready var skins_grid = $TabContainer/SkinPanel/GridContainer
@onready var skin_panel = $TabContainer/SkinPanel
@onready var item_panel = $TabContainer/ItemPanel
@onready var tab_container = $TabContainer
@onready var shop_item_scene = preload("res://objects/npc/shop/shop_item/shop_item.tscn")

func _ready():
	_load_skill_items()
	_load_skin_items()
	var tab_style = StyleBoxFlat.new()
	tab_style.bg_color = Color("4b3d33")
	tab_style.set_border_width_all(2)
	tab_style.border_color = Color("2d221a")
	tab_style.corner_radius_top_left = 4
	tab_style.corner_radius_top_right = 4

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("2d221a") # nền tối hơn
	bg_style.set_border_width_all(2)
	bg_style.border_color = Color("4b3d33")
	
	tab_container.add_theme_stylebox_override("tab_unselected", tab_style)
	tab_container.add_theme_stylebox_override("tab_selected", tab_style)
	tab_container.add_theme_stylebox_override("panel", bg_style)
	
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("4b3d33")
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color("2d221a")
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	skin_panel.add_theme_stylebox_override("panel", panel_style)
	item_panel.add_theme_stylebox_override("panel", panel_style)
	
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
