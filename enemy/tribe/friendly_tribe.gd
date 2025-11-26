extends EnemyCharacter

func _ready() -> void:
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	invincible = true
	
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if fsm.current_state.name != "surprise" and fsm.current_state.name != "flee":
		fsm.change_state(fsm.states.surprise)

func _on_player_not_in_sight() -> void:
	if fsm.current_state.name == "flee" or fsm.current_state.name == "surprise":
		fsm.change_state(fsm.states.run)
		
func _on_hurt_area_2d_hurt(direction: Vector2, damage: float) -> void:
	# Turn to face attacker if hit from behind (immediately, before knockback)
	# Direction points FROM attacker TO us, so negate to get attacker's position
	if direction.x != 0:
		var attacker_side = -sign(direction.x)
		if attacker_side != self.direction:
			change_direction(attacker_side)
	
	_take_damage_from_dir(direction, damage)
	fsm.change_state(fsm.states.hurt)
