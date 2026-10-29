extends Node2D

var pulse_time: float = 0.0

func _process(delta: float) -> void:
	pulse_time += delta * 2.5
	rotation += delta * 0.5
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var base_rad = 34.0
	var pulse = sin(pulse_time * 2.0) * 1.5
	var r = base_rad + pulse
	
	# 1. Subtle inner force field glow
	draw_circle(Vector2.ZERO, r, Color(0.1, 0.7, 1.0, 0.12 + sin(pulse_time) * 0.04))
	
	# 2. Main hex ring
	var sides = 6
	var pts: Array[Vector2] = []
	for i in range(sides):
		var ang = (TAU / sides) * i
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	pts.append(pts[0])
	
	for i in range(sides):
		draw_line(pts[i], pts[i+1], Color(0.2, 0.9, 1.0, 0.65 + sin(pulse_time + i) * 0.2), 2.5)
		draw_circle(pts[i], 3.0, Color(0.6, 1.0, 1.0, 0.85))
		
	# 3. Outer shield ripple
	draw_arc(Vector2.ZERO, r + 4.0, 0, TAU, 32, Color(0.1, 0.5, 0.9, 0.25), 1.5)
