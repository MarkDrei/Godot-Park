class_name CoastSkipping
extends Minigame
## Steine flitschen at the water's edge (doc/moewenbucht.md): three flat stones over the sea. A
## gauge at the side of the screen shows the throwing angle, its needle swinging from flat to
## steep; "Werfen!" (Aktion) throws at the needle's angle. In the green (flat) zone the stone
## skips five to ten times, in the yellow two to four, red (too steep) it plops in. Every skip
## is a splash ring and its number in big; the best throw counts.

const THROWS := 3
const PERIOD := 2.6             # seconds the needle takes from flat to steep and back
const MAX_ANGLE := 40.0
const GREEN := Vector2(6.0, 14.0)
const PERFECT := Vector2(8.5, 11.5)
const YELLOW := Vector2(2.0, 19.0)
const REACT := 0.15             # the cue leads by this (a press needs a moment)
const STAND := Vector2(-30, 169.5)

var throws := 0
var best := 0
var last := -1
var t := 0.0
var angle := 0.0
var state := "aim"              # aim, flying, done
var gauge: AngleGauge
var stone: MeshInstance3D
var rings: Array[Dictionary] = []    # {node, t}
var _flight: Array = []         # the stone's touch points along the way
var _fly_t := 0.0
var _hop := 0
var _cue_t := 0.0
var pace := 1.0                 # < 1 slows the needle (tests)


func _init() -> void:
	title = "Steine flitschen"
	host_id = ""
	host_needed = false
	cost = 0


func describe() -> String:
	return "Am Strand flache Steine über das Wasser hüpfen lassen: Wirf, wenn die Nadel im grünen Bereich ist. Drei Würfe, der beste zählt."


func goal_done() -> bool:
	return GameState.stat("skips_best") >= 8


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.coast != null


func stand() -> Vector3:
	return Vector3(STAND.x, world.map.walk_height(STAND.x, STAND.y), STAND.y)


func begin() -> void:
	throws = 0
	best = 0
	last = -1
	actor.teleport(stand())
	actor.face(stand() + Vector3(0, 0, 5), true)
	gauge = AngleGauge.new()
	gauge.name = "AngleGauge"
	hud.add_child(gauge)
	_place_gauge.call_deferred()
	stone = MeshInstance3D.new()
	stone.mesh = CoastModels.skipping_stone()
	stone.visible = false
	world.add_child(stone)
	set_info("Rechts zeigt die Nadel, wie flach du wirfst. Ist sie im GRÜNEN Bereich, drück „Werfen!“ (Aktion): Je flacher, desto öfter hüpft der Stein. Rot ist zu steil: Plopp!")
	add_button("Werfen!", func() -> void: throw(), 220)
	_next()


func _place_gauge() -> void:
	if gauge and hud:
		var s := clampf(hud.size.y * 0.42, 170.0, 280.0)
		gauge.size = Vector2(s, s)
		gauge.position = Vector2(hud.size.x - s - 24.0, (hud.size.y - s) * 0.5)


func _next() -> void:
	state = "aim"
	t = 0.0
	stone.visible = false
	_aim_view()
	_update_score()


func _update_score() -> void:
	set_score("Wurf %d von %d  ·  Bester: %d Sprünge" % [mini(throws + 1, THROWS), THROWS, best])


func _aim_view() -> void:
	var s := stand()
	look(s + Vector3(1.4, 2.3, -4.2), s + Vector3(0, 0.4, 16.0))


## The needle's angle at time `at` (flat 0 to steep MAX_ANGLE and back).
func angle_at(at: float) -> float:
	return MAX_ANGLE * 0.5 * (1.0 - cos(at * TAU / PERIOD))


## A press now would throw flat enough (the green zone), the reaction included.
func green_now() -> bool:
	var a := angle_at(t + REACT * pace)
	return state == "aim" and a >= GREEN.x and a <= GREEN.y


func _process(delta: float) -> void:
	if not active:
		return
	_cue_t -= delta
	for r: Dictionary in rings.duplicate():
		r["t"] += delta
		var k: float = r["t"] / 1.2
		var node: MeshInstance3D = r["node"]
		node.scale = Vector3.ONE * (1.0 + k * 2.2)
		node.transparency = clampf(k, 0.0, 1.0)
		if k >= 1.0:
			node.queue_free()
			rings.erase(r)
	match state:
		"aim":
			t += delta * pace
			angle = angle_at(t)
			gauge.angle = angle
			gauge.green = green_now()
			if _cue_t <= 0.0:
				set_cue("JETZT!" if green_now() else "", Color("4ee05a"))
		"flying":
			_fly(delta)


## "Werfen!": the stone leaves at the needle's angle.
func throw() -> void:
	if state != "aim" or not active:
		return
	state = "flying"
	gauge.green = false
	var hops := skips_for(angle)
	last = hops
	throws += 1
	best = maxi(best, hops)
	actor.play_anim("throw", 0.6)
	Sound.play("whistle", actor.global_position, -10.0, 1.6)
	# The touch points: the first a few metres out, each hop shorter.
	var s := stand()
	_flight = [Vector3(s.x + 0.3, s.y + 1.3, s.z + 0.6)]
	var z := s.z + 6.0 + (0.0 if hops > 0 else -1.5)
	var step := 4.2
	for i in maxi(hops, 1):
		_flight.append(Vector3(s.x + 0.3 + sin(i * 0.7) * 0.4, ParkLayout.WATER_Y + 0.05, z))
		z += step
		step *= 0.82
	_fly_t = 0.0
	_hop = 0
	stone.visible = true
	set_cue("")


## How often a stone thrown at `a` degrees skips (some luck within its zone).
func skips_for(a: float) -> int:
	if a >= PERFECT.x and a <= PERFECT.y:
		return rng.randi_range(8, 10)
	if a >= GREEN.x and a <= GREEN.y:
		return rng.randi_range(5, 7)
	if a >= YELLOW.x and a <= YELLOW.y:
		return rng.randi_range(2, 4)
	return 0


## Seconds per leg of the flight: the first longer, the hops quicker.
func _leg_time(i: int) -> float:
	return 0.55 if i == 0 else maxf(0.22, 0.42 * pow(0.85, i))


func _fly(delta: float) -> void:
	_fly_t += delta
	var leg := _leg_time(_hop)
	var a: Vector3 = _flight[_hop]
	var b: Vector3 = _flight[_hop + 1]
	var k := clampf(_fly_t / leg, 0.0, 1.0)
	var hgt := (1.0 if _hop == 0 else 0.55 * pow(0.8, _hop)) * sin(k * PI)
	var pos := a.lerp(b, k) + Vector3(0, hgt, 0)
	stone.global_position = pos
	stone.rotation.y += delta * 18.0
	_follow(pos)
	if k < 1.0:
		return
	_fly_t = 0.0
	_hop += 1
	var hops := last
	if hops == 0:
		_splash(b, 1.4)
		Sound.play("splash", b)
		_flash("Plopp! Zu steil", UiTheme.RED)
		_landed()
		return
	_splash(b, 0.8)
	Sound.play("splash", b, -8.0, 1.4)
	_flash(str(_hop), Color("4ee05a") if _hop >= 5 else UiTheme.GOLD)
	if _hop >= hops:
		_landed()


func _landed() -> void:
	state = "landed"
	stone.visible = false
	_update_score()
	var hops := last
	if hops > 0:
		_flash("%d Sprünge!%s" % [hops, "\nSchön flach!" if hops >= 5 else ""], Color("4ee05a") if hops >= 5 else UiTheme.GOLD, 1.6)
	var s := session
	get_tree().create_timer(1.7, false).timeout.connect(func() -> void:
		if not still_running(s):
			return
		if throws >= THROWS:
			_finish()
		else:
			_next())


func _follow(pos: Vector3) -> void:
	var s := stand()
	var from := s + Vector3(1.4, 2.3, -4.2)
	var behind := pos + Vector3(1.2, 2.2, -6.0)
	look(from.lerp(behind, clampf((pos.z - s.z - 4.0) / 10.0, 0.0, 0.8)), pos + Vector3(0, -0.2, 3.0))


func _splash(p: Vector3, r: float) -> void:
	var node := MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.use("glow")
	kit.torus(Vector3.ZERO, r * 0.5, 0.06, 16, 3, Color(1, 1, 1))
	node.mesh = kit.commit()
	node.position = Vector3(p.x, ParkLayout.WATER_Y + 0.06, p.z)
	world.add_child(node)
	rings.append({"node": node, "t": 0.0})


func _flash(text: String, color: Color, secs := 0.7) -> void:
	set_cue(text, color)
	_cue_t = secs


func _finish() -> void:
	state = "done"
	GameState.set_stat_max("skips_best", best)
	GameState.add_stat("skips_games")
	var won := best >= 5
	end_after(0.3, {"won": won, "joy": 10.0 + best * 1.5,
		"text": "%d Sprünge war dein bester Wurf. %s" % [best, "Ein echter Flitscher!" if best >= 8
			else ("Schön flach!" if won else "Flacher werfen – dann hüpft er öfter.")]})


func cleanup() -> void:
	set_cue("")
	if is_instance_valid(gauge):
		gauge.queue_free()
	gauge = null
	if is_instance_valid(stone):
		stone.queue_free()
	stone = null
	for r: Dictionary in rings:
		if is_instance_valid(r["node"]):
			(r["node"] as Node).queue_free()
	rings.clear()


func game_input(event: InputEvent) -> void:
	if primary_pressed(event):
		throw()


## The throwing angle, big at the side of the screen: a quarter circle from flat (bottom) to
## steep (top) with its zones, the needle, "flach" and "steil"; the green zone lights up while
## a throw now would be flat enough.
class AngleGauge extends Control:
	var angle := 0.0
	var green := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	## Screen angle of a throwing angle: 0° points right, MAX_ANGLE straight up (scaled up).
	func _dir(a: float) -> Vector2:
		var s := a / CoastSkipping.MAX_ANGLE * PI * 0.5
		return Vector2(cos(s), -sin(s))

	func _band(o: Vector2, r0: float, r1: float, a0: float, a1: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 9:
			pts.append(o + _dir(lerpf(a0, a1, k / 8.0)) * r1)
		for k in range(8, -1, -1):
			pts.append(o + _dir(lerpf(a0, a1, k / 8.0)) * r0)
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.86
		var o := Vector2(size.x * 0.08, size.y * 0.92)
		draw_circle(o + Vector2(r, -r) * 0.5, r * 0.78, Color(0, 0, 0, 0.35))
		var m := CoastSkipping.MAX_ANGLE
		var y := CoastSkipping.YELLOW
		var g := CoastSkipping.GREEN
		var p := CoastSkipping.PERFECT
		_band(o, r * 0.35, r, 0.0, y.x, Color("e0a32e"))
		_band(o, r * 0.35, r, y.x, g.x, Color("e0a32e"))
		_band(o, r * 0.35, r, g.x, g.y, Color("7ee08a") if green else Color("3a9a4a"))
		_band(o, r * 0.35, r, p.x, p.y, Color("b8ffb8") if green else Color("4ec05a"))
		_band(o, r * 0.35, r, g.y, y.y, Color("e0a32e"))
		_band(o, r * 0.35, r, y.y, m, Color("c8352e"))
		var f := get_theme_default_font()
		draw_string_outline(f, o + Vector2(r * 0.4, 26), "flach", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.8))
		draw_string(f, o + Vector2(r * 0.4, 26), "flach", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f4f1ea"))
		draw_string_outline(f, o + Vector2(-8, -r - 10), "steil", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, 0.8))
		draw_string(f, o + Vector2(-8, -r - 10), "steil", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f4f1ea"))
		var tip := o + _dir(angle) * (r + 10.0)
		draw_line(o, tip, Color("1a1a1a"), 9.0)
		draw_line(o, tip, Color("ffe14a") if green else Color("f4f1ea"), 5.0)
		draw_circle(o, 10.0, Color("1a1a1a"))
