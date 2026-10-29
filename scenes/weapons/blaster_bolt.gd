extends Area2D

@export var speed: float = 800.0
@export var damage: float = 25.0
@export var lifetime: float = 2.5
@export var pierce_count: int = 1
@export var can_chain: bool = false
@export var chain_targets_count: int = 2

var velocity: Vector2 = Vector2.ZERO
var hits_done: int = 0
var hit_enemies: Array = []

# Trailing plasma line history
var trail: Array[Vector2] = []

# --- Visual-only state (no gameplay effect) ---
const MUZZLE_TEX := preload("res://assets/sprites/fx/muzzle_flash.png")
const SPARK_TEX := preload("res://assets/sprites/fx/spark_star.png")
const GLOW_TEX := preload("res://assets/sprites/fx/glow_soft.png")
const LIGHTNING_TEX := preload("res://assets/sprites/fx/lightning.png")
const MUZZLE_TIME := 0.07
const IMPACT_TIME := 0.18
const ARC_TIME := 0.24
const MAX_ARCS := 4
const BOLT_CYAN := Color(0.2, 0.85, 1.0)
const STORM_MAGENTA := Color(1.0, 0.3, 0.85)

var spawn_pos: Vector2 = Vector2.ZERO
var age: float = 0.0
var is_storm: bool = false
var impact_timer: float = -1.0
var impact_pos: Vector2 = Vector2.ZERO
# Fixed-size chain arc buffers (global coords + remaining life)
var arc_a: PackedVector2Array = PackedVector2Array()
var arc_b: PackedVector2Array = PackedVector2Array()
var arc_life: PackedFloat32Array = PackedFloat32Array()
var arc_head: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow: Sprite2D = $Glow

func setup(p_position: Vector2, p_direction: Vector2, p_damage: float, p_pierce: int = 1, p_chain: bool = false) -> void:
	global_position = p_position
	velocity = p_direction.normalized() * speed
	rotation = p_direction.angle() + PI / 2.0
	damage = p_damage
	pierce_count = p_pierce
	can_chain = p_chain
	spawn_pos = p_position

# Hit circle of the bolt; enemies are found through EnemyRegistry, not physics
const HIT_RADIUS := 6.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	if spawn_pos == Vector2.ZERO:
		spawn_pos = global_position
	arc_a.resize(MAX_ARCS)
	arc_b.resize(MAX_ARCS)
	arc_life.resize(MAX_ARCS)
	is_storm = can_chain and GameManager.is_synergy_active("plasma_storm")
	if can_chain:
		chain_targets_count = GameManager.chain_targets()
	var tint := STORM_MAGENTA if is_storm else BOLT_CYAN
	glow.modulate = Color(tint, 0.85)
	if is_storm:
		sprite.modulate = Color(1.0, 0.75, 1.0)
		glow.scale *= 1.3

func _physics_process(delta: float) -> void:
	age += delta
	_tick_arcs(delta)

	# Impact linger: projectile is spent, only the hit flash is drawn
	if impact_timer >= 0.0:
		impact_timer -= delta
		queue_redraw()
		if impact_timer <= 0.0 and not _arcs_alive():
			queue_free()
		return

	trail.push_front(global_position)
	if trail.size() > 6:
		trail.pop_back()

	global_position += velocity * delta
	queue_redraw()
	var hit = EnemyRegistry.first_hit(global_position, HIT_RADIUS, hit_enemies)
	if hit:
		_on_hit(hit)
		return
	# Clash: a bolt that meets a hostile shot destroys it and is spent too
	var shots = EnemyShots.in_radius(global_position, HIT_RADIUS + 6.0)
	if not shots.is_empty():
		shots[0].pop(STORM_MAGENTA if is_storm else BOLT_CYAN)
		_start_impact(global_position)

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _arcs_alive() -> bool:
	for i in MAX_ARCS:
		if arc_life[i] > 0.0:
			return true
	return false

func _tick_arcs(delta: float) -> void:
	for i in MAX_ARCS:
		if arc_life[i] > 0.0:
			arc_life[i] -= delta

func _draw() -> void:
	var tint := STORM_MAGENTA if is_storm else BOLT_CYAN

	# 1. Muzzle flash at the emitter for the first frames
	if age < MUZZLE_TIME:
		var mk := 1.0 - age / MUZZLE_TIME
		var mp := to_local(spawn_pos)
		var msz := Vector2(16.0, 28.0) * (0.7 + 0.5 * mk)
		draw_texture_rect(MUZZLE_TEX, Rect2(mp - Vector2(msz.x * 0.5, msz.y * 0.85), msz), false, Color(tint.lerp(Color.WHITE, 0.4), mk))
		draw_texture_rect(GLOW_TEX, Rect2(mp - Vector2(14, 14), Vector2(28, 28)), false, Color(tint, 0.6 * mk))

	# 2. Glowing plasma tail behind the bolt (additive via node material)
	if impact_timer < 0.0 and trail.size() > 1:
		for i in range(trail.size() - 1):
			var p1 = to_local(trail[i])
			var p2 = to_local(trail[i+1])
			var a = (1.0 - float(i) / trail.size()) * 0.7
			draw_line(p1, p2, Color(tint, a), 4.0)
			draw_line(p1, p2, Color(1.0, 1.0, 1.0, a * 0.9), 1.4)

	# 3. Impact flash and sparks
	if impact_timer >= 0.0:
		var ik := clampf(impact_timer / IMPACT_TIME, 0.0, 1.0)
		var ip := to_local(impact_pos)
		var gs := 34.0 * (1.4 - ik * 0.4)
		draw_texture_rect(GLOW_TEX, Rect2(ip - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(tint, 0.8 * ik))
		var ss := 30.0 * (0.6 + (1.0 - ik) * 0.8)
		draw_texture_rect(SPARK_TEX, Rect2(ip - Vector2(ss, ss) * 0.5, Vector2(ss, ss)), false, Color(1, 1, 1, ik))

	# 4. Chain lightning arcs (plasma storm / conductor)
	for i in MAX_ARCS:
		if arc_life[i] > 0.0:
			_draw_arc_bolt(to_local(arc_a[i]), to_local(arc_b[i]), arc_life[i] / ARC_TIME, tint)

func _draw_arc_bolt(p1: Vector2, p2: Vector2, k: float, tint: Color) -> void:
	var d := p2 - p1
	var length := d.length()
	if length < 2.0:
		return
	var width := (54.0 if is_storm else 38.0)
	# Lightning texture is vertical: rotate +Y onto the arc direction
	draw_set_transform((p1 + p2) * 0.5, d.angle() - PI / 2.0, Vector2.ONE)
	draw_texture_rect(LIGHTNING_TEX, Rect2(-width * 0.5, -length * 0.5, width, length), false, Color(tint.lerp(Color.WHITE, 0.3), k))
	if is_storm:
		# Second, mirrored strand in the other synergy colour
		draw_texture_rect(LIGHTNING_TEX, Rect2(width * 0.5, -length * 0.5, -width, length), false, Color(BOLT_CYAN, k * 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Hot core: jagged polyline, re-rolled each redraw for crackle
	var n := d.normalized().orthogonal()
	var m1 := p1 + d * 0.33 + n * randf_range(-10, 10)
	var m2 := p1 + d * 0.66 + n * randf_range(-10, 10)
	draw_polyline(PackedVector2Array([p1, m1, m2, p2]), Color(1, 1, 1, k), 1.6)
	var es := 26.0 * k
	draw_texture_rect(GLOW_TEX, Rect2(p2 - Vector2(es, es) * 0.5, Vector2(es, es)), false, Color(tint, k))

func _start_impact(at: Vector2) -> void:
	if impact_timer >= 0.0:
		return
	impact_pos = at
	impact_timer = IMPACT_TIME
	sprite.visible = false
	glow.visible = false

func _on_hit(body: Object) -> void:
	if body in hit_enemies:
		return

	hit_enemies.append(body)
	hits_done += 1

	if body.has_method("take_damage"):
		body.take_damage(damage, velocity.normalized())

	if can_chain:
		trigger_chain_lightning(body)

	if hits_done >= pierce_count:
		# Was queue_free(): the bolt now stops, stops monitoring and frees after the hit flash
		_start_impact(global_position)

func trigger_chain_lightning(origin_enemy: Object) -> void:
	var exclude: Array = hit_enemies.duplicate()
	exclude.append(origin_enemy)
	var origin_pos = origin_enemy.global_position
	for enemy in EnemyRegistry.nearest(origin_pos, chain_targets_count, 220.0, exclude):
		hit_enemies.append(enemy)
		spawn_chain_fx(origin_pos, enemy.global_position)
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage * 0.8, (enemy.global_position - origin_pos).normalized())

# Drawn by this bolt from a fixed ring buffer: no Line2D or Tween per chain target
func spawn_chain_fx(p1: Vector2, p2: Vector2) -> void:
	arc_a[arc_head] = p1
	arc_b[arc_head] = p2
	arc_life[arc_head] = ARC_TIME
	arc_head = (arc_head + 1) % MAX_ARCS
