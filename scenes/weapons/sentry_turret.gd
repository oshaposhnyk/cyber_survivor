extends Node2D

# Engineer sentry: stationary, fires blaster bolts at the nearest enemy until its charge runs out.
# Tesla coil and missile battery upgrades mount on every turret.

const RANGE := 430.0
const ACCENT := Color(1.0, 0.55, 0.15)
const ZAP_COLOR := Color(0.55, 0.85, 1.0)
const FORTRESS_RADIUS := 170.0
const MAX_ZAP_LINES := 6
# CIWS: a turret with a tesla coil or missile battery zaps one hostile shot nearby
const CIWS_RANGE := 140.0
const CIWS_INTERVAL := 0.35
const BOLT_SCENE := preload("res://scenes/weapons/blaster_bolt.tscn")
const MISSILE_SCENE := preload("res://scenes/weapons/missile.tscn")

var damage: float = 20.0
var fire_interval: float = 0.55
var lifetime: float = 12.0
var max_lifetime: float = 12.0
var tesla_lvl: int = 0
var battery_lvl: int = 0
var is_fortress: bool = false

var fire_timer: float = 0.2
var tesla_timer: float = 1.0
var battery_timer: float = 1.5
var aim_angle: float = -PI / 2.0
var age: float = 0.0
var muzzle_flash: float = 0.0
var zap_lines: Array[PackedVector2Array] = []
var zap_life: float = 0.0
var ciws_timer: float = 0.0
# ENG-05 dome: radius 0 when the skill is not learned
var dome_radius: float = 0.0

func setup(p_pos: Vector2, p_damage: float, p_lifetime: float, p_tesla: int, p_battery: int, p_fortress: bool) -> void:
	global_position = p_pos
	damage = p_damage
	lifetime = p_lifetime
	max_lifetime = p_lifetime
	tesla_lvl = p_tesla
	battery_lvl = p_battery
	is_fortress = p_fortress
	if is_fortress:
		fire_interval *= 0.5

func _ready() -> void:
	z_index = 4
	if GameManager.get_skill_level("dome") > 0 and is_instance_valid(GameManager.player_node):
		dome_radius = GameManager.player_node.dome_radius()

func _physics_process(delta: float) -> void:
	age += delta
	lifetime -= delta
	if lifetime <= 0.0:
		EnemyBase.spawn_explosion(get_parent(), global_position, 22.0, ACCENT)
		queue_free()
		return
	muzzle_flash = maxf(0.0, muzzle_flash - delta * 8.0)
	zap_life = maxf(0.0, zap_life - delta * 4.0)

	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = fire_interval
		fire_bolt()

	if tesla_lvl > 0:
		tesla_timer -= delta
		if tesla_timer <= 0.0:
			tesla_timer = 1.8
			discharge_tesla()

	if dome_radius > 0.0:
		EnemyShots.clear_radius(global_position, dome_radius, ACCENT)

	if tesla_lvl > 0 or battery_lvl > 0:
		ciws_timer -= delta
		if ciws_timer <= 0.0 and run_ciws():
			ciws_timer = CIWS_INTERVAL

	if battery_lvl > 0:
		battery_timer -= delta
		if battery_timer <= 0.0:
			battery_timer = 3.0 - 0.5 * (battery_lvl - 1)
			fire_battery()

	queue_redraw()

func fire_bolt() -> void:
	var found = EnemyRegistry.nearest(global_position, 1, RANGE)
	if found.is_empty():
		return
	var dir = (found[0].global_position - global_position).normalized()
	aim_angle = dir.angle()
	var bolt = BOLT_SCENE.instantiate()
	bolt.setup(global_position + dir * 22.0, dir, damage, 1, GameManager.get_skill_level("conductor") > 0)
	get_parent().add_child(bolt)
	muzzle_flash = 1.0

# Shoots down the nearest hostile shot; true when one was hit
func run_ciws() -> bool:
	var shots = EnemyShots.in_radius(global_position, CIWS_RANGE)
	if shots.is_empty():
		return false
	var best = shots[0]
	for s in shots:
		if global_position.distance_squared_to(s.global_position) < global_position.distance_squared_to(best.global_position):
			best = s
	var to_s: Vector2 = best.global_position - global_position
	best.pop(ZAP_COLOR)
	zap_lines.clear()
	zap_lines.append(_jagged(Vector2.ZERO, to_s))
	zap_life = 1.0
	return true

func tesla_radius() -> float:
	return 110.0 * (1.0 + 0.25 * (tesla_lvl - 1))

func discharge_tesla() -> void:
	var targets = EnemyRegistry.in_radius(global_position, tesla_radius())
	if targets.is_empty():
		return
	var dmg = (18.0 + 15.0 * tesla_lvl) * damage / 20.0
	zap_lines.clear()
	for e in targets:
		var to_e = e.global_position - global_position
		e.take_damage(dmg, to_e.normalized() * 0.4)
		if zap_lines.size() < MAX_ZAP_LINES:
			zap_lines.append(_jagged(Vector2.ZERO, to_e))
	zap_life = 1.0
	AudioManager.play_sfx("laser", 0.2, -6.0)

func fire_battery() -> void:
	var targets = EnemyRegistry.nearest(global_position, battery_lvl, 650.0)
	if targets.is_empty():
		return
	for i in range(battery_lvl):
		var m = MISSILE_SCENE.instantiate()
		var side = -1.0 if i % 2 == 0 else 1.0
		m.setup(global_position, Vector2.UP.rotated(side * 0.6), (40.0 + 15.0 * battery_lvl) * damage / 20.0, 60.0, false)
		m.target = targets[i % targets.size()]
		get_parent().add_child(m)
	AudioManager.play_sfx("missile", 0.15, -4.0)

func _jagged(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([a])
	var normal = (b - a).orthogonal().normalized()
	for i in range(1, 5):
		pts.append(a.lerp(b, i / 5.0) + normal * randf_range(-9.0, 9.0))
	pts.append(b)
	return pts

func _octagon(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(8):
		pts.append(Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * r)
	return pts

func _draw() -> void:
	# Deploy shockwave in the first half second
	if age < 0.5:
		var k = age / 0.5
		draw_arc(Vector2.ZERO, 14.0 + 40.0 * k, 0.0, TAU, 24, Color(ACCENT, 1.0 - k), 2.0)

	# Dome generator: faint fill, rotating segmented rim
	if dome_radius > 0.0:
		draw_circle(Vector2.ZERO, dome_radius, Color(ACCENT, 0.06))
		for i in range(12):
			var da := age * 0.5 + TAU * i / 12.0
			draw_arc(Vector2.ZERO, dome_radius, da, da + TAU / 24.0, 4, Color(ACCENT, 0.55), 2.0)

	if is_fortress:
		draw_circle(Vector2.ZERO, FORTRESS_RADIUS, Color(ACCENT, 0.04))
		draw_arc(Vector2.ZERO, FORTRESS_RADIUS, 0.0, TAU, 48, Color(ACCENT, 0.25), 1.5)

	if tesla_lvl > 0:
		draw_arc(Vector2.ZERO, tesla_radius(), age, age + TAU * 0.15, 12, Color(ZAP_COLOR, 0.25), 1.5)
		draw_arc(Vector2.ZERO, tesla_radius(), age + PI, age + PI + TAU * 0.15, 12, Color(ZAP_COLOR, 0.25), 1.5)

	# Base
	var body = _octagon(16.0)
	draw_colored_polygon(body, Color(0.06, 0.06, 0.09))
	var rim = body.duplicate()
	rim.append(body[0])
	draw_polyline(rim, ACCENT, 2.0, true)

	# Missile pods either side of the base
	if battery_lvl > 0:
		for side in [-1.0, 1.0]:
			draw_rect(Rect2(Vector2(side * 18.0 - 3.0, -6.0), Vector2(6, 12)), Color(ACCENT, 0.85))

	# Barrel tracks the last target
	var dir = Vector2.from_angle(aim_angle)
	draw_line(Vector2.ZERO, dir * 22.0, Color(0.02, 0.02, 0.04), 7.0)
	draw_line(Vector2.ZERO, dir * 22.0, ACCENT, 3.0)
	draw_circle(Vector2.ZERO, 6.0, ACCENT.lerp(Color.WHITE, 0.3))
	if muzzle_flash > 0.0:
		draw_circle(dir * 24.0, 6.0 * muzzle_flash, Color(1.0, 0.9, 0.5, muzzle_flash))

	# Tesla coil cap flickers when charged
	if tesla_lvl > 0:
		draw_circle(Vector2.ZERO, 3.5, Color(ZAP_COLOR, 0.6 + 0.4 * sin(age * 20.0)))

	if zap_life > 0.0:
		for line in zap_lines:
			draw_polyline(line, Color(ZAP_COLOR, zap_life * 0.5), 4.0)
			draw_polyline(line, Color(1, 1, 1, zap_life), 1.5)

	# Remaining charge
	var frac = clampf(lifetime / max_lifetime, 0.0, 1.0)
	draw_arc(Vector2.ZERO, 22.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 32, Color(ACCENT, 0.6), 2.0)
