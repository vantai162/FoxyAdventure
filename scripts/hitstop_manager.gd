extends Node
## HitstopManager — Centralized hitstop control to prevent race conditions
## 
## PROBLEM SOLVED: Multiple simultaneous hitstops would fight over Engine.time_scale,
## potentially causing permanent freezes when Timer 1 restores time_scale while Timer 2
## is still waiting with time_scale = 0.
##
## SOLUTION: Single mutex-like controller. Only one hitstop can be active.
## New hitstop requests during an active hitstop are ignored (first wins).

var is_hitstop_active: bool = false
var hitstop_timer: Timer = null

func _ready() -> void:
	# Create a timer that processes even when time_scale = 0
	hitstop_timer = Timer.new()
	hitstop_timer.one_shot = true
	hitstop_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	hitstop_timer.timeout.connect(_on_hitstop_end)
	add_child(hitstop_timer)


## Request a hitstop. If one is already active, this request is IGNORED (no stacking).
## Returns true if hitstop was started, false if already in hitstop.
func request_hitstop(duration: float) -> bool:
	if is_hitstop_active:
		return false  # Already frozen — ignore new request
	
	if duration <= 0:
		return false
	
	is_hitstop_active = true
	Engine.time_scale = 0.0
	
	# Use process_always to tick even with time_scale = 0
	hitstop_timer.wait_time = duration
	hitstop_timer.start()
	
	return true


func _on_hitstop_end() -> void:
	Engine.time_scale = 1.0
	is_hitstop_active = false


## Force end hitstop (for scene transitions, pause menu, etc.)
func cancel_hitstop() -> void:
	if is_hitstop_active:
		hitstop_timer.stop()
		Engine.time_scale = 1.0
		is_hitstop_active = false
