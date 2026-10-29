class_name FireDirector
extends RefCounted

# Attack tokens: at most MAX_TOKENS swarm shooters aim or fire at the same time.
# 80 assault droids around the ship then fire in rhythmic bursts, not one wall
# of lasers, which leaves gaps to manoeuvre. The boss does not use tokens.

const MAX_TOKENS := 5

# Token holders. Missiles and the railgun read this to hit shooters first.
static var aiming: Array = []

static func request(unit: Object) -> bool:
	_prune()
	if aiming.has(unit):
		return true
	if aiming.size() >= MAX_TOKENS:
		return false
	aiming.append(unit)
	return true

static func release(unit: Object) -> void:
	aiming.erase(unit)

static func reset() -> void:
	aiming.clear()

# Dead holders never call release(); drop them before counting
static func _prune() -> void:
	for i in range(aiming.size() - 1, -1, -1):
		if aiming[i].is_dead:
			aiming.remove_at(i)

# Nearest live token holder within `max_dist` of `pos`, or null
static func nearest_aiming(pos: Vector2, max_dist: float) -> Object:
	_prune()
	var best: Object = null
	var best_d := max_dist * max_dist
	for u in aiming:
		var d := pos.distance_squared_to(u.global_position)
		if d <= best_d:
			best = u
			best_d = d
	return best
