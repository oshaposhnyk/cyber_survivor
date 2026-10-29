extends Control

@onready var start_btn: Button = $VBoxContainer/StartBtn
@onready var info_btn: Button = $VBoxContainer/InfoBtn
@onready var credits_btn: Button = $VBoxContainer/CreditsBtn
@onready var music_btn: Button = $TopControls/MusicBtn
@onready var sfx_btn: Button = $TopControls/SFXBtn
@onready var info_dialog: PanelContainer = $InfoDialog
@onready var close_info_btn: Button = $InfoDialog/Margin/VBox/CloseInfoBtn
@onready var info_text: RichTextLabel = $InfoDialog/Margin/VBox/InfoText

var stars: Array[Dictionary] = []
var nebulae: Array[Dictionary] = []
var time_elapsed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_btn.pressed.connect(_on_start_pressed)
	info_btn.pressed.connect(_on_info_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)
	close_info_btn.pressed.connect(func(): info_dialog.visible = false)
	music_btn.pressed.connect(_on_toggle_music)
	sfx_btn.pressed.connect(_on_toggle_sfx)
	info_dialog.visible = false
	
	init_space_fx()
	AudioManager.play_music()

func init_space_fx() -> void:
	# Menu Stars
	for i in range(120):
		stars.append({
			"pos": Vector2(randf_range(0, 1280), randf_range(0, 720)),
			"speed": randf_range(10.0, 40.0),
			"size": randf_range(1.0, 2.8),
			"alpha": randf_range(0.3, 0.9),
			"color": Color(0.85, 0.95, 1.0) if randf() < 0.7 else Color(1.0, 0.85, 0.5)
		})
		
	# Menu Nebulae
	nebulae = [
		{"pos": Vector2(250, 180), "radius": 320.0, "color": Color(0.08, 0.02, 0.18, 0.28)},
		{"pos": Vector2(1000, 520), "radius": 420.0, "color": Color(0.02, 0.08, 0.22, 0.32)},
		{"pos": Vector2(640, 360), "radius": 350.0, "color": Color(0.01, 0.12, 0.16, 0.22)}
	]

func _process(delta: float) -> void:
	time_elapsed += delta
	# Move stars downwards/left for drift
	for s in stars:
		s["pos"].y += s["speed"] * delta
		s["pos"].x -= (s["speed"] * 0.3) * delta
		if s["pos"].y > 720.0:
			s["pos"].y = 0.0
			s["pos"].x = randf_range(0, 1280)
		if s["pos"].x < 0.0:
			s["pos"].x = 1280.0
	queue_redraw()

func _draw() -> void:
	# 1. Background Void
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.012, 0.016, 0.032))
	
	# 2. Glowing Nebulae
	for neb in nebulae:
		var p = neb["pos"] + Vector2(sin(time_elapsed * 0.5) * 20.0, cos(time_elapsed * 0.4) * 15.0)
		var c: Color = neb["color"]
		var r = neb["radius"]
		draw_circle(p, r, Color(c.r, c.g, c.b, c.a * 0.4))
		draw_circle(p, r * 0.6, Color(c.r, c.g, c.b, c.a * 0.7))
		
	# 3. Drifting Stars
	for s in stars:
		var pulse = 0.7 + 0.3 * sin(time_elapsed * 3.0 + s["pos"].x)
		var c: Color = s["color"]
		draw_circle(s["pos"], s["size"], Color(c.r, c.g, c.b, s["alpha"] * pulse))
		
	# 4. Sci-Fi Tech Corner Brackets
	var cyan_accent = Color(0.1, 0.8, 1.0, 0.4)
	draw_line(Vector2(20, 20), Vector2(80, 20), cyan_accent, 2.0)
	draw_line(Vector2(20, 20), Vector2(20, 80), cyan_accent, 2.0)
	
	draw_line(Vector2(1260, 20), Vector2(1200, 20), cyan_accent, 2.0)
	draw_line(Vector2(1260, 20), Vector2(1260, 80), cyan_accent, 2.0)
	
	draw_line(Vector2(20, 700), Vector2(80, 700), cyan_accent, 2.0)
	draw_line(Vector2(20, 700), Vector2(20, 640), cyan_accent, 2.0)
	
	draw_line(Vector2(1260, 700), Vector2(1200, 700), cyan_accent, 2.0)
	draw_line(Vector2(1260, 700), Vector2(1260, 640), cyan_accent, 2.0)

func _on_start_pressed() -> void:
	AudioManager.play_sfx("upgrade_select")
	GameManager.start_game()

func _on_info_pressed() -> void:
	AudioManager.play_sfx("laser", 0.1, -4.0)
	info_dialog.visible = true
	info_text.text = "[b][color=#33c3ff]КЕРУВАННЯ:[/color][/b]\n" + \
		"• [b]W, A, S, D[/b] або [b]Стрілки[/b] — пересування андроїда ARC-01\n" + \
		"• [b]ТАВ[/b] або [b]T[/b] — відкрити/закрити Технологічну Матрицю (дерево скілів)\n" + \
		"• [b]ESC[/b] або [b]P[/b] — пауза\n\n" + \
		"[b][color=#ffcc33]СУТЬ ГРИ ТА СИСТЕМА ПРОКАЧКИ:[/color][/b]\n" + \
		"• Знищуйте хвилі ворожих роботів та збирайте сині/золоті нанітні ядра.\n" + \
		"• На відміну від випадкових карток, ви маєте [b]повне відкрите дерево розвитку[/b]!\n" + \
		"• Розвивайте 3 гілки: Озброєння, Захисні системи, Оверклокінг.\n" + \
		"• Відкривайте [b]СИНЕРГІЇ[/b] (Плазмовий Шторм, Апокаліптичний EMP, Рій Валькірія, Нанітний Бастіон) при виборі взаємодоповнюючих скілів!\n" + \
		"• Протримайтеся 7 хвилин у глибинах орбітальної станції, знищивши босів-мехів!"

func _on_credits_pressed() -> void:
	AudioManager.play_sfx("laser", 0.1, -4.0)
	info_dialog.visible = true
	info_text.text = "[b][color=#33ff88]ДЖЕРЕЛА ВІДКРИТИХ РЕСУРСІВ (CC0):[/color][/b]\n\n" + \
		"• [b]Графіка:[/b] Kenney CC0 Assets (Robot Pack, Space Shooter Redux, RTS Sci-Fi Pack) — kenney.nl\n" + \
		"• [b]Шрифт:[/b] Kenney Future (CC0 Public Domain)\n" + \
		"• [b]Звукові ефекти:[/b] Kenney Digital Audio & Impact Sounds (CC0 1.0 Universal)\n" + \
		"• [b]Саундтрек:[/b] Синтезований кіберпанк-мотив D-minor (CC0 Public Domain)\n" + \
		"• [b]Рушій:[/b] Godot Engine 4.7.2 (MIT License)\n\n" + \
		"[color=#aaaaaa]Навчальний проект для НУБіП України. Всі ассети 100% безкоштовні та відкриті для некомерційного використання.[/color]"

func _on_toggle_music() -> void:
	var on = AudioManager.toggle_music()
	music_btn.text = "🎵 Музика: " + ("Увімк" if on else "Вимк")

func _on_toggle_sfx() -> void:
	var on = AudioManager.toggle_sfx()
	sfx_btn.text = "🔊 Звуки: " + ("Увімк" if on else "Вимк")
