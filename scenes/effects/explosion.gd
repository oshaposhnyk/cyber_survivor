extends Node2D

@export var blast_color: Color = Color(1.0, 0.6, 0.1)
@export var max_radius: float = 35.0

var current_radius: float = 0.0
var ring_alpha: float = 1.0

func _ready() -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "current_radius", max_radius, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "ring_alpha", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Expanding shockwave circle
	var col = blast_color
	col.a = ring_alpha
	draw_circle(Vector2.ZERO, current_radius, Color(col.r, col.g, col.b, col.a * 0.3))
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, col, 3.0)
	
	# Core flash
	var core_col = Color.WHITE
	core_col.a = ring_alpha * 0.8
	draw_circle(Vector2.ZERO, current_radius * 0.35, core_col)
