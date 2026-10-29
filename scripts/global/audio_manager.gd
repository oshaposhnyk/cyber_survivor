extends Node

# Audio Manager Autoload - Advanced Cyberpunk Audio Director
# Features: Sound throttling (prevents WebAudio overload), voice limiter,
# scrap collection combo pitch escalator, and dynamic priority ducking.

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_channels: int = 10
var sfx_index: int = 0

var sound_streams: Dictionary = {}

var music_muted: bool = false
var sfx_muted: bool = false

# Cooldowns per sound type to strictly prevent audio overload and clipping
var sound_cooldowns: Dictionary = {
	"laser": 0.12,
	"railgun": 0.15,
	"missile": 0.18,
	"scrap": 0.22,               # Max 1 scrap chime per 0.22s (prevents machine-gun audio spam)
	"explosion": 0.28,           # Max 1 explosion per 0.28s for hordes
	"heavy_explosion": 0.35,
	"shield_hit": 0.16,
	"ui_hover": 0.06,
	"upgrade_select": 0.08,
	"emp_blast": 0.25,
	"level_up": 0.3,
	"victory": 0.4
}
var last_play_times: Dictionary = {}

# Scrap pickup combo pitch escalator
var scrap_combo: int = 0
var scrap_combo_timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Music player
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -12.0
	add_child(bgm_player)
	
	# SFX Players pool (strictly clamped to 6 channels for clean browser audio)
	max_sfx_channels = 6
	for i in range(max_sfx_channels):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
		
	# Load sound resources
	load_sounds()
	play_music()

const MUSIC_DB := -12.0
const MUSIC_FADE := 2.0

func _process(delta: float) -> void:
	_update_music_fade()
	if scrap_combo_timer > 0.0:
		scrap_combo_timer -= delta
		if scrap_combo_timer <= 0.0:
			scrap_combo = 0

func load_sounds() -> void:
	# Short SFX are WAV (Godot's recommended format for one-shots; low decode cost on web).
	# A value is one path or an Array of variant paths; play_sfx picks a random variant.
	# Sources and licences: assets/audio/CREDITS.txt
	var files = {
		"laser": ["res://assets/audio/laser_fire.wav", "res://assets/audio/laser_fire_2.wav", "res://assets/audio/laser_fire_3.wav"],
		"railgun": "res://assets/audio/railgun_fire.wav",
		"missile": "res://assets/audio/missile_launch.wav",
		"scrap": ["res://assets/audio/scrap_pickup.wav", "res://assets/audio/scrap_pickup_2.wav"],
		"level_up": "res://assets/audio/level_up.wav",
		"explosion": ["res://assets/audio/explosion.wav", "res://assets/audio/explosion_2.wav", "res://assets/audio/explosion_3.wav"],
		"heavy_explosion": "res://assets/audio/heavy_explosion.wav",
		"emp_blast": "res://assets/audio/emp_blast.wav",
		"shield_hit": "res://assets/audio/shield_hit.wav",
		"upgrade_select": "res://assets/audio/upgrade_select.wav",
		"ui_hover": "res://assets/audio/ui_hover.wav",
		"victory": "res://assets/audio/victory.wav",
		"game_over": "res://assets/audio/game_over.wav"
	}
	for key in files.keys():
		var paths: Array = files[key] if files[key] is Array else [files[key]]
		var streams: Array = []
		for path in paths:
			if ResourceLoader.exists(path):
				streams.append(load(path))
		if not streams.is_empty():
			sound_streams[key] = streams
		last_play_times[key] = -999.0

func play_music() -> void:
	if music_muted:
		return
	var bgm_path = "res://assets/audio/bgm_cyberpunk_sonata.mp3"
	if ResourceLoader.exists(bgm_path):
		var stream = load(bgm_path)
		bgm_player.stream = stream
		bgm_player.play()
		if not bgm_player.finished.is_connected(_on_music_finished):
			bgm_player.finished.connect(_on_music_finished)

func _on_music_finished() -> void:
	if not music_muted and bgm_player.stream:
		bgm_player.play()

# The track is not built to loop: fade out over its last seconds and fade in after restart
func _update_music_fade() -> void:
	if not bgm_player.playing or bgm_player.stream == null:
		return
	var pos = bgm_player.get_playback_position()
	var left = bgm_player.stream.get_length() - pos
	var k = clampf(min(pos, left) / MUSIC_FADE, 0.0, 1.0)
	bgm_player.volume_db = lerpf(-40.0, MUSIC_DB, k)

func play_sfx(sound_name: String, pitch_rnd: float = 0.08, volume_offset_db: float = 0.0) -> void:
	if sfx_muted:
		return
	if not sound_streams.has(sound_name):
		return
		
	var now = Time.get_ticks_msec() / 1000.0
	var cd = sound_cooldowns.get(sound_name, 0.03)
	var last_time = last_play_times.get(sound_name, -999.0)
	
	# Drop request if within cooldown window to protect audio bus
	if now - last_time < cd:
		return
	last_play_times[sound_name] = now
	
	# Find next available player or round-robin
	var player = sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % max_sfx_channels
	
	player.stream = sound_streams[sound_name].pick_random()
	
	# Scrap combo pitch scaling
	var base_pitch: float = 1.0
	if sound_name == "scrap":
		scrap_combo += 1
		scrap_combo_timer = 0.45
		base_pitch = clampf(1.0 + float(scrap_combo) * 0.035, 1.0, 1.65)
	
	player.volume_db = -7.0 + volume_offset_db
	player.pitch_scale = base_pitch + randf_range(-pitch_rnd, pitch_rnd)
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
