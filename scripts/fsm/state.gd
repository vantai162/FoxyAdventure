extends Node
class_name FSMState

## Base state class for Finite State Machine states

var fsm: FSM = null
var obj: BaseCharacter = null
var timer: float = 0.0

@export_group("Audio Settings")
@export var state_sound: AudioStream ## Kéo file .wav/.mp3 vào đây
@export var is_looping_sound: bool = false ## Dùng cho tiếng chạy bộ (Run)

func _enter() -> void:
	# Tự động phát nhạc khi vào State
	if state_sound and obj:
		if is_looping_sound:
			# Nếu là nhạc loop (bước chân), không random pitch để tránh nghe lạ tai
			obj.play_sfx(state_sound, false)
		else:
			# Nhạc one-shot (nhảy, dash)
			obj.play_sfx(state_sound)
	pass

func _exit() -> void:
	# Nếu là nhạc loop (như chạy bộ), khi thoát state phải tắt đi
	if is_looping_sound and obj:
		obj.stop_sfx()
	pass

func _update( _delta ):
	pass

# Update timer and return true if timer is finished
func update_timer(delta: float) -> bool:
	if timer <= 0:
		return false
	timer -= delta
	if timer <= 0:
		return true
	return false


func change_state(new_state: FSMState) -> void:
	#neu player duoi 0 mau chac chac phai dead
	if obj.health <= 0 and fsm.states.has("dead"):
		if fsm.current_state == fsm.states.dead:
			return
		fsm.change_state(fsm.states.dead)
		return
	fsm.change_state(new_state)
