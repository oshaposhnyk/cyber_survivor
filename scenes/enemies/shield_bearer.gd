class_name ShieldBearer
extends EnemyBase

# Slow support unit: projects an energy dome that halves direct damage to nearby allies.
# Kill it first, or burn the pack with DoT, which ignores the dome.

const WARD_RADIUS := 190.0
const WARD_MULT := 0.5
const WARD_TICK := 0.25
const MAX_TETHERS := 10
const DOME_COLOR := Color(0.3, 0.75, 1.0)

var ward_timer: float = 0.0
var dome_phase: float = 0.0
var tethered: Array = []

func _tick(delta: float) -> void:
	super._tick(delta)
	if is_dead:
		return
	dome_phase += delta
	# A stunned bearer drops its dome
	if stun_timer <= 0.0:
		ward_timer -= delta
		if ward_timer <= 0.0:
			ward_timer = WARD_TICK
			project_ward()
	else:
		tethered.clear()

func project_ward() -> void:
	tethered.clear()
	for e in EnemyRegistry.in_radius(global_position, WARD_RADIUS):
		# Bearers never shield each other, or clusters of them become unkillable
		if e is ShieldBearer or not e.has_method("apply_ward"):
			continue
		e.apply_ward(WARD_TICK + 0.1, WARD_MULT)
		if tethered.size() < MAX_TETHERS:
			tethered.append(e)

func has_overlay() -> bool:
	return true

func draw_overlay(c: Node2D) -> void:
	# A champion bearer also shows its champion aura
	super.draw_overlay(c)
	if is_dead or stun_timer > 0.0:
		return
	var pulse = 0.5 + 0.5 * sin(dome_phase * 3.0)
	c.draw_circle(Vector2.ZERO, WARD_RADIUS, Color(DOME_COLOR, 0.05 + 0.03 * pulse))
	# Rotating segmented rim
	var segs = 12
	for i in range(segs):
		var a0 = TAU * i / segs + dome_phase * 0.6
		c.draw_arc(Vector2.ZERO, WARD_RADIUS, a0, a0 + TAU / segs * 0.6, 6, Color(DOME_COLOR, 0.45 + 0.2 * pulse), 2.0)
	# Energy tethers to shielded allies
	for e in tethered:
		if is_instance_valid(e) and not e.is_dead:
			c.draw_line(Vector2.ZERO, e.global_position - global_position, Color(DOME_COLOR, 0.25 + 0.15 * pulse), 1.5)

func die() -> void:
	if is_dead:
		return
	# Dome collapse flash, then normal death and loot
	EnemyBase.spawn_explosion(world, global_position, WARD_RADIUS * 0.45, DOME_COLOR, true)
	super.die()
