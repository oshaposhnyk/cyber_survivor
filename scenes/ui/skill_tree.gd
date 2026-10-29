extends CanvasLayer

@onready var points_label: Label = $Panel/Margin/VBox/Header/PointsLabel
@onready var offense_container: VBoxContainer = $Panel/Margin/VBox/Columns/OffenseCol/Scroll/VBox
@onready var defense_container: VBoxContainer = $Panel/Margin/VBox/Columns/DefenseCol/Scroll/VBox
@onready var overclock_container: VBoxContainer = $Panel/Margin/VBox/Columns/OverclockCol/Scroll/VBox
@onready var synergies_list: VBoxContainer = $Panel/Margin/VBox/Columns/SynergiesCol/Scroll/VBox
@onready var close_btn: Button = $Panel/Margin/VBox/Footer/CloseBtn

var node_cards: Dictionary = {}

func _ready() -> void:
	add_to_group("skill_tree_ui")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	close_btn.pressed.connect(close_tree)
	GameManager.stats_updated.connect(refresh_all)
	build_ui()

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
	AudioManager.play_sfx("upgrade_select", 0.05)
	refresh_all()

func close_tree() -> void:
	visible = false
	GameManager.set_state(GameManager.State.PLAYING)

func build_ui() -> void:
	# Build cards for each skill in SkillData
	for skill_id in SkillData.SKILLS.keys():
		var skill = SkillData.SKILLS[skill_id]
		var card = create_skill_card(skill)
		node_cards[skill_id] = card
		
		match skill["branch"]:
			SkillData.Branch.OFFENSE:
				offense_container.add_child(card)
			SkillData.Branch.DEFENSE:
				defense_container.add_child(card)
			SkillData.Branch.OVERCLOCK:
				overclock_container.add_child(card)
				
	build_synergies_panel()

func create_skill_card(skill: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.08, 0.14, 0.92)
	style.border_color = skill["icon_color"]
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(skill["icon_color"].r, skill["icon_color"].g, skill["icon_color"].b, 0.25)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	# Header (Name + Level)
	var hbox_header = HBoxContainer.new()
	var name_lbl = Label.new()
	name_lbl.text = skill["name"]
	name_lbl.modulate = skill["icon_color"]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_header.add_child(name_lbl)
	
	var lvl_lbl = Label.new()
	lvl_lbl.name = "LevelLabel"
	lvl_lbl.text = "[0/%d]" % skill["max_lvl"]
	lvl_lbl.add_theme_font_size_override("font_size", 12)
	lvl_lbl.modulate = Color(1.0, 0.85, 0.3)
	hbox_header.add_child(lvl_lbl)
	vbox.add_child(hbox_header)
	
	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = skill["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.modulate = Color(0.8, 0.85, 0.95)
	vbox.add_child(desc_lbl)
	
	# Per level info
	var info_lbl = Label.new()
	info_lbl.text = "⚡ " + skill["per_level"]
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_lbl.add_theme_font_size_override("font_size", 10)
	info_lbl.modulate = Color(0.3, 1.0, 0.6)
	vbox.add_child(info_lbl)
	
	# Prereq / Status label
	var status_lbl = Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.add_theme_font_size_override("font_size", 10)
	vbox.add_child(status_lbl)
	
	# Upgrade Button styled with sci-fi look
	var btn = Button.new()
	btn.name = "UpgradeBtn"
	btn.text = "▲ ДОСЛІДИТИ ТЕХНОЛОГІЮ"
	btn.add_theme_font_size_override("font_size", 11)
	
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.08, 0.22, 0.36, 0.9)
	btn_normal.border_color = skill["icon_color"]
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", btn_normal)
	
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.12, 0.35, 0.55, 0.95)
	btn_hover.border_color = Color(1, 1, 1, 1)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", btn_hover)
	
	btn.pressed.connect(func(): GameManager.upgrade_skill(skill["id"]))
	vbox.add_child(btn)
	
	return panel

func build_synergies_panel() -> void:
	for child in synergies_list.get_children():
		child.queue_free()
		
	for syn_id in SkillData.SYNERGIES.keys():
		var syn = SkillData.SYNERGIES[syn_id]
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.05, 0.07, 0.12, 0.92)
		style.border_color = syn["icon_color"]
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		panel.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		margin.add_child(vbox)
		
		var name_lbl = Label.new()
		name_lbl.text = syn["name"]
		name_lbl.modulate = syn["icon_color"]
		name_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(name_lbl)
		
		var desc_lbl = Label.new()
		desc_lbl.text = syn["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.modulate = Color(0.8, 0.85, 0.9)
		vbox.add_child(desc_lbl)
		
		var req_lbl = Label.new()
		req_lbl.name = "ReqLabel_" + syn_id
		req_lbl.add_theme_font_size_override("font_size", 10)
		vbox.add_child(req_lbl)
		
		synergies_list.add_child(panel)

func refresh_all() -> void:
	points_label.text = "⚡ ДОСТУПНО ОЧОК: %d" % GameManager.available_skill_points
	
	# Update each skill card
	for skill_id in node_cards.keys():
		var card = node_cards[skill_id]
		var skill = SkillData.SKILLS[skill_id]
		var cur_lvl = GameManager.get_skill_level(skill_id)
		var max_lvl = skill["max_lvl"]
		
		var lvl_lbl: Label = card.find_child("LevelLabel", true, false)
		if lvl_lbl:
			lvl_lbl.text = "[%d/%d]" % [cur_lvl, max_lvl]
			
		var status_lbl: Label = card.find_child("StatusLabel", true, false)
		var btn: Button = card.find_child("UpgradeBtn", true, false)
		
		var can_up = GameManager.can_upgrade_skill(skill_id)
		btn.disabled = not can_up
		
		if cur_lvl >= max_lvl:
			btn.visible = false
			status_lbl.text = "★ МАКСИМАЛЬНИЙ РІВЕНЬ"
			status_lbl.modulate = Color(1.0, 0.8, 0.2)
		elif skill["prereq"] != "" and GameManager.get_skill_level(skill["prereq"]) < skill["prereq_lvl"]:
			var req_name = SkillData.SKILLS[skill["prereq"]]["name"]
			status_lbl.text = "🔒 Потрібно: %s Рів. %d" % [req_name, skill["prereq_lvl"]]
			status_lbl.modulate = Color(1.0, 0.35, 0.35)
		else:
			status_lbl.text = "Готово до модернізації"
			status_lbl.modulate = Color(0.3, 0.8, 1.0)
			
	# Update Synergies panel
	for syn_id in SkillData.SYNERGIES.keys():
		var syn = SkillData.SYNERGIES[syn_id]
		var req_lbl: Label = synergies_list.find_child("ReqLabel_" + syn_id, true, false)
		if req_lbl:
			if GameManager.is_synergy_active(syn_id):
				req_lbl.text = "✅ АКТИВОВАНО!"
				req_lbl.modulate = Color(0.2, 1.0, 0.4)
			else:
				var parts: Array[String] = []
				for rk in syn["req"].keys():
					var rname = SkillData.SKILLS[rk]["name"]
					var rlvl = syn["req"][rk]
					var clvl = GameManager.get_skill_level(rk)
					parts.append("%s [%d/%d]" % [rname, clvl, rlvl])
				req_lbl.text = "Вимоги: " + ", ".join(parts)
				req_lbl.modulate = Color(0.7, 0.7, 0.7)
