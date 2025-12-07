extends EnemyCharacter
class_name EliteSpawnerMushroom
## Elite Mushroom: "The Spawner"
## Army builder: Pursues player, spawns mini kamikaze mushrooms
## NO self-destruct - elite survives and creates army over time
## Visual: Inverted colors + red glowing eye trail

@export var mini_mushroom_scene: PackedScene  ## Assign mini_mushroom.tscn
@export var spawn_interval: float = 4.0  ## Time between spawns
@export var max_active_minions: int = 5  ## Limit to avoid spam
@export var panic_spawn_count: int = 2  ## Burst spawn when hurt

var spawn_timer: float = 0.0
var active_minions: Array[Node] = []

func _ready() -> void:
	# Start in run state (no sleep - active threat)
	fsm = FSM.new(self, $States, $States/Run)
	super._ready()
	
	# Enable player detection for pursuit
	enable_check_player_in_sight()
	
	# Initialize spawn timer (first spawn after 2s)
	spawn_timer = 2.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Clean up dead minions from tracking array
	_cleanup_dead_minions()
	
	# Spawn timer countdown
	if spawn_timer > 0.0:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and active_minions.size() < max_active_minions:
			_spawn_mini_mushroom()
			spawn_timer = spawn_interval

# Override player detection for pursuit behavior
func _on_player_in_sight(_player_pos: Vector2) -> void:
	if found_player:
		# Face player
		if found_player.global_position.x > global_position.x:
			change_direction(1)
		else:
			change_direction(-1)
	
	# Pursuit state (menacing approach)
	if fsm.current_state == fsm.states.run:
		if fsm.states.has("spawner_pursue"):
			fsm.change_state(fsm.states.spawnerpursue)

func _on_player_not_in_sight() -> void:
	# Return to patrol when player lost
	if fsm.current_state.name == "spawner_pursue":
		fsm.change_state(fsm.states.run)

# Override hurt to trigger panic spawn
func _on_hurt_area_2d_hurt(direction: Vector2, damage: float) -> void:
	if direction.x != 0:
		var attacker_side = -sign(direction.x)
		if attacker_side != self.direction:
			change_direction(attacker_side)
	
	take_damage(damage)
	
	# Panic spawn: Burst 2 mushrooms immediately
	_panic_spawn()
	
	# Then transition to hurt state
	if fsm.states.has("hurt"):
		fsm.change_state(fsm.states.hurt)

func _spawn_mini_mushroom() -> void:
	## Spawn single mini mushroom at current position
	if not mini_mushroom_scene:
		push_warning("EliteSpawnerMushroom: mini_mushroom_scene not assigned!")
		return
	
	if active_minions.size() >= max_active_minions:
		return  # At capacity
	
	var mini = mini_mushroom_scene.instantiate()
	mini.global_position = global_position + Vector2(0, -10)  # Spawn slightly above
	get_parent().add_child(mini)
	
	# Track minion
	active_minions.append(mini)
	
	# Visual feedback: Small spawn puff
	_spawn_effect()

func _panic_spawn() -> void:
	## Emergency spawn burst when hurt
	for i in range(panic_spawn_count):
		if active_minions.size() >= max_active_minions:
			break
		
		var mini = mini_mushroom_scene.instantiate()
		# Offset spawns left/right
		var offset = Vector2((i - 1) * 20, -10)
		mini.global_position = global_position + offset
		get_parent().add_child(mini)
		active_minions.append(mini)
	
	_spawn_effect()

func _cleanup_dead_minions() -> void:
	## Remove dead/freed minions from tracking array
	for i in range(active_minions.size() - 1, -1, -1):
		if not is_instance_valid(active_minions[i]):
			active_minions.remove_at(i)

func _spawn_effect() -> void:
	## Visual feedback: Brief scale pulse on spawner
	var tween = create_tween()
	tween.tween_property($Direction/AnimatedSprite2D, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property($Direction/AnimatedSprite2D, "scale", Vector2(1.0, 1.0), 0.2)
