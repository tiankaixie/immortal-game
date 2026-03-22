extends Node
## AudioManager — 全局音频管理器
##
## Manages SFX and music playback as an autoload singleton.
## SFX pool: 8 AudioStreamPlayer nodes for concurrent sound effects.
## Music: 2 AudioStreamPlayer nodes for crossfading between tracks.
## Loads audio from res://assets/sfx/ and res://assets/music/.

# ─── Constants ────────────────────────────────────────────────
const SFX_PATH := "res://assets/sfx/"
const MUSIC_PATH := "res://assets/music/"
const SFX_POOL_SIZE: int = 8

## Registered SFX names — maps logical name to filename
const SFX_FILES: Dictionary = {
	# Combat
	"hit": "hit.ogg",
	"crit": "crit.ogg",
	"skill_fire": "skill_fire.ogg",
	"skill_ice": "skill_ice.ogg",
	"skill_thunder": "skill_thunder.ogg",
	# Equipment / economy
	"equip": "equip.ogg",
	"unequip": "unequip.ogg",
	"purchase": "purchase.ogg",
	"level_up": "level_up.ogg",
	# UI
	"ui_click": "ui_click.ogg",
	"ui_open": "ui_open.ogg",
	"ui_close": "ui_close.ogg",
	# Enemies / player
	"enemy_die": "enemy_die.ogg",
	"player_hurt": "player_hurt.ogg",
	"dodge": "dodge.ogg",
}

# ─── Audio Bus Indices ────────────────────────────────────────
var _sfx_bus_index: int = 1
var _music_bus_index: int = 2

# ─── Node Pools ──────────────────────────────────────────────
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _active_music: AudioStreamPlayer = null
var _current_music_track: String = ""

# ─── Audio Cache ─────────────────────────────────────────────
var _sfx_cache: Dictionary = {}  # sfx_name -> AudioStream
var _music_cache: Dictionary = {}  # track_name -> AudioStream

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_audio_buses()
	_create_sfx_pool()
	_create_music_players()
	print("[AudioManager] Initialized — %d SFX pool, 2 music players" % SFX_POOL_SIZE)

# ─── Audio Bus Setup ─────────────────────────────────────────
func _ensure_audio_buses() -> void:
	"""Ensure SFX and Music audio buses exist."""
	# Look for existing buses by name
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	_music_bus_index = AudioServer.get_bus_index("Music")

	if _sfx_bus_index == -1:
		AudioServer.add_bus()
		_sfx_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_sfx_bus_index, "SFX")
		AudioServer.set_bus_send(_sfx_bus_index, "Master")

	if _music_bus_index == -1:
		AudioServer.add_bus()
		_music_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_music_bus_index, "Music")
		AudioServer.set_bus_send(_music_bus_index, "Master")

# ─── Player Node Creation ────────────────────────────────────
func _create_sfx_pool() -> void:
	"""Create a pool of AudioStreamPlayer nodes for concurrent SFX."""
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.name = "SFX_%d" % i
		add_child(player)
		_sfx_players.append(player)

func _create_music_players() -> void:
	"""Create two AudioStreamPlayers for music crossfading."""
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	_music_a.name = "Music_A"
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	_music_b.name = "Music_B"
	add_child(_music_b)

	_active_music = _music_a

# ─── SFX Playback ────────────────────────────────────────────
func play_sfx(sfx_name: String) -> void:
	"""Play a one-shot sound effect by name."""
	var stream := _load_sfx(sfx_name)
	if stream == null:
		return

	# Find an available player (not currently playing)
	var player := _get_available_sfx_player()
	if player == null:
		# All players busy — steal the oldest one
		player = _sfx_players[0]

	player.stream = stream
	player.play()

func has_sfx(sfx_name: String) -> bool:
	"""Check if an SFX resource exists without logging warnings."""
	if _sfx_cache.has(sfx_name):
		return true

	var filename: String = SFX_FILES.get(sfx_name, sfx_name)
	var path: String = SFX_PATH + filename
	if ResourceLoader.exists(path):
		return true

	return ResourceLoader.exists(SFX_PATH + filename.get_basename() + ".wav")

func _load_sfx(sfx_name: String) -> AudioStream:
	"""Load and cache an SFX audio stream."""
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]

	var filename: String = SFX_FILES.get(sfx_name, sfx_name)
	# Try with the filename as-is, or add .ogg if no extension
	var path: String = SFX_PATH + filename
	if not ResourceLoader.exists(path):
		# Try .wav
		path = SFX_PATH + filename.get_basename() + ".wav"
		if not ResourceLoader.exists(path):
			push_warning("[AudioManager] SFX not found: %s (tried %s)" % [sfx_name, SFX_PATH + filename])
			return null

	var stream: AudioStream = load(path)
	if stream != null:
		_sfx_cache[sfx_name] = stream
	return stream

func _get_available_sfx_player() -> AudioStreamPlayer:
	"""Find the first SFX player that isn't currently playing."""
	for player in _sfx_players:
		if not player.playing:
			return player
	return null

# ─── Music Playback ──────────────────────────────────────────
func play_music(track_name: String, fade_in: float = 1.0) -> void:
	"""Crossfade to a new music track."""
	if track_name == _current_music_track:
		return

	var stream := _load_music(track_name)
	if stream == null:
		return

	_current_music_track = track_name

	# Determine which player to fade in (the inactive one)
	var fade_in_player: AudioStreamPlayer
	var fade_out_player: AudioStreamPlayer

	if _active_music == _music_a:
		fade_in_player = _music_b
		fade_out_player = _music_a
	else:
		fade_in_player = _music_a
		fade_out_player = _music_b

	# Set up the new track
	fade_in_player.stream = stream
	fade_in_player.volume_db = -80.0
	fade_in_player.play()

	# Crossfade
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(fade_in_player, "volume_db", 0.0, fade_in)
	if fade_out_player.playing:
		tween.tween_property(fade_out_player, "volume_db", -80.0, fade_in)
		tween.chain().tween_callback(fade_out_player.stop)

	_active_music = fade_in_player

func stop_music(fade_out: float = 1.0) -> void:
	"""Stop music with fade out."""
	_current_music_track = ""

	var tween := create_tween()
	if _music_a.playing:
		tween.tween_property(_music_a, "volume_db", -80.0, fade_out)
		tween.tween_callback(_music_a.stop)
	if _music_b.playing:
		tween.set_parallel(true)
		tween.tween_property(_music_b, "volume_db", -80.0, fade_out)
		tween.tween_callback(_music_b.stop)

func _load_music(track_name: String) -> AudioStream:
	"""Load and cache a music audio stream."""
	if _music_cache.has(track_name):
		return _music_cache[track_name]

	# Try common extensions
	for ext in [".ogg", ".mp3", ".wav"]:
		var path: String = MUSIC_PATH + track_name + ext
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream != null:
				_music_cache[track_name] = stream
				return stream

	# Try exact path (track_name might include extension)
	var direct_path: String = MUSIC_PATH + track_name
	if ResourceLoader.exists(direct_path):
		var stream: AudioStream = load(direct_path)
		if stream != null:
			_music_cache[track_name] = stream
			return stream

	push_warning("[AudioManager] Music track not found: %s" % track_name)
	return null

# ─── Volume Control ──────────────────────────────────────────
func set_master_volume(value: float) -> void:
	"""Set master volume (0.0 to 1.0)."""
	var bus_index := AudioServer.get_bus_index("Master")
	if bus_index == -1:
		bus_index = 0
	_apply_volume(bus_index, value)

func set_sfx_volume(value: float) -> void:
	"""Set SFX volume (0.0 to 1.0)."""
	_apply_volume(_sfx_bus_index, value)

func set_music_volume(value: float) -> void:
	"""Set music volume (0.0 to 1.0)."""
	_apply_volume(_music_bus_index, value)

func _apply_volume(bus_index: int, value: float) -> void:
	"""Apply volume to a specific audio bus."""
	if bus_index < 0 or bus_index >= AudioServer.bus_count:
		return
	if value <= 0.0:
		AudioServer.set_bus_mute(bus_index, true)
	else:
		AudioServer.set_bus_mute(bus_index, false)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
