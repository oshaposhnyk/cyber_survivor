extends Control

@onready var start_btn: Button = $VBoxContainer/StartBtn
@onready var cyberdeck_btn: Button = $VBoxContainer/CyberdeckBtn
@onready var info_btn: Button = $VBoxContainer/InfoBtn
@onready var credits_btn: Button = $VBoxContainer/CreditsBtn
@onready var music_btn: Button = $TopControls/MusicBtn
@onready var sfx_btn: Button = $TopControls/SFXBtn
@onready var info_dialog: PanelContainer = $InfoDialog
@onready var dialog_title: Label = $InfoDialog/Margin/VBox/Header/DialogTitle
@onready var close_info_btn: Button = $InfoDialog/Margin/VBox/Header/CloseInfoBtn
@onready var info_text: RichTextLabel = $InfoDialog/Margin/VBox/InfoText
@onready var ship: Sprite2D = $Ship

# Cyberdeck Permanent Upgrades Dialog
var cyberdeck_dialog: PanelContainer
var nanites_label: Label
var upgrades_container: VBoxContainer

const ENEMY_SPRITES = [
	"res://assets/sprites/enemies/scout_drone.png",
	"res://assets/sprites/enemies/assault_droid.png",
	"res://assets/sprites/enemies/kamikaze_drone.png",
	"res://assets/sprites/enemies/spider_bot.png",
	"res://assets/sprites/enemies/heavy_mech.png",
]

var stars: Array[Dictionary] = []
var swarm: Array[Dictionary] = []
var enemy_textures: Array[Texture2D] = []
var time_elapsed: float = 0.0
var ship_base: Vector2

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_btn.pressed.connect(_on_start_pressed)
	cyberdeck_btn.pressed.connect(_on_cyberdeck_pressed)
	info_btn.pressed.connect(_on_info_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)
	close_info_btn.pressed.connect(func(): info_dialog.visible = false)
	music_btn.pressed.connect(_on_toggle_music)
	sfx_btn.pressed.connect(_on_toggle_sfx)
	for b in [start_btn, cyberdeck_btn, info_btn, credits_btn, music_btn, sfx_btn, close_info_btn]:
		b.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.05, -8.0))
	info_dialog.visible = false
	_build_cyberdeck_dialog()
	ship_base = ship.position

	_sync_audio_icons()
	init_space_fx()
	AudioManager.play_music()
	start_btn.grab_focus()

func init_space_fx() -> void:
	for p in ENEMY_SPRITES:
		if ResourceLoader.exists(p):
			enemy_textures.append(load(p))
	for i in range(110):
		stars.append({
			"pos": Vector2(randf_range(0, 1280), randf_range(0, 720)),
			"speed": randf_range(20.0, 90.0),
			"size": randf_range(1.0, 2.4),
			"alpha": randf_range(0.25, 0.8),
		})
	for i in range(14):
		swarm.append(_new_swarm_unit(true))

func _new_swarm_unit(anywhere: bool) -> Dictionary:
	return {
		"pos": Vector2(randf_range(560, 1300), randf_range(-60, 760) if anywhere else -80.0),
		"speed": randf_range(30.0, 70.0),
		"scale": randf_range(0.35, 0.7),
		"tex": enemy_textures.pick_random() if enemy_textures.size() > 0 else null,
	}

func _process(delta: float) -> void:
	time_elapsed += delta
	for s in stars:
		s["pos"].y += s["speed"] * delta
		if s["pos"].y > 720.0:
			s["pos"] = Vector2(randf_range(0, 1280), 0.0)
	for i in swarm.size():
		swarm[i]["pos"].y += swarm[i]["speed"] * delta
		if swarm[i]["pos"].y > 780.0:
			swarm[i] = _new_swarm_unit(false)
	ship.position = ship_base + Vector2(sin(time_elapsed * 0.9) * 10.0, sin(time_elapsed * 1.7) * 8.0)
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	var Y = CyberPalette.YELLOW

	# 1. Void
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.035))

	# 2. Stars streaking downward (ship flies "up")
	for s in stars:
		var a = s["alpha"]
		draw_line(s["pos"], s["pos"] - Vector2(0, s["speed"] * 0.08), Color(0.8, 0.9, 1.0, a * 0.6), s["size"])

	# 3. Perspective grid floor
	var horizon = h * 0.62
	var grid_col = Color(CyberPalette.CYAN, 0.12)
	for i in range(-12, 13):
		var x0 = w * 0.62 + float(i) * 34.0
		var x1 = w * 0.62 + float(i) * 260.0
		draw_line(Vector2(x0, horizon), Vector2(x1, h), grid_col, 1.0)
	var scroll = fmod(time_elapsed * 0.35, 1.0)
	for j in range(12):
		var t = (float(j) + scroll) / 12.0
		var y = horizon + (h - horizon) * t * t
		draw_line(Vector2(0, y), Vector2(w, y), Color(CyberPalette.CYAN, 0.04 + 0.12 * t), 1.0)
	draw_rect(Rect2(0, horizon - 1, w, 2), Color(CyberPalette.RED, 0.35))

	# 4. Hostile swarm silhouettes (red-tinted, behind the ship)
	for e in swarm:
		if e["tex"]:
			var tex: Texture2D = e["tex"]
			var sz = tex.get_size() * e["scale"]
			draw_texture_rect(tex, Rect2(e["pos"] - sz * 0.5, sz), false, Color(1.0, 0.15, 0.3, 0.28))

	# 5. Diagonal hazard slash behind the title
	var slash = PackedVector2Array([Vector2(0, 118), Vector2(700, 118), Vector2(640, 136), Vector2(0, 136)])
	draw_colored_polygon(slash, Color(Y, 0.9))
	for k in range(0, 640, 24):
		draw_colored_polygon(PackedVector2Array([
			Vector2(k, 136), Vector2(k + 12, 136), Vector2(k + 4, 142), Vector2(k - 8, 142)
		]), Color(Y, 0.55))

	# 6. Corner brackets
	var c = Color(Y, 0.6)
	for corner in [Vector2(24, 24), Vector2(w - 24, 24), Vector2(24, h - 24), Vector2(w - 24, h - 24)]:
		var sx = 1.0 if corner.x < w * 0.5 else -1.0
		var sy = 1.0 if corner.y < h * 0.5 else -1.0
		draw_line(corner, corner + Vector2(48 * sx, 0), c, 3.0)
		draw_line(corner, corner + Vector2(0, 48 * sy), c, 3.0)

	# 7. Engine glow under the ship
	var flame = 0.6 + 0.4 * sin(time_elapsed * 22.0)
	var tail = ship.position + Vector2(0, 120).rotated(ship.rotation)
	draw_circle(tail, 40.0 * flame, Color(CyberPalette.CYAN, 0.10))
	draw_circle(tail, 18.0 * flame, Color(CyberPalette.CYAN, 0.25))

func _on_start_pressed() -> void:
	AudioManager.play_sfx("upgrade_select")
	GameManager.start_game()

func _img(icon_name: String, hex: String) -> String:
	return "[img width=30 height=30 color=%s]%s%s.png[/img]" % [hex, CyberPalette.ICON_DIR, icon_name]

func _key(k: String) -> String:
	return "[bgcolor=#fcee0a][color=#05050a][b] %s [/b][/color][/bgcolor]" % k

func _on_info_pressed() -> void:
	AudioManager.play_sfx("laser", 0.1, -4.0)
	dialog_title.text = "КЕРУВАННЯ"
	info_dialog.visible = true
	info_text.text = "%s %s  рух\n\n%s %s  ривок / фазовий зсув\n\n%s %s  модернізація\n\n%s  пауза / закрити\n\n" % [
		_key("W A S D"), _key("СТРІЛКИ"), _key("ПРОБІЛ"), _key("SHIFT"), _key("TAB"), _key("T"), _key("ESC")] + \
		"[color=#8c8fa8]Протримайся 7 хвилин. Збирай брухт, качай модулі, поєднуй їх у синергії:[/color]\n\n" + \
		"%s %s  [color=#ff4dd9]=[/color]  %s          " % [_img("blaster", "#ff003c"), _img("conductor", "#fcee0a"), _img("plasma_storm", "#ff4dd9")] + \
		"%s %s  [color=#ff4dd9]=[/color]  %s\n\n" % [_img("shield", "#00f0ff"), _img("emp", "#fcee0a"), _img("emp_apocalypse", "#ff4dd9")] + \
		"%s %s  [color=#ff4dd9]=[/color]  %s          " % [_img("missiles", "#ff003c"), _img("railgun", "#ff003c"), _img("valkyrie_swarm", "#ff4dd9")] + \
		"%s %s  [color=#ff4dd9]=[/color]  %s\n\n" % [_img("repair", "#00f0ff"), _img("drones", "#ff003c"), _img("nanite_bastion", "#ff4dd9")] + \
		"%s %s  [color=#ff4dd9]=[/color]  %s          " % [_img("virus", "#33ff8c"), _img("emp", "#fcee0a"), _img("black_ice", "#ff4dd9")] + \
		"%s %s  [color=#ff4dd9]=[/color]  %s" % [_img("data_spike", "#33ff8c"), _img("drones", "#ff003c"), _img("ghost_swarm", "#ff4dd9")]

func _on_cyberdeck_pressed() -> void:
	AudioManager.play_sfx("laser", 0.1, -4.0)
	if is_instance_valid(cyberdeck_dialog):
		info_dialog.visible = false
		cyberdeck_dialog.visible = true
		_refresh_cyberdeck_dialog()

func _build_cyberdeck_dialog() -> void:
	cyberdeck_dialog = PanelContainer.new()
	cyberdeck_dialog.theme_type_variation = &"CyberPanel"
	cyberdeck_dialog.anchors_preset = Control.PRESET_CENTER
	cyberdeck_dialog.position = Vector2(230, 60)
	cyberdeck_dialog.custom_minimum_size = Vector2(820, 580)
	cyberdeck_dialog.visible = false
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	
	# Header
	var header = HBoxContainer.new()
	var title = Label.new()
	title.theme_type_variation = &"HeadingLabel"
	title.text = "КІБЕРДЕКА: ПОСТІЙНІ МОДИФІКАЦІЇ"
	header.add_child(title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.text = "✖ ЗАКРИТИ"
	close_btn.pressed.connect(func(): cyberdeck_dialog.visible = false)
	header.add_child(close_btn)
	vbox.add_child(header)
	
	# Nanites balance banner
	var bal_box = HBoxContainer.new()
	nanites_label = Label.new()
	nanites_label.theme_type_variation = &"MonoLabel"
	nanites_label.add_theme_font_size_override("font_size", 18)
	nanites_label.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	bal_box.add_child(nanites_label)
	vbox.add_child(bal_box)
	
	# Upgrades scroll container - strictly disable horizontal scroll
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 420)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	
	upgrades_container = VBoxContainer.new()
	upgrades_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_container.add_theme_constant_override("separation", 10)
	scroll.add_child(upgrades_container)
	vbox.add_child(scroll)
	
	margin.add_child(vbox)
	cyberdeck_dialog.add_child(margin)
	add_child(cyberdeck_dialog)

func _refresh_cyberdeck_dialog() -> void:
	if not is_instance_valid(upgrades_container):
		return
	nanites_label.text = "БАЛАНС НАНІТІВ: %d ⬡  (зберігаються між усіма забігами)" % GameManager.meta_nanites
	for c in upgrades_container.get_children():
		c.queue_free()
		
	for key in GameManager.META_UPGRADE_DEFS.keys():
		var def = GameManager.META_UPGRADE_DEFS[key]
		var lvl = GameManager.get_meta_upgrade_level(key)
		var max_lvl = def["max_lvl"]
		var cost = GameManager.get_meta_upgrade_cost(key)
		var is_max = lvl >= max_lvl
		var can_afford = GameManager.meta_nanites >= cost and not is_max
		
		var card = PanelContainer.new()
		card.theme_type_variation = &"HudPlate"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 16)
		
		# Icon
		var icon_rect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(42, 42)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if ResourceLoader.exists(def["icon"]):
			icon_rect.texture = load(def["icon"])
		icon_rect.self_modulate = Color(1.0, 0.85, 0.2) if is_max else Color(0.2, 0.9, 1.0)
		hbox.add_child(icon_rect)
		
		# Info VBox
		var info_box = VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		# Level pips bar e.g. [■■■□□]
		var pips = ""
		for p in range(max_lvl):
			pips += "■" if p < lvl else "□"
		
		var name_lbl = Label.new()
		name_lbl.theme_type_variation = &"HeadingLabel"
		name_lbl.text = "%s   [%s]  %d/%d" % [def["name"], pips, lvl, max_lvl]
		if is_max:
			name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
			
		var desc_lbl = Label.new()
		desc_lbl.theme_type_variation = &"DimLabel"
		desc_lbl.text = def["desc"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		info_box.add_child(name_lbl)
		info_box.add_child(desc_lbl)
		hbox.add_child(info_box)
		
		# Action Button
		var buy_btn = Button.new()
		buy_btn.custom_minimum_size = Vector2(190, 44)
		if is_max:
			buy_btn.text = "МАКСИМУМ"
			buy_btn.disabled = true
		else:
			buy_btn.text = "КУПИТИ (%d ⬡)" % cost
			buy_btn.disabled = not can_afford
			buy_btn.mouse_entered.connect(func(): AudioManager.play_sfx("ui_hover", 0.05, -8.0))
			buy_btn.pressed.connect(func():
				if GameManager.buy_meta_upgrade(key):
					_refresh_cyberdeck_dialog()
			)
		hbox.add_child(buy_btn)
		
		card.add_child(hbox)
		upgrades_container.add_child(card)

func _on_credits_pressed() -> void:
	AudioManager.play_sfx("laser", 0.1, -4.0)
	dialog_title.text = "АВТОРИ"
	info_dialog.visible = true
	info_text.text = "[b]Графіка[/b]\nKenney — kenney.nl (CC0)\nВибухи: Sinestesia (CC0) · Бос: pzUH (CC0)\n\n" + \
		"[b]Іконки[/b]\ngame-icons.net — Lorc, Delapouite, sbed, guard13007 (CC BY 3.0)\n\n" + \
		"[b]Шрифти[/b]\nTektur, JetBrains Mono (SIL OFL 1.1)\n\n" + \
		"[b]Звук[/b]\nKenney, Juhani Junkala, rubberduck (CC0)\nМузика: Joth — Cyberpunk Moonlight Sonata (CC0)\n\n" + \
		"[b]Рушій[/b]\nGodot Engine (MIT)\n\n" + \
		"[color=#8c8fa8]Навчальний проєкт, НУБіП України. Некомерційне використання.[/color]"

func _sync_audio_icons() -> void:
	music_btn.modulate = Color(1, 1, 1, 0.35) if AudioManager.music_muted else Color.WHITE
	sfx_btn.icon = CyberPalette.icon("sfx_off" if AudioManager.sfx_muted else "sfx_on")

func _on_toggle_music() -> void:
	AudioManager.toggle_music()
	_sync_audio_icons()

func _on_toggle_sfx() -> void:
	AudioManager.toggle_sfx()
	_sync_audio_icons()
