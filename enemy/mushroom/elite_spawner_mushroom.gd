extends EnemyCharacter
class_name EliteSpawnerMushroom
## Elite Mushroom: "Aggressive Spawner Artillery"
## Aggressive pursuit, burst spawns on detection, continuous spawn pressure
## Death spawns 3 final minis + fade (no explosion)

@export var mini_mushroom_scene: PackedScene
@export var spawn_interval: float = 2.5  ## Time between spawns (FAST - constant pressure!)
@export var minis_per_wave: int = 2  ## Spawn 2 minis each wave (saturation attack)

var spawn_timer: float = 0.0
var has_burst_spawned: bool = false  ## Track if initial burst done

@onready var mini_factory = $Direction/MiniMushroomFactory

func _ready() -> void:
	# Start in sleep state
	fsm = FSM.new(self, $States, $States/Sleep)
	super._ready()
	
	# Override jump_speed for strategic artillery (lower than default 320)
	jump_speed = 250.0  ## Moderate jump height - not aggressive melee
	
	enable_check_player_in_sight()
	spawn_timer = spawn_interval  ## Ready to spawn on first detection

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# ONLY decrement spawn timer if player detected
	if found_player != null and spawn_timer > 0.0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_mini_wave()  ## Spawn full wave (2 minis)
			spawn_timer = spawn_interval

func _on_player_in_sight(_player_pos: Vector2) -> void:
	# Transition from sleep to surprise (alert reaction)
	if fsm and fsm.current_state and fsm.current_state.name.to_lower() == "sleep":
		if fsm.states.has("surprise"):
			fsm.change_state(fsm.states.surprise)
		# BURST SPAWN: Immediately spawn 2 minis on first detection
		if not has_burst_spawned:
			has_burst_spawned = true
			_spawn_mini_wave()  ## Instant threat!

func _on_player_not_in_sight() -> void:
	# Lost player → return to sleep (handled by pursuit state)
	pass

func _on_hurt_area_2d_hurt(direction: Vector2, damage: float) -> void:
	if direction.x != 0:
		var attacker_side = -sign(direction.x)
		if attacker_side != self.direction:
			change_direction(attacker_side)
	
	take_damage(damage)
	
	# Transition to hurt (no panic spawn)
	if fsm and fsm.current_state and fsm.states.has("hurt"):
		fsm.change_state(fsm.states.hurt)

func _spawn_mini_wave() -> void:
	## Spawn wave of minis (2 per wave for saturation artillery)
	## Spawns FROM ELITE'S FRONT with STAGGERED timing to avoid visual merge
	if not mini_factory:
		push_warning("EliteSpawnerMushroom: MiniMushroomFactory not found!")
		return
	
	var original_pos = mini_factory.global_position
	
	# Spawn positions: in front of elite + slight horizontal spread
	var front_offset = direction * 15  ## 15px in front of elite
	var horizontal_offsets = [0, direction * 8]  ## Second mini slightly ahead
	
	for i in range(minis_per_wave):
		# Spawn from elite's FRONT with slight offset
		mini_factory.global_position.x = original_pos.x + front_offset + horizontal_offsets[i]
		mini_factory.global_position.y = original_pos.y
		
		var mini = mini_factory.create()
		mini.initial_direction = direction
		
		# Stagger second mini spawn by 0.15s to avoid visual merge
		if i < minis_per_wave - 1:
			await get_tree().create_timer(0.15).timeout
	
	# Restore factory position
	mini_factory.global_position = original_pos
	_spawn_effect()

func _spawn_effect() -> void:
	## Brief scale pulse feedback
	var sprite = get_node("Direction/AnimatedSprite2D")
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
