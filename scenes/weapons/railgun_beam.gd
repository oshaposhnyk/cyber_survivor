extends Node2D

@export var damage: float = 120.0
@export var beam_length: float = 1400.0
@export var beam_width: float = 16.0

var direction: Vector2 = Vector2.RIGHT
var alpha: float = 1.0
var beam_fired: bool = false

# Jagged lightning crackles along the beam
var lightning_segments: Array[Vector2] = []

# --- Visual-only state ---
const GLOW_TEX := preload("res://assets/sprites/fx/glow_soft.png")
const SPARK_TEX := preload("res://assets/sprites/fx/spark_star.png")
const RING_TEX := preload("res://assets/sprites/fx/ring.png")
const LIFE := 0.4
const CHARGE := 0.06
const MAX_HIT_MARKS := 10
var elapsed: float = 0.0
# Local positions of the first enemies hit, for impact flashes (bounded)
var hit_marks: PackedVector2Array = PackedVector2Array()

func setup(p_origin: Vector2, p_direction: Vector2, p_damage: float) -> void:
	global_position = p_origin
	direction = p_direction.normalized()
	damage = p_damage
	# Visual only: rebuild the crackle along the real direction and drop flashes
	# recorded before setup() moved the node (fire order is player.gd's concern)
	generate_lightning_arcs()
	hit_marks.clear()
	if is_inside_tree() and not beam_fired:
		fire_beam()

func _ready() -> void:
	z_index = 18
	generate_lightning_arcs()
	if not beam_fired:
		fire_beam()

func generate_lightning_arcs() -> void:
	lightning_segments.clear()
	var steps = 18
	var step_len = beam_length / steps
	for i in range(steps + 1):
		var base_pt = direction * (i * step_len)
		var perp = Vector2(-direction.y, direction.x) * randf_range(-14.0, 14.0)
		lightning_segments.append(base_pt + perp)

func fire_beam() -> void:
	if beam_fired or not is_inside_tree():
		return
	beam_fired = true

	# Swarm units have no physics bodies: test the beam segment against the registry.
	# Same 128-target limit as the old shape query.
	var hit_list := EnemyRegistry.on_segment(global_position, global_position + direction * beam_length, 2.0)
	if hit_list.size() > 128:
		hit_list.resize(128)
	for collider in hit_list:
		if hit_marks.size() < MAX_HIT_MARKS:
			hit_marks.append(collider.global_position - global_position)
		if collider.has_method("take_damage"):
			collider.take_damage(damage, direction)

	# Clears a safe corridor: the beam also burns hostile shots on its line
	EnemyShots.clear_segment(global_position, global_position + direction * beam_length, 12.0, Color(0.2, 1.0, 0.75))

	AudioManager.play_sfx("railgun", 0.1)

# Fade driven by a timer instead of a Tween (same 0.4 s ease-out curve)
func _process(delta: float) -> void:
	elapsed += delta
	var k := elapsed / LIFE
	if k >= 1.0:
		queue_free()
		return
	alpha = 1.0 - (1.0 - (1.0 - k) * (1.0 - k))
	queue_redraw()

func _draw() -> void:
	var end_pt = direction * beam_length
	# Charge: beam snaps open over the first frames, then thins while fading
	var open := clampf(elapsed / CHARGE, 0.0, 1.0)
	var w := beam_width * open * (0.45 + 0.55 * alpha)

	# 0. Muzzle charge flash at the emitter
	var cs := 70.0 * (0.6 + 0.8 * alpha)
	draw_texture_rect(GLOW_TEX, Rect2(-Vector2(cs, cs) * 0.5, Vector2(cs, cs)), false, Color(0.2, 1.0, 0.75, alpha))
	var ss := 46.0 * alpha
	draw_set_transform(Vector2.ZERO, elapsed * 6.0, Vector2.ONE)
	draw_texture_rect(SPARK_TEX, Rect2(-Vector2(ss, ss) * 0.5, Vector2(ss, ss)), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 1. Broad outer ionisation aura
	draw_line(Vector2.ZERO, end_pt, Color(0.1, 1.0, 0.6, alpha * 0.35), w * 2.6)

	# 2. Main cyan/emerald beam glow
	draw_line(Vector2.ZERO, end_pt, Color(0.2, 0.95, 0.7, alpha * 0.85), w)

	# 3. Blinding white core
	draw_line(Vector2.ZERO, end_pt, Color(1.0, 1.0, 1.0, alpha * 0.98), maxf(1.0, w * 0.35))

	# 4. Crackling lightning arcs along the beam
	if lightning_segments.size() > 1:
		draw_polyline(PackedVector2Array(lightning_segments), Color(0.5, 1.0, 0.85, alpha * 0.9), 2.2)

	# 5. Expanding ring bursts along the trajectory
	for i in range(1, 5):
		var ring_pos = direction * (i * (beam_length / 5.0))
		var rr := 18.0 * (1.6 - alpha) / 0.6
		draw_texture_rect(RING_TEX, Rect2(ring_pos - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(0.2, 1.0, 0.7, alpha * 0.7))

	# 6. Impact flashes on struck enemies
	var hs := 40.0 * (0.7 + 0.6 * (1.0 - alpha))
	for p in hit_marks:
		draw_texture_rect(GLOW_TEX, Rect2(p - Vector2(hs, hs) * 0.5, Vector2(hs, hs)), false, Color(0.4, 1.0, 0.8, alpha))
