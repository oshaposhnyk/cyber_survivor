extends CharacterBody2D

# Combat Android ARC-01 (Mecha Vanguard)

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

var is_thrusting: bool = false
var thruster_time: float = 0.0

func _draw() -> void:
	# Dual Ion Thruster Exhaust Plumes (located at engine ports Vector2(-11, 20) and Vector2(11, 20))
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

# Weapon Timers
var blaster_timer: float = 0.0
var missile_timer: float = 0.0
var railgun_timer: float = 0.0
var emp_timer: float = 0.0

# Active Orbital Drones list
var spawned_drones: Array[Node2D] = []

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
	# 1. Armor & Health
	var armor_lvl = GameManager.get_skill_level("armor")
	max_hp = base_max_hp + armor_lvl * 35.0
	current_hp = min(current_hp, max_hp)
	damage_reduction = armor_lvl * 0.12
	
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
		hp_regen_rate += 8.0 # Bastion triple healing
		
	# 4. Magnet Radius
	var magnet_lvl = GameManager.get_skill_level("magnet")
	if magnet_shape and magnet_shape.shape is CircleShape2D:
		magnet_shape.shape.radius = 85.0 + magnet_lvl * 60.0
		
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
		get_parent().call_deferred("add_child", d)
		spawned_drones.append(d)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.State.PLAYING:
		return
		
	handle_movement(delta)
	handle_shield_recharge(delta)
	handle_regen(delta)
	handle_weapons(delta)

func handle_movement(delta: float) -> void:
	var input_vec = Vector2.ZERO
	input_vec.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vec.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_vec = input_vec.normalized()
	
	var speed_lvl = GameManager.get_skill_level("speed")
	var move_speed = base_speed * (1.0 + speed_lvl * 0.18)
	
	velocity = input_vec * move_speed
	move_and_slide()
	
	is_thrusting = input_vec.length() > 0.05
	queue_redraw()
	
	if is_thrusting:
		rotation = lerp_angle(rotation, input_vec.angle() + PI / 2.0, 12.0 * delta)

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
	if hp_regen_rate > 0.0 and current_hp < max_hp:
		current_hp = min(max_hp, current_hp + hp_regen_rate * delta)
		GameManager.player_damaged.emit(current_hp, max_hp, current_shield, max_shield)

func handle_weapons(delta: float) -> void:
	var cd_lvl = GameManager.get_skill_level("cooldown")
	var cd_mult = pow(0.88, cd_lvl)
	
	# 1. Pulse Blaster
	var blaster_lvl = GameManager.get_skill_level("blaster")
	if blaster_lvl > 0:
		blaster_timer -= delta
		if blaster_timer <= 0.0:
			var base_cd = max(0.25, 0.65 - blaster_lvl * 0.06)
			blaster_timer = base_cd * cd_mult
			fire_blaster(blaster_lvl)
			
	# 2. Micro Missiles
	var missile_lvl = GameManager.get_skill_level("missiles")
	if missile_lvl > 0:
		missile_timer -= delta
		if missile_timer <= 0.0:
			missile_timer = max(0.9, 2.0 - missile_lvl * 0.2) * cd_mult
			fire_missiles(missile_lvl)
			
	# 3. Railgun Piercer
	var railgun_lvl = GameManager.get_skill_level("railgun")
	if railgun_lvl > 0:
		railgun_timer -= delta
		if railgun_timer <= 0.0:
			railgun_timer = max(1.5, 3.4 - railgun_lvl * 0.35) * cd_mult
			fire_railgun(railgun_lvl)
			
	# 4. EMP Shockwave
	var emp_lvl = GameManager.get_skill_level("emp")
	if emp_lvl > 0:
		emp_timer -= delta
		if emp_timer <= 0.0:
			emp_timer = max(3.5, 8.5 - emp_lvl * 1.1) * cd_mult
			fire_emp(emp_lvl)

func find_nearest_enemies(count: int = 1) -> Array[Node2D]:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var valid_enemies: Array[Dictionary] = []
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			valid_enemies.append({"enemy": enemy, "dist": dist})
	valid_enemies.sort_custom(func(a, b): return a["dist"] < b["dist"])
	
	var res: Array[Node2D] = []
	for i in range(min(count, valid_enemies.size())):
		res.append(valid_enemies[i]["enemy"])
	return res

func fire_blaster(lvl: int) -> void:
	var target = find_nearest_enemies(1)
	var shoot_dir = Vector2.UP.rotated(rotation - PI/2.0)
	if target.size() > 0:
		shoot_dir = (target[0].global_position - global_position).normalized()
		
	var bolt_scene = preload("res://scenes/weapons/blaster_bolt.tscn")
	var damage = 22.0 + lvl * 6.0
	var is_storm = GameManager.is_synergy_active("plasma_storm")
	var conductor_lvl = GameManager.get_skill_level("conductor")
	var can_chain = is_storm or conductor_lvl > 0
	
	var count = 1
	if is_storm:
		count = 3
	elif lvl >= 5:
		count = 3
	elif lvl >= 3:
		count = 2
		
	var spread = 0.25
	for i in range(count):
		var ang_offset = (i - (count - 1) / 2.0) * spread
		var dir = shoot_dir.rotated(ang_offset)
		var bolt = bolt_scene.instantiate()
		bolt.setup(global_position, dir, damage, 2 if is_storm else 1, can_chain)
		get_parent().add_child(bolt)
		
	AudioManager.play_sfx("laser", 0.15)

func fire_missiles(lvl: int) -> void:
	var targets = find_nearest_enemies(lvl + 1)
	var is_valkyrie = GameManager.is_synergy_active("valkyrie_swarm")
	var missile_scene = preload("res://scenes/weapons/missile.tscn")
	var count = lvl + 1
	var damage = 45.0 + lvl * 15.0
	
	for i in range(count):
		var launch_dir = Vector2.UP.rotated(randf() * TAU)
		var missile = missile_scene.instantiate()
		missile.setup(global_position, launch_dir, damage, 60.0 + lvl * 10.0, is_valkyrie)
		if i < targets.size():
			missile.target = targets[i]
		get_parent().add_child(missile)
		
	AudioManager.play_sfx("missile", 0.1)

func fire_railgun(lvl: int) -> void:
	var target = find_nearest_enemies(1)
	var dir = Vector2.UP.rotated(rotation - PI/2.0)
	if target.size() > 0:
		dir = (target[0].global_position - global_position).normalized()
		
	var rail_scene = preload("res://scenes/weapons/railgun_beam.tscn")
	var rail = rail_scene.instantiate()
	var dmg = 120.0 + lvl * 45.0
	get_parent().add_child(rail)
	rail.setup(global_position, dir, dmg)

func fire_emp(lvl: int, force_apocalypse: bool = false) -> void:
	var is_apocalypse = force_apocalypse or GameManager.is_synergy_active("emp_apocalypse")
	var emp_scene = preload("res://scenes/weapons/emp_wave.tscn")
	var emp = emp_scene.instantiate()
	var rad = 220.0 + lvl * 40.0
	var dmg = 50.0 + lvl * 20.0
	var stun = 2.0 + lvl * 0.5
	emp.setup(global_position, rad, dmg, stun, is_apocalypse)
	get_parent().add_child(emp)

func take_damage(amount: float) -> void:
	var actual_damage = amount * (1.0 - damage_reduction)
	shield_timer = shield_recharge_delay
	
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
			# EMP Apocalypse triggers on shield break!
			if GameManager.is_synergy_active("emp_apocalypse"):
				fire_emp(GameManager.get_skill_level("emp"), true)
				
	if actual_damage > 0.0:
		current_hp -= actual_damage
		flash_hit()
		
	GameManager.player_damaged.emit(current_hp, max_hp, current_shield, max_shield)
	
	if current_hp <= 0.0:
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
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)

func die() -> void:
	GameManager.trigger_game_over(false)

func _on_magnet_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("pickups") and body.has_method("attract"):
		body.attract(self)

func _on_magnet_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("pickups") and area.has_method("attract"):
		area.attract(self)
