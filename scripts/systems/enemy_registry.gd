class_name EnemyRegistry
extends RefCounted

# Flat list of live enemies for targeting queries.
# Replaces get_tree().get_nodes_in_group("enemies"), which allocates a new
# array of every enemy on each call (hundreds of calls per second in big waves).

# Swarm units (EnemyBase, RefCounted) plus node targets (boss, reactors)
static var list: Array = []

# Uniform spatial hash over `list`. Late game runs thousands of queries per frame
# (death hacks, mines, missiles, bearers); a full scan per query was O(N) each.
# Rebuilt lazily: at most once per physics frame, or after an enemy leaves the tree.
# A rebuild costs about three full scans, so frames with few queries keep scanning.
const GRID_MIN_QUERIES := 4
const CELL := 128.0
# Search cap for unbounded nearest(): enemies wrap back within 2100 px of the player
const MAX_SEARCH := 2400.0
# Enemies move a few px between the rebuild and a later query in the same frame
const CELL_PAD := 8.0
static var grid: Dictionary = {}
static var grid_frame: int = -1
static var query_frame: int = -1
static var queries_now: int = 0
static var queries_prev: int = 0

static func register(e: Object) -> void:
	e.set_meta("_reg_idx", list.size())
	list.append(e)
	grid_frame = -1

# Swap-remove: O(1) instead of Array.erase's O(N).
static func unregister(e: Object) -> void:
	if not e.has_meta("_reg_idx"):
		return
	var i: int = e.get_meta("_reg_idx")
	e.remove_meta("_reg_idx")
	var last: Object = list[list.size() - 1]
	if last != e:
		list[i] = last
		last.set_meta("_reg_idx", i)
	list.resize(list.size() - 1)
	grid_frame = -1

static func count() -> int:
	return list.size()

static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))

# Counts queries per physics frame; true when the grid is worth (re)building
static func _use_grid() -> bool:
	var frame := Engine.get_physics_frames()
	if frame != query_frame:
		query_frame = frame
		queries_prev = queries_now
		queries_now = 0
	queries_now += 1
	if queries_prev < GRID_MIN_QUERIES and queries_now < GRID_MIN_QUERIES:
		return false
	_ensure_grid()
	return true

static func _ensure_grid() -> void:
	var frame := Engine.get_physics_frames()
	if grid_frame == frame:
		return
	grid_frame = frame
	# Cell arrays are reused between rebuilds; drop them all now and then,
	# because the player travels and old cells would pile up
	if grid.size() > 4096:
		grid.clear()
	else:
		for bucket in grid.values():
			bucket.clear()
	for e in list:
		if e.is_dead:
			continue
		var key := _cell(e.global_position)
		var bucket = grid.get(key)
		if bucket == null:
			bucket = []
			grid[key] = bucket
		bucket.append(e)

# Nearest `n` live enemies to `pos` within `max_dist`, nearest first.
# Walks rings of cells outwards and stops once no closer enemy is possible.
static func nearest(pos: Vector2, n: int = 1, max_dist: float = INF, exclude: Array = []) -> Array[Object]:
	var best: Array[Object] = []
	var best_d: Array[float] = []
	var worst_i := 0
	var limit := minf(max_dist, MAX_SEARCH)
	var max_d2 := limit * limit
	if not _use_grid():
		for e in list:
			# Cheap reject inline; the bookkeeping call is only for real candidates
			var d2 := pos.distance_squared_to(e.global_position)
			if d2 <= max_d2 and (best.size() < n or d2 < best_d[worst_i]):
				worst_i = _consider(e, d2, n, exclude, best, best_d, worst_i)
		return _sorted(best, best_d)
	var c := _cell(pos)
	var max_ring := ceili((limit + CELL_PAD) / CELL)
	for ring in range(max_ring + 1):
		# Any enemy in this ring is at least (ring - 1) cells away
		if best.size() >= n:
			var ring_min := maxf(0.0, (ring - 1) * CELL - CELL_PAD)
			if ring_min * ring_min > best_d[worst_i]:
				break
		for y in range(c.y - ring, c.y + ring + 1):
			var edge_row := y == c.y - ring or y == c.y + ring
			var step := 1 if edge_row else ring * 2
			var x := c.x - ring
			while x <= c.x + ring:
				var bucket = grid.get(Vector2i(x, y))
				x += step
				if bucket == null:
					continue
				for e in bucket:
					var d2 := pos.distance_squared_to(e.global_position)
					if d2 <= max_d2 and (best.size() < n or d2 < best_d[worst_i]):
						worst_i = _consider(e, d2, n, exclude, best, best_d, worst_i)
	return _sorted(best, best_d)

# Keeps the n closest in best/best_d (d2 already within range); returns the index of the farthest
static func _consider(e: Object, d2: float, n: int, exclude: Array, best: Array[Object], best_d: Array[float], worst_i: int) -> int:
	if e.is_dead or e in exclude:
		return worst_i
	if best.size() < n:
		best.append(e)
		best_d.append(d2)
		return best.size() - 1 if best.size() == 1 or d2 > best_d[worst_i] else worst_i
	if d2 < best_d[worst_i]:
		best[worst_i] = e
		best_d[worst_i] = d2
		for k in best_d.size():
			if best_d[k] > best_d[worst_i]:
				worst_i = k
	return worst_i

# Orders the small result set nearest-first
static func _sorted(best: Array[Object], best_d: Array[float]) -> Array[Object]:
	var idx = range(best.size())
	idx.sort_custom(func(a, b): return best_d[a] < best_d[b])
	var out: Array[Object] = []
	for i in idx:
		out.append(best[i])
	return out

static func in_radius(pos: Vector2, radius: float) -> Array[Object]:
	var out: Array[Object] = []
	var r2 := radius * radius
	if not _use_grid():
		for e in list:
			if not e.is_dead and pos.distance_squared_to(e.global_position) <= r2:
				out.append(e)
		return out
	var lo := _cell(pos - Vector2(radius + CELL_PAD, radius + CELL_PAD))
	var hi := _cell(pos + Vector2(radius + CELL_PAD, radius + CELL_PAD))
	for y in range(lo.y, hi.y + 1):
		for x in range(lo.x, hi.x + 1):
			var bucket = grid.get(Vector2i(x, y))
			if bucket == null:
				continue
			for e in bucket:
				if not e.is_dead and pos.distance_squared_to(e.global_position) <= r2:
					out.append(e)
	return out

# Targets whose hit circle (hit_radius) overlaps the circle at `pos` with radius `r`.
# Projectiles use this instead of physics overlaps: swarm units have no bodies.
const MAX_HIT_RADIUS := 120.0

static func overlapping(pos: Vector2, r: float) -> Array[Object]:
	var out: Array[Object] = []
	for e in in_radius(pos, r + MAX_HIT_RADIUS):
		var reach: float = r + e.hit_radius
		if pos.distance_squared_to(e.global_position) <= reach * reach:
			out.append(e)
	return out

# First target touching the circle at `pos`, skipping `exclude`; null when none
static func first_hit(pos: Vector2, r: float, exclude: Array = []) -> Object:
	for e in in_radius(pos, r + MAX_HIT_RADIUS):
		if e in exclude:
			continue
		var reach: float = r + e.hit_radius
		if pos.distance_squared_to(e.global_position) <= reach * reach:
			return e
	return null

# Targets whose hit circle touches the segment a-b widened by `half_width` (railgun)
static func on_segment(a: Vector2, b: Vector2, half_width: float) -> Array[Object]:
	var out: Array[Object] = []
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	for e in list:
		if e.is_dead:
			continue
		var t := clampf((e.global_position - a).dot(ab) / len2, 0.0, 1.0)
		var reach: float = half_width + e.hit_radius
		if e.global_position.distance_squared_to(a + ab * t) <= reach * reach:
			out.append(e)
	return out
