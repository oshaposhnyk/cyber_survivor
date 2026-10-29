extends CanvasLayer

@onready var hp_bar: ProgressBar = $PilotPlate/HBox/Bars/HPRow/HPBar
@onready var hp_label: Label = $PilotPlate/HBox/Bars/HPRow/HPLabel
@onready var shield_bar: ProgressBar = $PilotPlate/HBox/Bars/ShieldBar
@onready var xp_bar: ProgressBar = $XPBar
@onready var level_label: Label = $PilotPlate/HBox/LevelChip/LevelLabel
@onready var timer_label: Label = $StatsPlate/HBox/TimerBox/TimerLabel
@onready var kills_label: Label = $StatsPlate/HBox/KillsBox/KillsLabel
@onready var scrap_label: Label = $StatsPlate/HBox/ScrapBox/ScrapLabel
@onready var boss_container: VBoxContainer = $BossContainer
@onready var boss_label: Label = $BossContainer/Header/BossLabel
@onready var boss_bar: ProgressBar = $BossContainer/BossBar
@onready var upgrade_banner: Button = $UpgradeBanner
@onready var wave_banner: PanelContainer = $WaveBanner
@onready var wave_title: Label = $WaveBanner/VBox/WaveTitle
@onready var wave_desc: Label = $WaveBanner/VBox/WaveDesc
@onready var synergies_container: HBoxContainer = $SynergiesContainer
@onready var edge_flash: ColorRect = $EdgeFlash

var banner_tween: Tween = null
var flash_tween: Tween = null
var last_hp: float = -1.0
var doctrine_chip: PanelContainer
var doctrine_label: Label

func _ready() -> void:
	add_to_group("hud")
	GameManager.player_damaged.connect(_on_player_health_changed)
	GameManager.stats_updated.connect(_on_stats_updated)
	GameManager.level_up_occurred.connect(_on_level_up)
	GameManager.synergy_unlocked.connect(_on_synergy_unlocked)
	GameManager.doctrine_changed.connect(_on_doctrine_changed)
	_build_doctrine_chip()

	upgrade_banner.pressed.connect(_on_upgrade_banner_pressed)
	wave_banner.modulate.a = 0.0
	upgrade_banner.pivot_offset = upgrade_banner.size * 0.5
	_on_stats_updated()

func _process(_delta: float) -> void:
	var total_sec = int(GameManager.time_survived)
	timer_label.text = "%02d:%02d" % [floori(float(total_sec) / 60.0), total_sec % 60]

	var pts = GameManager.available_skill_points
	upgrade_banner.visible = pts > 0
	if pts > 0:
		upgrade_banner.text = "x%d   TAB" % pts
		var pulse = (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
		upgrade_banner.scale = Vector2.ONE * (1.0 + pulse * 0.04)

func _on_player_health_changed(hp: float, max_hp: float, shield: float, max_shield: float) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_label.text = "%d" % int(hp)
	hp_label.modulate = CyberPalette.RED if hp < max_hp * 0.3 else Color.WHITE

	shield_bar.max_value = max(1.0, max_shield)
	shield_bar.value = shield
	shield_bar.visible = (max_shield > 0.0)

	if last_hp >= 0.0 and hp < last_hp:
		_flash_edges(CyberPalette.RED, 0.3)
	last_hp = hp

func _on_stats_updated() -> void:
	level_label.text = str(GameManager.player_level)
	xp_bar.max_value = GameManager.xp_needed
	xp_bar.value = GameManager.current_xp
	kills_label.text = str(GameManager.enemies_killed)
	scrap_label.text = str(GameManager.scrap_collected)

func show_boss_bar(boss_name: String, max_hp: float) -> void:
	boss_container.visible = true
	boss_label.text = CyberPalette.strip_emoji(boss_name)
	boss_bar.max_value = max_hp
	boss_bar.value = max_hp
	_flash_edges(CyberPalette.RED, 0.8)

func update_boss_hp(hp: float) -> void:
	if boss_container.visible:
		boss_bar.value = hp

func hide_boss_bar() -> void:
	boss_container.visible = false

func _on_level_up(_level: int, _points: int) -> void:
	_on_stats_updated()
	_flash_edges(CyberPalette.YELLOW, 0.45)

func _on_synergy_unlocked(_syn_id: String, syn_info: Dictionary) -> void:
	var badge = TextureRect.new()
	badge.texture = load(syn_info["icon_path"]) if ResourceLoader.exists(syn_info["icon_path"]) else null
	badge.custom_minimum_size = Vector2(36, 36)
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	badge.self_modulate = syn_info["icon_color"]
	badge.tooltip_text = CyberPalette.strip_emoji(syn_info["name"])
	synergies_container.add_child(badge)
	show_announcement("СИНЕРГІЯ АКТИВНА", syn_info["name"])
	_flash_edges(syn_info["icon_color"], 0.5)

# Doctrine chip under the pilot plate; hidden until a branch takes over
func _build_doctrine_chip() -> void:
	doctrine_chip = PanelContainer.new()
	doctrine_chip.theme_type_variation = &"HudPlate"
	doctrine_chip.position = Vector2(16, 78)
	doctrine_chip.visible = false
	doctrine_label = Label.new()
	doctrine_label.theme_type_variation = &"MonoLabel"
	doctrine_label.add_theme_font_size_override("font_size", 15)
	doctrine_chip.add_child(doctrine_label)
	add_child(doctrine_chip)

func _on_doctrine_changed(branch: int) -> void:
	doctrine_chip.visible = branch >= 0
	if branch < 0:
		return
	var doc = SkillData.DOCTRINES[branch]
	var col = CyberPalette.branch_color(branch)
	doctrine_label.text = "ДОКТРИНА: " + doc["name"].to_upper()
	doctrine_label.add_theme_color_override("font_color", col)
	doctrine_chip.tooltip_text = "%s\n%s" % [doc["bonus"], doc["malus"]]
	show_announcement("ДОКТРИНА: " + doc["name"].to_upper(), "%s  |  %s" % [doc["bonus"], doc["malus"]])
	_flash_edges(col, 0.5)

func show_announcement(title: String, desc: String) -> void:
	wave_title.text = CyberPalette.strip_emoji(title)
	wave_desc.text = CyberPalette.strip_emoji(desc)

	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()

	wave_banner.pivot_offset = wave_banner.size * 0.5
	wave_banner.scale = Vector2(1.0, 0.0)
	banner_tween = create_tween()
	banner_tween.tween_property(wave_banner, "modulate:a", 1.0, 0.12)
	banner_tween.parallel().tween_property(wave_banner, "scale:y", 1.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Short flicker to sell the "signal" feel
	banner_tween.tween_property(wave_banner, "modulate:a", 0.4, 0.05)
	banner_tween.tween_property(wave_banner, "modulate:a", 1.0, 0.05)
	banner_tween.tween_interval(3.0)
	banner_tween.tween_property(wave_banner, "scale:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	banner_tween.parallel().tween_property(wave_banner, "modulate:a", 0.0, 0.2)

func _flash_edges(col: Color, strength: float) -> void:
	var mat := edge_flash.material as ShaderMaterial
	mat.set_shader_parameter("flash_color", col)
	if flash_tween and flash_tween.is_valid():
		flash_tween.kill()
	flash_tween = create_tween()
	flash_tween.tween_method(func(v: float): mat.set_shader_parameter("intensity", v), strength, 0.0, 0.45)

func _on_upgrade_banner_pressed() -> void:
	var tree = get_tree().get_first_node_in_group("skill_tree_ui")
	if tree and tree.has_method("open_tree"):
		tree.open_tree()
