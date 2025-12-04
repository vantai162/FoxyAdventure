# save_system.gd
extends Node

## Save system for persistent checkpoint data
## HÃY ĐĂNG KÝ SCRIPT NÀY LÀM AUTOLOAD VỚI TÊN "SaveSystem"

const SAVE_FILE = "user://checkpoint_save.dat"
const SETTING_FILE="user://setting.dat"
const SKIN_FILE="user://skin.dat"
# Save checkpoint data to file
func save_checkpoint_data(data: Dictionary) -> void:
	# Mở file để ghi
	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	
	if file:
		# Dùng store_var để lưu Dictionary (hỗ trợ cả Vector2, v.v.)
		file.store_var(data)
		file.close() # Đừng quên đóng file
	else:
		printerr("LỖI: Không thể mở file để lưu: ", SAVE_FILE)

# Load checkpoint data from file
func load_checkpoint_data() -> Dictionary:
	# Kiểm tra file có tồn tại không
	if not has_save_file(SAVE_FILE):
		return {} # Trả về Dictionary rỗng nếu không có file save

	# Mở file để đọc
	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	
	if file:
		# Dùng get_var để đọc lại Dictionary
		var data = file.get_var()
		file.close()
		
		# Kiểm tra xem dữ liệu có phải là Dictionary không
		if data is Dictionary:
			return data
		else:
			printerr("LỖI: File save bị hỏng, dữ liệu không phải Dictionary.")
			return {}
	else:
		printerr("LỖI: Không thể mở file để tải: ", SAVE_FILE)
		return {}

# Check if save file exists
func has_save_file(path:String) -> bool:
	return FileAccess.file_exists(path)

# Delete save file
func delete_save_file(path:String) -> void:
	if has_save_file(path):
		var err = DirAccess.remove_absolute(path)
		if err == OK:
			pass
		else:
			printerr("LỖI: Không thể xóa save file.")

func save_setting(data:Dictionary):
	var file = FileAccess.open(SETTING_FILE, FileAccess.WRITE)
	
	if file:
		# Dùng store_var để lưu Dictionary (hỗ trợ cả Vector2, v.v.)
		file.store_var(data)
		file.close() # Đừng quên đóng file
	else:
		printerr("LỖI: Không thể mở file để lưu: ", SETTING_FILE)

func load_setting()->Dictionary:
	if not has_save_file(SETTING_FILE):
		return {} # Trả về Dictionary rỗng nếu không có file save

	# Mở file để đọc
	var file = FileAccess.open(SETTING_FILE, FileAccess.READ)
	
	if file:
		# Dùng get_var để đọc lại Dictionary
		var data = file.get_var()
		file.close()
		
		# Kiểm tra xem dữ liệu có phải là Dictionary không
		if data is Dictionary:
			return data
		else:
			printerr("LỖI: File save bị hỏng, dữ liệu không phải Dictionary.")
			return {}
	else:
		printerr("LỖI: Không thể mở file để tải: ", SETTING_FILE)
		return {}

func save_skin_data(data:Dictionary):
	var file = FileAccess.open(SKIN_FILE, FileAccess.WRITE)
	
	if file:
		# Dùng store_var để lưu Dictionary (hỗ trợ cả Vector2, v.v.)
		file.store_var(data)
		file.close() # Đừng quên đóng file
	else:
		printerr("LỖI: Không thể mở file để lưu: ", SKIN_FILE)
	
func load_skin_data():
	if not has_save_file(SKIN_FILE):
		return {} # Trả về Dictionary rỗng nếu không có file save

	# Mở file để đọc
	var file = FileAccess.open(SKIN_FILE, FileAccess.READ)
	
	if file:
		# Dùng get_var để đọc lại Dictionary
		var data = file.get_var()
		file.close()
		
		# Kiểm tra xem dữ liệu có phải là Dictionary không
		if data is Dictionary:
			return data
		else:
			printerr("LỖI: File save bị hỏng, dữ liệu không phải Dictionary.")
			return {}
	else:
		printerr("LỖI: Không thể mở file để tải: ", SKIN_FILE)
		return {}
		
