extends RigidBody2D

## Water Bubble - Projectile that traps player on contact
##
## BEHAVIOR:
## 1. Spawns small, grows to full size during grow_time
## 2. After growing, starts moving in launch direction
## 3. On player contact: stops, traps player, applies Stun
## 4. After trap_duration or life_time: explodes and frees player
##
## Uses RigidBody2D in KINEMATIC mode - we control position directly

@export var speed: float = 300.0
@export var life_time: float = 3.0
@export var trap_duration: float = 2.0
@export var grow_time: float = 1.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var life_timer: Timer = $life_timer

var trapped_player: Node2D = null
var trap_timer: float = 0.0
var launch_velocity := Vector2.ZERO
var is_moving: bool = false
var is_exploding: bool = false


func _ready() -> void:
	# Use KINEMATIC mode - we control movement, not physics
	freeze = true
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	
	trap_timer = 0.0
	is_moving = false
	is_exploding = false
	
	# Start life timer
	if life_timer:
		life_timer.wait_time = life_time
		life_timer.start()
	
	# Start small
	sprite.play("idle")
	scale = Vector2(0.2, 0.2)
	_start_grow_effect()


func launch(direction: Vector2, bullet_speed: float) -> void:
	## Called by bubble_attack state after spawning
	launch_velocity = direction.normalized() * bullet_speed


func _start_grow_effect() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), grow_time)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.finished.connect(_on_grow_finished)


func _on_grow_finished() -> void:
	is_moving = true


func _physics_process(delta: float) -> void:
	# Hitstop: freeze in place when hit lands
	if HitstopManager.is_frozen(self):
		return
	
	if is_exploding:
		return
	
	# Handle trap timer
	if trap_timer > 0:
		trap_timer -= delta
		if trap_timer <= 0:
			explode()
			return
	
	# Move if not trapped anything
	if is_moving and trapped_player == null:
		global_position += launch_velocity * delta
	
	# Keep trapped player centered
	if trapped_player and is_instance_valid(trapped_player):
		trapped_player.global_position = global_position


func _on_life_timer_timeout() -> void:
	if not is_exploding:
		explode()


func explode() -> void:
	if is_exploding:
		return
	is_exploding = true
	is_moving = false
	
	# Free the trapped player
	if trapped_player and is_instance_valid(trapped_player):
		if trapped_player.has_method("_applyeffect"):
			# Clear bubble trap effect
			trapped_player.Effect["BubbleTrap"] = 0
		trapped_player = null
	
	# Play explosion animation
	sprite.play("explode")
	await sprite.animation_finished
	queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if is_exploding or trapped_player != null:
		return
	
	# Only trap players
	if not body.is_in_group("player"):
		return
	
	# Check if player is already stunned (don't double-trap)
	if body.has_method("_applyeffect"):
		if body.Effect.get("Stun", 0) > 0:
			return
		
		# Trap the player!
		trap_timer = trap_duration
		trapped_player = body
		is_moving = false
		launch_velocity = Vector2.ZERO
		
		# Apply stun and bubble trap effect
		AudioManager.play_sound("water_prison",20.0)
		body._applyeffect("Stun", trap_duration)
		body._applyeffect("BubbleTrap", trap_duration)
