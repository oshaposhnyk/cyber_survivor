extends Node2D

@export var max_radius: float = 240.0
@export var damage: float = 60.0
@export var stun_duration: float = 2.5
@export var is_apocalypse: bool = false

var current_radius: float = 0.0
var alpha: float = 1.0
var hit_ids: Dictionary = {}

# --- Visual-only ---
const RING_TEX := preload("res://assets/sprites/fx/ring.png")
const TWIRL_TEX := preload("res://assets/sprites/fx/twirl_arc.png")
const GLOW_TEX := preload("res://assets/sprites/fx/glow_soft.png")
# Bright band of ring.png sits at 60 % of its half-size; twirl arc at ~80 %
const RING_BAND := 0.6
const TWIRL_BAND := 0.8
const EMP_VIOLET := Color(0.75, 0.3, 1.0)
const SYN_MAGENTA := Color(1.0, 0.3, 0.85)
const SPOKES := 20
var spin: float = 0.0

func setup(p_origin: Vector2, p_radius: float, p_damage: float, p_stun: float, p_apocalypse: bool = false) -> void:
	global_position = p_origin
	max_radius = p_radius
	damage = p_damage
	stun_duration = p_stun
	is_apocalypse = p_apocalypse
	if is_apocalypse:
		max_radius = 800.0 # Screen-wide
		damage *= 2.0
		stun_duration = 4.0

func _ready() -> void:
	z_index = 12
	AudioManager.play_sfx("emp_blast", 0.05, 3.0 if is_apocalypse else 0.0)
	spin = randf() * TAU

	var duration = 0.55 if not is_apocalypse else 0.8
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "current_radius", max_radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "alpha", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	spin += delta * (2.4 if is_apocalypse else 3.2)
	queue_redraw()

	# Detect enemies inside current wave radius
	# Set lookup by instance id: the old Array 'in' check was O(N) per enemy per frame
	var r2 = current_radius * current_radius
	# Bullet clear: the wave front burns every hostile shot it passes
	EnemyShots.clear_radius(global_position, current_radius, SYN_MAGENTA if is_apocalypse else EMP_VIOLET)
	for enemy in EnemyRegistry.list:
		if enemy.is_dead or hit_ids.has(enemy.get_instance_id()):
			continue
		if global_position.distance_squared_to(enemy.global_position) <= r2:
			hit_ids[enemy.get_instance_id()] = true
			if enemy.has_method("apply_stun"):
				enemy.apply_stun(stun_duration)
			if enemy.has_method("take_damage"):
				var push = (enemy.global_position - global_position).normalized()
				enemy.take_damage(damage, push)

func _ring(r: float, col: Color) -> void:
	var h := r / RING_BAND
	draw_texture_rect(RING_TEX, Rect2(-h, -h, h * 2.0, h * 2.0), false, col)

func _draw() -> void:
	var r := current_radius
	if r < 1.0:
		return
	var col := SYN_MAGENTA if is_apocalypse else EMP_VIOLET
	var a := alpha

	# 1. Interior fill: a soft glow disc (apocalypse doubles as a screen flash)
	var fill_a := a * (0.1 if not is_apocalypse else 0.2 * a + 0.05)
	draw_texture_rect(GLOW_TEX, Rect2(-r * 1.1, -r * 1.1, r * 2.2, r * 2.2), false, Color(col, fill_a))

	# 2. Leading shock front: bright textured ring + thin white edge
	_ring(r, Color(col, a))
	draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1, 1, 1, a * 0.7), 2.0)

	# 3. Trailing distortion ring (lags behind the front)
	_ring(r * 0.72, Color(col.lerp(Color(0.3, 0.9, 1.0), 0.5), a * 0.4))

	# 4. Rotating ion swirls riding the front
	var th := r / TWIRL_BAND
	for i in 3:
		draw_set_transform(Vector2.ZERO, spin + TAU / 3.0 * i, Vector2.ONE)
		draw_texture_rect(TWIRL_TEX, Rect2(-th, -th, th * 2.0, th * 2.0), false, Color(col.lerp(Color.WHITE, 0.3), a * 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 5. Apocalypse only: second outer ring, radial glitch spokes and core flare
	if is_apocalypse:
		_ring(r * 1.08, Color(0.3, 0.9, 1.0, a * 0.6))
		for i in SPOKES:
			var ang := spin * 0.5 + TAU / SPOKES * i
			var dir := Vector2(cos(ang), sin(ang))
			var inner := r * (0.55 + 0.1 * sin(spin * 3.0 + i))
			draw_line(dir * inner, dir * r * 0.97, Color(SYN_MAGENTA, a * 0.45), 3.0)
		var core := 160.0 * (0.5 + a)
		draw_texture_rect(GLOW_TEX, Rect2(-core * 0.5, -core * 0.5, core, core), false, Color(1, 1, 1, a * 0.8))
