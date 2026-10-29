class_name EnemyShots
extends RefCounted

# Live enemy projectiles (enemy_laser.gd), for the anti-projectile mechanics:
# drones, deflector, Aegis dome, EMP, dilation, dash trail, turrets, mines, bolts, railgun.
# The fire director keeps the count in the tens, so plain scans are enough.

static var list: Array = []

static func register(s: Node2D) -> void:
	list.append(s)

static func unregister(s: Node2D) -> void:
	list.erase(s)

# Shots that can still be stopped or turned (not already popping)
static func in_radius(pos: Vector2, r: float, hostile_only: bool = true) -> Array:
	var out := []
	var r2 := r * r
	for s in list:
		if s.is_live() and (not hostile_only or s.is_hostile()) and pos.distance_squared_to(s.global_position) <= r2:
			out.append(s)
	return out

static func on_segment(a: Vector2, b: Vector2, half_width: float) -> Array:
	var out := []
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	var w2 := half_width * half_width
	for s in list:
		if not s.is_live() or not s.is_hostile():
			continue
		var t := clampf((s.global_position - a).dot(ab) / len2, 0.0, 1.0)
		if s.global_position.distance_squared_to(a + ab * t) <= w2:
			out.append(s)
	return out

# Pops every hostile shot in the circle with `color`; returns how many
static func clear_radius(pos: Vector2, r: float, color: Color) -> int:
	var hit := in_radius(pos, r)
	for s in hit:
		s.pop(color)
	return hit.size()

static func clear_segment(a: Vector2, b: Vector2, half_width: float, color: Color) -> int:
	var hit := on_segment(a, b, half_width)
	for s in hit:
		s.pop(color)
	return hit.size()
