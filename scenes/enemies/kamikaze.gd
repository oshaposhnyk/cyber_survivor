extends EnemyBase

# Blast stats at spawn time; damage grows with the wave scaling of contact_damage
const BLAST_RADIUS := 90.0
const BLAST_DAMAGE := 35.0
const BASE_CONTACT := 25.0
# Warning colours: yellow-white, so the 0.55 s fuse never reads as a hit flash (white)
# or as plain damage (red)
const WARN_HOT := Color(2.4, 2.1, 0.3)
const WARN_RING := Color(1.0, 0.85, 0.15)

var primed: bool = false
var prime_timer: float = 0.55
var blink_timer: float = 0.0

func _tick(delta: float) -> void:
	if primed:
		update_status(delta)
		if is_dead:
			return
		prime_timer -= delta
		blink_timer += delta * 25.0
		body_tint = WARN_HOT if sin(blink_timer) > 0.0 else Color.WHITE
		if prime_timer <= 0.0:
			self_destruct()
			return
		step_motion(delta)
		return

	if stun_timer <= 0.0 and is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist < 120.0 and not primed:
			prime_drone()
	super._tick(delta)

func prime_drone() -> void:
	primed = true
	move_speed *= 1.45
	# Lunge: the primed branch keeps this velocity, so the speed-up must be applied here
	if is_instance_valid(target_player):
		velocity = (target_player.global_position - global_position).normalized() * move_speed
	Swarm.instance.add_overlay(self)
	AudioManager.play_sfx("kamikaze_arm", 0.05)

func has_overlay() -> bool:
	return primed or super.has_overlay()

# Ground ring of the blast radius, filling as the fuse burns down
func draw_overlay(c: Node2D) -> void:
	super.draw_overlay(c)
	if not primed or is_dead:
		return
	var k := clampf(1.0 - prime_timer / 0.55, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(blink_timer)
	c.draw_circle(Vector2.ZERO, BLAST_RADIUS * k, Color(WARN_RING, 0.12 + 0.08 * pulse))
	c.draw_arc(Vector2.ZERO, BLAST_RADIUS, 0.0, TAU, 40, Color(WARN_RING, 0.55 + 0.35 * pulse), 2.5)

func self_destruct() -> void:
	if is_dead:
		return
	is_dead = true

	EnemyBase.spawn_explosion(world, global_position, 80.0, Color(1.0, 0.2, 0.1), true)

	AudioManager.play_sfx("heavy_explosion", 0.1, 2.0)

	# Damage player if in blast radius
	if is_instance_valid(target_player):
		var dist = global_position.distance_to(target_player.global_position)
		if dist <= BLAST_RADIUS and target_player.has_method("take_damage"):
			var falloff = 1.0 - (dist / BLAST_RADIUS) * 0.5
			target_player.take_damage(BLAST_DAMAGE * (contact_damage / BASE_CONTACT) * falloff, global_position)

	# A detonation still counts as a kill and triggers hack effects
	GameManager.add_kill()
	on_death_hacks()
	drop_loot()
