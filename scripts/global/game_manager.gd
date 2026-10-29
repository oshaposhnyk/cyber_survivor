extends Node

# Global Game Manager - tracks state, progression, skills, synergies, score

signal state_changed(new_state)
signal stats_updated
signal level_up_occurred(new_level, points_available)
signal skill_upgraded(skill_id, new_level)
signal synergy_unlocked(synergy_id, synergy_info)
signal doctrine_changed(branch)
signal player_damaged(current_hp, max_hp, current_shield, max_shield)
signal scrap_picked_up(amount)
signal wave_changed(wave_index, wave_name)
signal game_over_screen(stats)
signal meta_updated()
signal dash_updated(current_cd, max_cd)
signal overdrive_changed(active)

enum State {
	MENU,
	PLAYING,
	SKILL_TREE,
	PAUSED,
	GAME_OVER,
	VICTORY
}

var current_state: State = State.MENU

# Persistent Save Data across runs
const SAVE_PATH := "user://cyber_save.json"
var meta_nanites: int = 0
var meta_upgrades: Dictionary = {
	"hull": 0,      # Max 5: +10 max HP each
	"speed": 0,     # Max 5: +4% speed each
	"magnet": 0,    # Max 5: +15% magnet radius each
	"dash": 0,      # Max 3: -12% dash cooldown each
	"reboot": 0     # Max 1: Emergency Reboot (revive 1 time per run at 50% HP)
}

const META_UPGRADE_DEFS = {
	"hull": {
		"name": "Посилений Каркас",
		"desc": "+10 до базового HP корабля на старті кожного забігу.",
		"max_lvl": 5,
		"base_cost": 60,
		"cost_mult": 1.5,
		"icon": "res://assets/sprites/ui/gi/armor.png"
	},
	"speed": {
		"name": "Іонні Прискорювачі",
		"desc": "+4% до базової швидкості маневрування за рівень.",
		"max_lvl": 5,
		"base_cost": 50,
		"cost_mult": 1.45,
		"icon": "res://assets/sprites/ui/gi/speed.png"
	},
	"magnet": {
		"name": "Граві-Захоплювач",
		"desc": "+15% до стартового радіуса притягання нанітів за рівень.",
		"max_lvl": 5,
		"base_cost": 45,
		"cost_mult": 1.4,
		"icon": "res://assets/sprites/ui/gi/magnet.png"
	},
	"dash": {
		"name": "Фазовий Оверклок",
		"desc": "-12% часу кулдауну тактичного ривка (Dash) за рівень.",
		"max_lvl": 3,
		"base_cost": 90,
		"cost_mult": 1.7,
		"icon": "res://assets/sprites/ui/gi/cooldown.png"
	},
	"reboot": {
		"name": "Аварійний Ребут",
		"desc": "1 раз за забіг при фатальному пошкодженні реактор перезавантажується з 50% HP та випускає захисний EMP-імпульс.",
		"max_lvl": 1,
		"base_cost": 250,
		"cost_mult": 1.0,
		"icon": "res://assets/sprites/ui/gi/emp.png"
	}
}

# Run-specific buff states
var reboot_used: bool = false
var overdrive_timer: float = 0.0

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

# Active doctrine: a SkillData.Branch value, or -1 for none
var active_doctrine: int = -1

# Reference to active player node
var player_node: Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_save()
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
	reboot_used = false
	overdrive_timer = 0.0
	
	skill_levels.clear()
	for skill_id in SkillData.SKILLS.keys():
		skill_levels[skill_id] = 0
	
	# Start with Blaster Level 1
	skill_levels["blaster"] = 1
	
	active_synergies.clear()
	active_doctrine = -1
	current_state = State.MENU

func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json_str = file.get_as_text()
	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		meta_nanites = int(parsed.get("meta_nanites", 0))
		var saved_upgrades = parsed.get("meta_upgrades", {})
		if saved_upgrades is Dictionary:
			for k in saved_upgrades.keys():
				if meta_upgrades.has(k):
					meta_upgrades[k] = int(saved_upgrades[k])
	meta_updated.emit()

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	var data = {
		"meta_nanites": meta_nanites,
		"meta_upgrades": meta_upgrades
	}
	file.store_string(JSON.stringify(data))

func get_meta_upgrade_level(key: String) -> int:
	return meta_upgrades.get(key, 0)

func get_meta_upgrade_cost(key: String) -> int:
	if not META_UPGRADE_DEFS.has(key):
		return 999999
	var def = META_UPGRADE_DEFS[key]
	var lvl = get_meta_upgrade_level(key)
	return int(def["base_cost"] * pow(def["cost_mult"], lvl))

func can_buy_meta_upgrade(key: String) -> bool:
	if not META_UPGRADE_DEFS.has(key):
		return false
	var lvl = get_meta_upgrade_level(key)
	if lvl >= META_UPGRADE_DEFS[key]["max_lvl"]:
		return false
	return meta_nanites >= get_meta_upgrade_cost(key)

func buy_meta_upgrade(key: String) -> bool:
	if not can_buy_meta_upgrade(key):
		return false
	var cost = get_meta_upgrade_cost(key)
	meta_nanites -= cost
	meta_upgrades[key] += 1
	save_game()
	meta_updated.emit()
	AudioManager.play_sfx("upgrade_select")
	return true

func has_reboot_available() -> bool:
	return get_meta_upgrade_level("reboot") > 0 and not reboot_used

func consume_reboot() -> void:
	reboot_used = true

func trigger_overdrive(duration: float = 10.0) -> void:
	overdrive_timer = duration
	overdrive_changed.emit(true)

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
		if overdrive_timer > 0.0:
			overdrive_timer -= delta
			if overdrive_timer <= 0.0:
				overdrive_changed.emit(false)
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
	update_doctrine()
	
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

func branch_points(branch: int) -> int:
	var total = 0
	for skill_id in SkillData.SKILLS.keys():
		if SkillData.SKILLS[skill_id]["branch"] == branch:
			total += get_skill_level(skill_id)
	return total

# A branch takes over only with strictly more points than the current doctrine,
# so a tie never flips the play style back and forth.
func update_doctrine() -> void:
	var best = active_doctrine
	var best_pts = branch_points(active_doctrine) if active_doctrine >= 0 else SkillData.DOCTRINE_MIN_POINTS - 1
	for branch in SkillData.DOCTRINES.keys():
		var pts = branch_points(branch)
		if pts > best_pts:
			best = branch
			best_pts = pts
	if best != active_doctrine:
		active_doctrine = best
		doctrine_changed.emit(best)

func doctrine_mod(key: String, default: float = 1.0) -> float:
	if active_doctrine < 0:
		return default
	return SkillData.DOCTRINES[active_doctrine]["mods"].get(key, default)

func trigger_game_over(victory: bool = false) -> void:
	if current_state == State.GAME_OVER or current_state == State.VICTORY:
		return
	set_state(State.VICTORY if victory else State.GAME_OVER)
	if victory:
		AudioManager.play_sfx("victory")
	else:
		AudioManager.play_sfx("game_over")
		
	# Accumulate into persistent meta nanite bank
	var earned = scrap_collected
	meta_nanites += earned
	save_game()
	meta_updated.emit()
		
	var final_stats = {
		"victory": victory,
		"time": time_survived,
		"kills": enemies_killed,
		"scrap": scrap_collected,
		"level": player_level,
		"synergies": active_synergies.duplicate(),
		"meta_nanites": meta_nanites,
		"earned_nanites": earned
	}
	game_over_screen.emit(final_stats)
