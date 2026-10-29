class_name Swarm
extends Node2D

# Owns every swarm enemy (EnemyBase units) and draws them.
# - Update: one loop runs _tick() per unit; off-screen units run every LOD_STRIDE-th frame.
# - Render: per kind, one MultiMeshInstance2D for bodies and one for shadows, filled from
#   a packed buffer each frame. On-screen units only.
# - Overlay: one canvas draws champion auras and shield domes for the units that have them.
# Replaces one CharacterBody2D + two Sprite2D per enemy, which capped the web build
# at about 30 fps with 1100 enemies.

# Floats per MultiMesh instance: 8 for the 2D transform, 4 for the colour
const STRIDE := 12
const SHADOW_COLOR := Color(0, 0, 0, 0.45)
const SHADOW_SCALE := 0.95
const START_CAPACITY := 256

static var instance: Swarm = null

var units: Array[EnemyBase] = []
var overlay_units: Array[EnemyBase] = []
var overlay: Node2D

# Per kind render state
var bodies: Dictionary = {}       # kind -> MultiMeshInstance2D
var shadows: Dictionary = {}      # kind -> MultiMeshInstance2D
var body_buf: Dictionary = {}     # kind -> PackedFloat32Array
var shadow_buf: Dictionary = {}   # kind -> PackedFloat32Array

func _enter_tree() -> void:
	instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null
	FireDirector.reset()
	for u in units:
		EnemyRegistry.unregister(u)
	units.clear()

func _ready() -> void:
	EnemyBase.world = get_parent()
	for kind in EnemyKinds.KINDS:
		var def: Dictionary = EnemyKinds.KINDS[kind]
		shadows[kind] = _make_layer(def, def["z"] - 2)
		bodies[kind] = _make_layer(def, def["z"])
		body_buf[kind] = PackedFloat32Array()
		shadow_buf[kind] = PackedFloat32Array()
	overlay = Node2D.new()
	overlay.z_index = 8
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

# Quad sized to the scaled sprite, UVs top-left origin (QuadMesh is flipped in 2D)
func _make_layer(def: Dictionary, z: int) -> MultiMeshInstance2D:
	var tex: Texture2D = def["texture"]
	var h: Vector2 = tex.get_size() * def["sprite_scale"] * 0.5
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = START_CAPACITY
	mm.visible_instance_count = 0
	# Bounds are not recomputed when the whole buffer is replaced; without a fixed
	# AABB the layer is culled as soon as the swarm leaves its first bounds
	mm.custom_aabb = AABB(Vector3(-1e6, -1e6, -1.0), Vector3(2e6, 2e6, 2.0))
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.texture = tex
	mmi.z_index = z
	add_child(mmi)
	return mmi

# Creates a unit of `kind` at `pos`. Wave scaling multiplies the kind's base stats.
func spawn(kind: String, pos: Vector2, hp_mult: float = 1.0, dmg_mult: float = 1.0) -> EnemyBase:
	var def: Dictionary = EnemyKinds.KINDS[kind]
	var u: EnemyBase = def["script"].new()
	u.kind = kind
	for key in EnemyKinds.STATS:
		u.set(key, def[key])
	u.max_health *= hp_mult
	u.contact_damage *= dmg_mult
	u.global_position = pos
	u._spawned()
	units.append(u)
	EnemyRegistry.register(u)
	if u.has_overlay():
		overlay_units.append(u)
	return u

func make_champion(u: EnemyBase) -> void:
	u.make_champion()
	add_overlay(u)

# For units that gain an overlay after spawning (champion, primed kamikaze)
func add_overlay(u: EnemyBase) -> void:
	if not overlay_units.has(u):
		overlay_units.append(u)

func _physics_process(delta: float) -> void:
	var frame := Engine.get_physics_frames()
	var removed := false
	for u in units:
		if u.is_dead:
			removed = true
			continue
		u.lod_dt += delta
		if not u.is_champion and (frame + u.lod_slot) % EnemyBase.LOD_STRIDE != 0 and u._off_screen():
			continue
		var dt := u.lod_dt
		u.lod_dt = 0.0
		u._tick(dt)
		if u.is_dead:
			removed = true
	if removed:
		_remove_dead()

# Dead units leave the registry and the update list; stale references elsewhere
# (missile targets, tethers) keep reading is_dead == true
func _remove_dead() -> void:
	var alive: Array[EnemyBase] = []
	for u in units:
		if u.is_dead:
			EnemyRegistry.unregister(u)
		else:
			alive.append(u)
	units = alive
	overlay_units = overlay_units.filter(func(u): return not u.is_dead)

func _process(_delta: float) -> void:
	_fill_buffers()
	overlay.queue_redraw()

func _fill_buffers() -> void:
	var c := EnemyBase.view_center
	var half := EnemyBase.view_half
	var by_kind := {}
	for kind in bodies:
		by_kind[kind] = []
	for u in units:
		var p := u.global_position
		if u.is_dead or absf(p.x - c.x) > half.x or absf(p.y - c.y) > half.y:
			continue
		by_kind[u.kind].append(u)
	for kind in bodies:
		_fill_kind(kind, by_kind[kind])

func _fill_kind(kind: String, list: Array) -> void:
	var body_mm: MultiMesh = bodies[kind].multimesh
	var shadow_mm: MultiMesh = shadows[kind].multimesh
	if list.size() > body_mm.instance_count:
		var cap := maxi(list.size(), body_mm.instance_count * 2)
		body_mm.instance_count = cap
		shadow_mm.instance_count = cap
	# Take the buffers out of the dictionaries so writes stay in place (no copy-on-write)
	var b: PackedFloat32Array = body_buf[kind]
	var sb: PackedFloat32Array = shadow_buf[kind]
	body_buf[kind] = PackedFloat32Array()
	shadow_buf[kind] = PackedFloat32Array()
	if b.size() != body_mm.instance_count * STRIDE:
		b.resize(body_mm.instance_count * STRIDE)
		sb.resize(b.size())
	var off := EnemyBase.SHADOW_OFFSET
	var o := 0
	for u in list:
		var sc: float = u.sprite_scale
		var cs: float = u.facing_cos * sc
		var sn: float = u.facing_sin * sc
		var px: float = u.global_position.x + u.jitter.x
		var py: float = u.global_position.y + u.jitter.y
		var col: Color = u.flash_tint * u.status_tint * u.body_tint
		b[o] = cs; b[o + 1] = -sn; b[o + 2] = 0.0; b[o + 3] = px
		b[o + 4] = sn; b[o + 5] = cs; b[o + 6] = 0.0; b[o + 7] = py
		b[o + 8] = col.r; b[o + 9] = col.g; b[o + 10] = col.b; b[o + 11] = col.a
		var scs := cs * SHADOW_SCALE
		var ssn := sn * SHADOW_SCALE
		sb[o] = scs; sb[o + 1] = -ssn; sb[o + 2] = 0.0; sb[o + 3] = px + off.x
		sb[o + 4] = ssn; sb[o + 5] = scs; sb[o + 6] = 0.0; sb[o + 7] = py + off.y
		sb[o + 8] = 0.0; sb[o + 9] = 0.0; sb[o + 10] = 0.0; sb[o + 11] = SHADOW_COLOR.a * col.a
		o += STRIDE
	if not list.is_empty():
		body_mm.buffer = b
		shadow_mm.buffer = sb
	body_mm.visible_instance_count = list.size()
	shadow_mm.visible_instance_count = list.size()
	body_buf[kind] = b
	shadow_buf[kind] = sb

func _draw_overlay() -> void:
	var c := EnemyBase.view_center
	var half := EnemyBase.view_half
	for u in overlay_units:
		if u.is_dead:
			continue
		var p := u.global_position
		if absf(p.x - c.x) > half.x + 200.0 or absf(p.y - c.y) > half.y + 200.0:
			continue
		overlay.draw_set_transform(p)
		u.draw_overlay(overlay)
	overlay.draw_set_transform(Vector2.ZERO)
