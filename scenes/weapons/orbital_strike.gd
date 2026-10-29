extends Node2D

# WPN-05 Orbital Strike: a warning ring locks on for WARN_TIME, then a beam hits.
# The blast damages every enemy in the circle and clears hostile shots in it.

const WARN_TIME := 0.6
const BEAM_TIME := 0.25
const GLOW_TEX := preload("res://assets/sprites/fx/glow_soft.png")
const RING_TEX := preload("res://assets/sprites/fx/ring.png")
const STRIKE_RED := Color(1.0, 0.25, 0.3)

var radius: float = 130.0
var damage: float = 150.0
var age: float = 0.0
var fired: bool = false

func setup(p_pos: Vector2, p_radius: float, p_damage: float) -> void:
	global_position = p_pos
	radius = p_radius
	damage = p_damage

func _ready() -> void:
	z_index = 24

func _physics_process(delta: float) -> void:
	age += delta
	if not fired and age >= WARN_TIME:
		_detonate()
	if age >= WARN_TIME + BEAM_TIME:
		queue_free()
		return
	queue_redraw()

func _detonate() -> void:
	fired = true
	for e in EnemyRegistry.in_radius(global_position, radius):
		e.take_damage(damage, (e.global_position - global_position).normalized())
	EnemyShots.clear_radius(global_position, radius, STRIKE_RED)
	EnemyBase.spawn_explosion(get_parent(), global_position, radius * 0.7, STRIKE_RED, true)
	AudioManager.play_sfx("heavy_explosion", 0.05, 1.0)
	var main = get_parent()
	if main and main.has_method("apply_screen_shake"):
		main.apply_screen_shake(5.0)

func _draw() -> void:
	if not fired:
		# Lock-on: ring closes in, crosshair ticks, inner fill grows
		var k := clampf(age / WARN_TIME, 0.0, 1.0)
		var r := radius * (1.35 - 0.35 * k)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(STRIKE_RED, 0.4 + 0.5 * k), 2.0)
		draw_circle(Vector2.ZERO, radius * k, Color(STRIKE_RED, 0.08 + 0.1 * k))
		for i in 4:
			var d := Vector2.from_angle(TAU * i / 4.0 + PI / 4.0)
			draw_line(d * (r - 14.0), d * (r + 6.0), Color(STRIKE_RED, 0.9), 2.0)
		return
	# Beam from orbit: tall bright column fading out
	var b := 1.0 - (age - WARN_TIME) / BEAM_TIME
	draw_rect(Rect2(-10.0 * b, -900.0, 20.0 * b, 900.0), Color(1.0, 0.9, 0.9, 0.8 * b))
	draw_rect(Rect2(-24.0 * b, -900.0, 48.0 * b, 900.0), Color(STRIKE_RED, 0.35 * b))
	var g := radius * 2.2
	draw_texture_rect(GLOW_TEX, Rect2(-Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(STRIKE_RED, 0.7 * b))
	var rr := radius * 2.0 * (1.2 - 0.2 * b)
	draw_texture_rect(RING_TEX, Rect2(-Vector2(rr, rr) * 0.5, Vector2(rr, rr)), false, Color(1, 1, 1, b))
