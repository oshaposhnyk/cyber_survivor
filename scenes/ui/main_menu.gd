extends Control

@onready var start_btn: Button = $VBoxContainer/StartBtn
@onready var info_btn: Button = $VBoxContainer/InfoBtn
@onready var credits_btn: Button = $VBoxContainer/CreditsBtn
@onready var music_btn: Button = $TopControls/MusicBtn
@onready var sfx_btn: Button = $TopControls/SFXBtn
@onready var info_dialog: PanelContainer = $InfoDialog
@onready var close_info_btn: Button = $InfoDialog/Margin/VBox/CloseInfoBtn
@onready var info_text: RichTextLabel = $InfoDialog/Margin/VBox/InfoText

var star_layers: Array[Node2D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_btn.pressed.connect(_on_start_pressed)
	info_btn.pressed.connect(_on_info_pressed)
	credits_btn.pressed.connect(_on_credits_pressed)
	close_info_btn.pressed.connect(func(): info_dialog.visible = false)
	music_btn.pressed.connect(_on_toggle_music)
	sfx_btn.pressed.connect(_on_toggle_sfx)
	info_dialog.visible = false
	
	AudioManager.play_music()

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
