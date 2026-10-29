extends Area2D

@export var speed: float = 430.0
@export var turn_speed: float = 6.5
@export var damage: float = 50.0
@export var aoe_radius: float = 65.0
@export var lifetime: float = 4.0
@export var pierce_count: int = 1
@export var is_valkyrie: bool = false

var current_direction: Vector2 = Vector2.UP
var target: Node2D = null
var hits: int = 0
var hit_enemies: Array[Node2D] = []

# --- Visual-only state ---
const SMOKE_TEX := preload("res://assets/sprites/fx/smoke_puff.png")
const GLOW_TEX := preload("res://assets/sprites/fx/glow_soft.png")
const TRAIL_LEN := 16
const PUFF_LIFE := 0.45
const LAUNCH_TIME := 0.12
const VALK_CYAN := Color(0.3, 0.9, 1.0)
const VALK_MAGENTA := Color(1.0, 0.3, 0.85)

# Exhaust trail: preallocated ring buffer (global coords + age), no per-frame allocations
var trail_pos: PackedVector2Array = PackedVector2Array()
var trail_age: PackedFloat32Array = PackedFloat32Array()
var trail_head: int = 0
var spawn_pos: Vector2 = Vector2.ZERO
var age: float = 0.0

@onready var flame: Sprite2D = $Flame

func setup(p_position: Vector2, p_direction: Vector2, p_damage: float, p_aoe: float = 65.0, p_valkyrie: bool = false) -> void:
	global_position = p_position
	current_direction = p_direction.normalized()
	damage = p_damage
	aoe_radius = p_aoe
	is_valkyrie = p_valkyrie
	if is_valkyrie:
		speed *= 1.35
		pierce_count = 2
		aoe_radius *= 1.5
	rotation = current_direction.angle() + PI / 2.0
	spawn_pos = p_position

var retarget_timer: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	find_closest_target()
	if spawn_pos == Vector2.ZERO:
		spawn_pos = global_position
	trail_pos.resize(TRAIL_LEN)
	trail_age.resize(TRAIL_LEN)
	trail_age.fill(PUFF_LIFE)
	flame.modulate = VALK_CYAN if is_valkyrie else Color(1.0, 0.75, 0.3)

func find_closest_target() -> void:
	var found = EnemyRegistry.nearest(global_position, 1)
	target = found[0] if found.size() > 0 else null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_dead:
		retarget_timer -= delta
		if retarget_timer <= 0.0:
			retarget_timer = 0.15
			find_closest_target()

	if is_instance_valid(target):
		var desired_dir = (target.global_position - global_position).normalized()
		current_direction = current_direction.slerp(desired_dir, turn_speed * delta).normalized()

	rotation = current_direction.angle() + PI / 2.0
	global_position += current_direction * speed * delta

	# Trail puff at the tail
	age += delta
	for i in TRAIL_LEN:
		trail_age[i] += delta
	trail_pos[trail_head] = global_position - current_direction * 14.0
	trail_age[trail_head] = 0.0
	trail_head = (trail_head + 1) % TRAIL_LEN
	var flick := randf_range(0.8, 1.15)
	flame.scale = Vector2(0.22, 0.32 * flick) * (1.3 if is_valkyrie else 1.0)

	queue_redraw()

	lifetime -= delta
	if lifetime <= 0:
		explode()

func _draw() -> void:
	# 1. Launch flash and smoke burst at the missile bay
	if age < LAUNCH_TIME:
		var lk := 1.0 - age / LAUNCH_TIME
		var lp := to_local(spawn_pos)
		var ls := 30.0 * (1.0 + (1.0 - lk))
		draw_texture_rect(SMOKE_TEX, Rect2(lp - Vector2(ls, ls) * 0.5, Vector2(ls, ls)), false, Color(0.85, 0.85, 0.9, 0.55 * lk))
		draw_texture_rect(GLOW_TEX, Rect2(lp - Vector2(14, 14), Vector2(28, 28)), false, Color(1.0, 0.85, 0.5, 0.8 * lk))

	# 2. Smoke trail, oldest first so new puffs sit on top
	var smoke_col := VALK_MAGENTA.lerp(Color(0.8, 0.8, 0.9), 0.35) if is_valkyrie else Color(0.75, 0.72, 0.7)
	var prev := Vector2.INF
	for n in TRAIL_LEN:
		var i := (trail_head + n) % TRAIL_LEN
		var t := trail_age[i]
		if t >= PUFF_LIFE:
			continue
		var k := t / PUFF_LIFE
		var rel := to_local(trail_pos[i])
		var s := 8.0 + k * 18.0
		draw_texture_rect(SMOKE_TEX, Rect2(rel - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(smoke_col, 0.5 * (1.0 - k)))
		# Valkyrie: railgun-accelerated streak through the trail
		if is_valkyrie and prev != Vector2.INF:
			draw_line(prev, rel, Color(VALK_CYAN, 0.8 * (1.0 - k)), 2.5)
		prev = rel

	# 3. Valkyrie piercing tip: bright chevron ahead of the nose
	if is_valkyrie:
		var tip := Vector2(0, -16)
		draw_polyline(PackedVector2Array([tip + Vector2(-7, 7), tip, tip + Vector2(7, 7)]), Color(VALK_MAGENTA, 0.95), 2.5)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies") or body in hit_enemies:
		return
	hit_enemies.append(body)
	hits += 1

	if body.has_method("take_damage"):
		body.take_damage(damage, current_direction)

	if hits >= pierce_count:
		explode()

func explode() -> void:
	EnemyBase.spawn_explosion(get_parent(), global_position, aoe_radius, Color(1.0, 0.35, 0.1) if is_valkyrie else Color(1.0, 0.75, 0.2))

	AudioManager.play_sfx("explosion", 0.2)

	for enemy in EnemyRegistry.in_radius(global_position, aoe_radius):
		if enemy in hit_enemies:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		var falloff = 1.0 - (dist / aoe_radius) * 0.5
		if enemy.has_method("take_damage"):
			var push = (enemy.global_position - global_position).normalized()
			enemy.take_damage(damage * falloff, push)

	queue_free()
