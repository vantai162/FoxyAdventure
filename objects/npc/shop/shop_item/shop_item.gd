extends Control

# set từ ShopUI khi instantiate
var key:String
var item_type = ShopSystem.itemType.Skill # hoặc .skins
var price:int 
var stock:int  
var description: String = ""

@onready var price_label = $VBoxContainer/PriceLabel
@onready var name_label = $VBoxContainer/NameLabel
@onready var stock_label = $VBoxContainer/StockLabel
@onready var buy_button = $VBoxContainer/BuyButton
@onready var icon = $VBoxContainer/TextureRect

func _ready():
	buy_button.pressed.connect(_on_buy_pressed)
	buy_button.add_theme_stylebox_override("normal", create_shop_style())
	connect("mouse_entered", _on_mouse_entered)
	connect("mouse_exited", _on_mouse_exited)
	_update_ui()

func create_shop_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("4b3d33")
	style.set_border_width_all(2)
	style.border_color = Color("2d221a")
	style.corner_radius_top_left = 2
	style.corner_radius_bottom_right = 2
	return style

func _update_ui():
	price_label.text = "Giá: " + str(price)
	name_label.text = str(key)
	if item_type == ShopSystem.itemType.Skill:
		stock_label.text = "x" + str(stock)
		buy_button.disabled = (stock <= 0)
	elif item_type == ShopSystem.itemType.skins:
		stock_label.text = ""
		if GameManager.skin_manager.is_skin_bought(key):
			buy_button.disabled = true
	
	
func set_icon(tex:CompressedTexture2D):
	print(tex)
	print(icon.texture)
	icon.texture = tex

func _on_buy_pressed():
	var money = GameManager.player.inventory.get_coin()
	var result = ShopSystem.BuyItem(money, item_type, key)

	match result:
		ShopSystem.TransactionResult.Successful:
			# trừ tiền (bạn phải cập nhật money ở GameManager)
			GameManager.player.inventory.use_coin(price)
			# update UI stock, coin display (ShopUI nên lắng nghe)
			if item_type == ShopSystem.itemType.Skill and stock_label:
				stock -= 1
				stock_label.text = "x" + str(stock)
				if stock <= 0:
					buy_button.disabled = true
			elif item_type == ShopSystem.itemType.skins:
				buy_button.disabled = true
				GameManager.player.change_skin(key,true)
			_show_popup("Mua thành công!")
		ShopSystem.TransactionResult.AlreadyBought:
			_show_popup("Bạn đã mua item này rồi.")
		ShopSystem.TransactionResult.NotEnoughMoney:
			_show_popup("Không đủ tiền.")
		ShopSystem.TransactionResult.NotUnlockedYet:
			_show_popup("Chưa mở khóa item.")
		ShopSystem.TransactionResult.OutofStock:
			_show_popup("Hết hàng.")
		_:
			_show_popup("Lỗi không xác định.")

func _show_popup(text:String):
	var dlg = AcceptDialog.new()
	dlg.dialog_text = text
	dlg.size = Vector2(270, 100)
	dlg.borderless = true
	dlg.title = ""
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("4b3d33")   # nền nâu
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color("2d221a")
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_top = 20 
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_bottom = 10
	dlg.add_theme_stylebox_override("panel", panel_style)
	var label = dlg.get_label()
	var font = load("res://assets/fonts/Roboto_Mono/static/RobotoMono-Bold.ttf") as FontFile

	# Override font cho nội dung text
	label.add_theme_font_override("font", font)
	label.add_theme_color_override("font_color", Color("e0d4c0"))
	
	
	var ok_button = dlg.get_ok_button()
	if ok_button:
		ok_button.add_theme_stylebox_override("normal", create_shop_style())
		ok_button.add_theme_color_override("font_color", Color("e0d4c0")) # chữ màu kem
		ok_button.size = Vector2(100, 100)
	
	add_child(dlg)
	dlg.popup_centered()
	
func _on_mouse_entered():
	_show_tooltip()

func _on_mouse_exited():
	_hide_tooltip()
	
func _show_tooltip():
	var tooltip = PopupPanel.new()
	tooltip.name = "Tooltip"
	var label = Label.new()
	
	# --- Style giống panel ---
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("4b3d33")   # nền nâu
	panel_style.set_border_width_all(2)
	panel_style.border_color = Color("2d221a")
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_top = 10
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_bottom = 10
	tooltip.add_theme_stylebox_override("panel", panel_style)
	
	label.text = description
	label.autowrap_mode = 3
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("e0d4c0"))
	var font = load("res://assets/fonts/Roboto_Mono/static/RobotoMono-Bold.ttf") as FontFile
	label.add_theme_font_override("font", font)
	label.custom_minimum_size = Vector2(180, 0)  # giới hạn chiều ngang, chiều cao tự động
	tooltip.add_child(label)
	add_child(tooltip)
	await get_tree().process_frame
	var label_size = label.get_minimum_size()
	var final_size = label_size + Vector2(20, 20) # cộng thêm margin
	tooltip.popup(Rect2(get_global_mouse_position(), final_size))

func _hide_tooltip():
	if has_node("Tooltip"):
		get_node("Tooltip").queue_free()
