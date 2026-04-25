extends Node

# ============================================================
# AudioManager - global SFX system for Shafted
# Plays positioned 2D sounds via a pool of reusable players.
# Handles random variation selection (no-repeat) and pitch jitter.
# ============================================================

# --- Enemy hit/death SFX ---
const ENEMY_HIT_SOUNDS: Array[AudioStream] = [
	preload("res://Assets/audio/sfx/enemies/enemy_hit_01.wav"),
	preload("res://Assets/audio/sfx/enemies/enemy_hit_02.wav"),
	preload("res://Assets/audio/sfx/enemies/enemy_hit_03.wav"),
]
const ENEMY_DEATH_SOUND: AudioStream = preload("res://Assets/audio/sfx/enemies/enemy_death.wav")
# --- Boss Golem hit SFX ---
const GOLEM_HIT_SOUNDS: Array[AudioStream] = [
	preload("res://Assets/audio/sfx/boss/golem_hit_01.wav"),
	preload("res://Assets/audio/sfx/boss/golem_hit_02.wav"),
	preload("res://Assets/audio/sfx/boss/golem_hit_03.wav"),
]
# --- Boss Golem laser SFX (sustained ~4s sound) ---
const GOLEM_LASER_SOUND: AudioStream = preload("res://Assets/audio/sfx/boss/golem_laser.wav")

var _last_golem_hit_index: int = -1
# --- Configuration ---
const PITCH_VARIANCE: float = 0.1   # ±10% pitch randomization
const POOL_SIZE: int = 16            # concurrent SFX cap 

# --- Internal state ---
var _player_pool: Array[AudioStreamPlayer2D] = []
var _last_hit_index: int = -1


func _ready() -> void:
	# Pre-create a pool of AudioStreamPlayer2D nodes.
	# Pooling avoids per-shot node allocation, which matters when
	# many enemies get hit in the same frame.
	for i in POOL_SIZE:
		var player := AudioStreamPlayer2D.new()
		player.bus = "Master"  # change to "SFX" once you add an SFX bus
		add_child(player)
		_player_pool.append(player)


# Returns a player that isn't currently in use, or the oldest one
# if everything is busy (graceful degradation under heavy load).
func _get_available_player() -> AudioStreamPlayer2D:
	for player in _player_pool:
		if not player.playing:
			return player
	return _player_pool[0]


# Play one of the 3 enemy hit variations at the given world position.
# Never plays the same variation twice in a row.
func play_enemy_hit(world_position: Vector2) -> void:
	if ENEMY_HIT_SOUNDS.is_empty():
		return

	var index := randi() % ENEMY_HIT_SOUNDS.size()
	if index == _last_hit_index and ENEMY_HIT_SOUNDS.size() > 1:
		index = (index + 1) % ENEMY_HIT_SOUNDS.size()
	_last_hit_index = index

	var player := _get_available_player()
	player.stream = ENEMY_HIT_SOUNDS[index]
	player.global_position = world_position
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIANCE, PITCH_VARIANCE)
	player.play()


# Play the enemy death sound at the given world position.
func play_enemy_death(world_position: Vector2) -> void:
	if ENEMY_DEATH_SOUND == null:
		return

	var player := _get_available_player()
	player.stream = ENEMY_DEATH_SOUND
	player.global_position = world_position
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIANCE, PITCH_VARIANCE)
	player.play()

func play_golem_hit(world_position: Vector2) -> void:
	if GOLEM_HIT_SOUNDS.is_empty():
	
		return

	var index := randi() % GOLEM_HIT_SOUNDS.size()
	if index == _last_golem_hit_index and GOLEM_HIT_SOUNDS.size() > 1:
		index = (index + 1) % GOLEM_HIT_SOUNDS.size()
	_last_golem_hit_index = index

	var player := _get_available_player()
	player.stream = GOLEM_HIT_SOUNDS[index]
	player.global_position = world_position
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIANCE, PITCH_VARIANCE)
	player.play()


# Play the golem laser sound at the given world position.
# Returns the player so the caller can stop it early (e.g. on death,
# or when the shorter straight laser ends before the 4s sound finishes).
# Pitch is locked to 1.0 — no jitter on sustained sounds, it sounds wobbly.
func play_golem_laser(world_position: Vector2) -> AudioStreamPlayer2D:
	if GOLEM_LASER_SOUND == null:
		return null

	var player := _get_available_player()
	player.stream = GOLEM_LASER_SOUND
	player.global_position = world_position
	player.pitch_scale = 1.0
	player.play()
	return player


# Stop a sustained sound early. Safe to call with null or with a player
# that's no longer playing — both no-op.
func stop_golem_laser(player: AudioStreamPlayer2D) -> void:
	if player == null:
		return
	if player.playing:
		player.stop()
