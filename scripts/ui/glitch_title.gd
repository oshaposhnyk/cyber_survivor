@tool
class_name GlitchTitle
extends Control

# Title text with constant RGB split and short random glitch bursts.

@export var text: String = "TITLE":
	set(v):
		text = v
		_refresh_size()
@export var font_size: int = 64:
	set(v):
		font_size = v
		_refresh_size()
@export var color: Color = CyberPalette.YELLOW
@export var centered: bool = true

var _burst: float = 0.0
var _next_burst: float = 1.5
var _jitter := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_size()

func _font() -> Font:
	return get_theme_font("font", "TitleLabel")

func _refresh_size() -> void:
	if not is_inside_tree():
		return
	var sz = _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	custom_minimum_size = Vector2(sz.x + 8.0, sz.y)
	queue_redraw()

func glitch(duration: float = 0.25) -> void:
	_burst = duration

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_next_burst -= delta
	if _next_burst <= 0.0:
		_burst = randf_range(0.08, 0.22)
		_next_burst = randf_range(1.8, 4.5)
	if _burst > 0.0:
		_burst -= delta
		_jitter = Vector2(randf_range(-6.0, 6.0), randf_range(-2.0, 2.0))
	else:
		_jitter = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var font = _font()
	var sz = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var x = (size.x - sz.x) * 0.5 if centered else 0.0
	var base = Vector2(x, (size.y - sz.y) * 0.5 + font.get_ascent(font_size))
	var split = 2.0 + (6.0 if _burst > 0.0 else 0.0)
	draw_string(font, base + _jitter + Vector2(-split, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(CyberPalette.CYAN, 0.75))
	draw_string(font, base - _jitter + Vector2(split, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(CyberPalette.RED, 0.75))
	draw_string(font, base + _jitter * 0.3, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	if _burst > 0.0:
		# Horizontal tear lines across the glyphs
		for i in 3:
			var y = randf_range(0.0, size.y)
			draw_rect(Rect2(x + randf_range(-20, 20), y, sz.x * randf_range(0.3, 1.0), randf_range(1.0, 4.0)), Color(color, 0.8))
