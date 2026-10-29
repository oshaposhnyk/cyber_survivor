extends CharacterBody2D
class_name EnemyBase

@export var max_health: float = 30.0
@export var move_speed: float = 130.0
@export var contact_damage: float = 10.0
@export var scrap_count: int = 1
@export var gold_chance: float = 0.06
@export var repair_chance: float = 0.03
@export var score_points: int = 10

# Shared caps so huge hordes do not flood the scene tree with short-lived FX nodes
const MAX_DAMAGE_TEXTS := 24
const MAX_EXPLOSIONS := 36
const MAX_PICKUPS := 160
const FX_RANGE_SQ := 1000.0 * 1000.0
const CONTACT_RANGE_SQ := 40.0 * 40.0
const WRAP_DIST_SQ := 2100.0 * 2100.0
# Fake top light: shadow cast down-right in world space
const SHADOW_OFFSET := Vector2(10.0, 16.0)

static var damage_text_count: int = 0
static var explosion_count: int = 0
static var pickup_count: int = 0
static var spike_count: int = 0
const MAX_SPIKES := 14
const VIRUS_TINT := Color(0.55, 1.0, 0.65)

var current_health: float = 30.0
var knockback: Vector2 = Vector2.ZERO
var stun_timer: float = 0.0
var is_dead: bool = false
var target_player: Node2D = null
var hit_flash: float = 0.0
var shadow: Sprite2D = null

# Hacking branch status effects
var infected_time: float = 0.0
var infect_dps: float = 0.0
var infect_tick: float = 0.0
var slow_time: float = 0.0
var slow_mult: float = 1.0

# Shield bearer dome: cuts direct hits only. DoT (virus, glitch field) bypasses it,
# so the HACK branch is the natural answer to shielded packs.
var ward_time: float = 0.0
var ward_mult: float = 1.0

# Elite Champion Variant System
enum ChampionType { NONE, HASTE, JAMMER, MENDER }
var champion_type: ChampionType = ChampionType.NONE
var is_champion: bool = false
var champion_aura_timer: float = 0.0
var champion_pulse_time: float = 0.0

# Swarm natural dispersal angle so enemies naturally envelop the player
var swarm_angle_offset: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _enter_tree() -> void:
	EnemyRegistry.register(self)

func _exit_tree() -> void:
	EnemyRegistry.unregister(self)

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2 # Layer 2: Enemies (hit by player weapons)
	collision_mask = 0  # Enemies never run physics movement; contact is a distance check
	current_health = max_health
	swarm_angle_offset = randf_range(-0.35, 0.35)
	_add_shadow()
	find_player()

func _add_shadow() -> void:
	if not sprite:
		return
	shadow = Sprite2D.new()
	shadow.texture = sprite.texture
	shadow.scale = sprite.scale * 0.95
	shadow.modulate = Color(0, 0, 0, 0.45)
	add_child(shadow)
	move_child(shadow, 0) # drawn before the body sprite

func find_player() -> void:
	target_player = GameManager.player_node if is_instance_valid(GameManager.player_node) else null
	if target_player == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]

# Direct integration instead of move_and_slide(): enemies do not collide with each
# other or walls, so a kinematic solve per enemy per frame was pure overhead.
func step_motion(delta: float) -> void:
	global_position += velocity * delta * (slow_mult if slow_time > 0.0 else 1.0)
	if shadow:
		shadow.position = SHADOW_OFFSET.rotated(-rotation)

# Returns false when the enemy was wrapped back near the player this frame.
func keep_near_player(to_player: Vector2) -> bool:
	if to_player.length_squared() > WRAP_DIST_SQ:
		var wrap_angle = randf() * TAU
		global_position = target_player.global_position + Vector2(cos(wrap_angle), sin(wrap_angle)) * randf_range(950.0, 1150.0)
		return false
	return true

func apply_contact(to_player: Vector2, delta: float) -> void:
	if to_player.length_squared() <= CONTACT_RANGE_SQ and target_player.has_method("take_damage"):
		target_player.take_damage(contact_damage * delta * 2.8, global_position)
		# Tank doctrine: hull spikes burn whatever rams the ship
		var thorns: float = target_player.get("thorns_dps")
		if thorns > 0.0:
			apply_dot(thorns * delta)

# Per-frame status: hit flash, slow and virus damage-over-time
func update_status(delta: float) -> void:
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0 and sprite:
			sprite.modulate = Color.WHITE
	if slow_time > 0.0:
		slow_time -= delta
	if ward_time > 0.0:
		ward_time -= delta
	if infected_time > 0.0:
		infected_time -= delta
		infect_tick -= delta
		if infect_tick <= 0.0:
			infect_tick = 0.5
			apply_dot(infect_dps * 0.5)
		if infected_time <= 0.0 and sprite:
			sprite.self_modulate = Color.WHITE

func infect(duration: float, dps: float) -> void:
	if is_dead:
		return
	infected_time = max(infected_time, duration)
	infect_dps = max(infect_dps, dps)
	if sprite:
		sprite.self_modulate = VIRUS_TINT

func apply_ward(duration: float, mult: float) -> void:
	ward_time = max(ward_time, duration)
	ward_mult = mult

func apply_slow(duration: float, mult: float) -> void:
	slow_time = max(slow_time, duration)
	slow_mult = mult

# Damage without knockback, flash or floating text (DoT and fields)
func apply_dot(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	if current_health <= 0.0:
		die()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	update_status(delta)

	if is_champion:
		champion_pulse_time += delta * 4.0
		champion_aura_timer -= delta
		if champion_aura_timer <= 0.0:
			champion_aura_timer = 0.6
			apply_champion_aura()
		queue_redraw()

	# Handle EMP Stun
	if stun_timer > 0.0:
		stun_timer -= delta
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 600.0 * delta)
		step_motion(delta)
		modulate = Color(0.4, 0.8, 1.0) if fmod(stun_timer, 0.2) < 0.1 else Color.WHITE
		if stun_timer <= 0.0:
			modulate = Color.WHITE
		return

	if not is_instance_valid(target_player):
		find_player()
		return

	var to_player = target_player.global_position - global_position
	if not keep_near_player(to_player):
		return

	# Move toward player with slight swarm angle offset for natural surrounding behaviour
	var move_dir = to_player.normalized().rotated(swarm_angle_offset)
	rotation = to_player.angle() + PI / 2.0

	velocity = move_dir * move_speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	step_motion(delta)
	apply_contact(to_player, delta)

func make_champion(p_type: ChampionType = ChampionType.NONE) -> void:
	is_champion = true
	if p_type == ChampionType.NONE:
		var types = [ChampionType.HASTE, ChampionType.JAMMER, ChampionType.MENDER]
		champion_type = types.pick_random()
	else:
		champion_type = p_type
		
	max_health *= 3.5
	current_health = max_health
	contact_damage *= 1.4
	score_points *= 4
	scrap_count += 3
	gold_chance = 0.6
	
	if sprite:
		sprite.scale *= 1.35
	if shadow:
		shadow.scale *= 1.35
	queue_redraw()

func apply_champion_aura() -> void:
	match champion_type:
		ChampionType.HASTE:
			for e in EnemyRegistry.in_radius(global_position, 220.0):
				if e != self and is_instance_valid(e) and e.has_method("apply_slow"):
					e.apply_slow(0.8, 1.45)
		ChampionType.JAMMER:
			# Jamming pulse effect
			pass
		ChampionType.MENDER:
			for e in EnemyRegistry.in_radius(global_position, 200.0):
				if e != self and is_instance_valid(e) and "current_health" in e and "max_health" in e:
					if e.current_health < e.max_health:
						e.current_health = min(e.max_health, e.current_health + e.max_health * 0.08)

func _draw() -> void:
	if not is_champion:
		return
	var pulse = (sin(champion_pulse_time * 1.5) + 1.0) * 0.5
	var aura_col = Color(1.0, 0.8, 0.15)
	var type_label = "HASTE"
	match champion_type:
		ChampionType.HASTE:
			aura_col = Color(1.0, 0.82, 0.15)
			type_label = "HASTE"
		ChampionType.JAMMER:
			aura_col = Color(0.92, 0.25, 1.0)
			type_label = "JAMMER"
			if randf() < 0.3 and sprite:
				sprite.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		ChampionType.MENDER:
			aura_col = Color(0.2, 1.0, 0.55)
			type_label = "REPAIR"
			
	var r_outer = 44.0 + pulse * 6.0
	var r_inner = 30.0
	
	# 1. Outer Tech Ring with rotating notches
	var rot_speed = champion_pulse_time * 0.8
	draw_arc(Vector2.ZERO, r_outer, 0, TAU, 32, Color(aura_col.r, aura_col.g, aura_col.b, 0.55), 2.0)
	draw_circle(Vector2.ZERO, r_outer, Color(aura_col.r, aura_col.g, aura_col.b, 0.05))
	for i in range(8):
		var a = rot_speed + float(i) * (TAU / 8.0)
		var p1 = Vector2(cos(a), sin(a)) * (r_outer - 5.0)
		var p2 = Vector2(cos(a), sin(a)) * (r_outer + 5.0)
		draw_line(p1, p2, aura_col, 2.0)
		
	# 2. Inner Counter-Rotating Dashed Ring
	for i in range(6):
		var a0 = -rot_speed * 1.2 + float(i) * (TAU / 6.0)
		draw_arc(Vector2.ZERO, r_inner, a0, a0 + 0.5, 8, Color(aura_col.r, aura_col.g, aura_col.b, 0.7), 1.5)
		
	# 3. Type-Specific Special VFX
	match champion_type:
		ChampionType.HASTE:
			# Orbiting speed sparks
			for i in range(3):
				var sa = rot_speed * 2.5 + float(i) * (TAU / 3.0)
				var sp_pos = Vector2(cos(sa), sin(sa)) * (r_outer + 8.0)
				draw_circle(sp_pos, 2.5, Color.WHITE)
				draw_line(sp_pos, sp_pos - Vector2(-sin(sa), cos(sa)) * 14.0, aura_col, 1.8)
		ChampionType.JAMMER:
			# Flickering EMP static arcs
			if randf() < 0.6:
				var a1 = randf() * TAU
				var a2 = a1 + randf_range(0.8, 1.8)
				var arc_p1 = Vector2(cos(a1), sin(a1)) * r_inner
				var arc_p2 = Vector2(cos(a2), sin(a2)) * r_inner
				var arc_mid = (arc_p1 + arc_p2) * 0.5 + Vector2(randf_range(-10, 10), randf_range(-10, 10))
				draw_line(arc_p1, arc_mid, Color(1.0, 0.4, 1.0, 0.9), 1.8)
				draw_line(arc_mid, arc_p2, Color.WHITE, 1.8)
		ChampionType.MENDER:
			# Floating emerald healing crosses
			for i in range(3):
				var cross_y = -18.0 - fmod(champion_pulse_time * 16.0 + float(i) * 12.0, 28.0)
				var cross_x = sin(champion_pulse_time + float(i) * 2.0) * 20.0
				var cp = Vector2(cross_x, cross_y)
				draw_line(cp + Vector2(-3, 0), cp + Vector2(3, 0), aura_col, 1.8)
				draw_line(cp + Vector2(0, -3), cp + Vector2(0, 3), aura_col, 1.8)

	# 4. Floating Crown Bracket & Mini Health Bar above the enemy
	var top_y = -38.0
	draw_line(Vector2(-16, top_y), Vector2(-6, top_y - 6), aura_col, 2.0)
	draw_line(Vector2(-6, top_y - 6), Vector2(6, top_y - 6), aura_col, 2.0)
	draw_line(Vector2(6, top_y - 6), Vector2(16, top_y), aura_col, 2.0)
	draw_circle(Vector2(0, top_y - 6), 2.5, Color.WHITE)
	
	# Mini health bar
	var bar_w = 42.0
	var bar_h = 4.0
	var bar_y = top_y - 12.0
	var hp_frac = clampf(current_health / max(1.0, max_health), 0.0, 1.0)
	draw_rect(Rect2(-bar_w * 0.5 - 1.0, bar_y - 1.0, bar_w + 2.0, bar_h + 2.0), Color(0.05, 0.05, 0.1, 0.85), true)
	draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * hp_frac, bar_h), aura_col, true)
	draw_rect(Rect2(-bar_w * 0.5 - 1.0, bar_y - 1.0, bar_w + 2.0, bar_h + 2.0), Color(1, 1, 1, 0.4), false, 1.0)

func apply_stun(duration: float) -> void:
	stun_timer = max(stun_timer, duration)

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return

	if ward_time > 0.0:
		amount *= ward_mult
	current_health -= amount
	knockback = knockback_dir * 160.0

	spawn_damage_text(amount)
	flash_hit()

	if current_health <= 0:
		die()

func flash_hit() -> void:
	# Timer-driven flash: no Tween allocation per hit
	if sprite:
		sprite.modulate = Color(3.0, 0.4, 0.4)
		hit_flash = 0.1

func _near_player() -> bool:
	return is_instance_valid(target_player) and global_position.distance_squared_to(target_player.global_position) < FX_RANGE_SQ

func spawn_damage_text(amount: float) -> void:
	var is_crit = amount >= 45.0
	if damage_text_count >= MAX_DAMAGE_TEXTS or not _near_player():
		return
	if not is_crit and randf() > 0.35:
		return
	var ft = preload("res://scenes/effects/floating_text.tscn").instantiate()
	ft.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-14, -4))
	damage_text_count += 1
	ft.tree_exited.connect(func(): EnemyBase.damage_text_count -= 1)
	get_parent().add_child(ft)
	ft.setup(str(int(amount)), Color(1.0, 0.93, 0.04) if is_crit else Color.WHITE, 1.3 if is_crit else 0.95)

static func spawn_explosion(parent: Node, pos: Vector2, radius: float, color: Color = Color(1.0, 0.5, 0.1), force: bool = false) -> void:
	if explosion_count >= MAX_EXPLOSIONS and not force:
		return
	var exp_node = preload("res://scenes/effects/explosion.tscn").instantiate()
	exp_node.global_position = pos
	exp_node.max_radius = radius
	exp_node.blast_color = color
	explosion_count += 1
	exp_node.tree_exited.connect(func(): EnemyBase.explosion_count -= 1)
	parent.add_child(exp_node)

func die() -> void:
	if is_dead:
		return
	is_dead = true

	if _near_player():
		spawn_explosion(get_parent(), global_position, 26.0)
		# Audio throttle during massive waves
		if randf() < 0.25:
			AudioManager.play_sfx("explosion", 0.3, -3.0)

	GameManager.add_kill()
	on_death_hacks()
	drop_loot()
	queue_free()

# Hacking branch death effects: virus spread, botnet pulse, intercepted missile
func on_death_hacks() -> void:
	var parent = get_parent()
	if infected_time > 0.0:
		for e in EnemyRegistry.nearest(global_position, 2, 170.0, [self]):
			if e.has_method("infect"):
				e.infect(4.0, infect_dps)
		var botnet = GameManager.get_skill_level("botnet")
		if botnet > 0:
			var r = 90.0 * (1.0 + 0.25 * (botnet - 1))
			for e in EnemyRegistry.in_radius(global_position, r):
				if e != self and e.has_method("apply_dot"):
					e.apply_stun(0.6 + 0.5 * botnet)
					e.apply_dot(10.0 + 10.0 * botnet)
			spawn_explosion(parent, global_position, r * 0.6, Color(0.2, 1.0, 0.55))
	var spike_lvl = GameManager.get_skill_level("data_spike")
	if spike_lvl > 0 and spike_count < MAX_SPIKES:
		var ghost = GameManager.is_synergy_active("ghost_swarm")
		var chance = 0.06 * spike_lvl * (2.0 if ghost else 1.0)
		if randf() < chance:
			var m = preload("res://scenes/weapons/missile.tscn").instantiate()
			m.setup(global_position, Vector2.UP.rotated(randf() * TAU), 30.0 * (1.0 + 0.2 * spike_lvl), 55.0, false)
			if ghost:
				m.pierce_count = 3
			spike_count += 1
			m.tree_exited.connect(func(): EnemyBase.spike_count -= 1)
			parent.call_deferred("add_child", m)

static func spawn_pickup(parent: Node, pos: Vector2, p_type: int) -> void:
	var p = preload("res://scenes/pickups/nanite_scrap.tscn").instantiate()
	p.global_position = pos
	p.setup(p_type)
	pickup_count += 1
	p.tree_exited.connect(func(): EnemyBase.pickup_count -= 1)
	parent.call_deferred("add_child", p)

func drop_loot() -> void:
	if is_champion:
		var beacon = preload("res://scenes/pickups/magnet_beacon.tscn").instantiate()
		beacon.global_position = global_position
		get_parent().call_deferred("add_child", beacon)
		var ft = preload("res://scenes/effects/floating_text.tscn").instantiate()
		ft.global_position = global_position + Vector2(0, -32)
		get_parent().call_deferred("add_child", ft)
		ft.setup("+ ЧЕМПІОНА ЗНИЩЕНО! +", Color(1.0, 0.85, 0.2), 1.8)

	if randf() < repair_chance:
		spawn_pickup(get_parent(), global_position, 2) # REPAIR
		return

	# Too many pickups on the ground: absorb directly instead of adding more nodes
	if pickup_count > MAX_PICKUPS:
		GameManager.add_scrap(scrap_count)
		return

	for i in range(scrap_count):
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		spawn_pickup(get_parent(), global_position + offset, 1 if randf() < gold_chance else 0)
