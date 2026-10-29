extends CanvasLayer

@onready var hp_bar: ProgressBar = $MarginContainer/MainPanel/PanelMargin/VBoxContainer/TopRow/HealthContainer/HPBar
@onready var hp_label: Label = $MarginContainer/MainPanel/PanelMargin/VBoxContainer/TopRow/HealthContainer/HPLabel
@onready var shield_bar: ProgressBar = $MarginContainer/MainPanel/PanelMargin/VBoxContainer/TopRow/HealthContainer/ShieldBar
@onready var xp_bar: ProgressBar = $MarginContainer/MainPanel/PanelMargin/VBoxContainer/XPBar
@onready var level_label: Label = $MarginContainer/MainPanel/PanelMargin/VBoxContainer/TopRow/LevelLabel
@onready var timer_label: Label = $MarginContainer/MainPanel/PanelMargin/VBoxContainer/TopRow/StatsContainer/TimerLabel
@onready var kills_label: Label = $MarginContainer/MainPanel/PanelMargin/VBoxContainer/TopRow/StatsContainer/KillsLabel
@onready var scrap_label: Label = $MarginContainer/MainPanel/PanelMargin/VBoxContainer/TopRow/StatsContainer/ScrapLabel
@onready var upgrade_banner: Button = $UpgradeBanner
@onready var wave_banner: PanelContainer = $WaveBanner
@onready var wave_title: Label = $WaveBanner/VBox/WaveTitle
@onready var wave_desc: Label = $WaveBanner/VBox/WaveDesc
@onready var synergies_container: HBoxContainer = $SynergiesContainer

var banner_tween: Tween = null
var cursor_blink: float = 0.0

func _ready() -> void:
	GameManager.player_damaged.connect(_on_player_health_changed)
	GameManager.stats_updated.connect(_on_stats_updated)
	GameManager.level_up_occurred.connect(_on_level_up)
	GameManager.synergy_unlocked.connect(_on_synergy_unlocked)
	
	upgrade_banner.pressed.connect(_on_upgrade_banner_pressed)
	wave_banner.modulate.a = 0.0
	_on_stats_updated()

func _process(delta: float) -> void:
	cursor_blink += delta * 4.0
	var cur = "_" if fmod(cursor_blink, 2.0) < 1.0 else " "
	
	var total_sec = int(GameManager.time_survived)
	var mins = floori(float(total_sec) / 60.0)
	var secs = total_sec % 60
	timer_label.text = "[T_MISSION: %02d:%02d]" % [mins, secs]
	
	var pts = GameManager.available_skill_points
	if pts > 0:
		upgrade_banner.visible = true
		upgrade_banner.text = ">> [!] MEM_TECH_POINTS: 0x%02X // COMPILE_[TAB] %s <<" % [pts, cur]
		var pulse = (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
		upgrade_banner.modulate = Color(1.0, 0.75 + pulse * 0.25, 0.2 + pulse * 0.4)
	else:
		upgrade_banner.visible = false

func _on_player_health_changed(hp: float, max_hp: float, shield: float, max_shield: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "HULL_INTEGRITY: %d/%d HP" % [int(hp), int(max_hp)]
	
	shield_bar.max_value = max(1.0, max_shield)
	shield_bar.value = shield
	shield_bar.visible = (max_shield > 0.0)

func _on_stats_updated() -> void:
	level_label.text = "> ARC-01 // LVL_%02d" % GameManager.player_level
	xp_bar.max_value = GameManager.xp_needed
	xp_bar.value = GameManager.current_xp
	kills_label.text = "[PURGED: %d]" % GameManager.enemies_killed
	scrap_label.text = "[NANO_SCRAP: %d]" % GameManager.scrap_collected

func _on_level_up(_level: int, _points: int) -> void:
	_on_stats_updated()

func _on_synergy_unlocked(_syn_id: String, syn_info: Dictionary) -> void:
	var badge = Label.new()
	badge.text = "[SYN::" + syn_info["id"].to_upper() + "]"
	badge.modulate = syn_info["icon_color"]
	badge.add_theme_font_size_override("font_size", 12)
	synergies_container.add_child(badge)
	show_announcement("KERNEL_ALERT: SYNERGY_ONLINE!", syn_info["name"] + " // INITIALIZED")

func show_announcement(title: String, desc: String) -> void:
	wave_title.text = ">> " + title + " <<"
	wave_desc.text = "// " + desc
	
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
		
	banner_tween = create_tween()
	banner_tween.tween_property(wave_banner, "modulate:a", 1.0, 0.35)
	banner_tween.tween_interval(3.2)
	banner_tween.tween_property(wave_banner, "modulate:a", 0.0, 0.45)

func _on_upgrade_banner_pressed() -> void:
	var tree = get_tree().get_first_node_in_group("skill_tree_ui")
	if tree and tree.has_method("open_tree"):
		tree.open_tree()
