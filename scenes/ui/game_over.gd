extends CanvasLayer

@onready var title_label: GlitchTitle = $Panel/Margin/VBox/TitleLabel
@onready var panel: PanelContainer = $Panel
@onready var stripes: TextureRect = $Panel/Margin/VBox/Stripes
@onready var time_stat: Label = $Panel/Margin/VBox/StatsGrid/TimeTile/VBox/TimeVal
@onready var kills_stat: Label = $Panel/Margin/VBox/StatsGrid/KillsTile/VBox/KillsVal
@onready var scrap_stat: Label = $Panel/Margin/VBox/StatsGrid/ScrapTile/VBox/ScrapVal
@onready var level_stat: Label = $Panel/Margin/VBox/StatsGrid/LevelTile/VBox/LevelVal
@onready var synergies_row: HBoxContainer = $Panel/Margin/VBox/SynergiesRow
@onready var retry_btn: Button = $Panel/Margin/VBox/Buttons/RetryBtn
@onready var menu_btn: Button = $Panel/Margin/VBox/Buttons/MenuBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.game_over_screen.connect(show_screen)
	retry_btn.pressed.connect(_on_retry_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)

func show_screen(stats: Dictionary) -> void:
	visible = true
	var is_victory = stats.get("victory", false)
	var accent = CyberPalette.YELLOW if is_victory else CyberPalette.RED
	
	title_label.text = "СЕКТОР ЗАЧИЩЕНО" if is_victory else "СИСТЕМУ ЗНИЩЕНО"
	title_label.color = accent
	title_label.glitch(0.4)
	stripes.self_modulate = accent
	panel.theme_type_variation = &"CyberPanel" if is_victory else &"DangerPanel"
	
	var total_sec = int(stats.get("time", 0.0))
	time_stat.text = "%02d:%02d" % [floori(float(total_sec) / 60.0), total_sec % 60]
	_count_up(kills_stat, int(stats.get("kills", 0)))
	var earned = int(stats.get("earned_nanites", stats.get("scrap", 0)))
	var total_bank = int(stats.get("meta_nanites", GameManager.meta_nanites))
	scrap_stat.text = "+%d (БАНК: %d)" % [earned, total_bank]
	level_stat.text = str(stats.get("level", 1))
	
	for c in synergies_row.get_children():
		c.queue_free()
	for sid in stats.get("synergies", []):
		if not SkillData.SYNERGIES.has(sid):
			continue
		var syn = SkillData.SYNERGIES[sid]
		var ic = TextureRect.new()
		ic.texture = load(syn["icon_path"]) if ResourceLoader.exists(syn["icon_path"]) else null
		ic.custom_minimum_size = Vector2(36, 36)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.self_modulate = Color(1.0, 0.3, 0.85)
		ic.tooltip_text = CyberPalette.strip_emoji(syn["name"])
		synergies_row.add_child(ic)
	
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(1.0, 0.02)
	var tw = create_tween()
	tw.tween_property(panel, "scale:y", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	retry_btn.grab_focus()

func _count_up(lbl: Label, target: int) -> void:
	var tw = create_tween()
	tw.tween_method(func(v: int): lbl.text = str(v), 0, target, 0.8).set_delay(0.2)

func _on_retry_pressed() -> void:
	visible = false
	GameManager.start_game()

func _on_menu_pressed() -> void:
	visible = false
	GameManager.reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
