extends CanvasLayer

# Upgrade matrix: icon tiles per branch, circuit wires between prerequisites,
# and an inspector panel. Hover a tile to inspect it, click to install an upgrade.

var branch_columns = [
	{"branch": SkillData.Branch.OFFENSE, "title": "ЗБРОЯ", "color": Color(1.0, 0.0, 0.235)},
	{"branch": SkillData.Branch.DEFENSE, "title": "ЗАХИСТ", "color": Color(0.0, 0.941, 1.0)},
	{"branch": SkillData.Branch.OVERCLOCK, "title": "РОЗГІН", "color": Color(0.988, 0.933, 0.039)},
	{"branch": SkillData.Branch.HACK, "title": "ХАКІНГ", "color": Color(0.2, 1.0, 0.55)},
	{"branch": SkillData.Branch.ENGINEER, "title": "ІНЖЕНЕР", "color": CyberPalette.ORANGE},
]
const SYNERGY_COLOR := Color(1.0, 0.3, 0.85)

@onready var points_label: Label = $Root/VBox/Header/PointsPlate/HBox/PointsLabel
@onready var close_btn: Button = $Root/VBox/Header/CloseBtn
@onready var wire_overlay: Control = $Root/VBox/Body/TreeBoard/WireOverlay
@onready var columns: HBoxContainer = $Root/VBox/Body/TreeBoard/Columns

# Inspector controls
@onready var inspector_icon: TextureRect = $Root/VBox/Body/InspectorPanel/VBox/IconCenter/InspectorIcon
@onready var inspector_name: Label = $Root/VBox/Body/InspectorPanel/VBox/TechName
@onready var inspector_pips: Control = $Root/VBox/Body/InspectorPanel/VBox/Pips
@onready var status_icon: TextureRect = $Root/VBox/Body/InspectorPanel/VBox/StatusRow/StatusIcon
@onready var status_label: Label = $Root/VBox/Body/InspectorPanel/VBox/StatusRow/StatusLabel
@onready var inspector_desc: Label = $Root/VBox/Body/InspectorPanel/VBox/TechDesc
@onready var next_row: HBoxContainer = $Root/VBox/Body/InspectorPanel/VBox/NextRow
@onready var inspector_next: Label = $Root/VBox/Body/InspectorPanel/VBox/NextRow/TechNext
@onready var links_title: Label = $Root/VBox/Body/InspectorPanel/VBox/LinksTitle
@onready var links_row: HFlowContainer = $Root/VBox/Body/InspectorPanel/VBox/LinksRow
@onready var inspector_upgrade_btn: Button = $Root/VBox/Body/InspectorPanel/VBox/UpgradeActionBtn
@onready var header: HBoxContainer = $Root/VBox/Header
@onready var inspector_vbox: VBoxContainer = $Root/VBox/Body/InspectorPanel/VBox

# Doctrine UI, built in code: header plate, per-column point counters, inspector block
var doctrine_label: Label
var doctrine_box: VBoxContainer
var doctrine_title: Label
var doctrine_bonus: Label
var doctrine_malus: Label
var column_heads: Dictionary = {}

var node_cards: Dictionary = {}
var synergy_cards: Dictionary = {}
var selected_skill_id: String = "blaster"
var selected_is_synergy: bool = false
var pinned_id: String = "blaster"
var pinned_is_synergy: bool = false

# Animated circuit pulses
var pulse_time: float = 0.0

func _ready() -> void:
	add_to_group("skill_tree_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	close_btn.pressed.connect(close_tree)
	close_btn.mouse_entered.connect(_on_hover_sound)
	inspector_upgrade_btn.pressed.connect(_on_inspector_upgrade_pressed)
	inspector_upgrade_btn.mouse_entered.connect(_on_hover_sound)
	inspector_pips.draw.connect(_on_inspector_pips_draw)

	GameManager.stats_updated.connect(refresh_all)
	wire_overlay.draw.connect(_on_wire_overlay_draw)

	build_ui()
	build_doctrine_ui()
	select_skill("blaster")

func _process(delta: float) -> void:
	if visible:
		pulse_time += delta * 2.0
		wire_overlay.queue_redraw()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_skill_tree"):
		toggle_tree()
	elif event.is_action_pressed("pause") and visible:
		close_tree()
		get_viewport().set_input_as_handled()

func toggle_tree() -> void:
	if visible:
		close_tree()
	else:
		open_tree()

func open_tree() -> void:
	visible = true
	get_tree().call_group("hud", "set_visible", false)
	GameManager.set_state(GameManager.State.SKILL_TREE)
	AudioManager.play_sfx("upgrade_select", 0.05, -2.0)
	refresh_all()
	wire_overlay.queue_redraw()
	if node_cards.has(selected_skill_id):
		node_cards[selected_skill_id].grab_focus()

func close_tree() -> void:
	visible = false
	get_tree().call_group("hud", "set_visible", true)
	GameManager.set_state(GameManager.State.PLAYING)

func accent_for(skill: Dictionary) -> Color:
	for col in branch_columns:
		if col["branch"] == skill["branch"]:
			return col["color"]
	return CyberPalette.YELLOW

func build_ui() -> void:
	var col_boxes: Dictionary = {}
	for col in branch_columns:
		col_boxes[col["branch"]] = _make_column(col["title"], col["color"], false, col["branch"])
	var syn_box = _make_column("СИНЕРГІЇ", SYNERGY_COLOR, true)

	for skill_id in SkillData.SKILLS.keys():
		var skill = SkillData.SKILLS[skill_id]
		var tile := SkillTile.new()
		tile.setup(_load_icon(skill), accent_for(skill), skill["max_lvl"])
		tile.tooltip_text = skill["name"]
		tile.mouse_entered.connect(func():
			select_skill(skill_id)
			_on_hover_sound()
		)
		tile.mouse_exited.connect(_restore_pinned)
		tile.focus_entered.connect(func(): _pin(skill_id, false))
		tile.pressed.connect(func(): _try_upgrade(skill_id))
		node_cards[skill_id] = tile
		col_boxes[skill["branch"]].add_child(tile)

	for syn_id in SkillData.SYNERGIES.keys():
		var syn = SkillData.SYNERGIES[syn_id]
		var tile := SkillTile.new()
		tile.setup(_load_icon(syn), SYNERGY_COLOR, 1, true)
		tile.tooltip_text = CyberPalette.strip_emoji(syn["name"])
		tile.mouse_entered.connect(func():
			select_synergy(syn_id)
			_on_hover_sound()
		)
		tile.mouse_exited.connect(_restore_pinned)
		tile.focus_entered.connect(func(): _pin(syn_id, true))
		tile.pressed.connect(func(): _pin(syn_id, true))
		synergy_cards[syn_id] = tile
		syn_box.add_child(tile)

func _make_column(title: String, color: Color, grid: bool = false, branch: int = -1) -> Container:
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if grid:
		col.size_flags_stretch_ratio = 2.0
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 14)

	var head = HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 8)
	var bar = ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(4, 16)
	head.add_child(bar)
	var lbl = Label.new()
	lbl.theme_type_variation = &"DimLabel"
	lbl.text = title
	lbl.add_theme_color_override("font_color", Color(color, 0.85))
	head.add_child(lbl)
	col.add_child(head)
	if branch >= 0:
		column_heads[branch] = {"label": lbl, "bar": bar, "title": title}

	var nodes: Container
	if grid:
		# Synergies: 2-column grid, pushed right so link cables have room to curve
		var g = GridContainer.new()
		g.columns = 2
		g.size_flags_horizontal = Control.SIZE_SHRINK_END
		g.add_theme_constant_override("h_separation", 26)
		g.add_theme_constant_override("v_separation", 22)
		nodes = g
	else:
		var v = VBoxContainer.new()
		v.add_theme_constant_override("separation", 22)
		nodes = v
	nodes.name = "NodesVBox"
	nodes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(nodes)
	columns.add_child(col)
	return nodes

func build_doctrine_ui() -> void:
	var plate = PanelContainer.new()
	plate.theme_type_variation = &"HudPlate"
	plate.tooltip_text = "Гілка з найбільшою кількістю очок (від %d) визначає стиль гри" % SkillData.DOCTRINE_MIN_POINTS
	doctrine_label = Label.new()
	doctrine_label.theme_type_variation = &"MonoLabel"
	doctrine_label.add_theme_font_size_override("font_size", 16)
	plate.add_child(doctrine_label)
	header.add_child(plate)
	header.move_child(plate, $Root/VBox/Header/PointsPlate.get_index())

	doctrine_box = VBoxContainer.new()
	doctrine_box.add_theme_constant_override("separation", 4)
	doctrine_title = Label.new()
	doctrine_title.theme_type_variation = &"DimLabel"
	doctrine_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doctrine_bonus = Label.new()
	doctrine_malus = Label.new()
	for l in [doctrine_bonus, doctrine_malus]:
		l.add_theme_font_size_override("font_size", 13)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	doctrine_bonus.add_theme_color_override("font_color", CyberPalette.GREEN)
	doctrine_malus.add_theme_color_override("font_color", CyberPalette.RED)
	doctrine_box.add_child(doctrine_title)
	doctrine_box.add_child(doctrine_bonus)
	doctrine_box.add_child(doctrine_malus)
	inspector_vbox.add_child(doctrine_box)
	inspector_vbox.move_child(doctrine_box, $Root/VBox/Body/InspectorPanel/VBox/Spacer.get_index())

# Points the branch still needs to take over the doctrine; 0 when it already holds it
func _doctrine_points_needed(branch: int) -> int:
	if branch == GameManager.active_doctrine:
		return 0
	var need = SkillData.DOCTRINE_MIN_POINTS
	if GameManager.active_doctrine >= 0:
		need = max(need, GameManager.branch_points(GameManager.active_doctrine) + 1)
	return need

func refresh_doctrine() -> void:
	var active = GameManager.active_doctrine
	if active >= 0:
		doctrine_label.text = "ДОКТРИНА: " + SkillData.DOCTRINES[active]["name"].to_upper()
		doctrine_label.add_theme_color_override("font_color", CyberPalette.branch_color(active))
	else:
		doctrine_label.text = "ДОКТРИНА: —"
		doctrine_label.add_theme_color_override("font_color", CyberPalette.DIM)
	for branch in column_heads.keys():
		var h = column_heads[branch]
		var is_active = branch == active
		h["label"].text = "%s  %d" % [h["title"], GameManager.branch_points(branch)]
		h["label"].add_theme_color_override("font_color", Color(CyberPalette.branch_color(branch), 1.0 if is_active else 0.7))
		h["bar"].custom_minimum_size = Vector2(10 if is_active else 4, 16)

func _update_doctrine_block(branch: int) -> void:
	var doc = SkillData.DOCTRINES[branch]
	var need = _doctrine_points_needed(branch)
	var state = "АКТИВНА" if need == 0 else "%d/%d ОЧОК" % [GameManager.branch_points(branch), need]
	doctrine_title.text = "ДОКТРИНА «%s»  ·  %s" % [doc["name"].to_upper(), state]
	doctrine_title.add_theme_color_override("font_color", CyberPalette.branch_color(branch) if need == 0 else CyberPalette.DIM)
	doctrine_bonus.text = doc["bonus"]
	doctrine_malus.text = doc["malus"]

func _load_icon(data: Dictionary) -> Texture2D:
	var p = data.get("icon_path", "")
	return load(p) if ResourceLoader.exists(p) else null

# Hover only previews a tile; click or keyboard focus pins it, so the mouse can
# cross other tiles on the way to the inspector button without losing the choice.
func _pin(id: String, is_synergy: bool) -> void:
	pinned_id = id
	pinned_is_synergy = is_synergy
	_restore_pinned()

func _restore_pinned() -> void:
	if pinned_is_synergy:
		select_synergy(pinned_id)
	else:
		select_skill(pinned_id)

func _try_upgrade(skill_id: String) -> void:
	_pin(skill_id, false)
	if GameManager.can_upgrade_skill(skill_id):
		_upgrade_with_burst(skill_id)
	else:
		AudioManager.play_sfx("shield_hit", 0.05, -10.0)

func select_skill(skill_id: String) -> void:
	if not SkillData.SKILLS.has(skill_id):
		return
	selected_skill_id = skill_id
	selected_is_synergy = false
	update_inspector()

func select_synergy(syn_id: String) -> void:
	if not SkillData.SYNERGIES.has(syn_id):
		return
	selected_skill_id = syn_id
	selected_is_synergy = true
	update_inspector()

func _set_status(icon_name: String, text: String, col: Color) -> void:
	status_icon.texture = CyberPalette.icon(icon_name)
	status_icon.self_modulate = col
	status_label.text = text
	status_label.add_theme_color_override("font_color", col)

func _clear_links() -> void:
	for c in links_row.get_children():
		c.queue_free()

func _add_link_chip(data: Dictionary, col: Color, caption: String) -> void:
	var chip = HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	chip.tooltip_text = CyberPalette.strip_emoji(data["name"])
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	var ic = TextureRect.new()
	ic.texture = _load_icon(data)
	ic.custom_minimum_size = Vector2(26, 26)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.self_modulate = col
	chip.add_child(ic)
	if caption != "":
		var lbl = Label.new()
		lbl.theme_type_variation = &"MonoLabel"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", col)
		lbl.text = caption
		chip.add_child(lbl)
	links_row.add_child(chip)

func update_inspector() -> void:
	_clear_links()
	for id in node_cards.keys():
		node_cards[id].selected = (id == selected_skill_id and not selected_is_synergy)
		node_cards[id].highlighted = false
	for id in synergy_cards.keys():
		synergy_cards[id].selected = (id == selected_skill_id and selected_is_synergy)

	if selected_is_synergy:
		var syn = SkillData.SYNERGIES[selected_skill_id]
		var active = GameManager.is_synergy_active(selected_skill_id)
		inspector_name.text = CyberPalette.strip_emoji(syn["name"])
		inspector_name.add_theme_color_override("font_color", SYNERGY_COLOR)
		inspector_icon.texture = _load_icon(syn)
		inspector_icon.self_modulate = SYNERGY_COLOR if active else CyberPalette.LOCKED
		inspector_pips.visible = false

		if active:
			_set_status("check", "АКТИВНА", CyberPalette.GREEN)
		else:
			_set_status("lock", "ЗАБЛОКОВАНО", CyberPalette.RED)
		inspector_desc.text = syn["desc"]
		next_row.visible = false

		links_title.text = "ПОТРІБНО"
		for rk in syn["req"].keys():
			var cur = GameManager.get_skill_level(rk)
			var need = syn["req"][rk]
			var col = CyberPalette.GREEN if cur >= need else CyberPalette.DIM
			_add_link_chip(SkillData.SKILLS[rk], col, "%d/%d" % [min(cur, need), need])
			if node_cards.has(rk):
				node_cards[rk].highlighted = true
		links_title.visible = true
		inspector_upgrade_btn.visible = false
		doctrine_box.visible = false
	else:
		var skill = SkillData.SKILLS[selected_skill_id]
		var cur_lvl = GameManager.get_skill_level(selected_skill_id)
		var max_lvl = skill["max_lvl"]
		var accent = accent_for(skill)

		inspector_name.text = skill["name"]
		inspector_name.add_theme_color_override("font_color", accent)
		inspector_icon.texture = _load_icon(skill)
		inspector_pips.visible = true
		inspector_pips.queue_redraw()

		var can_up = GameManager.can_upgrade_skill(selected_skill_id)
		var prereq_locked = skill["prereq"] != "" and GameManager.get_skill_level(skill["prereq"]) < skill["prereq_lvl"]
		inspector_icon.self_modulate = CyberPalette.LOCKED if prereq_locked else accent

		if cur_lvl >= max_lvl:
			_set_status("check", "МАКСИМУМ", CyberPalette.GREEN)
		elif prereq_locked:
			var req = SkillData.SKILLS[skill["prereq"]]
			_set_status("lock", "%s  LV %d" % [req["name"], skill["prereq_lvl"]], CyberPalette.RED)
		elif can_up:
			_set_status("upgrade", "ДОСТУПНО", CyberPalette.YELLOW)
		else:
			_set_status("level", "НЕМАЄ ОЧОК", CyberPalette.DIM)

		inspector_desc.text = skill["desc"]
		next_row.visible = cur_lvl < max_lvl
		inspector_next.text = skill["per_level"]

		var has_links = false
		for syn_id in SkillData.SYNERGIES.keys():
			var syn = SkillData.SYNERGIES[syn_id]
			if syn["req"].has(selected_skill_id):
				var col = SYNERGY_COLOR if GameManager.is_synergy_active(syn_id) else CyberPalette.DIM
				_add_link_chip(syn, col, "")
				has_links = true
		links_title.text = "СИНЕРГІЇ"
		links_title.visible = has_links

		doctrine_box.visible = true
		_update_doctrine_block(skill["branch"])

		inspector_upgrade_btn.visible = true
		inspector_upgrade_btn.disabled = not can_up
		inspector_upgrade_btn.text = "МАКСИМУМ" if cur_lvl >= max_lvl else "ВСТАНОВИТИ  v%d" % (cur_lvl + 1)

func _on_inspector_pips_draw() -> void:
	if selected_is_synergy or not SkillData.SKILLS.has(selected_skill_id):
		return
	var skill = SkillData.SKILLS[selected_skill_id]
	var w = min(inspector_pips.size.x, 36.0 * skill["max_lvl"])
	var r = Rect2((inspector_pips.size.x - w) * 0.5, 0, w, inspector_pips.size.y)
	SkillTile.draw_pips(inspector_pips, r, GameManager.get_skill_level(selected_skill_id), skill["max_lvl"], accent_for(skill))

func _on_inspector_upgrade_pressed() -> void:
	if not selected_is_synergy:
		_upgrade_with_burst(selected_skill_id)
		update_inspector()

# Upgrade and play the tile burst; also burst any synergy tile this upgrade activated
func _upgrade_with_burst(skill_id: String) -> void:
	var syn_before := GameManager.active_synergies.duplicate()
	if not GameManager.upgrade_skill(skill_id):
		return
	if node_cards.has(skill_id):
		node_cards[skill_id].play_upgrade_burst()
	for syn_id in GameManager.active_synergies:
		if syn_id not in syn_before and synergy_cards.has(syn_id):
			synergy_cards[syn_id].play_upgrade_burst()

func refresh_all() -> void:
	# stats_updated fires on every kill; only rebuild while the matrix is on screen
	if not visible:
		return
	points_label.text = str(GameManager.available_skill_points)
	refresh_doctrine()

	for skill_id in node_cards.keys():
		var skill = SkillData.SKILLS[skill_id]
		var cur_lvl = GameManager.get_skill_level(skill_id)
		var st := SkillTile.TileState.AVAILABLE
		if cur_lvl >= skill["max_lvl"]:
			st = SkillTile.TileState.MAXED
		elif skill["prereq"] != "" and GameManager.get_skill_level(skill["prereq"]) < skill["prereq_lvl"]:
			st = SkillTile.TileState.LOCKED
		elif GameManager.can_upgrade_skill(skill_id):
			st = SkillTile.TileState.UPGRADABLE
		node_cards[skill_id].set_state(cur_lvl, st)

	for syn_id in synergy_cards.keys():
		var syn = SkillData.SYNERGIES[syn_id]
		var active = GameManager.is_synergy_active(syn_id)
		var progress: Array = []
		for rk in syn["req"].keys():
			progress.append([float(min(GameManager.get_skill_level(rk), syn["req"][rk])) / syn["req"][rk], accent_for(SkillData.SKILLS[rk])])
		synergy_cards[syn_id].req_progress = progress
		synergy_cards[syn_id].set_state(1 if active else 0, SkillTile.TileState.ACTIVE if active else SkillTile.TileState.LOCKED)

	update_inspector()
	wire_overlay.queue_redraw()

func _on_wire_overlay_draw() -> void:
	if not visible:
		return
	var origin = wire_overlay.global_position
	
	# 1. Circuit traces from each prerequisite to its child skill
	for skill_id in SkillData.SKILLS.keys():
		var skill = SkillData.SKILLS[skill_id]
		var prereq_id = skill["prereq"]
		if prereq_id == "" or not node_cards.has(prereq_id) or not node_cards.has(skill_id):
			continue
		var p_rect: Rect2 = node_cards[prereq_id].get_global_rect()
		var c_rect: Rect2 = node_cards[skill_id].get_global_rect()
		var is_unlocked = GameManager.get_skill_level(prereq_id) >= skill["prereq_lvl"]
		var accent: Color = accent_for(skill)
		
		var pts: PackedVector2Array
		var tier_gap = int(skill["tier"]) - int(SkillData.SKILLS[prereq_id]["tier"])
		if tier_gap <= 1:
			# Straight drop from parent bottom to child top
			var x = p_rect.get_center().x - origin.x
			pts = PackedVector2Array([Vector2(x, p_rect.end.y - origin.y - 4), Vector2(x, c_rect.position.y - origin.y + 2)])
		else:
			# Skip connection: route around the left side of the tiles in between
			var lx = p_rect.position.x - origin.x - 14.0
			var py = p_rect.get_center().y - origin.y - 6.0
			var cy = c_rect.get_center().y - origin.y - 6.0
			pts = PackedVector2Array([
				Vector2(p_rect.position.x - origin.x + 2, py), Vector2(lx, py),
				Vector2(lx, cy), Vector2(c_rect.position.x - origin.x + 2, cy)
			])
		if is_unlocked:
			_draw_glow_path(pts, accent, 1.0)
			var t = fmod(pulse_time * 0.6 + float(skill["tier"]) * 0.3, 1.0)
			_draw_packet(_point_on_path(pts, t), accent)
		else:
			_draw_dashed_path(pts, Color(CyberPalette.LOCKED, 0.55))
		# Requirement level badge at the joint
		var mid = _point_on_path(pts, 0.5)
		var need = skill["prereq_lvl"]
		var have = min(GameManager.get_skill_level(prereq_id), need)
		_draw_req_pips(mid, have, need, accent if is_unlocked else CyberPalette.LOCKED)
	
	# 2. Synergy links: curved cables from each requirement tile to its synergy tile.
	# Faint by default; bright and animated when the synergy, or one of its parts, is focused.
	for syn_id in SkillData.SYNERGIES.keys():
		if not synergy_cards.has(syn_id):
			continue
		var syn = SkillData.SYNERGIES[syn_id]
		var s_rect: Rect2 = synergy_cards[syn_id].get_global_rect()
		var active = GameManager.is_synergy_active(syn_id)
		var focus = (selected_is_synergy and selected_skill_id == syn_id) or (not selected_is_synergy and syn["req"].has(selected_skill_id))
		var target = Vector2(s_rect.position.x - origin.x + 4, s_rect.position.y - origin.y + s_rect.size.x * 0.5)
		var k = 0
		for rk in syn["req"].keys():
			if not node_cards.has(rk):
				continue
			var r_rect: Rect2 = node_cards[rk].get_global_rect()
			var src = Vector2(r_rect.end.x - origin.x - 4, r_rect.position.y - origin.y + r_rect.size.x * 0.5)
			var met = GameManager.get_skill_level(rk) >= syn["req"][rk]
			var dst = target + Vector2(0, -10 if k == 0 else 10)
			var curve = _bezier(src, src + Vector2(70, 0), dst - Vector2(70, 0), dst, 24)
			var col = SYNERGY_COLOR if (met or active) else accent_for(SkillData.SKILLS[rk])
			if active:
				_draw_glow_path(curve, SYNERGY_COLOR, 0.8 if focus else 0.45)
				_draw_packet(_point_on_path(curve, fmod(pulse_time * 0.4 + k * 0.5, 1.0)), SYNERGY_COLOR)
			elif focus:
				_draw_glow_path(curve, col, 0.7 if met else 0.45)
				_draw_packet(_point_on_path(curve, fmod(pulse_time * 0.5 + k * 0.5, 1.0)), col)
			else:
				wire_overlay.draw_polyline(curve, Color(col, 0.10 if not met else 0.22), 1.5, true)
			k += 1

func _draw_glow_path(pts: PackedVector2Array, col: Color, strength: float) -> void:
	wire_overlay.draw_polyline(pts, Color(col, 0.10 * strength), 9.0, true)
	wire_overlay.draw_polyline(pts, Color(col, 0.30 * strength), 4.5, true)
	wire_overlay.draw_polyline(pts, Color(col.lerp(Color.WHITE, 0.35), 0.95 * strength), 1.8, true)
	wire_overlay.draw_circle(pts[0], 3.5, Color(col, strength))
	wire_overlay.draw_circle(pts[pts.size() - 1], 3.5, Color(col, strength))

func _draw_dashed_path(pts: PackedVector2Array, col: Color) -> void:
	for i in range(1, pts.size()):
		wire_overlay.draw_dashed_line(pts[i - 1], pts[i], col, 1.5, 6.0)

func _draw_packet(p: Vector2, col: Color) -> void:
	wire_overlay.draw_circle(p, 7.0, Color(col, 0.25))
	wire_overlay.draw_circle(p, 3.2, Color.WHITE)

# Small chip on a wire: filled segments = prerequisite levels reached
func _draw_req_pips(center: Vector2, have: int, need: int, col: Color) -> void:
	var w = 6.0
	var gap = 2.0
	var total_w = need * w + (need - 1) * gap
	var r = Rect2(center.x - total_w * 0.5 - 4, center.y - 6, total_w + 8, 12)
	wire_overlay.draw_rect(r, Color(0.02, 0.02, 0.04, 0.95))
	wire_overlay.draw_rect(r, Color(col, 0.6), false, 1.0)
	for i in range(need):
		var x = r.position.x + 4 + i * (w + gap)
		wire_overlay.draw_rect(Rect2(x, center.y - 3, w, 6), col if i < have else Color(col, 0.2))

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(steps + 1):
		var t = float(i) / steps
		var u = 1.0 - t
		out.append(u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3)
	return out

func _point_on_path(pts: PackedVector2Array, t: float) -> Vector2:
	var total = 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	var d = t * total
	for i in range(1, pts.size()):
		var seg = pts[i - 1].distance_to(pts[i])
		if d <= seg:
			return pts[i - 1].lerp(pts[i], d / max(seg, 0.001))
		d -= seg
	return pts[pts.size() - 1]

func _on_hover_sound() -> void:
	AudioManager.play_sfx("ui_hover", 0.05, -8.0)
