extends Node

# Global Game Manager - tracks state, progression, skills, synergies, score

signal state_changed(new_state)
signal stats_updated
signal level_up_occurred(new_level, points_available)
signal skill_upgraded(skill_id, new_level)
signal synergy_unlocked(synergy_id, synergy_info)
signal player_damaged(current_hp, max_hp, current_shield, max_shield)
signal scrap_picked_up(amount)
signal wave_changed(wave_index, wave_name)
signal game_over_screen(stats)

enum State {
	MENU,
	PLAYING,
	SKILL_TREE,
	PAUSED,
	GAME_OVER,
	VICTORY
}

var current_state: State = State.MENU

# Run Statistics
var time_survived: float = 0.0
var enemies_killed: int = 0
var scrap_collected: int = 0
var current_wave: int = 1

# Progression
var player_level: int = 1
var current_xp: int = 0
var xp_needed: int = 10
var available_skill_points: int = 1 # Start with 1 skill point to select first weapon/upgrade

# Skill levels: { "blaster": 1, "missiles": 0, ... }
var skill_levels: Dictionary = {}

# Active Synergies: Array of synergy_id strings
var active_synergies: Array[String] = []

# Reference to active player node
var player_node: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_run()

func reset_run() -> void:
	time_survived = 0.0
	enemies_killed = 0
	scrap_collected = 0
	current_wave = 1
	player_level = 1
	current_xp = 0
	xp_needed = 12
	available_skill_points = 1
	
	skill_levels.clear()
	for skill_id in SkillData.SKILLS.keys():
		skill_levels[skill_id] = 0
	
	# Start with Blaster Level 1
	skill_levels["blaster"] = 1
	
	active_synergies.clear()
	current_state = State.MENU

func start_game() -> void:
	reset_run()
	set_state(State.PLAYING)
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")

func set_state(new_state: State) -> void:
	current_state = new_state
	match current_state:
		State.PLAYING:
			get_tree().paused = false
		State.SKILL_TREE, State.PAUSED:
			get_tree().paused = true
		State.GAME_OVER, State.VICTORY:
			get_tree().paused = true
		State.MENU:
			get_tree().paused = false
	state_changed.emit(new_state)

func add_time(delta: float) -> void:
	if current_state == State.PLAYING:
		time_survived += delta
		stats_updated.emit()

func add_kill() -> void:
	enemies_killed += 1
	stats_updated.emit()

func add_scrap(amount: int = 1) -> void:
	scrap_collected += amount
	current_xp += amount * 3
	scrap_picked_up.emit(amount)
	
	while current_xp >= xp_needed:
		current_xp -= xp_needed
		player_level += 1
		available_skill_points += 1
		xp_needed = int(xp_needed * 1.35) + 5
		AudioManager.play_sfx("level_up")
		level_up_occurred.emit(player_level, available_skill_points)
	
	stats_updated.emit()

func get_skill_level(skill_id: String) -> int:
	return skill_levels.get(skill_id, 0)

func can_upgrade_skill(skill_id: String) -> bool:
	if available_skill_points <= 0:
		return false
	if not SkillData.SKILLS.has(skill_id):
		return false
	
	var skill = SkillData.SKILLS[skill_id]
	var current_lvl = get_skill_level(skill_id)
	
	if current_lvl >= skill["max_lvl"]:
		return false
		
	var prereq = skill["prereq"]
	if prereq != "":
		var prereq_lvl = skill["prereq_lvl"]
		if get_skill_level(prereq) < prereq_lvl:
			return false
			
	return true

func upgrade_skill(skill_id: String) -> bool:
	if not can_upgrade_skill(skill_id):
		return false
		
	available_skill_points -= 1
	skill_levels[skill_id] += 1
	AudioManager.play_sfx("upgrade_select")
	skill_upgraded.emit(skill_id, skill_levels[skill_id])
	stats_updated.emit()
	
	check_synergies()
	
	if player_node and player_node.has_method("apply_upgrades"):
		player_node.apply_upgrades()
		
	return true

func check_synergies() -> void:
	for syn_id in SkillData.SYNERGIES.keys():
		if syn_id in active_synergies:
			continue
		var syn = SkillData.SYNERGIES[syn_id]
		var reqs: Dictionary = syn["req"]
		var satisfied: bool = true
		for req_skill in reqs.keys():
			if get_skill_level(req_skill) < reqs[req_skill]:
				satisfied = false
				break
		if satisfied:
			active_synergies.append(syn_id)
			AudioManager.play_sfx("emp_blast")
			synergy_unlocked.emit(syn_id, syn)

func is_synergy_active(syn_id: String) -> bool:
	return syn_id in active_synergies

func trigger_game_over(victory: bool = false) -> void:
	if current_state == State.GAME_OVER or current_state == State.VICTORY:
		return
	set_state(State.VICTORY if victory else State.GAME_OVER)
	if victory:
		AudioManager.play_sfx("victory")
	else:
		AudioManager.play_sfx("game_over")
		
	var final_stats = {
		"victory": victory,
		"time": time_survived,
		"kills": enemies_killed,
		"scrap": scrap_collected,
		"level": player_level,
		"synergies": active_synergies.duplicate()
	}
	game_over_screen.emit(final_stats)
