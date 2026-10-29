extends Node2D

# Enemy projectile. No physics: it tests the player and enemies by distance, so the
# anti-projectile mechanics can flip its side in the same frame without mask changes.
# States:
#   HOSTILE    normal enemy fire, hits the player
#   ROGUE      fired from inside the glitch field: hits enemies (not its shooter) and the player
#   HACKED     turned by Data Spike: green, hits enemies only
#   REFLECTED  sent back by the deflector shield: cyan, hits enemies only

enum State { HOSTILE, ROGUE, HACKED, REFLECTED }

# 285 px/s (was 380): slow enough to dodge in flight at normal ship speed
@export var speed: float = 285.0
@export var damage: float = 12.0
@export var lifetime: float = 3.0

const PLAYER_RADIUS := 22.0
const HIT_RADIUS := 6.0
const POP_TIME := 0.15
# Damage of a shot that turned against the swarm, before the time curve
const FRIENDLY_DAMAGE := 30.0
# Data Spike turns hostile shots once, when they first come this close
const HACK_CHECK_RADIUS := 160.0
# Turned shots steer towards their target (rad/s), so a strafing shooter is still hit
const HOMING_TURN := 5.0

# Hostile fire has its own shape and hue: a dark-rimmed orange-red diamond.
# Player bolts are cyan streaks, so the two never read alike, also without colour.
const HOSTILE := Color(1.0, 0.32, 0.12)
const RIM := Color(0.05, 0.0, 0.02, 0.95)
const CORE := Color(1.0, 0.95, 0.8)
const SHAPE := [Vector2(0, -12), Vector2(6, 0), Vector2(0, 12), Vector2(-6, 0)]
const GLOW_TEX := preload("res://assets/sprites/fx/glow_soft.png")
const RING_TEX := preload("res://assets/sprites/fx/ring.png")

var velocity: Vector2 = Vector2.ZERO
var state: State = State.HOSTILE
var shooter: Object = null
var hack_checked: bool = false
var home_target: Object = null
# Shots that start inside their shooter (rogue, mind-controlled) must not hit it
var ignore_shooter: bool = false
var pop_timer: float = -1.0
var pop_color: Color = Color.WHITE

@onready var glow: Sprite2D = $Glow

func setup(p_pos: Vector2, p_dir: Vector2, p_damage: float, p_shooter: Object = null) -> void:
	global_position = p_pos
	velocity = p_dir.normalized() * speed
	rotation = p_dir.angle() + PI / 2.0
	damage = p_damage
	shooter = p_shooter

func _enter_tree() -> void:
	EnemyShots.register(self)

func _exit_tree() -> void:
	EnemyShots.unregister(self)

func is_live() -> bool:
	return pop_timer < 0.0

# Shots that still threaten the player and can be cleared by defences
func is_hostile() -> bool:
	return state == State.HOSTILE or state == State.ROGUE

func body_color() -> Color:
	match state:
		State.HACKED:
			return CyberPalette.GREEN
		State.REFLECTED:
			return CyberPalette.CYAN
	return HOSTILE

func _draw() -> void:
	if pop_timer >= 0.0:
		var k := pop_timer / POP_TIME
		var s := 34.0 * (1.5 - k)
		draw_texture_rect(RING_TEX, Rect2(-Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(pop_color, k))
		var g := 26.0 * k
		draw_texture_rect(GLOW_TEX, Rect2(-Vector2(g, g) * 0.5, Vector2(g, g)), false, Color(pop_color, k))
		return
	var rim := PackedVector2Array()
	var body := PackedVector2Array()
	for p in SHAPE:
		rim.append(p * 1.45)
		body.append(p)
	# Rogue shots keep the hostile body with a glitch-green rim
	draw_colored_polygon(rim, CyberPalette.GREEN if state == State.ROGUE else RIM)
	draw_colored_polygon(body, body_color())
	draw_circle(Vector2.ZERO, 2.6, CORE)

func _physics_process(delta: float) -> void:
	if pop_timer >= 0.0:
		pop_timer -= delta
		queue_redraw()
		if pop_timer <= 0.0:
			queue_free()
		return

	var player = GameManager.player_node
	var scale_t := 1.0
	if is_hostile() and is_instance_valid(player):
		scale_t = player.dilation_factor(global_position)
		if _blocked_by_turret(player):
			return
		if not hack_checked and state == State.HOSTILE and global_position.distance_squared_to(player.global_position) <= HACK_CHECK_RADIUS * HACK_CHECK_RADIUS:
			hack_checked = true
			if randf() < player.hack_chance():
				hack()
	if home_target and not home_target.is_dead:
		var want: float = (home_target.global_position - global_position).angle()
		var cur := velocity.angle()
		var turned := cur + clampf(angle_difference(cur, want), -HOMING_TURN * delta, HOMING_TURN * delta)
		velocity = Vector2.from_angle(turned) * velocity.length()
		rotation = turned + PI / 2.0
	global_position += velocity * delta * scale_t

	# Enemies first: turned and rogue shots damage the swarm
	if state != State.HOSTILE:
		# Reflected shots are meant to hit their shooter; shots fired from inside it are not
		var exclude := [shooter] if shooter and ignore_shooter else []
		var hit = EnemyRegistry.first_hit(global_position, HIT_RADIUS, exclude)
		if hit:
			hit.take_damage(FRIENDLY_DAMAGE * GameManager.damage_scale(), velocity.normalized())
			pop(body_color())
			return
	if is_hostile() and is_instance_valid(player) and global_position.distance_squared_to(player.global_position) <= PLAYER_RADIUS * PLAYER_RADIUS:
		player.take_laser_hit(self)
		if pop_timer < 0.0 and is_hostile():
			pop(HOSTILE)
		return

	lifetime -= delta
	if lifetime <= 0:
		queue_free()

# Engineer: turret hulls stop hostile fire
func _blocked_by_turret(player: Node) -> bool:
	for t in player.spawned_turrets:
		if is_instance_valid(t) and global_position.distance_squared_to(t.global_position) <= 18.0 * 18.0:
			pop(CyberPalette.ORANGE)
			return true
	return false

# Stops the shot and plays a short flash in `color`, then frees it
func pop(color: Color) -> void:
	if pop_timer >= 0.0:
		return
	pop_timer = POP_TIME
	pop_color = color
	glow.visible = false
	queue_redraw()

func _turn(dir: Vector2, new_state: State) -> void:
	state = new_state
	velocity = dir.normalized() * speed * 1.4
	rotation = dir.angle() + PI / 2.0
	lifetime = 2.0
	glow.modulate = Color(body_color(), 0.8)
	queue_redraw()

# Deflector shield: back at the shooter, or straight back
func reflect() -> void:
	var dir := -velocity
	if shooter and not shooter.is_dead:
		dir = shooter.global_position - global_position
		home_target = shooter
	_turn(dir, State.REFLECTED)

# Data Spike: hijacked towards the nearest enemy
func hack() -> void:
	var found = EnemyRegistry.nearest(global_position, 1, 600.0, [shooter] if shooter else [])
	var dir := -velocity
	if not found.is_empty():
		dir = found[0].global_position - global_position
		home_target = found[0]
	_turn(dir, State.HACKED)

# Glitch field: the shooter's targeting is scrambled, the shot hits whatever it meets
func make_rogue() -> void:
	state = State.ROGUE
	ignore_shooter = true
	queue_redraw()

# Fired by a mind-controlled shooter: green from the start, homing on `target`
func turn_hacked(target: Object) -> void:
	home_target = target
	ignore_shooter = true
	_turn(velocity, State.HACKED)
