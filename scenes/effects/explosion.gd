extends Node2D

@export var blast_color: Color = Color(1.0, 0.5, 0.1)
@export var max_radius: float = 38.0

var current_radius: float = 0.0
var ring_alpha: float = 1.0

# Shrapnel / energetic spark particles
var sparks: Array[Dictionary] = []

func _ready() -> void:
	z_index = 22
	# Generate 14-20 shrapnel sparks
	var spark_count = randi_range(14, 20)
	for i in range(spark_count):
		var ang = randf() * TAU
		var spd = randf_range(70.0, 240.0)
		sparks.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"size": randf_range(1.5, 3.2),
			"life": randf_range(0.3, 0.55),
			"color": Color(1.0, randf_range(0.6, 1.0), randf_range(0.2, 0.8))
		})

	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "current_radius", max_radius, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "ring_alpha", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

func _process(delta: float) -> void:
	for s in sparks:
		s["pos"] += s["vel"] * delta
		s["vel"] = s["vel"].move_toward(Vector2.ZERO, 350.0 * delta)
		s["life"] -= delta
	queue_redraw()

func _draw() -> void:
	# 1. Outer shockwave halo
	var col = blast_color
	col.a = ring_alpha
	draw_circle(Vector2.ZERO, current_radius, Color(col.r, col.g, col.b, col.a * 0.25))
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 36, col, 3.5)
	
	# 2. Secondary inner distortion ring
	if current_radius > 12.0:
		var inner_col = Color(1.0, 0.9, 0.4, ring_alpha * 0.7)
		draw_arc(Vector2.ZERO, current_radius * 0.6, 0, TAU, 28, inner_col, 2.0)
	
	# 3. Core plasma blinding flash
	var core_col = Color(1.0, 1.0, 1.0, ring_alpha * 0.95)
	draw_circle(Vector2.ZERO, max(2.0, (1.0 - ring_alpha * 0.7) * current_radius * 0.4), core_col)
	
	# 4. Flying Shrapnel Sparks
	for s in sparks:
		if s["life"] > 0.0:
			var sa = clampf(s["life"] / 0.4, 0.0, 1.0)
			var sc: Color = s["color"]
			draw_circle(s["pos"], s["size"], Color(sc.r, sc.g, sc.b, sa))
			# Motion blur spark streak
			draw_line(s["pos"], s["pos"] - s["vel"] * 0.03, Color(sc.r, sc.g, sc.b, sa * 0.6), 1.5)
