extends EnemyState

## Warlord Turtle Idle - Weighted attack selection with anti-repeat and mercy logic
##
## PHASE DESIGN (organic, not robotic):
## Phase 1: Bombs (primary), Rockets (secondary), Roar (close-range answer)
## Phase 2: Add water manipulation for arena control
##
## ANTI-ROBOTIC RULES:
## 1. Can't repeat same attack twice in a row
## 2. Idle duration has variance for organic feel
## 3. Context-aware (water cooldown, water raised state)
##
## MERCY RULES:
## 1. If player just got hit, give breathing room

## Attack weight tables - higher = more likely
const PHASE_1_WEIGHTS := {
	"skill1": 40,    # Bombs — primary attack, learnable patterns
	"skill2": 30,    # Rockets — secondary, requires positioning
	"roar": 30,      # Roar — shockwave, punishes melee
}

const PHASE_2_WEIGHTS := {
	"skill1": 25,       # Bombs — still reliable
	"skill2": 20,       # Rockets — less focus
	"roar": 20,         # Roar — spacing tool
	"raisewater": 20,   # Water control — arena manipulation
	"summonwhirlpool": 15,  # Whirlpool — requires water raised
}

## Track last attack to prevent repeats
var last_attack: String = ""


func _enter() -> void:
	obj.change_animation("idle")
	obj.velocity = Vector2.ZERO
	
	# Base idle with variance
	var base_idle = 1.0
	var variance = 0.35
	
	# MERCY: If player was recently hurt, longer idle
	if _player_recently_hurt():
		base_idle = 1.4
		variance = 0.15
	
	timer = base_idle + randf_range(-base_idle * variance, base_idle * variance)


func _update(delta: float) -> void:
	if update_timer(delta):
		_choose_next_action()


func _player_recently_hurt() -> bool:
	## Check if player has invincibility (just got hit)
	if obj.found_player and obj.found_player.has_method("get"):
		var effect = obj.found_player.get("Effect")
		if effect and effect is Dictionary and effect.has("Invicibility") and effect["Invicibility"] > 0:
			return true
	return false


func _choose_next_action() -> void:
	var weights: Dictionary
	
	if obj.current_phase == 1:
		weights = PHASE_1_WEIGHTS.duplicate()
	else:
		weights = PHASE_2_WEIGHTS.duplicate()
	
	# ANTI-REPEAT: Remove last attack from pool
	if last_attack in weights:
		weights.erase(last_attack)
	
	# CONTEXT: Water actions have requirements
	if "raisewater" in weights:
		if not obj.can_use_water_action():
			weights.erase("raisewater")
	
	if "summonwhirlpool" in weights:
		if not obj.water_raised:
			weights.erase("summonwhirlpool")
	
	# Pick using weighted random
	var chosen_key = _weighted_random_pick(weights)
	
	if chosen_key == "":
		chosen_key = "skill1"  # Fallback
	
	# Track for anti-repeat
	last_attack = chosen_key
	
	# Map to states
	var state_map := {
		"skill1": fsm.states.skill1,
		"skill2": fsm.states.skill2,
		"roar": fsm.states.roar if fsm.states.has("roar") else fsm.states.skill1,
		"raisewater": fsm.states.raisewater if fsm.states.has("raisewater") else fsm.states.skill1,
		"summonwhirlpool": fsm.states.summonwhirlpool if fsm.states.has("summonwhirlpool") else fsm.states.skill1,
	}
	
	var target_state = state_map.get(chosen_key, fsm.states.skill1)
	change_state(target_state)


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
	
	return weights.keys()[0]
