extends Node
## AudioManager - A robust audio system for mobile games
##
## Handles sound effects with pooling, background music with crossfading,
## and volume control through audio buses.
##
## Usage:
##   AudioManager.play_sfx("enemy_death")
##   AudioManager.play_music("gameplay")
##   AudioManager.set_sfx_volume(0.8)

# =============================================================================
# CONFIGURATION
# =============================================================================

## How many sound effects can play simultaneously
const SFX_POOL_SIZE: int = 16

## How many 2D positional sounds can play simultaneously  
const SFX_2D_POOL_SIZE: int = 12

## Duration of music crossfade in seconds
const MUSIC_FADE_DURATION: float = 1.5

## Random pitch variation for SFX (0.0 = none, 0.1 = ±10%)
const DEFAULT_PITCH_VARIATION: float = 0.05

# =============================================================================
# SOUND EFFECT LIBRARIES
# =============================================================================
# Preload all your sounds here. Preloading means they're loaded into memory
# when the game starts, so there's no delay when playing them.

## Non-positional sound effects (UI, global sounds)
var sfx_library: Dictionary = {
	# Player sounds
	# "player_hit": preload("res://audio/sfx/player_hit.ogg"),
	# "player_death": preload("res://audio/sfx/player_death.ogg"),
	# "level_up": preload("res://audio/sfx/level_up.ogg"),
	
	# Enemy sounds
	"enemy_death": preload("res://audio/sfx/LLF_death1.ogg"),
	"supernova": preload("res://audio/sfx/LLF_supernova.ogg"),
	# "enemy_hit": preload("res://audio/sfx/enemy_hit.ogg"),
	
	# Item/pickup sounds
	# "item_pickup": preload("res://audio/sfx/item_pickup.ogg"),
	# "health_pickup": preload("res://audio/sfx/health_pickup.ogg"),
	# "xp_pickup": preload("res://audio/sfx/xp_pickup.ogg"),
	
	# Weapon sounds
	# "weapon_fire": preload("res://audio/sfx/weapon_fire.ogg"),
	# "weapon_swing": preload("res://audio/sfx/weapon_swing.ogg"),
	
	# UI sounds
	# "ui_click": preload("res://audio/sfx/ui_click.ogg"),
	# "ui_hover": preload("res://audio/sfx/ui_hover.ogg"),
	# "ui_back": preload("res://audio/sfx/ui_back.ogg"),
}

## Music tracks
var music_library: Dictionary = {
	# "main_menu": preload("res://audio/music/main_menu.ogg"),
	# "gameplay": preload("res://audio/music/gameplay.ogg"),
	# "boss": preload("res://audio/music/boss.ogg"),
	# "game_over": preload("res://audio/music/game_over.ogg"),
	# "victory": preload("res://audio/music/victory.ogg"),
}

# =============================================================================
# INTERNAL STATE
# =============================================================================

# Pool of AudioStreamPlayer nodes for non-positional SFX
var _sfx_pool: Array[AudioStreamPlayer] = []

# Pool of AudioStreamPlayer2D nodes for positional SFX
var _sfx_2d_pool: Array[AudioStreamPlayer2D] = []

# Two music players for crossfading between tracks
var _music_player_a: AudioStreamPlayer
var _music_player_b: AudioStreamPlayer
var _active_music_player: AudioStreamPlayer  # Which one is currently playing

# Track the currently playing music to avoid restarting
var _current_music: String = ""

# Volume levels (0.0 to 1.0)
var _master_volume: float = 1.0
var _music_volume: float = 0.8
var _sfx_volume: float = 1.0
var _ui_volume: float = 1.0

# Mute states
var _music_muted: bool = false
var _sfx_muted: bool = false

# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	# Create the SFX player pool (non-positional sounds)
	_create_sfx_pool()
	
	# Create the 2D SFX player pool (positional sounds)
	_create_sfx_2d_pool()
	
	# Create music players for crossfading
	_create_music_players()
	
	# Load saved volume settings if they exist
	_load_audio_settings()
	
	print("AudioManager initialized with %d SFX + %d 2D SFX players" % [SFX_POOL_SIZE, SFX_2D_POOL_SIZE])


func _create_sfx_pool() -> void:
	## Creates a pool of AudioStreamPlayer nodes for reuse
	for i in SFX_POOL_SIZE:
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"  # Route to SFX bus for volume control
		add_child(player)
		_sfx_pool.append(player)


func _create_sfx_2d_pool() -> void:
	## Creates a pool of AudioStreamPlayer2D nodes for positional audio
	for i in SFX_2D_POOL_SIZE:
		var player = AudioStreamPlayer2D.new()
		player.bus = "SFX"
		player.max_distance = 2000.0  # How far the sound can be heard
		add_child(player)
		_sfx_2d_pool.append(player)


func _create_music_players() -> void:
	## Creates two music players for smooth crossfading
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Music"
	add_child(_music_player_a)
	
	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music"
	add_child(_music_player_b)
	
	_active_music_player = _music_player_a

# =============================================================================
# SOUND EFFECTS - PUBLIC API
# =============================================================================

func play_sfx(sound_name: String, volume_db: float = 0.0, pitch_variation: float = DEFAULT_PITCH_VARIATION) -> void:
	## Plays a non-positional sound effect
	##
	## Parameters:
	##   sound_name: Key from sfx_library dictionary
	##   volume_db: Volume adjustment in decibels (0 = normal, -6 = half volume)
	##   pitch_variation: Random pitch range (0.1 = ±10% variation)
	##
	## Example:
	##   AudioManager.play_sfx("enemy_death")
	##   AudioManager.play_sfx("player_hit", -3.0)  # Quieter
	
	if _sfx_muted:
		return
	
	# Check if sound exists
	if not sfx_library.has(sound_name):
		push_warning("AudioManager: SFX not found: " + sound_name)
		return
	
	# Find an available player from the pool
	var player = _get_available_sfx_player()
	if player == null:
		# All players busy - skip this sound (better than audio glitches)
		return
	
	# Configure and play
	player.stream = sfx_library[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = _get_random_pitch(pitch_variation)
	player.play()


func play_sfx_2d(sound_name: String, position: Vector2, volume_db: float = 0.0, pitch_variation: float = DEFAULT_PITCH_VARIATION) -> void:
	## Plays a positional 2D sound effect at the specified location
	##
	## Parameters:
	##   sound_name: Key from sfx_library dictionary
	##   position: World position where the sound originates
	##   volume_db: Volume adjustment in decibels
	##   pitch_variation: Random pitch range
	##
	## Example:
	##   AudioManager.play_sfx_2d("enemy_death", enemy.global_position)
	
	if _sfx_muted:
		return
	
	if not sfx_library.has(sound_name):
		push_warning("AudioManager: SFX not found: " + sound_name)
		return
	
	var player = _get_available_sfx_2d_player()
	if player == null:
		return
	
	player.stream = sfx_library[sound_name]
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = _get_random_pitch(pitch_variation)
	player.play()


func play_ui(sound_name: String, volume_db: float = 0.0) -> void:
	## Plays a UI sound effect (no pitch variation, uses UI bus)
	##
	## Example:
	##   AudioManager.play_ui("ui_click")
	
	if not sfx_library.has(sound_name):
		push_warning("AudioManager: UI sound not found: " + sound_name)
		return
	
	var player = _get_available_sfx_player()
	if player == null:
		return
	
	player.bus = "UI"  # Temporarily use UI bus
	player.stream = sfx_library[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = 1.0  # No variation for UI sounds
	player.play()
	
	# Reset bus after playing (when sound finishes)
	player.finished.connect(func(): player.bus = "SFX", CONNECT_ONE_SHOT)

# =============================================================================
# MUSIC - PUBLIC API
# =============================================================================

func play_music(track_name: String, crossfade: bool = true) -> void:
	## Plays a music track, optionally crossfading from current track
	##
	## Parameters:
	##   track_name: Key from music_library dictionary
	##   crossfade: If true, smoothly transitions from current music
	##
	## Example:
	##   AudioManager.play_music("gameplay")
	##   AudioManager.play_music("boss", false)  # Instant switch
	
	# Don't restart if already playing this track
	if track_name == _current_music and _active_music_player.playing:
		return
	
	if not music_library.has(track_name):
		push_warning("AudioManager: Music not found: " + track_name)
		return
	
	_current_music = track_name
	
	if crossfade and _active_music_player.playing:
		_crossfade_to_track(track_name)
	else:
		_play_track_immediate(track_name)


func stop_music(fade_out: bool = true) -> void:
	## Stops the current music
	##
	## Parameters:
	##   fade_out: If true, fades out smoothly; if false, stops immediately
	
	_current_music = ""
	
	if fade_out:
		var tween = create_tween()
		tween.tween_property(_active_music_player, "volume_db", -40.0, MUSIC_FADE_DURATION)
		tween.tween_callback(_active_music_player.stop)
	else:
		_active_music_player.stop()


func pause_music() -> void:
	## Pauses the current music (can be resumed)
	_active_music_player.stream_paused = true


func resume_music() -> void:
	## Resumes paused music
	_active_music_player.stream_paused = false


func is_music_playing() -> bool:
	## Returns true if music is currently playing
	return _active_music_player.playing and not _active_music_player.stream_paused

# =============================================================================
# VOLUME CONTROL - PUBLIC API
# =============================================================================

func set_master_volume(value: float) -> void:
	## Sets master volume (0.0 to 1.0)
	_master_volume = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(_master_volume)
	)
	_save_audio_settings()


func set_music_volume(value: float) -> void:
	## Sets music volume (0.0 to 1.0)
	_music_volume = clamp(value, 0.0, 0.9)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Music"),
		linear_to_db(_music_volume)
	)
	_save_audio_settings()


func set_sfx_volume(value: float) -> void:
	## Sets SFX volume (0.0 to 1.0)
	_sfx_volume = clamp(value, 0.0, 0.9)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("SFX"),
		linear_to_db(_sfx_volume)
	)
	_save_audio_settings()


func set_ui_volume(value: float) -> void:
	## Sets UI sound volume (0.0 to 1.0)
	_ui_volume = clamp(value, 0.0, 0.9)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("UI"),
		linear_to_db(_ui_volume)
	)
	_save_audio_settings()


func get_master_volume() -> float:
	return _master_volume


func get_music_volume() -> float:
	return _music_volume


func get_sfx_volume() -> float:
	return _sfx_volume


func get_ui_volume() -> float:
	return _ui_volume

# =============================================================================
# MUTE CONTROLS - PUBLIC API
# =============================================================================

func toggle_music_mute() -> void:
	## Toggles music mute state
	_music_muted = not _music_muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), _music_muted)
	_save_audio_settings()


func toggle_sfx_mute() -> void:
	## Toggles SFX mute state
	_sfx_muted = not _sfx_muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), _sfx_muted)
	_save_audio_settings()


func set_music_muted(muted: bool) -> void:
	_music_muted = muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), _music_muted)
	_save_audio_settings()


func set_sfx_muted(muted: bool) -> void:
	_sfx_muted = muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), _sfx_muted)
	_save_audio_settings()


func is_music_muted() -> bool:
	return _music_muted


func is_sfx_muted() -> bool:
	return _sfx_muted

# =============================================================================
# INTERNAL HELPER FUNCTIONS
# =============================================================================

func _get_available_sfx_player() -> AudioStreamPlayer:
	## Finds a free player from the pool, or returns null if all busy
	for player in _sfx_pool:
		if not player.playing:
			return player
	return null


func _get_available_sfx_2d_player() -> AudioStreamPlayer2D:
	## Finds a free 2D player from the pool, or returns null if all busy
	for player in _sfx_2d_pool:
		if not player.playing:
			return player
	return null


func _get_random_pitch(variation: float) -> float:
	## Returns a random pitch value within the variation range
	if variation <= 0.0:
		return 1.0
	return randf_range(1.0 - variation, 1.0 + variation)


func _play_track_immediate(track_name: String) -> void:
	## Immediately starts playing a track (no crossfade)
	_active_music_player.stream = music_library[track_name]
	_active_music_player.volume_db = 0.0
	_active_music_player.play()


func _crossfade_to_track(track_name: String) -> void:
	## Smoothly crossfades from current track to new track
	# Determine which player to fade to
	var old_player = _active_music_player
	var new_player = _music_player_b if _active_music_player == _music_player_a else _music_player_a
	
	# Set up the new player
	new_player.stream = music_library[track_name]
	new_player.volume_db = -40.0  # Start silent
	new_player.play()
	
	# Create crossfade tween
	var tween = create_tween()
	tween.set_parallel(true)  # Run both fades simultaneously
	
	# Fade out old track
	tween.tween_property(old_player, "volume_db", -40.0, MUSIC_FADE_DURATION)
	
	# Fade in new track
	tween.tween_property(new_player, "volume_db", 0.0, MUSIC_FADE_DURATION)
	
	# Stop old player when fade completes
	tween.chain().tween_callback(old_player.stop)
	
	# Update active player reference
	_active_music_player = new_player

# =============================================================================
# SETTINGS PERSISTENCE
# =============================================================================

const SETTINGS_PATH = "user://audio_settings.cfg"

func _save_audio_settings() -> void:
	## Saves volume and mute settings to disk
	var config = ConfigFile.new()
	
	config.set_value("audio", "master_volume", _master_volume)
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.set_value("audio", "ui_volume", _ui_volume)
	config.set_value("audio", "music_muted", _music_muted)
	config.set_value("audio", "sfx_muted", _sfx_muted)
	
	config.save(SETTINGS_PATH)


func _load_audio_settings() -> void:
	## Loads saved volume settings, applying defaults if no save exists
	var config = ConfigFile.new()
	
	if config.load(SETTINGS_PATH) != OK:
		# No saved settings, use defaults and apply them
		set_master_volume(_master_volume)
		set_music_volume(_music_volume)
		set_sfx_volume(_sfx_volume)
		set_ui_volume(_ui_volume)
		return
	
	# Load and apply saved values
	set_master_volume(config.get_value("audio", "master_volume", 1.0))
	set_music_volume(config.get_value("audio", "music_volume", 0.8))
	set_sfx_volume(config.get_value("audio", "sfx_volume", 1.0))
	set_ui_volume(config.get_value("audio", "ui_volume", 1.0))
	set_music_muted(config.get_value("audio", "music_muted", false))
	set_sfx_muted(config.get_value("audio", "sfx_muted", false))
