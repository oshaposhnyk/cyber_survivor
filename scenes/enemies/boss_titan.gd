extends CharacterBody2D

# Dreadnought Titan Boss "LEVIATHAN-01"
# Massive health, multi-phase attacks, drops Quantum Core with +500 XP

@export var max_health: float = 12000.0
@export var move_speed: float = 85.0
@export var contact_damage: float = 45.0

const LASER = preload("res://scenes/weapons/enemy_laser.tscn")
const MINIONS = ["drone", "kamikaze"]
# Hit circle for registry-based projectile hits (matches the CollisionShape2D)
const HIT_RADIUS := 120.0
var hit_radius: float = HIT_RADIUS

var current_health: float = 12000.0
var knockback: Vector2 = Vector2.ZERO
var is_dead: bool = false
var target_player: Node2D = null

# Attack Timers
var laser_timer: float = 2.0
var radial_timer: float = 3.0
var spiral_timer: float = 0.0
var spiral_angle: float = 0.0
var summon_timer: float = 6.0
var charge_timer: float = 7.0
var charge_time: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO
var hit_flash: float = 0.0
var hud_ref: Node = null

var pulse_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _enter_tree() -> void:
	EnemyRegistry.register(self)

func _exit_tree() -> void:
	EnemyRegistry.unregister(self)

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	collision_layer = 2 # Layer 2: Enemies
	collision_mask = 1  # Layer 1: Player
	# Scales with run time like the regular swarm
	max_health *= 1.0 + GameManager.time_survived / 60.0 * 0.25
	current_health = max_health
	find_player()
	
	# Connect to HUD boss health bar
	hud_ref = get_tree().get_first_node_in_group("hud")
	if hud_ref and hud_ref.has_method("show_boss_bar"):
		hud_ref.show_boss_bar("ДРЕДНОУТ-ТИТАН «LEVIATHAN-01»", max_health)

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]

func _physics_process(delta: float) -> void:
	if is_dead:
		return
		
	pulse_time += delta * 3.0
	queue_redraw()
	
	if not is_instance_valid(target_player):
		find_player()
		return
		
	var to_player = target_player.global_position - global_position
	var dist = to_player.length()
	
	# Rotate towards player
	rotation = lerp_angle(rotation, to_player.angle() + PI / 2.0, 4.0 * delta)
	
	if infected_time > 0.0:
		infected_time -= delta
		current_health -= infect_dps * delta
		if is_instance_valid(hud_ref):
			hud_ref.update_boss_hp(current_health)
		if current_health <= 0.0:
			die()
			return
	if hit_flash > 0.0:
		hit_flash -= delta
		if hit_flash <= 0.0 and sprite:
			sprite.modulate = Color.WHITE
	
	var hp_frac = current_health / max_health
	var enraged = hp_frac < 0.35
	
	# Charge attack: straight-line ram
	charge_timer -= delta
	if charge_time > 0.0:
		charge_time -= delta
		velocity = charge_dir * 520.0
	else:
		if charge_timer <= 0.0 and dist < 900.0:
			charge_timer = 5.0 if enraged else 8.0
			charge_time = 0.7
			charge_dir = to_player.normalized()
			AudioManager.play_sfx("missile", 0.05, 4.0)
		var cur_speed = move_speed * (1.4 if enraged else 1.0)
		velocity = to_player.normalized() * cur_speed + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	global_position += velocity * delta
	
	# Contact damage with player
	if dist <= 160.0 and target_player.has_method("take_damage"):
		target_player.take_damage(contact_damage * delta * 2.5, global_position)
		
	# Attack 1: aimed laser fan (all phases)
	laser_timer -= delta
	if laser_timer <= 0.0:
		laser_timer = 1.1 if enraged else 1.6
		fire_heavy_lasers(5 if hp_frac < 0.65 else 3)
		
	# Attack 2: radial ring of plasma (all phases, denser later)
	radial_timer -= delta
	if radial_timer <= 0.0:
		radial_timer = 2.2 if hp_frac < 0.65 else 3.2
		fire_radial_burst(24 if enraged else (18 if hp_frac < 0.65 else 12))
	
	# Attack 3: rotating spiral stream (phase 3)
	if enraged:
		spiral_timer -= delta
		if spiral_timer <= 0.0:
			spiral_timer = 0.11
			fire_spiral()
	
	# Attack 4: summon escorts
	summon_timer -= delta
	if summon_timer <= 0.0:
		summon_timer = 6.0 if enraged else 9.0
		summon_minions(10 if enraged else 6)

# Boss projectiles use enemy_laser (hits the player). The old radial burst and
# missiles reused player projectiles, which only damaged other enemies.
func _fire_laser(dir: Vector2, dmg: float, offset: float = 140.0) -> void:
	var laser = LASER.instantiate()
	laser.setup(global_position + dir * offset, dir, dmg)
	get_parent().add_child(laser)

func fire_heavy_lasers(count: int) -> void:
	if not is_instance_valid(target_player):
		return
	var base_dir = (target_player.global_position - global_position).normalized()
	for i in range(count):
		_fire_laser(base_dir.rotated((i - (count - 1) / 2.0) * 0.16), 20.0)
	AudioManager.play_sfx("laser", 0.1, 1.0)

func fire_radial_burst(count: int) -> void:
	var start = randf() * TAU
	for i in range(count):
		var ang = start + (TAU / count) * i
		_fire_laser(Vector2(cos(ang), sin(ang)), 16.0)
	AudioManager.play_sfx("railgun", 0.15, -2.0)

func fire_spiral() -> void:
	spiral_angle += 0.33
	for k in range(3):
		var ang = spiral_angle + k * TAU / 3.0
		_fire_laser(Vector2(cos(ang), sin(ang)), 12.0)

func summon_minions(count: int) -> void:
	if EnemyRegistry.count() > 1000:
		return
	for i in range(count):
		var ang = randf() * TAU
		Swarm.instance.spawn(MINIONS[i % MINIONS.size()], global_position + Vector2(cos(ang), sin(ang)) * randf_range(90.0, 160.0))

# Hacking effects: the boss ignores slows; virus and fields deal plain damage
var infected_time: float = 0.0
var infect_dps: float = 0.0

func infect(duration: float, dps: float) -> void:
	infected_time = max(infected_time, duration)
	infect_dps = max(infect_dps, dps)

func apply_slow(_duration: float, _mult: float) -> void:
	pass

func apply_stun(_duration: float) -> void:
	pass

func apply_dot(amount: float) -> void:
	take_damage(amount)

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if is_dead:
		return
		
	current_health -= amount
	knockback = knockback_dir * 12.0 # Very high poise
	
	# Timer-driven flash (no Tween per hit)
	if sprite:
		sprite.modulate = Color(2.2, 1.2, 1.2)
		hit_flash = 0.08
		
	if is_instance_valid(hud_ref) and hud_ref.has_method("update_boss_hp"):
		hud_ref.update_boss_hp(current_health)
		
	if current_health <= 0.0:
		die()

func _draw() -> void:
	# Enraged Red Energy Shield Ring
	var a = 0.4 + 0.2 * sin(pulse_time)
	var col = Color(1.0, 0.2, 0.1, a)
	draw_arc(Vector2.ZERO, 150.0, 0, TAU, 48, col, 3.0)
	
	# Orbiting Targeting Reticle
	var ret_ang = pulse_time * 1.5
	var p = Vector2(cos(ret_ang), sin(ret_ang)) * 165.0
	draw_circle(p, 4.0, Color(1.0, 0.8, 0.2, a))

func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Multi-stage explosions across chassis
	var exp_scene = preload("res://scenes/effects/explosion.tscn")
	for i in range(4):
		var exp_node = exp_scene.instantiate()
		exp_node.global_position = global_position + Vector2(randf_range(-35, 35), randf_range(-35, 35))
		exp_node.max_radius = 85.0
		exp_node.blast_color = Color(1.0, randf_range(0.2, 0.6), 0.1)
		get_parent().call_deferred("add_child", exp_node)
		
	AudioManager.play_sfx("heavy_explosion", 0.05, 5.0)
	GameManager.add_kill()
	
	# Hide Boss Bar in HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_boss_bar"):
		hud.hide_boss_bar()
	if hud and hud.has_method("show_announcement"):
		hud.show_announcement("ДРЕДНОУТ ЗНИЩЕНО", "Квантове ядро: +500 досвіду")
		
	# DROP GIGANTIC QUANTUM CORE (+500 XP)
	var core_scene = preload("res://scenes/pickups/quantum_core.tscn")
	var core = core_scene.instantiate()
	core.global_position = global_position
	get_parent().call_deferred("add_child", core)
	
	# Drop rich surrounding loot
	# Through EnemyBase so the shared pickup cap and counter stay accurate
	for i in range(8):
		EnemyBase.spawn_pickup(get_parent(), global_position + Vector2(randf_range(-45, 45), randf_range(-45, 45)), 1) # Gold
		
	for i in range(2):
		EnemyBase.spawn_pickup(get_parent(), global_position + Vector2(randf_range(-35, 35), randf_range(-35, 35)), 2) # Repair core
		
	queue_free()
