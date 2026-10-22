class_name BurgRings
extends BurgHorseGame
## Ringstechen with squire Till (doc/burg.md): one ride on Wolke past five rings hanging from
## posts on the tilt, to the right of the rider at lance height. The lance is held lowered, its
## tip passing just under the rings. A ring lights up green while a thrust would reach it:
## "Stechen!" (Aktion) lifts the lance into the ring line for a moment (LIFT) and spears it; it
## stays on the lance. A thrust that comes up next to a ring (within NEAR) knocks it: missed. A
## ring ridden past without a thrust is missed too. Thrusting far from any ring costs nothing.
## 0,50 € per ring; all five in one ride: Ringmeister.

const POSTS := 5
const RIDE_TIME := 12.0
const WINDOW := 0.8            # metres either side of a ring where the lifted tip spears it
const NEAR := 3.0              # a thrust this close to a ring but outside WINDOW knocks it
const RING_Y := 2.15           # above the lane
const RING_SIDE := 0.55        # to the right of the rider
const RING_R := 0.22
const DROP := 0.45             # the lowered tip this far below the ring line
const LIFT := 0.12             # seconds from "Stechen!" until the tip is up
const THRUST := 0.5            # seconds the whole thrust takes (no new one meanwhile)

var horse: Actor
var t := 0.0
var state := "ride"
var taken := 0
var tried := []                 # ring index -> true once speared, knocked or passed
var rings: Array[MeshInstance3D] = []
var on_lance: Array[MeshInstance3D] = []
var posts_x: Array[float] = []
var scenery: Node3D
var thrust_t := -1.0            # seconds since "Stechen!", < 0: lance lowered
var _checked := false           # this thrust's hit is decided
var _tip := Vector3.ZERO        # the lance's tip this frame
var _cue_t := 0.0               # a result cue ("+1 Ring") stays this long
var _gold: StandardMaterial3D
var _green: StandardMaterial3D


func _init() -> void:
	title = "Ringstechen"
	host_id = "till"
	cost = 100


func describe() -> String:
	return "Reite an fünf Ringen vorbei und stich sie mit der Lanze: Leuchtet ein Ring grün, „Stechen!“. 0,50 € pro Ring. Einsatz 1 €."


func goal_done() -> bool:
	return GameState.stat("rings_all") > 0


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Ringstechen reiten (%s)" % GameState.format_money(cost)


func ring_z() -> float:
	return LANE_S - RING_SIDE   # the rider rides east: the right is north (-z)


func begin() -> void:
	horse = take_horse("wolke")
	give_lance(actor)
	scenery = Node3D.new()
	add_child(scenery)
	_gold = _glow(Color("e2c050"))
	_green = _glow(Color("4ee05a"))
	posts_x.clear()
	rings.clear()
	on_lance.clear()
	tried.clear()
	for i in POSTS:
		var x := lerpf(X0 + 20.0, X1 - 10.0, float(i) / (POSTS - 1))
		posts_x.append(x)
		tried.append(false)
		# The post stands on the tilt; its arm reaches over the lane to the ring.
		var base := lane(x, ring_z() - 1.05)
		var post := MeshInstance3D.new()
		var kit := MeshKit.new()
		kit.box(Vector3(0, 1.45, 0), Vector3(0.14, 2.9, 0.14), BurgModels.WOOD_DARK)
		kit.box(Vector3(0, 2.84, 0.55), Vector3(0.1, 0.1, 1.2), BurgModels.WOOD_DARK)
		kit.box(Vector3(0, 2.84 - (2.84 - RING_Y - RING_R) * 0.5, 1.05), Vector3(0.02, 2.84 - RING_Y - RING_R, 0.02), Color("c9a86a"))
		post.mesh = kit.commit()
		post.position = base
		scenery.add_child(post)
		var ring := MeshInstance3D.new()
		var rk := MeshKit.new()
		rk.use("glow")
		rk.push(Transform3D(Basis(Vector3.FORWARD, PI / 2), Vector3.ZERO))
		rk.torus(Vector3.ZERO, RING_R, 0.035, 16, 4, Color.WHITE)
		rk.pop()
		ring.mesh = rk.commit()
		ring.material_override = _gold
		ring.position = lane(x, ring_z()) + Vector3(0, RING_Y, 0)
		scenery.add_child(ring)
		rings.append(ring)
	t = 0.0
	taken = 0
	thrust_t = -1.0
	_cue_t = 0.0
	_tip = lane(X0, LANE_S)
	state = "ride"
	host_say("Lanze unten lassen – und hoch, wenn der Ring grün leuchtet!", 3.5)
	set_info("Deine Lanze ist gesenkt. Leuchtet ein Ring GRÜN, drück „Stechen!“ (Aktion): Die Lanze fährt hoch und spießt ihn auf. Zu früh oder zu spät gestochen: Der Ring ist weg.")
	add_button("Stechen!", func() -> void: stab(), 220)
	_update_score()


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.8
	return m


func _update_score() -> void:
	set_score("Ringe: %d von %d" % [taken, POSTS])


## Where a thrust started now would bring the tip (x along the lane) when it is up.
func reach_x() -> float:
	return tip_x() + (X1 + 4.0 - X0) / RIDE_TIME * LIFT


## The lance's tip (x along the lane).
func tip_x() -> float:
	return _tip.x


## The next ring not yet decided, -1 when all are.
func next_ring() -> int:
	for i in POSTS:
		if not tried[i]:
			return i
	return -1


## A thrust now would spear ring i.
func in_reach(i: int) -> bool:
	return i >= 0 and absf(reach_x() - posts_x[i]) <= WINDOW


func _lift() -> float:
	if thrust_t < 0.0:
		return 0.0
	return smoothstep(0.0, LIFT, thrust_t) * (1.0 - smoothstep(THRUST - 0.15, THRUST, thrust_t))


func _process(delta: float) -> void:
	if not active or state != "ride":
		return
	t += delta
	var k := clampf(t / RIDE_TIME, 0.0, 1.0)
	var p := lane(lerpf(X0, X1 + 4.0, k), LANE_S)
	ride(actor, horse, p, PI / 2, (X1 + 4.0 - X0) / RIDE_TIME)
	# From the side and a little behind: the lance and the rings in profile.
	look(p + Vector3(-2.2, 2.4, 5.2), p + Vector3(4.5, 1.9, -0.6))
	if thrust_t >= 0.0:
		thrust_t += delta
		if thrust_t >= LIFT and not _checked:
			_checked = true
			_hit()
		if thrust_t >= THRUST:
			thrust_t = -1.0
	var line := Vector3(0, lane(p.x, ring_z()).y + RING_Y, ring_z())
	var aim := Vector3(lance_grip(actor).x + 3.0, line.y - DROP * (1.0 - _lift()), line.z)
	_tip = point_lance(actor, aim, _lift() * 0.3)
	var tip := _tip
	var dir := (tip - lance_grip(actor)).normalized()
	for j in on_lance.size():
		on_lance[j].global_position = tip - dir * (0.5 + j * 0.12)
	# A ring ridden past is gone; the next one glows green while a thrust would reach it.
	for i in POSTS:
		if not tried[i] and tip_x() > posts_x[i] + WINDOW:
			tried[i] = true
			host_say("Verpasst!", 1.2)
			_flash("Verpasst!", UiTheme.RED)
	var n := next_ring()
	for i in POSTS:
		if rings[i].get_parent() == scenery:
			rings[i].material_override = _green if i == n and in_reach(i) and thrust_t < 0.0 else _gold
	_cue_t -= delta
	if _cue_t <= 0.0:
		set_cue("JETZT!" if in_reach(n) and thrust_t < 0.0 else "", Color("4ee05a"))
	if k >= 1.0:
		state = "done"
		set_cue("")
		var all := taken == POSTS
		if all:
			GameState.add_stat("rings_all")
		end_after(0.8, {"won": taken >= 3, "money": taken * 50, "joy": 10.0 + taken * 3.0,
			"text": "%d von %d Ringen! %s" % [taken, POSTS, "Till staunt: „Alle fünf! Du bist ein echter Ringmeister!“" if all
				else ("„Gar nicht schlecht!“, ruft Till." if taken >= 3 else "„Nächstes Mal triffst du mehr!“, meint Till.")]})


## "Stechen!": the lance goes up (LIFT), the hit is decided then (_hit).
func stab() -> void:
	if state != "ride" or thrust_t >= 0.0:
		return
	thrust_t = 0.0
	_checked = false


## The tip is up: it spears the next ring within WINDOW, knocks one within NEAR.
func _hit() -> void:
	var i := next_ring()
	if i < 0:
		return
	var d := tip_x() - posts_x[i]
	if absf(d) <= WINDOW:
		tried[i] = true
		taken += 1
		var ring := rings[i]
		ring.material_override = _gold
		ring.reparent(self)
		on_lance.append(ring)
		Sound.play("coin", actor.global_position)
		host_say(["Aufgespießt!", "Sauber!", "Noch einer!"][taken % 3], 1.5)
		_flash("+1 Ring", Color("4ee05a"))
	elif absf(d) <= NEAR:
		tried[i] = true
		rings[i].visible = false
		Sound.play("click", actor.global_position)
		host_say("Zu früh!" if d < 0.0 else "Zu spät!", 1.5)
		_flash("Zu früh!" if d < 0.0 else "Zu spät!", UiTheme.RED)
	_update_score()


func _flash(text: String, color: Color) -> void:
	set_cue(text, color)
	_cue_t = 0.9


func cleanup() -> void:
	set_cue("")
	for r in on_lance:
		if is_instance_valid(r):
			r.queue_free()
	on_lance.clear()
	if scenery:
		scenery.queue_free()
		scenery = null
	drop_lances()
	dismount(actor, lane(X0 - 4.0, LANE_S + 4.0))
	release_horses()


func game_input(event: InputEvent) -> void:
	if primary_pressed(event):
		stab()
