class_name ProximityMine
extends Node2D

# Engineer proximity mine: arms after a short delay, detonates when an enemy comes close.

const MAX_MINES := 24
const ARM_TIME := 0.6
const TRIGGER_RADIUS := 46.0
const CHECK_INTERVAL := 0.1
const ACCENT := Color(1.0, 0.55, 0.15)
const EMP_COLOR := Color(0.4, 0.8, 1.0)

static var live_count: int = 0

var damage: float = 40.0
var blast_radius: float = 75.0
var stun: float = 0.0
var lifetime: float = 18.0
var age: float = 0.0
var check_timer: float = 0.0

func setup(p_pos: Vector2, p_damage: float, p_radius: float, p_stun: float) -> void:
	global_position = p_pos
	damage = p_damage
	blast_radius = p_radius
	stun = p_stun

func _enter_tree() -> void:
	live_count += 1

func _exit_tree() -> void:
	live_count -= 1

func _ready() -> void:
	z_index = 3

func _physics_process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	if age >= ARM_TIME:
		check_timer -= delta
		if check_timer <= 0.0:
			check_timer = CHECK_INTERVAL
			if not EnemyRegistry.nearest(global_position, 1, TRIGGER_RADIUS).is_empty():
				detonate()
				return
	queue_redraw()

func detonate() -> void:
	EnemyShots.clear_radius(global_position, blast_radius, EMP_COLOR if stun > 0.0 else ACCENT)
	for e in EnemyRegistry.in_radius(global_position, blast_radius):
		e.take_damage(damage, (e.global_position - global_position).normalized())
		if stun > 0.0 and e.has_method("apply_stun"):
			e.apply_stun(stun)
	EnemyBase.spawn_explosion(get_parent(), global_position, blast_radius * 0.8, EMP_COLOR if stun > 0.0 else ACCENT)
	AudioManager.play_sfx("explosion", 0.2, -4.0)
	queue_free()

func _draw() -> void:
	var armed = age >= ARM_TIME
	var light = EMP_COLOR if stun > 0.0 else Color(1.0, 0.2, 0.15)
	draw_circle(Vector2.ZERO, 8.0, Color(0.06, 0.06, 0.09))
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 16, ACCENT, 2.0)
	# Blinks faster as it nears the end of its life
	var blink_rate = 6.0 + 10.0 * (age / lifetime)
	if armed and sin(age * blink_rate) > 0.0:
		draw_circle(Vector2.ZERO, 3.0, light)
		draw_circle(Vector2.ZERO, 7.0, Color(light, 0.25))
	elif not armed:
		draw_circle(Vector2.ZERO, 2.5, Color(light, 0.4))
