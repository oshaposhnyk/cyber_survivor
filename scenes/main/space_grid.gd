extends Node2D

# Deep Space & Orbital Station Background
# Features: Multi-layer Parallax Stars, Cosmic Nebula Clouds, Tech Grid & Boundary Energy Field

@export var station_radius: float = 3200.0

# Star layers for parallax
var stars_far: Array[Dictionary] = []
var stars_mid: Array[Dictionary] = []
var stars_bright: Array[Dictionary] = []

# Cosmic Nebula clusters
var nebulae: Array[Dictionary] = []

var time_elapsed: float = 0.0

func _ready() -> void:
	z_index = -20
	init_nebulae()
	init_stars()

func init_nebulae() -> void:
	# 6 Large cosmic nebula clouds with rich colors
	var colors = [
		Color(0.08, 0.02, 0.18, 0.22), # Deep cosmic violet
		Color(0.02, 0.08, 0.22, 0.25), # Deep nebula blue
		Color(0.12, 0.03, 0.14, 0.20), # Magenta dust
		Color(0.01, 0.12, 0.16, 0.22), # Cyan gas cloud
		Color(0.06, 0.02, 0.12, 0.18), # Purple void
		Color(0.02, 0.06, 0.15, 0.24)  # Indigo
	]
	for i in range(colors.size()):
		nebulae.append({
			"pos": Vector2(randf_range(-2500, 2500), randf_range(-2500, 2500)),
			"radius": randf_range(500, 950),
			"color": colors[i],
			"drift_speed": Vector2(randf_range(-3, 3), randf_range(-3, 3))
		})

func init_stars() -> void:
	# 1. Distant small stars (slowest parallax)
	for i in range(160):
		stars_far.append({
			"pos": Vector2(randf_range(-3500, 3500), randf_range(-3500, 3500)),
			"size": randf_range(0.8, 1.5),
			"alpha": randf_range(0.25, 0.7),
			"twinkle_speed": randf_range(1.5, 4.0),
			"phase": randf() * TAU
		})
		
	# 2. Mid stars with subtle coloration
	var star_tints = [
		Color(0.7, 0.85, 1.0), # Blue-white
		Color(1.0, 0.95, 0.8), # Warm yellow
		Color(0.8, 1.0, 1.0),  # Cyan
		Color(1.0, 0.8, 0.8)   # Faint red
	]
	for i in range(80):
		stars_mid.append({
			"pos": Vector2(randf_range(-3500, 3500), randf_range(-3500, 3500)),
			"size": randf_range(1.6, 2.4),
			"color": star_tints[randi() % star_tints.size()],
			"alpha": randf_range(0.4, 0.9),
			"twinkle_speed": randf_range(2.0, 5.0),
			"phase": randf() * TAU
		})
		
	# 3. Bright hero stars with 4-point diffraction crosses
	for i in range(25):
		stars_bright.append({
			"pos": Vector2(randf_range(-3000, 3000), randf_range(-3000, 3000)),
			"size": randf_range(2.8, 4.0),
			"color": Color(0.9, 0.95, 1.0),
			"spike_len": randf_range(8.0, 16.0),
			"twinkle_speed": randf_range(1.0, 3.0),
			"phase": randf() * TAU
		})

func _process(delta: float) -> void:
	time_elapsed += delta
	queue_redraw()

func _draw() -> void:
	var cam_pos = Vector2.ZERO
	var vp = get_viewport()
	if vp and vp.get_camera_2d():
		cam_pos = vp.get_camera_2d().global_position

	# 1. Background Deep Void Fill
	var view_rect = Rect2(cam_pos - Vector2(1000, 700), Vector2(2000, 1400))
	draw_rect(view_rect, Color(0.012, 0.018, 0.035, 1.0))

	# 2. Cosmic Nebula Clouds (Soft gradient discs with drift)
	for neb in nebulae:
		var neb_pos = neb["pos"] + neb["drift_speed"] * time_elapsed
		# Parallax relative to camera
		var rel_pos = (neb_pos - cam_pos * 0.4)
		rel_pos.x = fposmod(rel_pos.x + 3500.0, 7000.0) - 3500.0
		rel_pos.y = fposmod(rel_pos.y + 3500.0, 7000.0) - 3500.0
		var draw_pt = cam_pos + rel_pos
		
		# Draw layered soft falloff
		var col = neb["color"]
		var rad = neb["radius"]
		draw_circle(draw_pt, rad, Color(col.r, col.g, col.b, col.a * 0.4))
		draw_circle(draw_pt, rad * 0.65, Color(col.r, col.g, col.b, col.a * 0.7))
		draw_circle(draw_pt, rad * 0.35, Color(col.r * 1.3, col.g * 1.3, col.b * 1.3, col.a * 0.9))

	# 3. Far Starfield (Parallax 0.15)
	for s in stars_far:
		var rel = (s["pos"] - cam_pos * 0.85)
		rel.x = fposmod(rel.x + 3500.0, 7000.0) - 3500.0
		rel.y = fposmod(rel.y + 3500.0, 7000.0) - 3500.0
		var pt = cam_pos + rel
		var a = s["alpha"] * (0.7 + 0.3 * sin(time_elapsed * s["twinkle_speed"] + s["phase"]))
		draw_circle(pt, s["size"], Color(0.85, 0.9, 1.0, a))

	# 4. Mid Starfield (Parallax 0.35)
	for s in stars_mid:
		var rel = (s["pos"] - cam_pos * 0.65)
		rel.x = fposmod(rel.x + 3500.0, 7000.0) - 3500.0
		rel.y = fposmod(rel.y + 3500.0, 7000.0) - 3500.0
		var pt = cam_pos + rel
		var a = s["alpha"] * (0.8 + 0.2 * sin(time_elapsed * s["twinkle_speed"] + s["phase"]))
		var col: Color = s["color"]
		draw_circle(pt, s["size"], Color(col.r, col.g, col.b, a))

	# 5. Bright Hero Stars with 4-Point Diffraction Crosses (Parallax 0.5)
	for s in stars_bright:
		var rel = (s["pos"] - cam_pos * 0.5)
		rel.x = fposmod(rel.x + 3500.0, 7000.0) - 3500.0
		rel.y = fposmod(rel.y + 3500.0, 7000.0) - 3500.0
		var pt = cam_pos + rel
		var pulse = 0.8 + 0.2 * sin(time_elapsed * s["twinkle_speed"] + s["phase"])
		var a = pulse * 0.95
		var col: Color = s["color"]
		
		# Core
		draw_circle(pt, s["size"], Color(1.0, 1.0, 1.0, a))
		# 4 Spikes
		var sl = s["spike_len"] * pulse
		var spike_col = Color(col.r, col.g, col.b, a * 0.6)
		draw_line(pt - Vector2(sl, 0), pt + Vector2(sl, 0), spike_col, 1.2)
		draw_line(pt - Vector2(0, sl), pt + Vector2(0, sl), spike_col, 1.2)

	# 6. Orbital Station High-Tech Decking & Grid
	var grid_step = 100.0
	var start_x = floor((cam_pos.x - 900.0) / grid_step) * grid_step
	var end_x = ceil((cam_pos.x + 900.0) / grid_step) * grid_step
	var start_y = floor((cam_pos.y - 600.0) / grid_step) * grid_step
	var end_y = ceil((cam_pos.y + 600.0) / grid_step) * grid_step
	
	var grid_line_col = Color(0.10, 0.28, 0.45, 0.18)
	var major_line_col = Color(0.18, 0.45, 0.70, 0.30)
	
	var x = start_x
	while x <= end_x:
		var is_major = (int(abs(x)) % 500 == 0)
		draw_line(Vector2(x, start_y), Vector2(x, end_y), major_line_col if is_major else grid_line_col, 1.5 if is_major else 1.0)
		x += grid_step
		
	var y = start_y
	while y <= end_y:
		var is_major = (int(abs(y)) % 500 == 0)
		draw_line(Vector2(start_x, y), Vector2(end_x, y), major_line_col if is_major else grid_line_col, 1.5 if is_major else 1.0)
		y += grid_step

	# High-tech navigation crosshairs at grid intersections every 500px
	var cross_x = floor((cam_pos.x - 900.0) / 500.0) * 500.0
	while cross_x <= end_x:
		var cross_y = floor((cam_pos.y - 600.0) / 500.0) * 500.0
		while cross_y <= end_y:
			var center = Vector2(cross_x, cross_y)
			draw_circle(center, 3.0, Color(0.2, 0.8, 1.0, 0.5))
			draw_line(center - Vector2(10, 0), center + Vector2(10, 0), Color(0.2, 0.8, 1.0, 0.35), 1.0)
			draw_line(center - Vector2(0, 10), center + Vector2(0, 10), Color(0.2, 0.8, 1.0, 0.35), 1.0)
			cross_y += 500.0
		cross_x += 500.0

	# 7. Station Core Perimeter & Hazard Shield Ring
	var shield_pulse = sin(time_elapsed * 2.0) * 0.15 + 0.85
	var outer_shield_col = Color(0.9, 0.2, 0.3, 0.45 * shield_pulse)
	draw_arc(Vector2.ZERO, station_radius, 0, TAU, 96, outer_shield_col, 5.0)
	draw_arc(Vector2.ZERO, station_radius - 20.0, 0, TAU, 96, Color(0.9, 0.4, 0.2, 0.25 * shield_pulse), 2.0)
