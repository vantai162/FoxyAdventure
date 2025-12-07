extends Control

# set từ ShopUI khi instantiate
var key:String
var item_type = ShopSystem.itemType.Skill # hoặc .skins
var price:int 
var stock:int  

@onready var price_label = $PriceLabel
@onready var name_label = $NameLabel
@onready var stock_label = $StockLabel
@onready var buy_button = $BuyButton
@onready var icon = $TextureRect

func _ready():
	buy_button.pressed.connect(_on_buy_pressed)
	print(icon)
	_update_ui()

func _update_ui():
	price_label.text += str(price)
	name_label.text = str(key)
	if stock_label:
		stock_label.text = "x" + str(stock)
	buy_button.disabled = (stock <= 0)
	
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
			if stock_label:
				stock -= 1
				stock_label.text = "x" + str(stock)
				if stock <= 0:
					buy_button.disabled = true
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
	add_child(dlg)
	dlg.popup_centered()
