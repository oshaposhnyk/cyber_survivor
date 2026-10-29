extends Node2D

# Orbital Data Cache Drop Pod
# Dynamic In-Run Event: Hold perimeter for 7 seconds to hack and claim rewards!

@export var capture_radius: float = 135.0
@export var capture_time: float = 7.0

var current_progress: float = 0.0
var is_player_inside: bool = false
var pulse_time: float = 0.0
var spawn_guard_timer: float = 2.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("data_caches")

func _process(delta: float) -> void:
	pulse_time += delta * 4.0
	var player = GameManager.player_node
	if is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		is_player_inside = dist <= capture_radius
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
	var base_col = Color(0.2, 1.0, 0.55) if is_player_inside else Color(0.2, 0.8, 1.0, 0.6)
	
	# Outer capture circle zone
	draw_arc(Vector2.ZERO, capture_radius, 0, TAU, 36, Color(base_col.r, base_col.g, base_col.b, 0.35), 2.0)
	
	# Progress arc
	if frac > 0.0:
		var fill_col = Color(0.1, 1.0, 0.6, 0.85)
		draw_arc(Vector2.ZERO, capture_radius, -PI * 0.5, -PI * 0.5 + TAU * frac, 36, fill_col, 5.0)
		draw_circle(Vector2.ZERO, capture_radius * frac, Color(0.1, 1.0, 0.5, 0.06))
		
	# Tech brackets & radar pings
	var ping = fmod(pulse_time * 20.0, capture_radius)
	draw_arc(Vector2.ZERO, ping, 0, TAU, 28, Color(base_col.r, base_col.g, base_col.b, 0.25 * (1.0 - ping / capture_radius)), 1.5)
	
	# Corner crosshairs
	for i in range(4):
		var a = float(i) * (PI * 0.5)
		var p1 = Vector2(cos(a), sin(a)) * (capture_radius - 8.0)
		var p2 = Vector2(cos(a), sin(a)) * (capture_radius + 8.0)
		draw_line(p1, p2, base_col, 2.0)

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
