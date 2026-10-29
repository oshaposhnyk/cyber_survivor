extends Node

# Audio Manager Autoload - handles music loops, sound effects pool, pitch variation

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_channels: int = 12
var sfx_index: int = 0

var sound_streams: Dictionary = {}

var music_muted: bool = false
var sfx_muted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Music player
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -10.0
	add_child(bgm_player)
	
	# SFX Players pool
	for i in range(max_sfx_channels):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
		
	# Load sound resources
	load_sounds()
	play_music()

func load_sounds() -> void:
	var files = {
		"laser": "res://assets/audio/laser_fire.ogg",
		"railgun": "res://assets/audio/railgun_fire.ogg",
		"missile": "res://assets/audio/missile_launch.ogg",
		"scrap": "res://assets/audio/scrap_pickup.ogg",
		"level_up": "res://assets/audio/level_up.ogg",
		"explosion": "res://assets/audio/explosion.ogg",
		"emp_blast": "res://assets/audio/emp_blast.ogg",
		"shield_hit": "res://assets/audio/shield_hit.ogg",
		"upgrade_select": "res://assets/audio/upgrade_select.ogg",
		"victory": "res://assets/audio/victory.ogg",
		"game_over": "res://assets/audio/game_over.ogg"
	}
	for key in files.keys():
		var path = files[key]
		if ResourceLoader.exists(path):
			sound_streams[key] = load(path)

func play_music() -> void:
	if music_muted:
		return
	var bgm_path = "res://assets/audio/bgm_cyber_loop.mp3"
	if ResourceLoader.exists(bgm_path):
		var stream = load(bgm_path)
		bgm_player.stream = stream
		bgm_player.play()
		if not bgm_player.finished.is_connected(_on_music_finished):
			bgm_player.finished.connect(_on_music_finished)

func _on_music_finished() -> void:
	if not music_muted and bgm_player.stream:
		bgm_player.play()

func play_sfx(sound_name: String, pitch_rnd: float = 0.1, volume_offset_db: float = 0.0) -> void:
	if sfx_muted:
		return
	if not sound_streams.has(sound_name):
		return
		
	var player = sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % max_sfx_channels
	
	player.stream = sound_streams[sound_name]
	player.volume_db = -6.0 + volume_offset_db
	player.pitch_scale = randf_range(1.0 - pitch_rnd, 1.0 + pitch_rnd)
	player.play()

func toggle_music() -> bool:
	music_muted = not music_muted
	if music_muted:
		bgm_player.stop()
	else:
		play_music()
	return not music_muted

func toggle_sfx() -> bool:
	sfx_muted = not sfx_muted
	return not sfx_muted
