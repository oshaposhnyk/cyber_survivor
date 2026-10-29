extends Node2D

# Ship aura (child of Player, additive material in player.tscn).
# - Persistent, subtle marker per active synergy (magenta family).
# - One-off burst when a synergy unlocks.
# - Short ring pulse in the branch colour when a skill is upgraded.
# One node, fixed-size burst slots, no Tweens.

const RING_TEX := preload("res://assets/sprites/fx/ring.png")
const GLOW_TEX := preload("res://assets/sprites/fx/glow_soft.png")
const SPARK_TEX := preload("res://assets/sprites/fx/spark_star.png")
const TWIRL_TEX := preload("res://assets/sprites/fx/twirl_arc.png")
const RING_BAND := 0.6

const SYN_MAGENTA := Color(1.0, 0.3, 0.85)
const SYN_CYAN := Color(0.3, 0.9, 1.0)

const MAX_BURSTS := 6
const UPGRADE_TIME := 0.65
const SYNERGY_TIME := 1.3
const STAGGER := 0.18

enum Kind { NONE, UPGRADE, SYNERGY }

var time: float = 0.0
var storm: bool = false
var apocalypse: bool = false
var valkyrie: bool = false
var bastion: bool = false
var active_count: int = 0
var was_busy: bool = false

var b_kind: PackedInt32Array = PackedInt32Array()
var b_time: PackedFloat32Array = PackedFloat32Array()
var b_col: PackedColorArray = PackedColorArray()

func _ready() -> void:
	b_kind.resize(MAX_BURSTS)
	b_time.resize(MAX_BURSTS)
	b_col.resize(MAX_BURSTS)
	GameManager.synergy_unlocked.connect(_on_synergy_unlocked)
	GameManager.skill_upgraded.connect(_on_skill_upgraded)
	_refresh_flags()

func _refresh_flags() -> void:
	storm = GameManager.is_synergy_active("plasma_storm")
	apocalypse = GameManager.is_synergy_active("emp_apocalypse")
	valkyrie = GameManager.is_synergy_active("valkyrie_swarm")
	bastion = GameManager.is_synergy_active("nanite_bastion")
	active_count = int(storm) + int(apocalypse) + int(valkyrie) + int(bastion)

func _on_synergy_unlocked(_synergy_id, _info) -> void:
	_refresh_flags()
	_add_burst(Kind.SYNERGY, SYN_MAGENTA)

func _on_skill_upgraded(skill_id, _new_level) -> void:
	_add_burst(Kind.UPGRADE, _branch_color(skill_id))

func _branch_color(skill_id: String) -> Color:
	if not SkillData.SKILLS.has(skill_id):
		return CyberPalette.YELLOW
	return CyberPalette.branch_color(SkillData.SKILLS[skill_id]["branch"])

# Several upgrades bought in one visit play one after another (negative time = delay)
func _add_burst(kind: Kind, col: Color) -> void:
	var slot := -1
	var delay := 0.0
	for i in MAX_BURSTS:
		if b_kind[i] == Kind.NONE:
			if slot < 0:
				slot = i
		elif b_time[i] < STAGGER:
			delay = maxf(delay, STAGGER - b_time[i])
	if slot < 0:
		return
	b_kind[slot] = kind
	b_col[slot] = col
	b_time[slot] = -delay

func _process(delta: float) -> void:
	time += delta
	var busy := active_count > 0
	for i in MAX_BURSTS:
		if b_kind[i] == Kind.NONE:
			continue
		busy = true
		b_time[i] += delta
		var life := SYNERGY_TIME if b_kind[i] == Kind.SYNERGY else UPGRADE_TIME
		if b_time[i] >= life:
			b_kind[i] = Kind.NONE
	# One extra redraw after the last effect ends clears the canvas
	if busy or was_busy:
		queue_redraw()
	was_busy = busy

func _tex(tex: Texture2D, center: Vector2, size: float, col: Color) -> void:
	draw_texture_rect(tex, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false, col)

func _ring(r: float, col: Color) -> void:
	var h := r / RING_BAND
	draw_texture_rect(RING_TEX, Rect2(-h, -h, h * 2.0, h * 2.0), false, col)

func _draw() -> void:
	if active_count > 0:
		_draw_persistent()
	for i in MAX_BURSTS:
		if b_kind[i] == Kind.NONE or b_time[i] < 0.0:
			continue
		if b_kind[i] == Kind.SYNERGY:
			_draw_synergy_burst(b_time[i] / SYNERGY_TIME)
		else:
			_draw_upgrade_pulse(b_time[i] / UPGRADE_TIME, b_col[i])

func _draw_persistent() -> void:
	var pulse := 0.5 + 0.5 * sin(time * 2.6)
	# Shared base: soft magenta under-glow, stronger with more synergies
	_tex(GLOW_TEX, Vector2.ZERO, 92.0 + 6.0 * active_count, Color(SYN_MAGENTA, 0.12 + 0.05 * active_count + 0.06 * pulse))

	if storm:
		# Three charged motes orbiting fast, with a crackle between two of them
		var pts: Array[Vector2] = []
		for i in 3:
			var ang := time * 4.0 + TAU / 3.0 * i
			pts.append(Vector2(cos(ang), sin(ang)) * 34.0)
			_tex(SPARK_TEX, pts[i], 14.0, Color(SYN_CYAN.lerp(SYN_MAGENTA, float(i) / 2.0), 0.9))
		if fmod(time, 0.5) < 0.12:
			var mid := (pts[0] + pts[1]) * 0.5 + Vector2(randf_range(-6, 6), randf_range(-6, 6))
			draw_polyline(PackedVector2Array([pts[0], mid, pts[1]]), Color(0.8, 0.95, 1.0, 0.8), 1.5)

	if apocalypse:
		# Slow dashed ring that "charges": dashes brighten in sequence
		var dashes := 12
		for i in dashes:
			var a0 := -time * 0.8 + TAU / dashes * i
			var lit := 0.5 + 0.5 * sin(time * 5.0 - i * 0.7)
			draw_arc(Vector2.ZERO, 44.0, a0, a0 + TAU / dashes * 0.55, 6, Color(SYN_MAGENTA, 0.25 + 0.45 * lit), 2.5)

	if valkyrie:
		# Two chevrons sweeping around the hull
		for i in 2:
			var ang := time * 2.2 + PI * i
			var dir := Vector2(cos(ang), sin(ang))
			var tip := dir * 40.0
			var side := dir.orthogonal() * 6.0
			var back := tip - dir * 8.0
			draw_polyline(PackedVector2Array([back + side, tip, back - side]), Color(1.0, 0.5, 0.3, 0.85), 2.5)
			draw_polyline(PackedVector2Array([back + side - dir * 5.0, tip - dir * 5.0, back - side - dir * 5.0]), Color(SYN_MAGENTA, 0.5), 2.0)

	if bastion:
		# Inner nanite halo, breathing green with magenta edge
		draw_arc(Vector2.ZERO, 27.0 + 2.0 * pulse, 0, TAU, 32, Color(0.2, 1.0, 0.55, 0.25 + 0.2 * pulse), 3.0)
		draw_arc(Vector2.ZERO, 30.0 + 2.0 * pulse, 0, TAU, 32, Color(SYN_MAGENTA, 0.2), 1.5)

func _draw_upgrade_pulse(k: float, col: Color) -> void:
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	var a := 1.0 - k
	_tex(GLOW_TEX, Vector2.ZERO, 70.0 + 40.0 * e, Color(col, 0.55 * a))
	_ring(26.0 + 70.0 * e, Color(col, a))
	_ring(18.0 + 40.0 * e, Color(Color.WHITE, 0.6 * a))
	# Six sparks thrown outwards
	for i in 6:
		var ang := TAU / 6.0 * i + 0.3
		var p := Vector2(cos(ang), sin(ang)) * (20.0 + 70.0 * e)
		_tex(SPARK_TEX, p, 16.0 * a + 4.0, Color(col.lerp(Color.WHITE, 0.4), a))

func _draw_synergy_burst(k: float) -> void:
	var e := 1.0 - pow(1.0 - k, 3.0)
	var a := 1.0 - k
	# Core flash
	_tex(GLOW_TEX, Vector2.ZERO, 120.0 + 160.0 * e, Color(SYN_MAGENTA, 0.7 * a))
	_tex(GLOW_TEX, Vector2.ZERO, 60.0, Color(1, 1, 1, 0.8 * a * a))
	# Two staggered shock rings
	_ring(30.0 + 220.0 * e, Color(SYN_MAGENTA, a))
	var k2 := clampf((k - 0.15) / 0.85, 0.0, 1.0)
	var e2 := 1.0 - pow(1.0 - k2, 3.0)
	_ring(20.0 + 150.0 * e2, Color(SYN_CYAN, 0.8 * (1.0 - k2)))
	# Spinning ion swirls
	for i in 2:
		draw_set_transform(Vector2.ZERO, time * 5.0 + PI * i, Vector2.ONE)
		var s := (60.0 + 120.0 * e) * 2.0
		_tex(TWIRL_TEX, Vector2.ZERO, s, Color(SYN_MAGENTA.lerp(Color.WHITE, 0.3), 0.8 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Radial spokes
	for i in 12:
		var ang := TAU / 12.0 * i
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(dir * (40.0 + 80.0 * e), dir * (70.0 + 170.0 * e), Color(SYN_MAGENTA, 0.6 * a), 3.0)
