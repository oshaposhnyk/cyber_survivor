extends Node2D

@export var grid_size: float = 80.0
@export var grid_color: Color = Color(0.12, 0.22, 0.35, 0.25)
@export var star_count: int = 120

var stars: Array[Vector2] = []
var star_sizes: Array[float] = []
var star_alphas: Array[float] = []

func _ready() -> void:
	z_index = -10
	# Generate static starfield relative to world
	for i in range(star_count):
		stars.append(Vector2(randf_range(-3000, 3000), randf_range(-3000, 3000)))
		star_sizes.append(randf_range(1.0, 2.5))
		star_alphas.append(randf_range(0.3, 0.9))

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var cam_pos = get_viewport().get_camera_2d().global_position if get_viewport().get_camera_2d() else Vector2.ZERO
	
	# Draw stars with slight parallax
	for i in range(stars.size()):
		var star_pos = stars[i]
		# Wrap around camera viewport
		var rel = (star_pos - cam_pos * 0.9)
		rel.x = fposmod(rel.x + 2500.0, 5000.0) - 2500.0
		rel.y = fposmod(rel.y + 2500.0, 5000.0) - 2500.0
		var screen_pt = cam_pos + rel
		var col = Color(0.85, 0.95, 1.0, star_alphas[i])
		draw_circle(screen_pt, star_sizes[i], col)

	# Draw sci-fi arena coordinate grid around camera
	var start_x = floor((cam_pos.x - 1000.0) / grid_size) * grid_size
	var end_x = ceil((cam_pos.x + 1000.0) / grid_size) * grid_size
	var start_y = floor((cam_pos.y - 700.0) / grid_size) * grid_size
	var end_y = ceil((cam_pos.y + 700.0) / grid_size) * grid_size
	
	var x = start_x
	while x <= end_x:
		draw_line(Vector2(x, start_y), Vector2(x, end_y), grid_color, 1.0)
		x += grid_size
		
	var y = start_y
	while y <= end_y:
		draw_line(Vector2(start_x, y), Vector2(end_x, y), grid_color, 1.0)
		y += grid_size
		
	# Draw orbital station boundary marker ring
	draw_arc(Vector2.ZERO, 3500.0, 0, TAU, 64, Color(0.9, 0.2, 0.2, 0.4), 4.0)
