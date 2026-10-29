extends CanvasLayer

# Advanced Cyberpunk Progression Tree (Neural Tech Matrix)
# Features:
# - PCB Circuit Conduit wiring with animated flowing energy pulses
# - Cyber-Chip styled skill node cards with Kenney sci-fi panels & icons
# - Level progress pips indicator ([■■■□□])
# - Interactive Neural Inspector side-deck showing real-time subsystem specs
# - Synergies Fusion Matrix with requirement link indicators
# - Audio-reactive feedback (ui_hover, upgrade_select, level_up)

@onready var points_label: Label = $Panel/Margin/VBox/Header/PointsLabel
@onready var wire_overlay: Control = $Panel/Margin/VBox/Body/TreeScroll/TreeBoard/WireOverlay
@onready var offense_vbox: VBoxContainer = $Panel/Margin/VBox/Body/TreeScroll/TreeBoard/Columns/OffenseCol/NodesVBox
@onready var defense_vbox: VBoxContainer = $Panel/Margin/VBox/Body/TreeScroll/TreeBoard/Columns/DefenseCol/NodesVBox
@onready var overclock_vbox: VBoxContainer = $Panel/Margin/VBox/Body/TreeScroll/TreeBoard/Columns/OverclockCol/NodesVBox
@onready var synergies_vbox: VBoxContainer = $Panel/Margin/VBox/Body/TreeScroll/TreeBoard/Columns/SynergiesCol/NodesVBox
@onready var close_btn: Button = $Panel/Margin/VBox/Footer/CloseBtn

# Inspector Controls
@onready var inspector_icon: TextureRect = $Panel/Margin/VBox/Body/InspectorPanel/InspectorMargin/InspectorVBox/IconHBox/InspectorIcon
@onready var inspector_name: Label = $Panel/Margin/VBox/Body/InspectorPanel/InspectorMargin/InspectorVBox/TechName
@onready var inspector_code: Label = $Panel/Margin/VBox/Body/InspectorPanel/InspectorMargin/InspectorVBox/TechCodeBadge
@onready var inspector_pips: Label = $Panel/Margin/VBox/Body/InspectorPanel/InspectorMargin/InspectorVBox/TierPipsLabel
@onready var inspector_status: Label = $Panel/Margin/VBox/Body/InspectorPanel/InspectorMargin/InspectorVBox/TechStatus
@onready var inspector_desc: Label = $Panel/Margin/VBox/Body/InspectorPanel/InspectorMargin/InspectorVBox/TechDesc
@onready var inspector_next: Label = $Panel/Margin/VBox/Body/InspectorPanel/InspectorMargin/InspectorVBox/TechNextBonus
@onready var inspector_syn_hint: Label = $Panel/Margin/VBox/Body/InspectorPanel/InspectorMargin/InspectorVBox/TechSynergiesHint
@onready var inspector_upgrade_btn: Button = $Panel/Margin/VBox/Body/InspectorPanel/InspectorMargin/InspectorVBox/UpgradeActionBtn

var node_cards: Dictionary = {}
var synergy_cards: Dictionary = {}
var selected_skill_id: String = "blaster"
var selected_is_synergy: bool = false

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
	
	GameManager.stats_updated.connect(refresh_all)
	wire_overlay.draw.connect(_on_wire_overlay_draw)
	
	build_ui()
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
	GameManager.set_state(GameManager.State.SKILL_TREE)
	AudioManager.play_sfx("upgrade_select", 0.05, -2.0)
	refresh_all()
	wire_overlay.queue_redraw()

func close_tree() -> void:
	visible = false
	GameManager.set_state(GameManager.State.PLAYING)

func build_ui() -> void:
	# 1. Build skill node cards
	for skill_id in SkillData.SKILLS.keys():
		var skill = SkillData.SKILLS[skill_id]
		var card = create_skill_card(skill)
		node_cards[skill_id] = card
		
		match skill["branch"]:
			SkillData.Branch.OFFENSE:
				offense_vbox.add_child(card)
			SkillData.Branch.DEFENSE:
				defense_vbox.add_child(card)
			SkillData.Branch.OVERCLOCK:
				overclock_vbox.add_child(card)
				
	# 2. Build synergy cards
	build_synergies_cards()

func create_skill_card(skill: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 102)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.07, 0.13, 0.92)
	style.border_color = skill["icon_color"]
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)
	
	# Top bar: Tech Code + Level
	var top_hbox = HBoxContainer.new()
	
	var code_lbl = Label.new()
	code_lbl.text = "[%s]" % skill.get("code", "SYS")
	code_lbl.modulate = Color(skill["icon_color"].r, skill["icon_color"].g, skill["icon_color"].b, 0.75)
	code_lbl.add_theme_font_size_override("font_size", 9)
	top_hbox.add_child(code_lbl)
	
	var lvl_lbl = Label.new()
	lvl_lbl.name = "LevelLabel"
	lvl_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lvl_lbl.text = "v0/4"
	lvl_lbl.modulate = Color(1.0, 0.85, 0.3)
	lvl_lbl.add_theme_font_size_override("font_size", 10)
	top_hbox.add_child(lvl_lbl)
	vbox.add_child(top_hbox)
	
	# Mid row: Icon + Name
	var mid_hbox = HBoxContainer.new()
	mid_hbox.add_theme_constant_override("separation", 6)
	
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(26, 26)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_p = skill.get("icon_path", "")
	if ResourceLoader.exists(icon_p):
		icon_rect.texture = load(icon_p)
	icon_rect.modulate = skill["icon_color"]
	mid_hbox.add_child(icon_rect)
	
	var name_lbl = Label.new()
	name_lbl.text = skill["name"]
	name_lbl.modulate = Color(1.0, 1.0, 1.0, 0.95)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	mid_hbox.add_child(name_lbl)
	vbox.add_child(mid_hbox)
	
	# Pips row
	var pips_lbl = Label.new()
	pips_lbl.name = "PipsLabel"
	pips_lbl.text = "[□□□□]"
	pips_lbl.modulate = skill["icon_color"]
	pips_lbl.add_theme_font_size_override("font_size", 9)
	vbox.add_child(pips_lbl)
	
	# Mini Upgrade Button on Card
	var mini_btn = Button.new()
	mini_btn.name = "MiniUpgradeBtn"
	mini_btn.text = "[+1 UPGRADE]"
	mini_btn.add_theme_font_size_override("font_size", 9)
	
	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.06, 0.18, 0.3, 0.9)
	b_style.border_color = skill["icon_color"]
	b_style.set_border_width_all(1)
	b_style.set_corner_radius_all(3)
	mini_btn.add_theme_stylebox_override("normal", b_style)
	
	var b_hover = StyleBoxFlat.new()
	b_hover.bg_color = Color(0.12, 0.32, 0.5, 1.0)
	b_hover.border_color = Color.WHITE
	b_hover.set_border_width_all(1)
	b_hover.set_corner_radius_all(3)
	mini_btn.add_theme_stylebox_override("hover", b_hover)
	
	mini_btn.pressed.connect(func():
		GameManager.upgrade_skill(skill["id"])
		select_skill(skill["id"])
	)
	mini_btn.mouse_entered.connect(_on_hover_sound)
	vbox.add_child(mini_btn)
	
	# Click / Hover on panel opens inspector
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select_skill(skill["id"])
			_on_hover_sound()
	)
	panel.mouse_entered.connect(func():
		select_skill(skill["id"])
		_on_hover_sound()
	)
	
	return panel

func build_synergies_cards() -> void:
	for child in synergies_vbox.get_children():
		child.queue_free()
	synergy_cards.clear()
	
	for syn_id in SkillData.SYNERGIES.keys():
		var syn = SkillData.SYNERGIES[syn_id]
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 102)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.03, 0.12, 0.92)
		style.border_color = syn["icon_color"]
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 8)
		margin.add_theme_constant_override("margin_right", 8)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		panel.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		margin.add_child(vbox)
		
		# Header
		var code_lbl = Label.new()
		code_lbl.text = "[%s] FUSION" % syn.get("code", "SYN")
		code_lbl.modulate = Color(syn["icon_color"].r, syn["icon_color"].g, syn["icon_color"].b, 0.8)
		code_lbl.add_theme_font_size_override("font_size", 9)
		vbox.add_child(code_lbl)
		
		# Name
		var name_lbl = Label.new()
		name_lbl.text = syn["name"]
		name_lbl.modulate = syn["icon_color"]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vbox.add_child(name_lbl)
		
		# Requirement / Status badge
		var status_badge = Label.new()
		status_badge.name = "StatusBadge"
		status_badge.add_theme_font_size_override("font_size", 9)
		vbox.add_child(status_badge)
		
		panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				select_synergy(syn_id)
				_on_hover_sound()
		)
		panel.mouse_entered.connect(func():
			select_synergy(syn_id)
			_on_hover_sound()
		)
		
		synergy_cards[syn_id] = panel
		synergies_vbox.add_child(panel)

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

func update_inspector() -> void:
	if selected_is_synergy:
		var syn = SkillData.SYNERGIES[selected_skill_id]
		inspector_name.text = syn["name"]
		inspector_name.modulate = syn["icon_color"]
		inspector_code.text = "CORE_SYNAPSE_FUSION: [%s]" % syn.get("code", "SYN")
		inspector_pips.text = "[ МАТРИЧНА СИНЕРГІЯ ]"
		
		var icon_p = syn.get("icon_path", "")
		if ResourceLoader.exists(icon_p):
			inspector_icon.texture = load(icon_p)
		inspector_icon.modulate = syn["icon_color"]
		
		var active = GameManager.is_synergy_active(selected_skill_id)
		if active:
			inspector_status.text = "[STATUS: ONLINE // KERNEL COMPILED]"
			inspector_status.modulate = Color(0.2, 1.0, 0.5)
		else:
			inspector_status.text = "[STATUS: LOCKED // REQUIREMENTS PENDING]"
			inspector_status.modulate = Color(1.0, 0.4, 0.4)
			
		inspector_desc.text = syn["desc"]
		
		# Show requirements
		var req_strs: Array[String] = []
		for rk in syn["req"].keys():
			var rname = SkillData.SKILLS[rk]["name"]
			var req_lvl = syn["req"][rk]
			var cur_lvl = GameManager.get_skill_level(rk)
			req_strs.append("%s (v%d / v%d)" % [rname, cur_lvl, req_lvl])
		inspector_next.text = "⚡ НЕОБХІДНІ КОМПОНЕНТИ:\n" + " + ".join(req_strs)
		inspector_syn_hint.text = "Автоматично активується при досягненні необхідних рівнів обох компонентів!"
		
		inspector_upgrade_btn.disabled = true
		inspector_upgrade_btn.text = "[ СИНЕРГІЯ АКТИВНА ]" if active else "[ ОЧІКУЄ ДОСЛІДЖЕННЯ КОМПОНЕНТІВ ]"
	else:
		var skill = SkillData.SKILLS[selected_skill_id]
		var cur_lvl = GameManager.get_skill_level(selected_skill_id)
		var max_lvl = skill["max_lvl"]
		
		inspector_name.text = skill["name"]
		inspector_name.modulate = skill["icon_color"]
		inspector_code.text = "ID: [%s] // PROTOCOL: %s" % [skill.get("code", "SYS"), get_branch_name(skill["branch"])]
		
		var pips = ""
		for i in range(max_lvl):
			pips += "■ " if i < cur_lvl else "□ "
		inspector_pips.text = "[ %s] (Рівень %d / %d)" % [pips, cur_lvl, max_lvl]
		
		var icon_p = skill.get("icon_path", "")
		if ResourceLoader.exists(icon_p):
			inspector_icon.texture = load(icon_p)
		inspector_icon.modulate = skill["icon_color"]
		
		var can_up = GameManager.can_upgrade_skill(selected_skill_id)
		if cur_lvl >= max_lvl:
			inspector_status.text = "[STATUS: MAX OVERCLOCK COMPILED]"
			inspector_status.modulate = Color(1.0, 0.85, 0.25)
		elif skill["prereq"] != "" and GameManager.get_skill_level(skill["prereq"]) < skill["prereq_lvl"]:
			var req_name = SkillData.SKILLS[skill["prereq"]]["name"]
			inspector_status.text = "[LOCKED // ПОТРІБНО: %s Рів. %d]" % [req_name, skill["prereq_lvl"]]
			inspector_status.modulate = Color(1.0, 0.35, 0.35)
		else:
			inspector_status.text = "[STATUS: READY FOR FLASH // 1 CORE POINT]"
			inspector_status.modulate = Color(0.25, 0.9, 1.0)
			
		inspector_desc.text = skill["desc"]
		inspector_next.text = "⚡ НАСТУПНИЙ РІВЕНЬ: " + skill["per_level"]
		
		# Find associated synergies
		var related_syn: Array[String] = []
		for syn_id in SkillData.SYNERGIES.keys():
			var syn = SkillData.SYNERGIES[syn_id]
			if syn["req"].has(selected_skill_id):
				related_syn.append(syn["name"])
		if related_syn.size() > 0:
			inspector_syn_hint.text = "✨ БЕРЕ УЧАСТЬ У СИНЕРГІЯХ: " + ", ".join(related_syn)
		else:
			inspector_syn_hint.text = "✨ БАЗОВА ОПТИМІЗАЦІЯ СИСТЕМИ"
			
		if cur_lvl >= max_lvl:
			inspector_upgrade_btn.disabled = true
			inspector_upgrade_btn.text = "[ МАКСИМАЛЬНИЙ РІВЕНЬ ]"
		else:
			inspector_upgrade_btn.disabled = not can_up
			inspector_upgrade_btn.text = "[ ⚡ ВСТАНОВИТИ ПРОШИВКУ v%d ]" % (cur_lvl + 1)

func _on_inspector_upgrade_pressed() -> void:
	if not selected_is_synergy:
		GameManager.upgrade_skill(selected_skill_id)
		update_inspector()

func refresh_all() -> void:
	points_label.text = "[ ⚡ ДОСТУПНІ ЯДРА ПАМ'ЯТІ: 0x%02X ]" % GameManager.available_skill_points
	
	# Update skill cards
	for skill_id in node_cards.keys():
		var card = node_cards[skill_id]
		var skill = SkillData.SKILLS[skill_id]
		var cur_lvl = GameManager.get_skill_level(skill_id)
		var max_lvl = skill["max_lvl"]
		
		var lvl_lbl: Label = card.find_child("LevelLabel", true, false)
		if lvl_lbl:
			lvl_lbl.text = "v%d/%d" % [cur_lvl, max_lvl]
			
		var pips_lbl: Label = card.find_child("PipsLabel", true, false)
		if pips_lbl:
			var pips = ""
			for i in range(max_lvl):
				pips += "■" if i < cur_lvl else "□"
			pips_lbl.text = "[%s]" % pips
			
		var mini_btn: Button = card.find_child("MiniUpgradeBtn", true, false)
		if mini_btn:
			var can_up = GameManager.can_upgrade_skill(skill_id)
			mini_btn.disabled = not can_up
			if cur_lvl >= max_lvl:
				mini_btn.text = "[MAXED]"
				mini_btn.disabled = true
			else:
				mini_btn.text = "[+1 UPGRADE]"
				
	# Update synergy cards
	for syn_id in synergy_cards.keys():
		var card = synergy_cards[syn_id]
		var syn = SkillData.SYNERGIES[syn_id]
		var status_badge: Label = card.find_child("StatusBadge", true, false)
		if status_badge:
			if GameManager.is_synergy_active(syn_id):
				status_badge.text = "[ONLINE]"
				status_badge.modulate = Color(0.2, 1.0, 0.45)
			else:
				var parts: Array[String] = []
				for rk in syn["req"].keys():
					var clvl = GameManager.get_skill_level(rk)
					var rlvl = syn["req"][rk]
					parts.append("%s:%d/%d" % [SkillData.SKILLS[rk].get("code", "REQ"), clvl, rlvl])
				status_badge.text = " + ".join(parts)
				status_badge.modulate = Color(0.7, 0.75, 0.85)
				
	update_inspector()
	wire_overlay.queue_redraw()

func _on_wire_overlay_draw() -> void:
	if not visible:
		return
		
	# Draw circuit traces connecting parent skills to child skills
	for skill_id in SkillData.SKILLS.keys():
		var skill = SkillData.SKILLS[skill_id]
		var prereq_id = skill["prereq"]
		if prereq_id != "" and node_cards.has(prereq_id) and node_cards.has(skill_id):
			var parent_card: PanelContainer = node_cards[prereq_id]
			var child_card: PanelContainer = node_cards[skill_id]
			
			var p_rect = parent_card.get_global_rect()
			var c_rect = child_card.get_global_rect()
			
			var p_pt = p_rect.get_center() - wire_overlay.global_position
			var c_pt = c_rect.get_center() - wire_overlay.global_position
			
			# Wire exits bottom of parent and enters top of child
			var start_pt = Vector2(p_pt.x, p_rect.end.y - wire_overlay.global_position.y)
			var end_pt = Vector2(c_pt.x, c_rect.position.y - wire_overlay.global_position.y)
			
			var is_unlocked = GameManager.get_skill_level(prereq_id) >= skill["prereq_lvl"]
			var col = skill["icon_color"] if is_unlocked else Color(0.25, 0.35, 0.45, 0.4)
			var wire_width = 3.0 if is_unlocked else 1.5
			
			# Draw circuit trace with right angles
			var mid_y = lerpf(start_pt.y, end_pt.y, 0.5)
			wire_overlay.draw_line(start_pt, Vector2(start_pt.x, mid_y), col, wire_width)
			wire_overlay.draw_line(Vector2(start_pt.x, mid_y), Vector2(end_pt.x, mid_y), col, wire_width)
			wire_overlay.draw_line(Vector2(end_pt.x, mid_y), end_pt, col, wire_width)
			
			# Little circuit terminal dots
			wire_overlay.draw_circle(start_pt, 3.5, col)
			wire_overlay.draw_circle(end_pt, 3.5, col)
			
			# Flowing energetic pulse dot when unlocked
			if is_unlocked:
				var t = fmod(pulse_time * 0.8 + float(skill["tier"]) * 0.3, 1.0)
				var pulse_pos = start_pt.lerp(end_pt, t)
				wire_overlay.draw_circle(pulse_pos, 4.0, Color.WHITE)

func get_branch_name(branch: int) -> String:
	match branch:
		SkillData.Branch.OFFENSE: return "OFFENSE_SYS"
		SkillData.Branch.DEFENSE: return "DEFENSE_SYS"
		SkillData.Branch.OVERCLOCK: return "OVERCLOCK_SYS"
		_: return "GENERAL"

func _on_hover_sound() -> void:
	AudioManager.play_sfx("ui_hover", 0.05, -8.0)
