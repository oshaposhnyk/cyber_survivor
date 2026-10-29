extends CharacterBody2D

# Player ship ARC-01

@export var base_speed: float = 230.0
@export var base_max_hp: float = 100.0

var current_hp: float = 100.0
var max_hp: float = 100.0

var current_shield: float = 0.0
var max_shield: float = 0.0
var shield_recharge_delay: float = 4.0
var shield_timer: float = 0.0
var shield_recharge_rate: float = 25.0
var damage_reduction: float = 0.0
var hp_regen_rate: float = 0.0

# Tank doctrine contact spikes; enemies read this when they ram the ship
var thorns_base: float = 0.0
var thorns_dps: float:
	get:
		return thorns_base * GameManager.damage_scale()

var is_thrusting: bool = false
var thruster_time: float = 0.0

# Phase Shift / Dash Ability
var dash_cooldown_base: float = 3.2
var dash_cooldown: float:
	get:
		var ovc = pow(0.92, GameManager.get_skill_level("cooldown"))
		var meta = 1.0 - GameManager.get_meta_upgrade_level("dash") * 0.12
		return dash_cooldown_base * ovc * meta
var dash_timer: float = 0.0
var is_dashing: bool = false
var dash_duration: float = 0.22
var dash_time_left: float = 0.0
var dash_dir: Vector2 = Vector2.UP
var afterimages: Array[Dictionary] = []
var afterimage_spawn_timer: float = 0.0
var dash_sparks: Array[Dictionary] = []

# Anti-projectile systems (see EnemyShots)
# Time dilation field (speed + cooldown skills): hostile shots inside slow down
const DILATION_RADIUS := 200.0
var dilation_radius: float = 0.0
var dilation_slow: float = 0.0
# Aegis Perimeter (Tank doctrine): shot-proof dome on a heavy hit or every 15 s
const AEGIS_RADIUS := 110.0
const AEGIS_TIME := 2.5
const AEGIS_PERIOD := 15.0
const AEGIS_HEAVY_HIT := 0.15
var aegis_time: float = 0.0
var aegis_cd: float = AEGIS_PERIOD
# Dash vacuum trail: half width of the cleared lane
const DASH_TRAIL_WIDTH := 40.0

# Tier-5 skills
const STRIKE_SEARCH := 800.0
const REBOOT_RADIUS := 220.0
const STASIS_RANGE := 1300.0
const MIND_RANGE := 600.0
const SHOOTER_KINDS := ["assault", "mech"]
var strike_timer: float = 2.0
var reboot_cd: float = 0.0
var nova_time: float = 0.0
var stasis_cd: float = 8.0
var stasis_time: float = 0.0
var stasis_ring: float = 0.0
var mind_cd: float = 4.0

# Weapon ports toggles
var blaster_barrel_toggle: int = 0
var missile_pod_toggle: int = 0

# Side hull damage spark bursts
var damage_sparks: Array[Dictionary] = []
# Contact damage arrives every frame from every touching enemy; hit FX are rate-limited
const HIT_FX_INTERVAL := 0.08
const MAX_DAMAGE_SPARKS := 72
var hit_fx_cooldown: float = 0.0
var hit_flash: float = 0.0

func spawn_side_damage_sparks(local_origin: Vector2, local_dir: Vector2) -> void:
	if damage_sparks.size() >= MAX_DAMAGE_SPARKS:
		return
	for i in range(12):
		var ang = local_dir.angle() + randf_range(-0.8, 0.8)
		var spd = randf_range(80.0, 220.0)
		damage_sparks.append({
			"pos": local_origin,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"size": randf_range(1.5, 3.2),
			"life": randf_range(0.2, 0.45),
			"max_life": 0.4,
			"color": Color(1.0, randf_range(0.4, 0.9), 0.1)
		})
	queue_redraw()

func _draw() -> void:
	# 1. Dual Ion Thruster Exhaust Plumes
	var engine_ports = [Vector2(-11, 20), Vector2(11, 20)]
	var plume_len = randf_range(16.0, 26.0) if is_thrusting else randf_range(5.0, 8.0)
	var plume_width = 4.5 if is_thrusting else 2.5
	var outer_col = Color(0.15, 0.85, 1.0, 0.85 if is_thrusting else 0.4)
	var core_col = Color(1.0, 1.0, 1.0, 0.95 if is_thrusting else 0.6)
	
	for port in engine_ports:
		var end_pt = port + Vector2(0, plume_len)
		draw_line(port, end_pt, outer_col, plume_width)
		draw_line(port, port + Vector2(0, plume_len * 0.5), core_col, plume_width * 0.4)
		draw_circle(port, plume_width * 0.8, outer_col)
		
	# Glitch field: jittering dashed ring, drawn unrotated
	if glitch_radius > 0.0:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		var g = Color(0.2, 1.0, 0.55, 0.35)
		var segs = 28
		for i in range(segs):
			if (i + int(glitch_phase * 10.0)) % 3 == 0:
				continue
			var a0 = TAU * i / segs + glitch_phase * 0.4
			var jitter = randf_range(-3.0, 3.0) if randf() < 0.15 else 0.0
			draw_arc(Vector2.ZERO, glitch_radius + jitter, a0, a0 + TAU / segs * 0.8, 4, g, 2.0)
		draw_circle(Vector2.ZERO, glitch_radius, Color(0.2, 1.0, 0.55, 0.04))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Time dilation field: slow dashed overclock ring
	if dilation_radius > 0.0:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		var dseg = 36
		for i in range(dseg):
			if i % 2 == 0:
				var da = TAU * i / dseg + Time.get_ticks_msec() * 0.0002
				draw_arc(Vector2.ZERO, dilation_radius, da, da + TAU / dseg, 3, Color(CyberPalette.YELLOW, 0.22), 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Aegis Perimeter: cyan hex dome, same language as the shield FX
	if aegis_time > 0.0:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		var fade = clampf(aegis_time / 0.4, 0.0, 1.0)
		var hex := PackedVector2Array()
		for i in range(7):
			var ha = TAU * i / 6.0 + PI / 6.0
			hex.append(Vector2(cos(ha), sin(ha)) * AEGIS_RADIUS)
		draw_colored_polygon(hex, Color(CyberPalette.CYAN, 0.08 * fade))
		draw_polyline(hex, Color(CyberPalette.CYAN, 0.75 * fade), 3.0)
		for i in range(6):
			draw_circle(hex[i], 3.5, Color(0.6, 1.0, 1.0, 0.9 * fade))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Shield reboot nova: cyan shock ring
	if nova_time > 0.0:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		var nk = 1.0 - nova_time / 0.45
		draw_arc(Vector2.ZERO, REBOOT_RADIUS * nk, 0.0, TAU, 48, Color(CyberPalette.CYAN, 1.0 - nk), 4.0)
		draw_circle(Vector2.ZERO, REBOOT_RADIUS * nk, Color(CyberPalette.CYAN, 0.12 * (1.0 - nk)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Stasis: yellow time-stop wave, then a slow dashed rim while it lasts
	if stasis_time > 0.0:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		var wave = minf(stasis_ring / 0.35, 1.0)
		if wave < 1.0:
			draw_arc(Vector2.ZERO, 900.0 * wave, 0.0, TAU, 64, Color(CyberPalette.YELLOW, 0.6 * (1.0 - wave)), 6.0)
		var segs = 24
		for i in range(segs):
			if i % 2 == 0:
				var sa = TAU * i / segs
				draw_arc(Vector2.ZERO, 46.0, sa, sa + TAU / segs, 3, Color(CyberPalette.YELLOW, 0.7), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Jammed by a JAMMER champion: magenta static around the hull
	if jam_timer > 0.0:
		draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
		for i in range(10):
			if randf() < 0.5:
				var ja = randf() * TAU
				draw_arc(Vector2.ZERO, 30.0 + randf_range(-3.0, 3.0), ja, ja + 0.35, 4, Color(0.92, 0.25, 1.0, 0.8), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Side Hull Breach Sparks
	for s in damage_sparks:
		if s["life"] > 0.0:
			var a = clampf(s["life"] / s["max_life"], 0.0, 1.0)
			var col: Color = s["color"]
			draw_circle(s["pos"], s["size"], Color(col.r, col.g, col.b, a))
			draw_line(s["pos"], s["pos"] - s["vel"] * 0.025, Color(1.0, 0.6, 0.1, a * 0.7), 1.5)
			
	# 3. Holographic Phase Shift Chromatic Aberration & Ghost Trail
	# Draw lightning arcs between consecutive ghost images
	if afterimages.size() > 1:
		for i in range(afterimages.size() - 1):
			var pA = to_local(afterimages[i]["pos"])
			var pB = to_local(afterimages[i + 1]["pos"])
			var mid = (pA + pB) * 0.5 + Vector2(randf_range(-8, 8), randf_range(-8, 8))
			var arc_alpha = min(afterimages[i]["alpha"], afterimages[i + 1]["alpha"])
			draw_line(pA, mid, Color(0.1, 0.95, 1.0, arc_alpha * 0.8), 2.0)
			draw_line(mid, pB, Color(1.0, 0.2, 0.85, arc_alpha * 0.8), 2.0)
			
	for a in afterimages:
		var rel_pos = to_local(a["pos"])
		var ship_pts = PackedVector2Array([
			Vector2(0, -22), Vector2(18, 15), Vector2(0, 8), Vector2(-18, 15)
		])
		
		# Cyan channel offset (left)
		draw_set_transform(rel_pos + Vector2(-3.5, 0).rotated(a["rot"]), a["rot"] - rotation, Vector2.ONE)
		draw_polyline(ship_pts, Color(0.1, 0.95, 1.0, a["alpha"] * 0.7), 1.8)
		draw_line(Vector2(-18, 15), Vector2(0, -22), Color(0.1, 0.95, 1.0, a["alpha"] * 0.7), 1.8)
		
		# Magenta channel offset (right)
		draw_set_transform(rel_pos + Vector2(3.5, 0).rotated(a["rot"]), a["rot"] - rotation, Vector2.ONE)
		draw_polyline(ship_pts, Color(1.0, 0.2, 0.85, a["alpha"] * 0.7), 1.8)
		draw_line(Vector2(-18, 15), Vector2(0, -22), Color(1.0, 0.2, 0.85, a["alpha"] * 0.7), 1.8)
		
		# White glowing energy core
		draw_set_transform(rel_pos, a["rot"] - rotation, Vector2.ONE)
		draw_polygon(ship_pts, PackedColorArray([Color(0.2, 0.85, 1.0, a["alpha"] * 0.25)]))
		draw_polyline(ship_pts, Color(1.0, 1.0, 1.0, a["alpha"] * 0.85), 1.2)
		draw_line(Vector2(-18, 15), Vector2(0, -22), Color(1.0, 1.0, 1.0, a["alpha"] * 0.85), 1.2)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 4. Warp Speed Streaks during Dash
	for sp in dash_sparks:
		if sp["life"] > 0.0:
			var rel = to_local(sp["pos"])
			var a = clampf(sp["life"] / sp["max_life"], 0.0, 1.0)
			var col: Color = sp["color"]
			draw_circle(rel, 2.5 * a, Color(col.r, col.g, col.b, a))
			draw_line(rel, rel - sp["vel"] * 0.035, Color(col.r, col.g, col.b, a * 0.8), 2.0)

# Weapon Timers
var blaster_timer: float = 0.0
var missile_timer: float = 0.0
var railgun_timer: float = 0.0
var emp_timer: float = 0.0
var virus_timer: float = 1.0
var glitch_timer: float = 0.0
var glitch_radius: float = 0.0
var glitch_phase: float = 0.0
var turret_timer: float = 0.5
var mine_timer: float = 1.0

# Active Orbital Drones list
var spawned_drones: Array[Node2D] = []
var spawned_turrets: Array[Node2D] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var magnet_area: Area2D = $MagnetArea
@onready var magnet_shape: CollisionShape2D = $MagnetArea/CollisionShape2D
@onready var shield_fx: Node2D = $ShieldFX

func _ready() -> void:
	add_to_group("player")
	collision_layer = 1 # Layer 1: Player
	collision_mask = 2  # Layer 2: Enemies
	GameManager.player_node = self
	current_hp = base_max_hp
	max_hp = base_max_hp
	apply_upgrades()

func apply_upgrades() -> void:
	# Meta upgrades integration
	var meta_hull = GameManager.get_meta_upgrade_level("hull") * 10.0
	var meta_spd_mult = 1.0 + GameManager.get_meta_upgrade_level("speed") * 0.04
	var effective_base_hp = base_max_hp + meta_hull
	
	# 1. Armor & Health
	var armor_lvl = GameManager.get_skill_level("armor")
	max_hp = (effective_base_hp + armor_lvl * 35.0) * GameManager.doctrine_mod("hp")
	current_hp = min(current_hp, max_hp)
	damage_reduction = armor_lvl * 0.12
	thorns_base = GameManager.doctrine_mod("thorns", 0.0)
	
	# 2. Shield
	var shield_lvl = GameManager.get_skill_level("shield")
	if shield_lvl > 0:
		max_shield = shield_lvl * 35.0
		shield_recharge_delay = max(1.8, 4.5 - shield_lvl * 0.6)
	else:
		max_shield = 0.0
		current_shield = 0.0
	current_shield = min(current_shield, max_shield)
	
	# 3. Nanite Repair
	var repair_lvl = GameManager.get_skill_level("repair")
	hp_regen_rate = repair_lvl * 2.2
	if GameManager.is_synergy_active("nanite_bastion"):
		hp_regen_rate *= 3.0 # Bastion triple healing
		
	# 3b. Time dilation: needs both Overclock basics; 60% slow once both reach level 3
	var spd_lvl = GameManager.get_skill_level("speed")
	var cd_skill = GameManager.get_skill_level("cooldown")
	if spd_lvl > 0 and cd_skill > 0:
		dilation_radius = DILATION_RADIUS
		dilation_slow = 0.6 if mini(spd_lvl, cd_skill) >= 3 else 0.5
	else:
		dilation_radius = 0.0
		dilation_slow = 0.0

	# 4. Magnet Radius
	var magnet_lvl = GameManager.get_skill_level("magnet")
	var meta_mag_mult = 1.0 + GameManager.get_meta_upgrade_level("magnet") * 0.15
	if magnet_shape and magnet_shape.shape is CircleShape2D:
		magnet_shape.shape.radius = (85.0 + magnet_lvl * 60.0) * meta_mag_mult
		
	# 5. Orbital Drones Rebuild
	update_orbital_drones()
	
	GameManager.player_damaged.emit(current_hp, max_hp, current_shield, max_shield)

func update_orbital_drones() -> void:
	var drone_lvl = GameManager.get_skill_level("drones")
	for d in spawned_drones:
		if is_instance_valid(d):
			d.queue_free()
	spawned_drones.clear()
	
	if drone_lvl <= 0:
		return
		
	var drone_count = drone_lvl
	var is_bastion = GameManager.is_synergy_active("nanite_bastion")
	var drone_scene = preload("res://scenes/weapons/orbital_drone.tscn")
	
	for i in range(drone_count):
		var d = drone_scene.instantiate()
		var init_angle = (TAU / drone_count) * i
		d.setup(self, init_angle, is_bastion)
		d.damage_mult = GameManager.doctrine_mod("dmg")
		# Per level after the first: +20% orbit radius and speed
		d.orbit_radius *= 1.0 + 0.2 * (drone_lvl - 1)
		d.orbit_speed *= 1.0 + 0.2 * (drone_lvl - 1)
		get_parent().call_deferred("add_child", d)
		spawned_drones.append(d)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
		
	handle_movement(delta)
	handle_aegis(delta)
	_tick_tier5_timers(delta)
	handle_shield_recharge(delta)
	handle_regen(delta)
	handle_weapons(delta)
	
	hit_fx_cooldown -= delta
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0 and sprite:
			sprite.modulate = Color.WHITE
	
	# Update side damage sparks
	if damage_sparks.size() > 0:
		var alive_sparks: Array[Dictionary] = []
		for s in damage_sparks:
			s["pos"] += s["vel"] * delta
			s["vel"] = s["vel"].move_toward(Vector2.ZERO, 300.0 * delta)
			s["life"] -= delta
			if s["life"] > 0.0:
				alive_sparks.append(s)
		damage_sparks = alive_sparks
		queue_redraw()
		
	# Update dash afterimages
	if afterimages.size() > 0:
		var alive_after: Array[Dictionary] = []
		for a in afterimages:
			a["alpha"] -= delta * 3.6
			if a["alpha"] > 0.0:
				alive_after.append(a)
		afterimages = alive_after
		queue_redraw()
		
	# Update dash warp sparks
	if dash_sparks.size() > 0:
		var alive_dsp: Array[Dictionary] = []
		for s in dash_sparks:
			s["pos"] += s["vel"] * delta
			s["vel"] = s["vel"].move_toward(Vector2.ZERO, 380.0 * delta)
			s["life"] -= delta
			if s["life"] > 0.0:
				alive_dsp.append(s)
		dash_sparks = alive_dsp
		queue_redraw()

func handle_movement(delta: float) -> void:
	var input_vec = Vector2.ZERO
	input_vec.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vec.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_vec = input_vec.normalized()
	
	var speed_lvl = GameManager.get_skill_level("speed")
	var meta_spd_mult = 1.0 + GameManager.get_meta_upgrade_level("speed") * 0.04
	var move_speed = base_speed * meta_spd_mult * (1.0 + speed_lvl * 0.18) * GameManager.doctrine_mod("speed")
	
	# Dash cooldown update
	if dash_timer > 0.0:
		dash_timer -= delta
		GameManager.dash_updated.emit(dash_timer, dash_cooldown)
	else:
		GameManager.dash_updated.emit(0.0, dash_cooldown)

	if Input.is_action_just_pressed("dash") and dash_timer <= 0.0 and not is_dashing:
		start_dash(input_vec)

	if is_dashing:
		dash_time_left -= delta
		velocity = dash_dir * (move_speed * 3.3)
		var dash_from := global_position
		move_and_slide()
		# Vacuum trail (Overclock): the dash lane swallows hostile shots
		if GameManager.get_skill_level("speed") > 0:
			EnemyShots.clear_segment(dash_from, global_position, DASH_TRAIL_WIDTH, CyberPalette.YELLOW)
		if sprite:
			sprite.modulate = Color(0.4, 1.8, 3.0, 0.75)
		afterimage_spawn_timer -= delta
		if afterimage_spawn_timer <= 0.0:
			afterimage_spawn_timer = 0.035
			spawn_afterimage()
		if dash_time_left <= 0.0:
			is_dashing = false
			if sprite:
				sprite.modulate = Color.WHITE
	else:
		velocity = input_vec * move_speed
		move_and_slide()
		_push_out_of_swarm()
	
	is_thrusting = (input_vec.length() > 0.05) or is_dashing
	queue_redraw()
	
	if input_vec.length() > 0.05:
		rotation = lerp_angle(rotation, input_vec.angle() + PI / 2.0, 12.0 * delta)

# Swarm units have no physics bodies, so the ship is eased out of them instead of
# hard-blocked: pushing into the horde slows it down. Dash (phase shift) passes through.
const PUSH_RADIUS := 20.0
const PUSH_STRENGTH := 0.35
const MAX_PUSH := 8.0

func _push_out_of_swarm() -> void:
	var push := Vector2.ZERO
	for e in EnemyRegistry.overlapping(global_position, PUSH_RADIUS):
		if not e is EnemyBase:
			continue
		var d: Vector2 = global_position - e.global_position
		var dist := maxf(d.length(), 0.01)
		push += d / dist * (PUSH_RADIUS + e.hit_radius - dist)
	if push != Vector2.ZERO:
		global_position += (push * PUSH_STRENGTH).limit_length(MAX_PUSH)

func start_dash(input_vec: Vector2) -> void:
	is_dashing = true
	dash_time_left = dash_duration
	dash_timer = dash_cooldown
	dash_dir = input_vec if input_vec.length() > 0.1 else Vector2.UP.rotated(rotation - PI / 2.0)
	AudioManager.play_sfx("dash", 0.12, 1.5)
	
	# Spawn bursting warp streaks
	for i in range(16):
		var ang = (-dash_dir).angle() + randf_range(-0.9, 0.9)
		var spd = randf_range(160.0, 360.0)
		dash_sparks.append({
			"pos": global_position,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": randf_range(0.2, 0.38),
			"max_life": 0.38,
			"color": Color(0.1, 0.95, 1.0) if i % 2 == 0 else Color(1.0, 0.2, 0.85)
		})
		
	spawn_afterimage()
	
	# Dash EMP shockwave pushes & stuns lightweight enemies nearby
	for e in EnemyRegistry.in_radius(global_position, 110.0):
		if e.has_method("apply_slow"):
			e.apply_slow(0.9, 0.35)
		if e.has_method("take_damage"):
			e.take_damage(30.0 * weapon_mult())

func spawn_afterimage() -> void:
	afterimages.append({
		"pos": global_position,
		"rot": rotation,
		"alpha": 0.8
	})

func _tick_tier5_timers(delta: float) -> void:
	reboot_cd = maxf(0.0, reboot_cd - delta)
	nova_time = maxf(0.0, nova_time - delta)
	if stasis_time > 0.0:
		stasis_time -= delta
		stasis_ring += delta

func has_aegis() -> bool:
	return GameManager.active_doctrine == SkillData.Branch.DEFENSE

func handle_aegis(delta: float) -> void:
	if not has_aegis():
		aegis_time = 0.0
		return
	aegis_cd -= delta
	if aegis_cd <= 0.0:
		raise_aegis()
	if aegis_time > 0.0:
		aegis_time -= delta
		EnemyShots.clear_radius(global_position, AEGIS_RADIUS, CyberPalette.CYAN)

func raise_aegis() -> void:
	aegis_time = AEGIS_TIME
	aegis_cd = AEGIS_PERIOD
	AudioManager.play_sfx("shield_hit", 0.05, 2.0)

# Speed multiplier for a hostile shot at `pos` (1.0 outside the field)
func dilation_factor(pos: Vector2) -> float:
	# Stasis (OVC-05) freezes every hostile shot, wherever it is
	if stasis_time > 0.0:
		return 0.0
	if dilation_radius > 0.0 and global_position.distance_squared_to(pos) <= dilation_radius * dilation_radius:
		return 1.0 - dilation_slow
	return 1.0

# Data Spike: chance to hijack an incoming shot, 20% at level 1 to 40% at level 4
func hack_chance() -> float:
	var lvl = GameManager.get_skill_level("data_spike")
	return 0.0 if lvl <= 0 else 0.2 + (lvl - 1) * (0.2 / 3.0)

# Deflector: while the shield holds, 35% (level 1) to 60% (level 5) of shots bounce back
func deflect_chance() -> float:
	var lvl = GameManager.get_skill_level("shield")
	return 0.0 if lvl <= 0 else 0.35 + (lvl - 1) * 0.0625

# An enemy shot reached the hull. The shot pops afterwards unless it was turned.
func take_laser_hit(laser: Node) -> void:
	if is_dashing:
		return
	if aegis_time > 0.0:
		laser.pop(CyberPalette.CYAN)
		return
	if current_shield > 0.0 and randf() < deflect_chance():
		laser.reflect()
		AudioManager.play_sfx("shield_hit", 0.15, -2.0)
		return
	take_damage(laser.damage, laser.global_position)

func handle_shield_recharge(delta: float) -> void:
	if max_shield <= 0.0:
		return
		
	if shield_timer > 0.0:
		shield_timer -= delta
	else:
		if current_shield < max_shield:
			current_shield = min(max_shield, current_shield + shield_recharge_rate * delta)
			GameManager.player_damaged.emit(current_hp, max_hp, current_shield, max_shield)
			
	if shield_fx:
		shield_fx.visible = (current_shield > 0.0)
		shield_fx.queue_redraw()

func handle_regen(delta: float) -> void:
	var rate = hp_regen_rate + dome_heal_rate()
	if rate > 0.0 and current_hp < max_hp:
		current_hp = min(max_hp, current_hp + rate * delta)
		GameManager.player_damaged.emit(current_hp, max_hp, current_shield, max_shield)

# Doctrine and time scaling for ship weapons
func weapon_mult() -> float:
	return GameManager.doctrine_mod("dmg") * GameManager.damage_scale()

# JAMMER champion field: weapon cooldowns tick at half speed while jammed
const JAM_RATE := 0.5
var jam_timer: float = 0.0

func jam(duration: float) -> void:
	if jam_timer <= 0.0:
		var ft = preload("res://scenes/effects/floating_text.tscn").instantiate()
		ft.global_position = global_position + Vector2(0, -36)
		get_parent().add_child(ft)
		ft.setup("СИСТЕМИ ЗАГЛУШЕНО", Color(0.92, 0.25, 1.0), 1.1)
	jam_timer = maxf(jam_timer, duration)

func handle_weapons(delta: float) -> void:
	if jam_timer > 0.0:
		jam_timer -= delta
		delta *= JAM_RATE
	var cd_lvl = GameManager.get_skill_level("cooldown")
	var cd_mult = pow(0.88, cd_lvl)
	# Doctrine fire-rate change hits ship weapons only, not turrets and mines
	var ship_cd = cd_mult * GameManager.doctrine_mod("cd")
	if GameManager.overdrive_timer > 0.0:
		ship_cd *= 0.65
	
	# 1. Pulse Blaster
	var blaster_lvl = GameManager.get_skill_level("blaster")
	if blaster_lvl > 0:
		blaster_timer -= delta
		if blaster_timer <= 0.0:
			var base_cd = max(0.25, 0.65 - blaster_lvl * 0.06)
			blaster_timer = base_cd * ship_cd
			fire_blaster(blaster_lvl)
			
	# 2. Micro Missiles
	var missile_lvl = GameManager.get_skill_level("missiles")
	if missile_lvl > 0:
		missile_timer -= delta
		if missile_timer <= 0.0:
			missile_timer = max(0.9, 2.0 - missile_lvl * 0.2) * ship_cd
			fire_missiles(missile_lvl)
			
	# 3. Railgun Piercer
	var railgun_lvl = GameManager.get_skill_level("railgun")
	if railgun_lvl > 0:
		railgun_timer -= delta
		if railgun_timer <= 0.0:
			railgun_timer = max(1.5, 3.4 - railgun_lvl * 0.35) * ship_cd
			fire_railgun(railgun_lvl)
			
	# 4. EMP Shockwave
	var emp_lvl = GameManager.get_skill_level("emp")
	if emp_lvl > 0:
		emp_timer -= delta
		if emp_timer <= 0.0:
			emp_timer = max(3.5, 8.5 - emp_lvl * 1.1) * ship_cd
			fire_emp(emp_lvl)
	
	# 5. Hacking branch
	var virus_lvl = GameManager.get_skill_level("virus")
	if virus_lvl > 0:
		virus_timer -= delta
		if virus_timer <= 0.0:
			virus_timer = 2.4 * ship_cd
			fire_virus(virus_lvl)
	
	var glitch_lvl = GameManager.get_skill_level("glitch_field")
	glitch_radius = 0.0
	if glitch_lvl > 0:
		glitch_radius = 150.0 * (1.0 + 0.2 * (glitch_lvl - 1))
		glitch_phase += delta
		glitch_timer -= delta
		if glitch_timer <= 0.0:
			glitch_timer = 0.25
			pulse_glitch_field(glitch_lvl)

	# 6. Tier-5 skills
	var strike_lvl = GameManager.get_skill_level("orbital_strike")
	if strike_lvl > 0:
		strike_timer -= delta
		if strike_timer <= 0.0:
			strike_timer = (7.0 - (strike_lvl - 1)) * ship_cd
			fire_orbital_strike(strike_lvl)

	var stasis_lvl = GameManager.get_skill_level("stasis")
	if stasis_lvl > 0:
		stasis_cd -= delta
		if stasis_cd <= 0.0:
			stasis_cd = 22.0 - 3.0 * (stasis_lvl - 1)
			trigger_stasis(stasis_lvl)

	var mind_lvl = GameManager.get_skill_level("mind_control")
	if mind_lvl > 0:
		mind_cd -= delta
		if mind_cd <= 0.0 and hijack_shooter(mind_lvl):
			mind_cd = 12.0 - 2.0 * (mind_lvl - 1)

	# 7. Engineer branch
	var turret_lvl = GameManager.get_skill_level("turret")
	if turret_lvl > 0:
		turret_timer -= delta
		if turret_timer <= 0.0:
			turret_timer = 4.0 * cd_mult
			deploy_turret(turret_lvl)

	var mines_lvl = GameManager.get_skill_level("mines")
	if mines_lvl > 0:
		mine_timer -= delta
		if mine_timer <= 0.0:
			mine_timer = 2.6 * cd_mult
			drop_mines(mines_lvl)

func find_nearest_enemies(count: int = 1) -> Array[Object]:
	return EnemyRegistry.nearest(global_position, count)

func fire_blaster(lvl: int) -> void:
	var target = find_nearest_enemies(1)
	var shoot_dir = Vector2.UP.rotated(rotation)
	if target.size() > 0:
		shoot_dir = (target[0].global_position - global_position).normalized()
		
	var bolt_scene = preload("res://scenes/weapons/blaster_bolt.tscn")
	var damage = (22.0 + lvl * 6.0) * weapon_mult()
	var is_storm = GameManager.is_synergy_active("plasma_storm")
	var conductor_lvl = GameManager.get_skill_level("conductor")
	var can_chain = is_storm or conductor_lvl > 0
	
	var count = 1
	if is_storm or lvl >= 5:
		count = 3
	elif lvl >= 3:
		count = 2
		
	var spread = 0.22
	var left_wing = Vector2(-15, -8).rotated(rotation)
	var right_wing = Vector2(15, -8).rotated(rotation)
	var nose_emitter = Vector2(0, -22).rotated(rotation)
	
	for i in range(count):
		var spawn_pt = global_position
		if count == 1:
			blaster_barrel_toggle += 1
			spawn_pt += left_wing if (blaster_barrel_toggle % 2 == 0) else right_wing
		elif count == 2:
			spawn_pt += left_wing if (i == 0) else right_wing
		else:
			if i == 0: spawn_pt += left_wing
			elif i == 1: spawn_pt += right_wing
			else: spawn_pt += nose_emitter
			
		var ang_offset = (i - (count - 1) / 2.0) * spread
		var dir = shoot_dir.rotated(ang_offset)
		var bolt = bolt_scene.instantiate()
		bolt.setup(spawn_pt, dir, damage, 2 if is_storm else 1, can_chain)
		get_parent().add_child(bolt)
		
	AudioManager.play_sfx("laser", 0.15)

func fire_missiles(lvl: int) -> void:
	var targets = find_nearest_enemies(lvl + 1)
	# Sniper targeting: the first missile goes for a shooter that is aiming
	var sniper = FireDirector.nearest_aiming(global_position, 700.0)
	if sniper:
		targets.erase(sniper)
		targets.push_front(sniper)
	var is_valkyrie = GameManager.is_synergy_active("valkyrie_swarm")
	var missile_scene = preload("res://scenes/weapons/missile.tscn")
	var count = lvl + 1
	var damage = (45.0 + lvl * 15.0) * weapon_mult()
	var fwd = Vector2.UP.rotated(rotation)
	
	for i in range(count):
		missile_pod_toggle += 1
		var is_left = (missile_pod_toggle % 2 == 0)
		var pod_offset = Vector2(-14, 4) if is_left else Vector2(14, 4)
		var spawn_pt = global_position + pod_offset.rotated(rotation)
		
		# Emerge angled from missile bay
		var side_angle = (-0.35 if is_left else 0.35) + randf_range(-0.15, 0.15)
		var launch_dir = fwd.rotated(side_angle)
		
		var missile = missile_scene.instantiate()
		missile.setup(spawn_pt, launch_dir, damage, 60.0 + lvl * 10.0, is_valkyrie)
		if i < targets.size():
			missile.target = targets[i]
		get_parent().add_child(missile)
		
	AudioManager.play_sfx("missile", 0.1)

func fire_railgun(lvl: int) -> void:
	var target = find_nearest_enemies(1)
	# Sniper targeting: an aiming shooter takes priority over the nearest enemy
	var sniper = FireDirector.nearest_aiming(global_position, 900.0)
	if sniper:
		target = [sniper]
	var dir = Vector2.UP.rotated(rotation)
	if target.size() > 0:
		dir = (target[0].global_position - global_position).normalized()
		
	var nose_emitter = global_position + Vector2(0, -24).rotated(rotation)
	var rail_scene = preload("res://scenes/weapons/railgun_beam.tscn")
	var rail = rail_scene.instantiate()
	var dmg = (120.0 + lvl * 45.0) * weapon_mult()
	# setup() before add_child(): _ready() fires the beam, so it needs position and direction first
	rail.setup(nose_emitter, dir, dmg)
	get_parent().add_child(rail)

func fire_emp(lvl: int, force_apocalypse: bool = false) -> void:
	var is_apocalypse = force_apocalypse or GameManager.is_synergy_active("emp_apocalypse")
	var emp_scene = preload("res://scenes/weapons/emp_wave.tscn")
	var emp = emp_scene.instantiate()
	var rad = 220.0 + lvl * 40.0
	var dmg = (50.0 + lvl * 20.0) * weapon_mult()
	var stun = 2.0 + lvl * 0.5
	emp.setup(global_position, rad, dmg, stun, is_apocalypse)
	get_parent().add_child(emp)
	# Black ICE synergy: the wave carries the virus
	if GameManager.is_synergy_active("black_ice"):
		var vdps = virus_dps(GameManager.get_skill_level("virus"))
		for e in EnemyRegistry.in_radius(global_position, rad * (2.5 if is_apocalypse else 1.0)):
			if e.has_method("infect"):
				e.infect(5.0, vdps)

func virus_dps(lvl: int) -> float:
	return (5.0 + 4.0 * lvl) * (1.0 + 0.25 * (lvl - 1)) * GameManager.damage_scale() * GameManager.doctrine_mod("dot")

func fire_virus(lvl: int) -> void:
	var dps = virus_dps(lvl)
	var targets = lvl + 1 + int(GameManager.doctrine_mod("infect", 0.0))
	for e in EnemyRegistry.nearest(global_position, targets, 650.0):
		if e.has_method("infect"):
			e.infect(5.0, dps)

func pulse_glitch_field(lvl: int) -> void:
	var mult = 0.75 - 0.1 * (lvl - 1)
	var dmg = (3.0 + 3.0 * lvl) * GameManager.damage_scale() * GameManager.doctrine_mod("dot")
	for e in EnemyRegistry.in_radius(global_position, glitch_radius):
		if e.has_method("apply_slow"):
			e.apply_slow(0.35, mult)
			e.apply_dot(dmg)

func deploy_turret(lvl: int) -> void:
	spawned_turrets = spawned_turrets.filter(func(t): return is_instance_valid(t))
	if spawned_turrets.size() >= lvl + int(GameManager.doctrine_mod("turret_extra", 0.0)):
		return
	var turret = preload("res://scenes/weapons/sentry_turret.tscn").instantiate()
	var dmg = (14.0 + 4.0 * lvl) * GameManager.doctrine_mod("turret_dmg") * GameManager.damage_scale()
	var life = (12.0 + 2.0 * lvl) * GameManager.doctrine_mod("turret_life")
	turret.setup(global_position, dmg, life, GameManager.get_skill_level("tesla"), GameManager.get_skill_level("missile_battery"), GameManager.is_synergy_active("fortress"))
	get_parent().add_child(turret)
	spawned_turrets.append(turret)

func drop_mines(lvl: int) -> void:
	var count = mini(lvl, ProximityMine.MAX_MINES - ProximityMine.live_count)
	if count <= 0:
		return
	var emp = GameManager.is_synergy_active("emp_mines")
	var dmg = 40.0 * (1.0 + 0.25 * (lvl - 1)) * GameManager.doctrine_mod("turret_dmg") * GameManager.damage_scale()
	var radius = 75.0 * (1.4 if emp else 1.0)
	var mine_scene = preload("res://scenes/weapons/proximity_mine.tscn")
	# Drop from the stern, spread sideways
	var back = Vector2.DOWN.rotated(rotation) * 30.0
	var side = Vector2.RIGHT.rotated(rotation)
	for i in range(count):
		var mine = mine_scene.instantiate()
		mine.setup(global_position + back + side * (i - (count - 1) / 2.0) * 26.0, dmg, radius, 1.5 if emp else 0.0)
		get_parent().add_child(mine)

# WPN-05: hits a shooter that is aiming, else the densest cluster nearby
func fire_orbital_strike(lvl: int) -> void:
	var radius = 130.0 + 20.0 * (lvl - 1)
	var target = FireDirector.nearest_aiming(global_position, STRIKE_SEARCH)
	if target == null:
		var best_n := 0
		for c in EnemyRegistry.nearest(global_position, 8, STRIKE_SEARCH):
			var n := EnemyRegistry.in_radius(c.global_position, radius).size()
			if n > best_n:
				best_n = n
				target = c
	if target == null:
		strike_timer = 0.5
		return
	var strike = preload("res://scenes/weapons/orbital_strike.gd").new()
	strike.setup(target.global_position, radius, (150.0 + 75.0 * (lvl - 1)) * weapon_mult())
	get_parent().add_child(strike)

# DEF-05: when the shield breaks, a nova clears the area and the shield comes back at 50%
func _on_shield_break() -> void:
	var lvl = GameManager.get_skill_level("shield_reboot")
	if lvl <= 0 or reboot_cd > 0.0:
		return
	reboot_cd = 20.0 - 4.0 * (lvl - 1)
	nova_time = 0.45
	var dmg = (40.0 + 30.0 * lvl) * weapon_mult()
	for e in EnemyRegistry.in_radius(global_position, REBOOT_RADIUS):
		e.take_damage(dmg, (e.global_position - global_position).normalized() * 2.0)
	EnemyShots.clear_radius(global_position, REBOOT_RADIUS, CyberPalette.CYAN)
	current_shield = max_shield * 0.5
	AudioManager.play_sfx("emp_blast", 0.05, -2.0)

# OVC-05: stuns everything nearby and freezes hostile shots
func trigger_stasis(lvl: int) -> void:
	var dur = 1.5 + 0.5 * (lvl - 1)
	stasis_time = dur
	stasis_ring = 0.0
	for e in EnemyRegistry.in_radius(global_position, STASIS_RANGE):
		e.apply_stun(dur)
	AudioManager.play_sfx("emp_blast", 0.02, 1.0)
	var ft = preload("res://scenes/effects/floating_text.tscn").instantiate()
	ft.global_position = global_position + Vector2(0, -40)
	get_parent().add_child(ft)
	ft.setup("СТОП-КАДР", CyberPalette.YELLOW, 1.4)

# HCK-05: turns the nearest shooter (aiming ones first); false when none in range
func hijack_shooter(lvl: int) -> bool:
	var target = FireDirector.nearest_aiming(global_position, MIND_RANGE)
	if target == null:
		for e in EnemyRegistry.nearest(global_position, 12, MIND_RANGE):
			if e is EnemyBase and e.kind in SHOOTER_KINDS and e.hijack_time <= 0.0:
				target = e
				break
	if target == null or not target is EnemyBase:
		return false
	target.hijack(4.0 + 2.0 * (lvl - 1))
	return true

# ENG-05: repair while inside any turret dome
func dome_heal_rate() -> float:
	var lvl = GameManager.get_skill_level("dome")
	if lvl <= 0:
		return 0.0
	return 3.0 + 2.0 * (lvl - 1) if near_turret(dome_radius()) else 0.0

static func dome_radius() -> float:
	return 110.0 + 20.0 * (GameManager.get_skill_level("dome") - 1)

func near_turret(radius: float) -> bool:
	for t in spawned_turrets:
		if is_instance_valid(t) and global_position.distance_squared_to(t.global_position) <= radius * radius:
			return true
	return false

func take_damage(amount: float, source_pos: Vector2 = Vector2.ZERO) -> void:
	if is_dashing:
		# Phase Shift invulnerability frames (i-frames)
		return
		
	var actual_damage = amount * (1.0 - damage_reduction) * GameManager.doctrine_mod("taken")
	# Fortress synergy: turret perimeter shields the hull
	if GameManager.is_synergy_active("fortress") and near_turret(170.0):
		actual_damage *= 0.7
	shield_timer = shield_recharge_delay
	
	# Spawn side hull sparks where the impact came from (rate-limited)
	var show_fx = hit_fx_cooldown <= 0.0
	if show_fx:
		hit_fx_cooldown = HIT_FX_INTERVAL
		if source_pos != Vector2.ZERO:
			var local_dir = (to_local(source_pos)).normalized()
			spawn_side_damage_sparks(local_dir * 18.0, local_dir)
		else:
			spawn_side_damage_sparks(Vector2(randf_range(-15, 15), randf_range(-15, 15)), Vector2.UP.rotated(randf() * TAU))
	
	# Shield absorbs first
	if current_shield > 0.0:
		if current_shield >= actual_damage:
			current_shield -= actual_damage
			actual_damage = 0.0
			AudioManager.play_sfx("shield_hit", 0.15)
		else:
			actual_damage -= current_shield
			current_shield = 0.0
			AudioManager.play_sfx("shield_hit", 0.1, 2.0)
			_on_shield_break()
			# EMP Apocalypse triggers on shield break!
			if GameManager.is_synergy_active("emp_apocalypse"):
				fire_emp(GameManager.get_skill_level("emp"), true)
				
	# Tank doctrine: a heavy single hit raises the dome early (at most every 5 s)
	if has_aegis() and actual_damage >= max_hp * AEGIS_HEAVY_HIT and aegis_time <= 0.0 and aegis_cd <= AEGIS_PERIOD - 5.0:
		raise_aegis()

	if actual_damage > 0.0:
		current_hp -= actual_damage
		if show_fx:
			flash_hit()
	
	if show_fx or current_hp <= 0.0:
		GameManager.player_damaged.emit(current_hp, max_hp, current_shield, max_shield)
	
	if current_hp <= 0.0:
		if GameManager.has_reboot_available():
			GameManager.consume_reboot()
			current_hp = max_hp * 0.5
			current_shield = max_shield * 0.5
			fire_emp(3, true)
			AudioManager.play_sfx("emp_blast", 0.05, 3.0)
			var ft_scene = preload("res://scenes/effects/floating_text.tscn")
			var ft = ft_scene.instantiate()
			ft.global_position = global_position + Vector2(0, -35)
			get_parent().add_child(ft)
			ft.setup("АВАРІЙНИЙ РЕБУТ!", Color(0.2, 1.0, 0.9), 2.2)
			GameManager.player_damaged.emit(current_hp, max_hp, current_shield, max_shield)
			return
		die()

func heal(amount: float) -> void:
	current_hp = min(max_hp, current_hp + amount)
	GameManager.player_damaged.emit(current_hp, max_hp, current_shield, max_shield)
	var ft_scene = preload("res://scenes/effects/floating_text.tscn")
	var ft = ft_scene.instantiate()
	ft.global_position = global_position + Vector2(0, -20)
	get_parent().add_child(ft)
	ft.setup("+" + str(int(amount)), Color(0.2, 1.0, 0.4), 1.2)

func flash_hit() -> void:
	if sprite:
		sprite.modulate = Color(3.0, 0.4, 0.4)
		hit_flash = 0.12

func die() -> void:
	GameManager.trigger_game_over(false)

func _on_magnet_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("pickups") and body.has_method("attract"):
		body.attract(self)

func _on_magnet_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("pickups") and area.has_method("attract"):
		area.attract(self)
