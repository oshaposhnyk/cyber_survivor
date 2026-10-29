class_name EnemyRegistry
extends RefCounted

# Flat list of live enemies for targeting queries.
# Replaces get_tree().get_nodes_in_group("enemies"), which allocates a new
# array of every enemy on each call (hundreds of calls per second in big waves).

static var list: Array[Node2D] = []

static func register(e: Node2D) -> void:
	e.set_meta("_reg_idx", list.size())
	list.append(e)

# Swap-remove: O(1) instead of Array.erase's O(N).
static func unregister(e: Node2D) -> void:
	if not e.has_meta("_reg_idx"):
		return
	var i: int = e.get_meta("_reg_idx")
	e.remove_meta("_reg_idx")
	var last: Node2D = list[list.size() - 1]
	if last != e:
		list[i] = last
		last.set_meta("_reg_idx", i)
	list.resize(list.size() - 1)

static func count() -> int:
	return list.size()

# Nearest `n` live enemies to `pos` within `max_dist`. Single pass, no sort of the full list.
static func nearest(pos: Vector2, n: int = 1, max_dist: float = INF, exclude: Array = []) -> Array[Node2D]:
	var best: Array[Node2D] = []
	var best_d: Array[float] = []
	var max_d2 = max_dist * max_dist
	for e in list:
		if e.is_dead or e in exclude:
			continue
		var d2 = pos.distance_squared_to(e.global_position)
		if d2 > max_d2:
			continue
		if best.size() < n:
			best.append(e)
			best_d.append(d2)
		else:
			var worst_i = 0
			for k in range(1, best_d.size()):
				if best_d[k] > best_d[worst_i]:
					worst_i = k
			if d2 < best_d[worst_i]:
				best[worst_i] = e
				best_d[worst_i] = d2
	# Order the small result set nearest-first
	var idx = range(best.size())
	idx.sort_custom(func(a, b): return best_d[a] < best_d[b])
	var out: Array[Node2D] = []
	for i in idx:
		out.append(best[i])
	return out

static func in_radius(pos: Vector2, radius: float) -> Array[Node2D]:
	var out: Array[Node2D] = []
	var r2 = radius * radius
	for e in list:
		if not e.is_dead and pos.distance_squared_to(e.global_position) <= r2:
			out.append(e)
	return out
