class_name SkillTile
extends Button

# Icon tile for one skill or synergy in the upgrade matrix.
# Draws a chamfered octagon frame, the icon, level pips and state badges. No text.

enum TileState { LOCKED, AVAILABLE, UPGRADABLE, MAXED, ACTIVE }

const CUT := 14.0

var accent: Color = CyberPalette.YELLOW
var tex: Texture2D = null
var level: int = 0
var max_level: int = 1
var tile_state: TileState = TileState.LOCKED
var selected: bool = false
var highlighted: bool = false
var is_synergy: bool = false
# Synergy tiles: [[fraction 0..1, branch colour], ...] per requirement
var req_progress: Array = []

var _pulse: float = 0.0
# Level-up burst: 1 -> 0 over BURST_TIME
const BURST_TIME := 0.7
var _burst: float = 0.0
var _lock_tex: Texture2D = CyberPalette.icon("lock")
var _plus_tex: Texture2D = CyberPalette.icon("upgrade")
var _check_tex: Texture2D = CyberPalette.icon("check")

func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_ALL
	custom_minimum_size = Vector2(84, 96)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# Focus is drawn as the thick border in _draw
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func setup(p_tex: Texture2D, p_accent: Color, p_max: int, p_synergy: bool = false) -> void:
	tex = p_tex
	accent = p_accent
	max_level = max(1, p_max)
	is_synergy = p_synergy
	queue_redraw()

func set_state(p_level: int, p_state: TileState) -> void:
	level = p_level
	tile_state = p_state
	queue_redraw()

# Flash, expanding frame and sparks when this tile levels up (or a synergy activates)
func play_upgrade_burst() -> void:
	_burst = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if tile_state == TileState.UPGRADABLE or highlighted or (is_synergy and tile_state == TileState.ACTIVE):
		_pulse += delta * 4.0
		queue_redraw()
	if _burst > 0.0:
		_burst = maxf(0.0, _burst - delta / BURST_TIME)
		queue_redraw()

func _frame_points(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x - cut, r.position.y),
		Vector2(r.end.x, r.position.y + cut), Vector2(r.end.x, r.end.y - cut),
		r.end - Vector2(cut, 0), Vector2(r.position.x + cut, r.end.y),
		Vector2(r.position.x, r.end.y - cut), r.position + Vector2(0, cut)
	])

func _draw() -> void:
	var frame := Rect2(Vector2(2, 2), Vector2(size.x - 4, size.x - 4))
	var pts := _frame_points(frame, CUT)
	var locked := tile_state == TileState.LOCKED
	var col := CyberPalette.LOCKED if locked else accent
	var glow := 0.5 + 0.5 * sin(_pulse)

	# Drop shadow for depth
	var shadow_pts := _frame_points(Rect2(frame.position + Vector2(4, 6), frame.size), CUT)
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.55))

	# Active synergy: rotating double halo
	if is_synergy and tile_state == TileState.ACTIVE:
		var c := frame.get_center()
		var r := frame.size.x * 0.62
		draw_arc(c, r, _pulse * 0.5, _pulse * 0.5 + PI * 0.7, 18, Color(accent, 0.8), 2.5, true)
		draw_arc(c, r, _pulse * 0.5 + PI, _pulse * 0.5 + PI * 1.7, 18, Color(accent, 0.8), 2.5, true)
		draw_arc(c, r + 5, -_pulse * 0.3, -_pulse * 0.3 + TAU, 40, Color(accent, 0.15 + 0.1 * glow), 4.0, true)

	# Body
	var fill := Color(col, 0.10 if not locked else 0.05)
	if tile_state == TileState.MAXED or tile_state == TileState.ACTIVE:
		fill = Color(col, 0.22)
	draw_colored_polygon(pts, Color(0.02, 0.02, 0.04, 0.95))
	draw_colored_polygon(pts, fill)

	# Outer glow when it can be bought or is linked to the selected synergy
	if tile_state == TileState.UPGRADABLE or highlighted:
		var gpts := _frame_points(frame.grow(3.0 + glow * 2.0), CUT + 2.0)
		gpts.append(gpts[0])
		draw_polyline(gpts, Color(CyberPalette.CYAN if highlighted else col, 0.25 + glow * 0.35), 3.0, true)

	# Border
	var border := pts.duplicate()
	border.append(pts[0])
	var bw := 2.0 if not locked else 1.0
	if selected or is_hovered() or has_focus():
		bw = 3.0
		col = Color.WHITE if not locked else CyberPalette.DIM
	draw_polyline(border, Color(col, 0.9 if not locked else 0.6), bw, true)

	# Corner accent ticks
	if not locked:
		draw_line(frame.position + Vector2(CUT + 4, -1), frame.position + Vector2(CUT + 18, -1), accent, 3.0)
		draw_line(frame.end + Vector2(-CUT - 4, 1), frame.end + Vector2(-CUT - 18, 1), accent, 3.0)

	# Icon
	if tex:
		var isz := frame.size.x * 0.56
		var irect := Rect2(frame.get_center() - Vector2(isz, isz) * 0.5, Vector2(isz, isz))
		var icol := accent if not locked else Color(CyberPalette.LOCKED, 0.8)
		draw_texture_rect(tex, irect, false, icol)

	# State badge (top-right)
	var badge := Rect2(Vector2(frame.end.x - 24, frame.position.y + 2), Vector2(20, 20))
	if locked and _lock_tex:
		draw_texture_rect(_lock_tex, badge.grow(-2), false, CyberPalette.DIM)
	elif tile_state == TileState.UPGRADABLE and _plus_tex:
		draw_rect(badge, Color(CyberPalette.YELLOW, 0.85 + glow * 0.15))
		draw_texture_rect(_plus_tex, badge.grow(-3), false, Color(0.02, 0.02, 0.04))
	elif (tile_state == TileState.MAXED or tile_state == TileState.ACTIVE) and _check_tex:
		draw_texture_rect(_check_tex, badge.grow(-2), false, CyberPalette.GREEN)

	# Requirement progress bars under synergy tiles
	if is_synergy and req_progress.size() > 0:
		var n := req_progress.size()
		var gap := 4.0
		var bar_w := (frame.size.x - 12 - gap * (n - 1)) / n
		for i in n:
			var r := Rect2(frame.position.x + 6 + i * (bar_w + gap), frame.end.y + 6, bar_w, 6)
			var pc: Color = req_progress[i][1]
			draw_rect(r, Color(pc, 0.18))
			draw_rect(Rect2(r.position, Vector2(r.size.x * float(req_progress[i][0]), r.size.y)), pc)

	# Level pips under the frame
	if not is_synergy:
		draw_pips(self, Rect2(frame.position.x + 6, frame.end.y + 6, frame.size.x - 12, 6), level, max_level, accent if not locked else CyberPalette.LOCKED)

	if _burst > 0.0:
		_draw_burst(frame)

func _draw_burst(frame: Rect2) -> void:
	var k := 1.0 - _burst
	var e := 1.0 - (1.0 - k) * (1.0 - k)
	# White flash over the body, fading fast
	draw_colored_polygon(_frame_points(frame, CUT), Color(1, 1, 1, 0.55 * _burst * _burst))
	# Two frames expanding outward in the accent colour and white
	for j in 2:
		var grow := 4.0 + (22.0 if j == 0 else 12.0) * e
		var gpts := _frame_points(frame.grow(grow), CUT + grow * 0.4)
		gpts.append(gpts[0])
		var c := accent if j == 0 else Color.WHITE
		draw_polyline(gpts, Color(c, _burst * (0.9 if j == 0 else 0.6)), 3.0 - j, true)
	# Eight sparks flying out from the centre
	var ctr := frame.get_center()
	var reach := frame.size.x * 0.5
	for i in 8:
		var dir := Vector2.from_angle(TAU / 8.0 * i + 0.4)
		draw_line(ctr + dir * reach * (0.5 + 0.6 * e), ctr + dir * reach * (0.7 + 0.8 * e), Color(accent.lerp(Color.WHITE, 0.5), _burst), 2.5)
	# Newest pip glows
	if not is_synergy and level > 0:
		var gap := 3.0
		var w := (frame.size.x - 12.0 - gap * float(max_level - 1)) / float(max_level)
		var x := frame.position.x + 6.0 + float(level - 1) * (w + gap)
		draw_rect(Rect2(x - 2, frame.end.y + 4, w + 4, 10), Color(1, 1, 1, 0.8 * _burst))

# Slanted segment row. Shared with the inspector.
static func draw_pips(ci: CanvasItem, r: Rect2, filled: int, total: int, col: Color) -> void:
	var gap := 3.0
	var w := (r.size.x - gap * float(total - 1)) / float(total)
	for i in total:
		var x := r.position.x + float(i) * (w + gap)
		var seg := PackedVector2Array([
			Vector2(x + 3, r.position.y), Vector2(x + w, r.position.y),
			Vector2(x + w - 3, r.end.y), Vector2(x, r.end.y)
		])
		ci.draw_colored_polygon(seg, col if i < filled else Color(col, 0.18))
