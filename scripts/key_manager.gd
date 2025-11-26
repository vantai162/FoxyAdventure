class_name KeyManager
var KeyDict={}
var is_listening=false
var captured_key=-1

signal key_captured(keycode:int)
func _get_key_dictionary_from_input_map():
	var actions=InputMap.get_actions()#get all action
	for action in actions:
		if(action.begins_with("ui_")):
			continue
		var events=InputMap.action_get_events(action)
		for event in events:
			if event is InputEventKey:
					KeyDict[action]=event.physical_keycode

func _set_key(action:String,key:int):
	if action=="pause":
		print("You can not change the paused key")
	if KeyDict.size()==0:
		print("Oops!You dont have the KeyDictYet ")
	if key>0:
		var cur_input=InputEventKey.new()
		cur_input.physical_keycode=KeyDict[action]
		InputMap.action_erase_event(action,cur_input)
		var new_input=InputEventKey.new()
		new_input.physical_keycode=key
		InputMap.action_add_event(action,new_input)
		KeyDict[action]=key
		
func _listening_key(scene_tree:SceneTree)->int:
	is_listening=true
	captured_key=-1
	while captured_key==-1 and is_listening:
		await scene_tree.process_frame
	is_listening=false
	return captured_key

# Inside handle_input:
func handle_input(event: InputEvent):#call in the gameager when key_manager is listening
	if not is_listening:   # ← Check if we're listening
		return             # ← If not, ignore the input
	
	if event is InputEventKey and event.pressed and not event.echo:
		var key = event.physical_keycode
		
		if key == KEY_ESCAPE:
			captured_key = -1      # ← Cancel
			is_listening = false
			return
		captured_key = key

func listening_and_set(scene_tree:SceneTree,action:String)->int:#only call this function
	if KeyDict.size()==0:
		print("Oops!You dont have the KeyDictYet ")
	if not KeyDict.has(action):
		print("Action '", action, "' not found in KeyDict")
		return -1
	var keycode = await _listening_key(scene_tree)
	if keycode>0:
		_set_key(action,keycode)
	return keycode
	
func disableinput(exception:Array):
	for key in KeyDict.keys():
		if(key!="pause"&&!(key in exception)):
			InputMap.action_erase_events(key)

func reloadinputmapbykeydict():
	for key in KeyDict.keys():
		var event=InputEventKey.new()
		event.physical_keycode=KeyDict[key]
		InputMap.action_add_event(key,event)
				
func enableinput():
	reloadinputmapbykeydict()				
	
