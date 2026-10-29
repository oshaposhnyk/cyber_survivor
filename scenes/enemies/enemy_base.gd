extends RefCounted
class_name EnemyBase

# One swarm enemy as plain data and behaviour, with no Node behind it.
# Swarm (scripts/systems/swarm.gd) owns the units, runs _tick() and draws every kind
# with one MultiMesh, so 1000+ enemies cost no scene nodes, canvas items or physics bodies.
# Weapons find units through EnemyRegistry and call the same methods as before.

# Stats come from EnemyKinds when Swarm spawns the unit
var kind: String = ""
var max_health: float = 30.0
var move_speed: float = 130.0
var contact_damage: float = 10.0
var scrap_count: int = 1
var gold_chance: float = 0.06
var repair_chance: float = 0.03
var score_points: int = 10
# Circle used by projectile hits and contact (was the CollisionShape2D radius)
var hit_radius: float = 20.0

# Shared caps so huge hordes do not flood the scene tree with short-lived FX nodes
const MAX_DAMAGE_TEXTS := 24
const MAX_EXPLOSIONS := 36
const MAX_PICKUPS := 160
const FX_RANGE_SQ := 1000.0 * 1000.0
const CONTACT_RANGE_SQ := 40.0 * 40.0
const WRAP_DIST_SQ := 2100.0 * 2100.0
# Off-screen enemies think every LOD_STRIDE-th physics frame with the summed delta.
# Most of the late-game horde sits outside the view, walking in from the spawn ring.
const LOD_STRIDE := 3
# Fake top light: shadow cast down-right in world space
const SHADOW_OFFSET := Vector2(10.0, 16.0)

static var damage_text_count: int = 0
static var explosion_count: int = 0
static var pickup_count: int = 0
static var spike_count: int = 0
# Camera view in world space plus a margin; main.gd refreshes it every frame
static var view_center: Vector2 = Vector2.ZERO
static var view_half: Vector2 = Vector2(1000.0, 620.0)
# Node that FX, loot and enemy projectiles are added to (the Main scene)
static var world: Node2D = null
const MAX_SPIKES := 14
const VIRUS_TINT := Color(0.55, 1.0, 0.65)
# Infected death clears hostile shots in this radius
const COMMS_PULSE_RADIUS := 90.0
# JAMMER champion: weapon cooldowns tick at half speed inside this radius
const JAM_RADIUS := 280.0

var global_position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var current_health: float = 30.0
var knockback: Vector2 = Vector2.ZERO
var stun_timer: float = 0.0
var is_dead: bool = false
var target_player: Node2D = null
var hit_flash: float = 0.0
# Render state read by Swarm: final colour is flash_tint * status_tint * body_tint
var facing: float = 0.0
var facing_cos: float = 1.0
var facing_sin: float = 0.0
var sprite_scale: float = 1.0
var jitter: Vector2 = Vector2.ZERO
var flash_tint: Color = Color.WHITE
var status_tint: Color = Color.WHITE
var body_tint: Color = Color.WHITE
var lod_dt: float = 0.0
var lod_slot: int = 0

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

# Ranged attack (assault droid, mech): attack token -> 0.4 s aim telegraph -> burst.
# See FireDirector: only a few shooters hold a token at a time.
enum FireState { IDLE, AIM, BURST }
const AIM_TIME := 0.4
# Share of volleys aimed at a player turret instead of the ship (aggro)
const TURRET_AGGRO := 0.35
# Retry delay when no token is free
const TOKEN_RETRY := 0.3
# Infected shooters fire 150% less often (virus blockade)
const INFECTED_FIRE_SLOW := 2.5
var shoot_interval: float = 2.5
var shoot_range: float = 420.0
var burst_count: int = 3
var burst_gap: float = 0.12
var shot_damage: float = 12.0
var fire_state: FireState = FireState.IDLE
var fire_cooldown: float = 1.0
var aim_left: float = 0.0
var burst_left: int = 0
var burst_timer: float = 0.0
var aim_target: Object = null
var aim_point: Vector2 = Vector2.ZERO
# Mind Control (HCK-05): while > 0 the unit fights for the player
var hijack_time: float = 0.0
const HIJACK_TINT := Color(0.55, 1.4, 0.75)

# Called by Swarm once stats and wave scaling are applied (was _ready)
func _spawned() -> void:
	current_health = max_health
	swarm_angle_offset = randf_range(-0.35, 0.35)
	lod_slot = randi() % LOD_STRIDE
	find_player()

func find_player() -> void:
	target_player = GameManager.player_node if is_instance_valid(GameManager.player_node) else null

# Swarm draws an overlay (champion aura, shield dome) only for units that ask for one
func has_overlay() -> bool:
	return is_champion

# Direct integration instead of move_and_slide(): enemies do not collide with each
# other or walls, so a kinematic solve per enemy per frame was pure overhead.
func step_motion(delta: float) -> void:
	global_position += velocity * delta * (slow_mult if slow_time > 0.0 else 1.0)

# Sprite angle used by the Swarm renderer; sin/cos cached so the per-frame
# buffer fill does no trigonometry for units that keep their heading
func face(angle: float) -> void:
	if absf(angle_difference(facing, angle)) < 0.02:
		return
	facing = angle
	facing_cos = cos(angle)
	facing_sin = sin(angle)

func _off_screen() -> bool:
	var d := (global_position - view_center).abs()
	return d.x > view_half.x or d.y > view_half.y

# Returns false when the enemy was wrapped back near the player this frame.
func keep_near_player(to_player: Vector2) -> bool:
	if to_player.length_squared() > WRAP_DIST_SQ:
		var wrap_angle = randf() * TAU
		global_position = target_player.global_position + Vector2(cos(wrap_angle), sin(wrap_angle)) * randf_range(950.0, 1150.0)
		return false
	return true

func apply_contact(to_player: Vector2, delta: float) -> void:
	if hijack_time > 0.0:
		return
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
		if hit_flash <= 0.0:
			flash_tint = Color.WHITE
	if slow_time > 0.0:
		slow_time -= delta
	if ward_time > 0.0:
		ward_time -= delta
	if hijack_time > 0.0:
		hijack_time -= delta
		if hijack_time <= 0.0:
			cancel_fire()
			status_tint = VIRUS_TINT if infected_time > 0.0 else Color.WHITE
	if infected_time > 0.0:
		infected_time -= delta
		infect_tick -= delta
		if infect_tick <= 0.0:
			infect_tick = 0.5
			apply_dot(infect_dps * 0.5)
		if infected_time <= 0.0:
			status_tint = Color.WHITE

func infect(duration: float, dps: float) -> void:
	if is_dead:
		return
	infected_time = max(infected_time, duration)
	infect_dps = max(infect_dps, dps)
	status_tint = VIRUS_TINT

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

# Per-enemy behaviour, run by Swarm (off-screen units at a lower rate, see LOD_STRIDE)
func _tick(delta: float) -> void:
	update_status(delta)

	if is_champion:
		champion_pulse_time += delta * 4.0
		champion_aura_timer -= delta
		if champion_aura_timer <= 0.0:
			champion_aura_timer = 0.6
			apply_champion_aura()

	# Handle EMP Stun
	if stun_timer > 0.0:
		cancel_fire()
		stun_timer -= delta
		velocity = knockback
		knockback = knockback.move_toward(Vector2.ZERO, 600.0 * delta)
		step_motion(delta)
		body_tint = Color(0.4, 0.8, 1.0) if fmod(stun_timer, 0.2) < 0.1 else Color.WHITE
		if stun_timer <= 0.0:
			body_tint = Color.WHITE
		return

	if not is_instance_valid(target_player):
		find_player()
		return

	var to_player = target_player.global_position - global_position
	if not keep_near_player(to_player):
		return

	# Move toward player with slight swarm angle offset for natural surrounding behaviour
	var move_dir = to_player.normalized().rotated(swarm_angle_offset)
	face(to_player.angle() + PI / 2.0)

	velocity = move_dir * move_speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	step_motion(delta)
	apply_contact(to_player, delta)

# Runs the shooter state machine; `dist` is the distance to the ship
func update_fire(delta: float, dist: float) -> void:
	match fire_state:
		FireState.IDLE:
			fire_cooldown -= delta / (INFECTED_FIRE_SLOW if infected_time > 0.0 else 1.0)
			if hijack_time > 0.0:
				_aim_for_player_side()
				return
			if fire_cooldown > 0.0 or dist > shoot_range:
				return
			if not FireDirector.request(self):
				fire_cooldown = TOKEN_RETRY
				return
			aim_target = _pick_aim_target()
			aim_left = AIM_TIME
			fire_state = FireState.AIM
			Swarm.instance.add_overlay(self)
		FireState.AIM:
			if _target_ok(aim_target):
				aim_point = aim_target.global_position
			aim_left -= delta
			if aim_left <= 0.0:
				fire_state = FireState.BURST
				burst_left = burst_count
				burst_timer = 0.0
		FireState.BURST:
			burst_timer -= delta
			if burst_timer > 0.0:
				return
			if _target_ok(aim_target):
				aim_point = aim_target.global_position
			_fire_volley((aim_point - global_position).normalized())
			burst_left -= 1
			burst_timer = burst_gap
			if burst_left <= 0:
				cancel_fire()
				fire_cooldown = shoot_interval

# Drops the token and any aim in progress (stun, death, end of burst)
func cancel_fire() -> void:
	if fire_state != FireState.IDLE:
		FireDirector.release(self)
		fire_state = FireState.IDLE

# Untyped on purpose: the aim target can be a turret that was freed while aiming,
# and a freed object passed to a typed Object parameter is a runtime error
func _target_ok(t) -> bool:
	return is_instance_valid(t) and not ("is_dead" in t and t.is_dead)

# Mind Control: no token needed; aims at the nearest other enemy
func _aim_for_player_side() -> void:
	if fire_cooldown > 0.0:
		return
	var found = EnemyRegistry.nearest(global_position, 1, shoot_range, [self])
	if found.is_empty():
		return
	aim_target = found[0]
	aim_point = aim_target.global_position
	aim_left = AIM_TIME
	fire_state = FireState.AIM

func hijack(duration: float) -> void:
	if is_dead:
		return
	cancel_fire()
	hijack_time = duration
	fire_cooldown = 0.0
	status_tint = HIJACK_TINT
	Swarm.instance.add_overlay(self)
	var ft = preload("res://scenes/effects/floating_text.tscn").instantiate()
	ft.global_position = global_position + Vector2(0, -30)
	world.add_child(ft)
	ft.setup("ЗЛАМАНО", CyberPalette.GREEN, 1.2)

# Mostly the ship; sometimes a nearby turret draws the fire
func _pick_aim_target() -> Node2D:
	if randf() < TURRET_AGGRO and is_instance_valid(target_player) and "spawned_turrets" in target_player:
		for t in target_player.spawned_turrets:
			if is_instance_valid(t) and global_position.distance_to(t.global_position) <= shoot_range:
				return t
	return target_player

# One shot or salvo towards `dir`; heavy units override this
func _fire_volley(dir: Vector2) -> void:
	_spawn_laser(dir, shot_damage)
	if randf() < 0.2:
		AudioManager.play_sfx("laser", 0.3, -5.0)

# Inside the glitch field the targeting is scrambled: +-90 deg spread, and the
# shot hits whatever it meets, the shooter's allies included
func _spawn_laser(dir: Vector2, dmg: float) -> void:
	var laser = preload("res://scenes/weapons/enemy_laser.tscn").instantiate()
	var rogue := hijack_time <= 0.0 and _in_glitch_field()
	if rogue:
		dir = dir.rotated(randf_range(-PI / 2.0, PI / 2.0))
	laser.setup(global_position, dir, dmg, self)
	world.add_child(laser)
	if hijack_time > 0.0:
		laser.turn_hacked(aim_target)
	elif rogue:
		laser.make_rogue()

func _in_glitch_field() -> bool:
	if not is_instance_valid(target_player):
		return false
	var r: float = target_player.get("glitch_radius")
	return r > 0.0 and global_position.distance_squared_to(target_player.global_position) <= r * r

func has_aim_overlay() -> bool:
	return fire_state == FireState.AIM

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
	
	sprite_scale *= 1.35

func apply_champion_aura() -> void:
	match champion_type:
		ChampionType.HASTE:
			for e in EnemyRegistry.in_radius(global_position, 220.0):
				if e != self and is_instance_valid(e) and e.has_method("apply_slow"):
					e.apply_slow(0.8, 1.45)
		ChampionType.JAMMER:
			# Jams the ship's weapon systems while it stays inside the field
			if is_instance_valid(target_player) and target_player.has_method("jam") \
					and global_position.distance_squared_to(target_player.global_position) <= JAM_RADIUS * JAM_RADIUS:
				target_player.jam(champion_aura_timer + 0.2)
		ChampionType.MENDER:
			# Repairs swarm units only: not the boss, not reactors
			for e in EnemyRegistry.in_radius(global_position, 200.0):
				if e != self and e is EnemyBase:
					if e.current_health < e.max_health:
						e.current_health = min(e.max_health, e.current_health + e.max_health * 0.08)

# Drawn by Swarm's overlay canvas with the transform already at global_position
func draw_overlay(c: Node2D) -> void:
	# Aim telegraph: thin red line that brightens over the 0.4 s before the burst
	if fire_state == FireState.AIM and not is_dead:
		var k := 1.0 - aim_left / AIM_TIME
		var tip := aim_point - global_position
		var aim_col: Color = CyberPalette.GREEN if hijack_time > 0.0 else CyberPalette.RED
		c.draw_line(Vector2.ZERO, tip, Color(aim_col, 0.25 + 0.6 * k), 1.0 + k)
		c.draw_circle(tip, 3.0 + 3.0 * k, Color(aim_col, 0.5 + 0.4 * k))
	# Mind Control: green dashed ring around the turned unit
	if hijack_time > 0.0 and not is_dead:
		for i in range(8):
			var ha := float(i) * TAU / 8.0 + float(Time.get_ticks_msec()) * 0.002
			c.draw_arc(Vector2.ZERO, hit_radius + 10.0, ha, ha + TAU / 16.0, 4, Color(CyberPalette.GREEN, 0.85), 2.0)
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
			if randf() < 0.3:
				jitter = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		ChampionType.MENDER:
			aura_col = Color(0.2, 1.0, 0.55)
			type_label = "REPAIR"
			
	var r_outer = 44.0 + pulse * 6.0
	var r_inner = 30.0
	
	# 1. Outer Tech Ring with rotating notches
	var rot_speed = champion_pulse_time * 0.8
	c.draw_arc(Vector2.ZERO, r_outer, 0, TAU, 32, Color(aura_col.r, aura_col.g, aura_col.b, 0.55), 2.0)
	c.draw_circle(Vector2.ZERO, r_outer, Color(aura_col.r, aura_col.g, aura_col.b, 0.05))
	for i in range(8):
		var a = rot_speed + float(i) * (TAU / 8.0)
		var p1 = Vector2(cos(a), sin(a)) * (r_outer - 5.0)
		var p2 = Vector2(cos(a), sin(a)) * (r_outer + 5.0)
		c.draw_line(p1, p2, aura_col, 2.0)
		
	# 2. Inner Counter-Rotating Dashed Ring
	for i in range(6):
		var a0 = -rot_speed * 1.2 + float(i) * (TAU / 6.0)
		c.draw_arc(Vector2.ZERO, r_inner, a0, a0 + 0.5, 8, Color(aura_col.r, aura_col.g, aura_col.b, 0.7), 1.5)
		
	# 3. Type-Specific Special VFX
	match champion_type:
		ChampionType.HASTE:
			# Orbiting speed sparks
			for i in range(3):
				var sa = rot_speed * 2.5 + float(i) * (TAU / 3.0)
				var sp_pos = Vector2(cos(sa), sin(sa)) * (r_outer + 8.0)
				c.draw_circle(sp_pos, 2.5, Color.WHITE)
				c.draw_line(sp_pos, sp_pos - Vector2(-sin(sa), cos(sa)) * 14.0, aura_col, 1.8)
		ChampionType.JAMMER:
			# Jamming field: dashed rim marks where ship weapons slow down
			for i in range(24):
				var ja = rot_speed * 0.5 + float(i) * (TAU / 24.0)
				c.draw_arc(Vector2.ZERO, JAM_RADIUS, ja, ja + TAU / 48.0, 4, Color(aura_col.r, aura_col.g, aura_col.b, 0.35), 2.0)
			# Flickering EMP static arcs
			if randf() < 0.6:
				var a1 = randf() * TAU
				var a2 = a1 + randf_range(0.8, 1.8)
				var arc_p1 = Vector2(cos(a1), sin(a1)) * r_inner
				var arc_p2 = Vector2(cos(a2), sin(a2)) * r_inner
				var arc_mid = (arc_p1 + arc_p2) * 0.5 + Vector2(randf_range(-10, 10), randf_range(-10, 10))
				c.draw_line(arc_p1, arc_mid, Color(1.0, 0.4, 1.0, 0.9), 1.8)
				c.draw_line(arc_mid, arc_p2, Color.WHITE, 1.8)
		ChampionType.MENDER:
			# Floating emerald healing crosses
			for i in range(3):
				var cross_y = -18.0 - fmod(champion_pulse_time * 16.0 + float(i) * 12.0, 28.0)
				var cross_x = sin(champion_pulse_time + float(i) * 2.0) * 20.0
				var cp = Vector2(cross_x, cross_y)
				c.draw_line(cp + Vector2(-3, 0), cp + Vector2(3, 0), aura_col, 1.8)
				c.draw_line(cp + Vector2(0, -3), cp + Vector2(0, 3), aura_col, 1.8)

	# 4. Floating Crown Bracket & Mini Health Bar above the enemy
	var top_y = -38.0
	c.draw_line(Vector2(-16, top_y), Vector2(-6, top_y - 6), aura_col, 2.0)
	c.draw_line(Vector2(-6, top_y - 6), Vector2(6, top_y - 6), aura_col, 2.0)
	c.draw_line(Vector2(6, top_y - 6), Vector2(16, top_y), aura_col, 2.0)
	c.draw_circle(Vector2(0, top_y - 6), 2.5, Color.WHITE)
	
	# Mini health bar
	var bar_w = 42.0
	var bar_h = 4.0
	var bar_y = top_y - 12.0
	var hp_frac = clampf(current_health / max(1.0, max_health), 0.0, 1.0)
	c.draw_rect(Rect2(-bar_w * 0.5 - 1.0, bar_y - 1.0, bar_w + 2.0, bar_h + 2.0), Color(0.05, 0.05, 0.1, 0.85), true)
	c.draw_rect(Rect2(-bar_w * 0.5, bar_y, bar_w * hp_frac, bar_h), aura_col, true)
	c.draw_rect(Rect2(-bar_w * 0.5 - 1.0, bar_y - 1.0, bar_w + 2.0, bar_h + 2.0), Color(1, 1, 1, 0.4), false, 1.0)

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
	# Timer-driven flash: no Tween allocation per hit. White, so red/yellow stay
	# free for real warnings (kamikaze fuse, player damage)
	flash_tint = Color(2.2, 2.2, 2.2)
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
	world.add_child(ft)
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
	cancel_fire()

	_death_fx()
	GameManager.add_kill()
	on_death_hacks()
	drop_loot()

# Explosion and sound on death; heavy units override this, not die()
func _death_fx() -> void:
	if _near_player():
		spawn_explosion(world, global_position, 26.0)
		# Audio throttle during massive waves
		if randf() < 0.25:
			AudioManager.play_sfx("explosion", 0.3, -3.0)

# Hacking branch death effects: virus spread, botnet pulse, intercepted missile
func on_death_hacks() -> void:
	var parent = world
	if infected_time > 0.0:
		# Comms failure pulse: an infected unit's death scrambles shots around it
		if EnemyShots.clear_radius(global_position, COMMS_PULSE_RADIUS, CyberPalette.GREEN) > 0:
			spawn_explosion(parent, global_position, COMMS_PULSE_RADIUS * 0.5, CyberPalette.GREEN)
		for e in EnemyRegistry.nearest(global_position, 2, 170.0, [self]):
			if e.has_method("infect"):
				e.infect(4.0, infect_dps)
		var botnet = GameManager.get_skill_level("botnet")
		if botnet > 0:
			var r = 90.0 * (1.0 + 0.25 * (botnet - 1))
			for e in EnemyRegistry.in_radius(global_position, r):
				if e != self and e.has_method("apply_dot"):
					e.apply_stun(0.6 + 0.5 * botnet)
					e.apply_dot((10.0 + 10.0 * botnet) * GameManager.damage_scale())
			spawn_explosion(parent, global_position, r * 0.6, Color(0.2, 1.0, 0.55))
	var spike_lvl = GameManager.get_skill_level("data_spike")
	if spike_lvl > 0 and spike_count < MAX_SPIKES:
		var ghost = GameManager.is_synergy_active("ghost_swarm")
		var chance = 0.06 * spike_lvl * (2.0 if ghost else 1.0)
		if randf() < chance:
			var m = preload("res://scenes/weapons/missile.tscn").instantiate()
			m.setup(global_position, Vector2.UP.rotated(randf() * TAU), 30.0 * (1.0 + 0.2 * spike_lvl) * GameManager.damage_scale(), 55.0, false)
			if ghost:
				m.pierce_count = 3
			spike_count += 1
			m.tree_exited.connect(func(): EnemyBase.spike_count -= 1)
			parent.call_deferred("add_child", m)

# Over the cap, scrap is absorbed directly instead of adding more nodes.
# Repair cores are dropped instead: absorbing them would be free healing, and
# uncapped they piled up by the hundreds across the map.
static func spawn_pickup(parent: Node, pos: Vector2, p_type: int) -> void:
	if pickup_count > MAX_PICKUPS:
		if p_type != 2:
			GameManager.add_scrap(5 if p_type == 1 else 1)
		return
	var p = preload("res://scenes/pickups/nanite_scrap.tscn").instantiate()
	p.global_position = pos
	p.setup(p_type)
	pickup_count += 1
	p.tree_exited.connect(func(): EnemyBase.pickup_count -= 1)
	parent.call_deferred("add_child", p)

func drop_loot() -> void:
	_drop_champion_reward()

	if randf() < repair_chance:
		spawn_pickup(world, global_position, 2) # REPAIR
		return

	for i in range(scrap_count):
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		spawn_pickup(world, global_position + offset, 1 if randf() < gold_chance else 0)

# Magnet beacon and banner for a killed champion, whatever its own loot is
func _drop_champion_reward() -> void:
	if is_champion:
		var beacon = preload("res://scenes/pickups/magnet_beacon.tscn").instantiate()
		beacon.global_position = global_position
		world.call_deferred("add_child", beacon)
		var ft = preload("res://scenes/effects/floating_text.tscn").instantiate()
		ft.global_position = global_position + Vector2(0, -32)
		world.call_deferred("add_child", ft)
		ft.setup("+ ЧЕМПІОНА ЗНИЩЕНО! +", Color(1.0, 0.85, 0.2), 1.8)
