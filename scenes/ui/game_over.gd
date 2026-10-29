extends CanvasLayer

@onready var title_label: Label = $Panel/Margin/VBox/TitleLabel
@onready var time_stat: Label = $Panel/Margin/VBox/StatsGrid/TimeVal
@onready var kills_stat: Label = $Panel/Margin/VBox/StatsGrid/KillsVal
@onready var scrap_stat: Label = $Panel/Margin/VBox/StatsGrid/ScrapVal
@onready var level_stat: Label = $Panel/Margin/VBox/StatsGrid/LevelVal
@onready var synergies_stat: Label = $Panel/Margin/VBox/StatsGrid/SynergiesVal
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
	
	if is_victory:
		title_label.text = "🏆 МІСІЯ УСПІШНА! СЕКТОР ЗАЧИЩЕНО!"
		title_label.modulate = Color(0.2, 1.0, 0.5)
	else:
		title_label.text = "💀 СИСТЕМНИЙ ЗБІЙ: КОРПУС ЗНИЩЕНО"
		title_label.modulate = Color(1.0, 0.3, 0.3)
		
	var total_sec = int(stats.get("time", 0.0))
	var mins = floori(float(total_sec) / 60.0)
	var secs = total_sec % 60
	time_stat.text = "%02d:%02d" % [mins, secs]
	kills_stat.text = str(stats.get("kills", 0))
	scrap_stat.text = str(stats.get("scrap", 0))
	level_stat.text = str(stats.get("level", 1))
	
	var syns: Array = stats.get("synergies", [])
	if syns.size() > 0:
		var syn_names: Array[String] = []
		for sid in syns:
			if SkillData.SYNERGIES.has(sid):
				syn_names.append(SkillData.SYNERGIES[sid]["name"])
		synergies_stat.text = "\n".join(syn_names)
	else:
		synergies_stat.text = "Не активовано"

func _on_retry_pressed() -> void:
	visible = false
	GameManager.start_game()

func _on_menu_pressed() -> void:
	visible = false
	GameManager.reset_run()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
