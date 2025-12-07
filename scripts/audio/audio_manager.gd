extends Node

## AudioManager manages all audio in the game
## Supports SFX (sound effects) and Music with separate buses

@export var audio_database: AudioDatabase

# Audio players for SFX (can play multiple sounds at once)
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 16

# Audio player for Music (only plays one song at a time)
var music_player: AudioStreamPlayer = null

# Bus names
const SFX_BUS: String = "SFX"
const MUSIC_BUS: String = "Music"


var current_sfx_bus_name: String = SFX_BUS

var current_music_id: String = ""

func _ready() -> void:
	# Initialize music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = MUSIC_BUS
	add_child(music_player)
	
	# Initialize pool of SFX players
	for i in range(max_sfx_players):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(i)
		player.bus = SFX_BUS
		add_child(player)
		sfx_players.append(player)
	
	# Load audio database if not exists
	if audio_database == null:
		audio_database = load("res://data/audio/audio_database.tres") as AudioDatabase
	
	print("AudioManager initialized with ", max_sfx_players, " SFX players")


## Play sound by ID from database
func play_sound(sound_id: String, volume_db: float = 0.0) -> void:
	if audio_database == null:
		push_error("AudioDatabase not loaded!")
		return
	
	var audio_clip: AudioClip = audio_database.get_clip(sound_id)
	if audio_clip == null:
		push_error("Audio clip not found with ID: " + sound_id)
		return
	
	play_audio_clip(audio_clip, volume_db, false)


## Play sound by path directly
func play_sound_path(sound_path: String, volume_db: float = 0.0) -> void:
	var stream = load(sound_path) as AudioStream
	if stream == null:
		push_error("Cannot load audio from path: " + sound_path)
		return
	
	var audio_clip = AudioClip.new()
	audio_clip.stream = stream
	audio_clip.volume_db = volume_db
	
	play_audio_clip(audio_clip, volume_db, false)


## Play music
func play_music(music_id: String, volume_db: float = 0.0, fade_in: float = 0.0) -> void:
	if audio_database == null:
		push_error("AudioDatabase not loaded!")
		return
	
	var audio_clip: AudioClip = audio_database.get_clip(music_id)
	if audio_clip == null:
		push_error("Music clip not found with ID: " + music_id)
		return
	
	current_music_id = music_id
	# Stop current music if playing
	if music_player.playing:
		music_player.stop()
	
	music_player.stream = audio_clip.stream
	music_player.volume_db = audio_clip.volume_db + volume_db
	music_player.play()
	
	# Fade in if exists
	if fade_in > 0.0:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", audio_clip.volume_db + volume_db, fade_in).from(-80.0)


## Stop music
func stop_music(fade_out: float = 0.0) -> void:
	if not music_player.playing:
		return
	
	if fade_out > 0.0:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, fade_out)
		await tween.finished
		music_player.stop()
		music_player.volume_db = 0.0
	else:
		music_player.stop()

## get current music id
func get_current_music_id() -> String:
	return current_music_id

## Play audio clip (internal function)
func play_audio_clip(clip: AudioClip, volume_override: float = 0.0, is_music: bool = false) -> void:
	if clip.stream == null:
		push_error("AudioClip does not have stream!")
		return
	
	# Find available player
	var player: AudioStreamPlayer = null
	
	if is_music:
		player = music_player
	else:
		for sfx_player in sfx_players:
			if not sfx_player.playing:
				player = sfx_player
				break
		
		# If no available player, use first player (override)
		if player == null:
			player = sfx_players[0]
	
	# Configure and play
	player.stream = clip.stream
	player.volume_db = clip.volume_db + volume_override
	if clip.randomize_pitch:
		player.pitch_scale = randf_range(clip.pitch_min, clip.pitch_max)
	else:
		player.pitch_scale = 1.0
	
	player.play()


## Set volume for bus
func set_bus_volume(bus_name: String, volume_db: float) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("Bus not exists: " + bus_name)
		return
	
	AudioServer.set_bus_volume_db(bus_index, volume_db)


## Get volume of bus
func get_bus_volume(bus_name: String) -> float:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(bus_index)

func switch_sfx_bus(bus_name: String) -> void:
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_error("Bus not exists: " + bus_name)
		return
	current_sfx_bus_name = bus_name
	#switch all sfx players to new bus
	for sfx_player in sfx_players:
		sfx_player.bus = bus_name

## get current sfx bus name	
func get_current_sfx_bus_name() -> String:
	return current_sfx_bus_name
