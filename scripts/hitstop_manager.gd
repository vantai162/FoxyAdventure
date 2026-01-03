extends Node
## HitstopManager — Centralized hitstop control to prevent race conditions
## 
## PROBLEM SOLVED: Multiple simultaneous hitstops would fight over Engine.time_scale,
## potentially causing permanent freezes when Timer 1 restores time_scale while Timer 2
## is still waiting with time_scale = 0.
##
## SOLUTION: Single mutex-like controller. Only one hitstop can be active.
## New hitstop requests during an active hitstop are ignored (first wins).
##
## CRITICAL FIX: Timer nodes do NOT work when Engine.time_scale = 0 because their
## delta becomes 0. We use SceneTree.create_timer() with ignore_time_scale=true instead.

var is_hitstop_active: bool = false
var active_timer: SceneTreeTimer = null


## Request a hitstop. If one is already active, this request is IGNORED (no stacking).
## Returns true if hitstop was started, false if already in hitstop.
func request_hitstop(duration: float) -> bool:
	if is_hitstop_active:
		return false  # Already frozen — ignore new request
	
	if duration <= 0:
		return false
	
	is_hitstop_active = true
	Engine.time_scale = 0.0
	
	# CRITICAL: Use SceneTreeTimer with ignore_time_scale=true
	# Signature: create_timer(time_sec, process_always, process_in_physics, ignore_time_scale)
	active_timer = get_tree().create_timer(duration, true, false, true)
	active_timer.timeout.connect(_on_hitstop_end)
	
	return true


func _on_hitstop_end() -> void:
	Engine.time_scale = 1.0
	is_hitstop_active = false
	active_timer = null


## Force end hitstop (for scene transitions, pause menu, etc.)
func cancel_hitstop() -> void:
	if is_hitstop_active:
		# SceneTreeTimer can't be stopped, but we can disconnect and reset immediately
		if active_timer and active_timer.timeout.is_connected(_on_hitstop_end):
			active_timer.timeout.disconnect(_on_hitstop_end)
		Engine.time_scale = 1.0
		is_hitstop_active = false
		active_timer = null
