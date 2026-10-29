extends Node2D

# Sprite-sheet explosion (4x4 atlas) with an additive glow flash and shock ring.
# No per-spark arrays, no Tween: frame and fades are driven from one elapsed timer.

@export var blast_color: Color = Color(1.0, 0.5, 0.1)
@export var max_radius: float = 38.0

const SMALL_SHEET := preload("res://assets/sprites/fx/explosion_small_sheet.png")
const BIG_SHEET := preload("res://assets/sprites/fx/explosion_big_sheet.png")
const FRAMES := 16
const BIG_RADIUS := 45.0
# Visible blast diameter as a share of one atlas cell (measured on the sheets)
const SMALL_FILL := 0.46 * 128.0
const BIG_FILL := 0.72 * 192.0
# Ring texture: the bright band sits at 60 % of the half-size
const RING_BAND := 0.6

@onready var sheet: Sprite2D = $Sheet
@onready var glow: Sprite2D = $Glow
@onready var ring: Sprite2D = $Ring

var elapsed: float = 0.0
var duration: float = 0.5
var glow_scale: float = 1.0
var ring_scale: float = 1.0

func _ready() -> void:
	z_index = 22
	var big := max_radius > BIG_RADIUS
	sheet.texture = BIG_SHEET if big else SMALL_SHEET
	sheet.hframes = 4
	sheet.vframes = 4
	sheet.frame = 0
	sheet.rotation = randf() * TAU
	sheet.scale = Vector2.ONE * (max_radius * 2.2 / (BIG_FILL if big else SMALL_FILL))
	# Sheets are pre-coloured fire: only nudge them towards the caller's colour
	sheet.modulate = blast_color.lerp(Color.WHITE, 0.55)
	duration = 0.75 if big else 0.5

	# Glow texture is 128 px; the bright core covers ~70 % of it
	glow_scale = max_radius * 2.0 / (128.0 * 0.7)
	glow.modulate = Color(blast_color.r, blast_color.g, blast_color.b, 0.9)
	# Ring texture is 256 px
	ring_scale = max_radius / (128.0 * RING_BAND)
	ring.modulate = Color(blast_color.lerp(Color.WHITE, 0.3), 0.0)
	_apply(0.0)

func _process(delta: float) -> void:
	elapsed += delta
	var k := elapsed / duration
	if k >= 1.0:
		queue_free()
		return
	_apply(k)

func _apply(k: float) -> void:
	sheet.frame = mini(FRAMES - 1, int(k * FRAMES))
	# Glow: fast pop, then a quadratic fade
	var pop := clampf(k * 6.0, 0.0, 1.0)
	glow.scale = Vector2.ONE * glow_scale * (0.5 + 0.7 * pop)
	glow.modulate.a = 0.9 * pop * (1.0 - k) * (1.0 - k)
	# Shock ring expands to max_radius over the first 60 % of the life
	var rk := clampf(k / 0.6, 0.0, 1.0)
	var ease_out := 1.0 - (1.0 - rk) * (1.0 - rk)
	ring.scale = Vector2.ONE * ring_scale * (0.15 + 0.85 * ease_out)
	ring.modulate.a = 0.85 * (1.0 - rk)
