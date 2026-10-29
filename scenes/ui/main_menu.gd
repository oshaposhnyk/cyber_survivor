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

const BOOT_LOGS = [
	"0x001A [BOOT] :: SYSTEM_INITIALIZE_KERNEL_v4.7.2",
	"0x004F [ARCH] :: WASM_COMPATIBILITY_THREADLESS_OK",
	"0x008E [ORBIT] :: CONNECTED_TO_AETHELGARD_CORE",
	"0x011C [ALERT] :: PROTOCOL_ZERO_CORRUPTION_DETECTED",
	"0x017A [SWARM] :: HOSTILE_MECH_SIGNATURES: 1,500+",
	"0x021F [PILOT] :: ARC-01_VANGUARD_INITIALIZING...",
	"0x02FE [ROOT] :: ACCESS_GRANTED // READY_FOR_COMMAND"
]

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
	for i in range(120):
		stars.append({
			"pos": Vector2(randf_range(0, 1280), randf_range(0, 720)),
			"speed": randf_range(10.0, 45.0),
			"size": randf_range(1.0, 2.8),
			"alpha": randf_range(0.3, 0.9),
			"color": Color(0.85, 0.95, 1.0) if randf() < 0.7 else Color(1.0, 0.85, 0.5)
		})
		
	nebulae = [
		{"pos": Vector2(250, 180), "radius": 320.0, "color": Color(0.08, 0.02, 0.18, 0.28)},
		{"pos": Vector2(1000, 520), "radius": 420.0, "color": Color(0.02, 0.08, 0.22, 0.32)},
		{"pos": Vector2(640, 360), "radius": 350.0, "color": Color(0.01, 0.12, 0.16, 0.22)}
	]

func _process(delta: float) -> void:
	time_elapsed += delta
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
		
	# 4. Cyberpunk Tech Brackets
	var cyan_accent = Color(0.1, 0.8, 1.0, 0.45)
	draw_line(Vector2(25, 25), Vector2(90, 25), cyan_accent, 2.0)
	draw_line(Vector2(25, 25), Vector2(25, 90), cyan_accent, 2.0)
	
	draw_line(Vector2(1255, 25), Vector2(1190, 25), cyan_accent, 2.0)
	draw_line(Vector2(1255, 25), Vector2(1255, 90), cyan_accent, 2.0)
	
	draw_line(Vector2(25, 695), Vector2(90, 695), cyan_accent, 2.0)
	draw_line(Vector2(25, 695), Vector2(25, 630), cyan_accent, 2.0)
	
	draw_line(Vector2(1255, 695), Vector2(1190, 695), cyan_accent, 2.0)
	draw_line(Vector2(1255, 695), Vector2(1255, 630), cyan_accent, 2.0)
	
	# 5. Cyberpunk Code Terminal Log Box (Left Side)
	var log_box_rect = Rect2(35, 140, 290, 260)
	draw_rect(log_box_rect, Color(0.02, 0.04, 0.08, 0.7))
	draw_rect(log_box_rect, Color(0.1, 0.6, 0.9, 0.35), false, 1.0)
	
	# Header for terminal log
	var font = ThemeDB.fallback_font
	var font_sz = 10
	draw_string(font, Vector2(45, 160), "// SECURE_SHELL::LOGS", HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color(0.3, 0.9, 1.0, 0.9))
	
	var visible_lines = min(BOOT_LOGS.size(), int(time_elapsed * 2.5) + 1)
	for i in range(visible_lines):
		var y_pos = 185 + i * 26
		draw_string(font, Vector2(45, y_pos), BOOT_LOGS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color(0.4, 0.8, 0.9, 0.75))
		
	# Terminal cursor
	if fmod(time_elapsed * 3.0, 2.0) < 1.0:
		var cur_y = 185 + visible_lines * 26
		if cur_y < 380:
			draw_string(font, Vector2(45, cur_y), "> _", HORIZONTAL_ALIGNMENT_LEFT, -1, font_sz, Color(0.2, 1.0, 0.5))

func _on_start_pressed() -> void:
	AudioManager.play_sfx("upgrade_select")
	GameManager.start_game()

func _on_info_pressed() -> void:
	AudioManager.play_sfx("laser", 0.1, -4.0)
	info_dialog.visible = true
	info_text.text = "[b][color=#33c3ff]КЕРУВАННЯ ТА БОРТОВІ СИСТЕМИ:[/color][/b]\n" + \
		"• [b]W, A, S, D[/b] / [b]Стрілки[/b] — маневрування та форсаж дюз ARC-01\n" + \
		"• [b]ТАВ[/b] / [b]T[/b] — виклик Технологічної Матриці (дерево навичок)\n" + \
		"• [b]ESC[/b] / [b]P[/b] — пауза та меню налаштувань\n\n" + \
		"[b][color=#ffcc33]СУТЬ ГРИ ТА КІБЕРПАНК-ПРОКАЧКА:[/color][/b]\n" + \
		"• Знищуйте тисячні армади заражених автоматонів та збирайте нанітні чіпи.\n" + \
		"• Повне [b]відкрите дерево розвитку[/b] (12 технологій, 3 кібер-шини: Озброєння, Захист, Оверклокінг).\n" + \
		"• Відкривайте [b]СИНЕРГІЇ[/b]:\n" + \
		"  - [color=#00f0ff]Плазмовий Шторм[/color] (ланцюгові блискавки)\n" + \
		"  - [color=#ff00aa]Апокаліптичний EMP[/color] (вибух на весь екран при зламі щита)\n" + \
		"  - [color=#ff8800]Рій Валькірія[/color] (тахіонні пробивальні ракети)\n" + \
		"  - [color=#00ff88]Нанітний Бастіон[/color] (орбітальний бар'єр та потрійна регенерація)!\n" + \
		"• Протримайтеся 7 хвилин під натиском армад ворогів до повної евакуації!"

func _on_credits_pressed() -> void:
	AudioManager.play_sfx("laser", 0.1, -4.0)
	info_dialog.visible = true
	info_text.text = "[b][color=#33ff88]ДЖЕРЕЛА ВІДКРИТИХ РЕСУРСІВ (CC0):[/color][/b]\n\n" + \
		"• [b]Графіка:[/b] Kenney CC0 Assets (Space Shooter Redux, Robot Pack, RTS Sci-Fi) — kenney.nl\n" + \
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
