extends EnemyState

## King Crab Idle - Weighted attack selection with anti-repeat and anti-combo logic
##
## PHASE DESIGN (organic, not robotic):
## Phase 1 (Aggressive Melee): Dive, Bubble, Claw, (rare) Coconut
## Phase 2 (Chaotic Overwhelm): Roll Bounce, Coconut, Spawn, Bubble
##
## ANTI-ROBOTIC RULES:
## 1. Can't repeat same attack twice in a row
## 2. Idle duration has variance (±35%) - prevents rhythm exploitation
## 3. Context-aware fallbacks (no tree = no coconut)
##
## MERCY RULES (smarter, not harder):
## 1. If player just got hit recently, give breathing room (longer idle)
## 2. Track recent attacks - avoid back-to-back high-pressure combos
## 3. Aggressive attacks (dive, claw) less likely after player damage

## Attack weight tables - higher = more likely
## Balanced for "impressive but fair" feel
const PHASE_1_WEIGHTS := {
	"dive": 35,      # Signature move - flashy, learnable
	"bubble": 20,    # Reduced from 30 - annoying if too frequent
	"claw": 30,      # Satisfying to dodge, clear punish window
	"coconut": 15,   # Slightly more common - it's fun to dodge
}

const PHASE_2_WEIGHTS := {
	"rollbounce": 35,  # Signature phase 2 move
	"bubble": 15,      # Reduced - don't spam traps
	"coconut": 25,     # Now more tuned, can appear more
	"summon": 25,      # Mini crabs add chaos, not damage
}

## Recent attack tracking for anti-combo
var attack_history: Array[String] = []
const MAX_HISTORY: int = 3

## High-pressure attacks that shouldn't combo together
const AGGRESSIVE_ATTACKS := ["dive", "claw", "rollbounce"]


func _enter() -> void:
	obj.change_animation("idle")
	obj.velocity = Vector2.ZERO
	
	# Calculate idle time with smart variance
	var base_idle = obj.idle_duration
	var variance_percent = 0.35  # ±35% variance for organic feel
	
	# MERCY: If player was recently hurt, give them more breathing room
	if _player_recently_hurt():
		base_idle *= 1.4  # 40% longer idle
		variance_percent = 0.15  # Less random, more consistent mercy
	
	var variance = base_idle * variance_percent
	timer = base_idle + randf_range(-variance, variance)


func _update(delta: float) -> void:
	if update_timer(delta):
		_choose_next_action()


func _player_recently_hurt() -> bool:
	## Check if player was hurt in last ~2 seconds
	## Uses the invincibility effect as indicator
	if obj.found_player and obj.found_player.has_method("get"):
		var effect = obj.found_player.Effect
		if effect and effect.has("Invicibility") and effect["Invicibility"] > 0:
			return true
	return false


func _choose_next_action() -> void:
	var weights: Dictionary
	var state_map: Dictionary
	
	if obj.current_phase == 1:
		weights = PHASE_1_WEIGHTS.duplicate()
		state_map = {
			"dive": fsm.states.diveattack,
			"bubble": fsm.states.bubbleattack,
			"claw": fsm.states.clawattack,
			"coconut": "tree_required",  # Special handling
		}
	else:
		weights = PHASE_2_WEIGHTS.duplicate()
		state_map = {
			"rollbounce": fsm.states.rollbounce,
			"bubble": fsm.states.bubbleattack,
			"coconut": "tree_required",
			"summon": fsm.states.summonminicrab,
		}
	
	# ANTI-REPEAT: Remove last attack from pool
	if obj.last_attack in weights:
		weights.erase(obj.last_attack)
	
	# ANTI-COMBO: Reduce weight of aggressive attacks if recent history is aggressive
	if _was_recent_attack_aggressive():
		for attack_key in AGGRESSIVE_ATTACKS:
			if attack_key in weights:
				weights[attack_key] = int(weights[attack_key] * 0.4)  # 60% reduction
	
	# MERCY: If player just got hurt, heavily penalize aggressive attacks
	if _player_recently_hurt():
		for attack_key in AGGRESSIVE_ATTACKS:
			if attack_key in weights:
				weights[attack_key] = int(weights[attack_key] * 0.3)  # 70% reduction
	
	# CONTEXT: Check if coconut throw is viable (needs tree)
	if "coconut" in weights:
		if not obj.find_nearest_tree():
			weights.erase("coconut")
	
	# Pick attack using weighted random
	var chosen_key = _weighted_random_pick(weights)
	
	if chosen_key == "":
		# Fallback if somehow all weights removed
		chosen_key = "bubble" if obj.current_phase == 1 else "summon"
	
	# Track for anti-repeat and anti-combo
	obj.last_attack = chosen_key
	_record_attack(chosen_key)
	
	# Execute the chosen attack
	if chosen_key == "coconut":
		# Coconut requires walking to tree first
		change_state(fsm.states.walktotree)
	else:
		var target_state = state_map.get(chosen_key)
		if target_state and target_state is FSMState:
			change_state(target_state)
		else:
			# Fallback
			change_state(fsm.states.bubbleattack)


func _record_attack(attack_key: String) -> void:
	attack_history.push_back(attack_key)
	if attack_history.size() > MAX_HISTORY:
		attack_history.pop_front()


func _was_recent_attack_aggressive() -> bool:
	## Returns true if the last attack was a high-pressure move
	if attack_history.is_empty():
		return false
	return attack_history.back() in AGGRESSIVE_ATTACKS


func _weighted_random_pick(weights: Dictionary) -> String:
	## Returns a key from weights dict based on weighted probability
	if weights.is_empty():
		return ""
	
	var total_weight: int = 0
	for w in weights.values():
		total_weight += w
	
	if total_weight <= 0:
		return weights.keys()[0]
	
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	
	for key in weights.keys():
		cumulative += weights[key]
		if roll < cumulative:
			return key
	
	# Fallback (shouldn't reach here)
	return weights.keys()[0]
