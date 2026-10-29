extends Node2D

var pulse_time: float = 0.0

func _process(delta: float) -> void:
	pulse_time += delta * 3.0
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var rad = 32.0 + sin(pulse_time) * 1.5
	var color = Color(0.2, 0.8, 1.0, 0.35 + sin(pulse_time) * 0.1)
	draw_circle(Vector2.ZERO, rad, Color(color.r, color.g, color.b, 0.12))
	draw_arc(Vector2.ZERO, rad, 0, TAU, 32, color, 2.5)
