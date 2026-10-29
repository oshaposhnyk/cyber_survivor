extends Node2D

# Orbital Data Cache Drop Pod
# Dynamic In-Run Event: Hold perimeter for 7 seconds to hack and claim rewards!

@export var capture_radius: float = 135.0
@export var capture_time: float = 7.0

var current_progress: float = 0.0
var is_player_inside: bool = false
var pulse_time: float = 0.0
var spawn_guard_timer: float = 2.0
# An unclaimed cache expires, so wave_manager (max 1) can drop the next one.
# It stays while the player is capturing it.
const LIFETIME := 75.0
const DESPAWN_DIST := 2400.0
var age: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("data_caches")

func _process(delta: float) -> void:
	pulse_time += delta * 4.0
	age += delta
	var player = GameManager.player_node
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		is_player_inside = dist <= capture_radius
		if dist > DESPAWN_DIST or (age > LIFETIME and current_progress <= 0.0):
			queue_free()
			return
	else:
		is_player_inside = false
		
	if is_player_inside:
		current_progress = min(capture_time, current_progress + delta)
		if current_progress >= capture_time:
			complete_capture()
			return
	else:
		# Slowly decay progress if player leaves the zone
		current_progress = max(0.0, current_progress - delta * 0.5)
		
	queue_redraw()

func _draw() -> void:
	var frac = current_progress / capture_time
	var base_col = Color(0.2, 1.0, 0.55) if is_player_inside else Color(0.2, 0.85, 1.0, 0.65)
	
	# 1. Concentric Cyber-Grid Rings
	draw_arc(Vector2.ZERO, capture_radius * 0.35, 0, TAU, 24, Color(base_col.r, base_col.g, base_col.b, 0.2), 1.0)
	draw_arc(Vector2.ZERO, capture_radius * 0.7, 0, TAU, 28, Color(base_col.r, base_col.g, base_col.b, 0.25), 1.0)
	draw_arc(Vector2.ZERO, capture_radius, 0, TAU, 36, Color(base_col.r, base_col.g, base_col.b, 0.45), 2.0)
	
	# 2. Sweeping Sonar / Radar Beam
	var sweep_angle = pulse_time * 2.2
	var sweep_end = Vector2(cos(sweep_angle), sin(sweep_angle)) * capture_radius
	draw_line(Vector2.ZERO, sweep_end, Color(base_col.r, base_col.g, base_col.b, 0.6), 2.0)
	
	# 3. Rotating Central Hex-Brackets around the core pod
	var hex_rot = pulse_time * 0.6
	for i in range(6):
		var ha = hex_rot + float(i) * (TAU / 6.0)
		var hp1 = Vector2(cos(ha), sin(ha)) * 32.0
		var hp2 = Vector2(cos(ha + 0.5), sin(ha + 0.5)) * 32.0
		draw_line(hp1, hp2, base_col, 2.5)
	
	# 4. Progress Arc and Holographic Sector Fill
	if frac > 0.0:
		var fill_col = Color(0.1, 1.0, 0.55, 0.9)
		draw_arc(Vector2.ZERO, capture_radius, -PI * 0.5, -PI * 0.5 + TAU * frac, 36, fill_col, 5.0)
		draw_circle(Vector2.ZERO, capture_radius * frac, Color(0.1, 1.0, 0.5, 0.07))
		
	# 5. Digital Uplink Stream Particles toward Player when inside
	var player = GameManager.player_node
	if is_player_inside and is_instance_valid(player):
		var to_p = player.global_position - global_position
		for i in range(5):
			var t_node = fmod(pulse_time * 1.8 + float(i) * 0.2, 1.0)
			var stream_pos = to_p * t_node + Vector2(sin(pulse_time * 6.0 + i) * 6.0, cos(pulse_time * 6.0 + i) * 6.0)
			draw_circle(stream_pos, 2.8, Color(0.2, 1.0, 0.6, 0.85))
			draw_line(stream_pos, stream_pos - to_p.normalized() * 12.0, Color(0.2, 1.0, 0.6, 0.5), 1.5)
	
	# 6. Corner Targeting Reticles
	for i in range(4):
		var a = float(i) * (PI * 0.5)
		var p1 = Vector2(cos(a), sin(a)) * (capture_radius - 10.0)
		var p2 = Vector2(cos(a), sin(a)) * (capture_radius + 10.0)
		draw_line(p1, p2, base_col, 2.5)

func complete_capture() -> void:
	var player = GameManager.player_node
	# 1. Grant +1 Free Skill Point
	GameManager.available_skill_points += 1
	GameManager.stats_updated.emit()
	
	# 2. Grant 10 seconds of Overdrive fire-rate
	GameManager.trigger_overdrive(10.0)
	
	# 3. Restore full shield
	if is_instance_valid(player):
		player.current_shield = player.max_shield
		GameManager.player_damaged.emit(player.current_hp, player.max_hp, player.current_shield, player.max_shield)
		
	# 4. Audio & VFX
	AudioManager.play_sfx("victory", 0.05, 3.0)
	AudioManager.play_sfx("emp_blast", 0.08, 2.0)
	
	var ft_scene = preload("res://scenes/effects/floating_text.tscn")
	var ft = ft_scene.instantiate()
	ft.global_position = global_position + Vector2(0, -40)
	get_parent().add_child(ft)
	ft.setup("ЗЛАМАНО! +1 АПГРЕЙД + ОВЕРДРАЙВ!", Color(0.2, 1.0, 0.6), 2.5)
	
	queue_free()
