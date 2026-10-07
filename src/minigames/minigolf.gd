class_name MinigolfGame
extends Minigame
## Six-hole minigolf course. The course is always visible as park decoration.

const FELT := Color("3f9a5a")
const BORDER := Color("f1eee6")
const LANE_Y := 0.1
const BALL_R := 0.045
const FRICTION := 0.85

## Holes in local coordinates around the minigolf area centre.
const HOLES := [
	{"name": "Der Klassiker", "par": 2, "poly": [Vector2(-13, -5.1), Vector2(-5, -5.1), Vector2(-5, -3.9), Vector2(-13, -3.9)],
		"tee": Vector2(-12.4, -4.5), "cup": Vector2(-5.6, -4.5)},
	{"name": "Der Knick", "par": 3, "poly": [Vector2(-3, -5.1), Vector2(3, -5.1), Vector2(3, -0.5), Vector2(1.8, -0.5),
		Vector2(1.8, -3.9), Vector2(-3, -3.9)], "tee": Vector2(-2.4, -4.5), "cup": Vector2(2.4, -1.1)},
	{"name": "Die Windmühle", "par": 3, "poly": [Vector2(5, -5.1), Vector2(13, -5.1), Vector2(13, -3.9), Vector2(5, -3.9)],
		"tee": Vector2(5.6, -4.5), "cup": Vector2(12.4, -4.5), "windmill": Vector2(9, -4.5)},
	{"name": "Slalom", "par": 3, "poly": [Vector2(-13, 3.9), Vector2(-5, 3.9), Vector2(-5, 5.1), Vector2(-13, 5.1)],
		"tee": Vector2(-12.4, 4.5), "cup": Vector2(-5.6, 4.5),
		"posts": [Vector2(-10.5, 4.2), Vector2(-8.5, 4.8), Vector2(-6.8, 4.25)]},
	{"name": "Das Entenhaus", "par": 2, "poly": [Vector2(-3, 3.6), Vector2(3, 3.6), Vector2(3, 5.4), Vector2(-3, 5.4)],
		"tee": Vector2(-2.4, 4.5), "cup": Vector2(2.55, 4.5),
		"walls": [[Vector2(0.9, 3.6), Vector2(2.1, 4.3)], [Vector2(0.9, 5.4), Vector2(2.1, 4.7)]], "duckhouse": Vector2(2.4, 4.5)},
	{"name": "Die Brücke", "par": 3, "poly": [Vector2(5, 3.9), Vector2(7.5, 3.9), Vector2(7.5, 4.25), Vector2(10.5, 4.25),
		Vector2(10.5, 3.9), Vector2(13, 3.9), Vector2(13, 5.1), Vector2(10.5, 5.1), Vector2(10.5, 4.75), Vector2(7.5, 4.75),
		Vector2(7.5, 5.1), Vector2(5, 5.1)], "tee": Vector2(5.6, 4.5), "cup": Vector2(12.4, 4.5), "bridge": true},
]

static var course_root: Node3D
static var windmill_blades: Node3D

var center: Vector2
var base_y := 0.0
var hole := 0
var strokes := 0
var total := 0
var aim := 0.0
var t := 0.0
var state := "aim"           # aim, rolling, between, done
var sim: BallSim
var ball: BallSim.Ball
var ball_node: MeshInstance3D
var poly_world := PackedVector2Array()
var cup_world := Vector2.ZERO
var aim_node: MeshInstance3D
var hole_scores: Array[int] = []
var _between := 0.0
var _last_safe := Vector2.ZERO


func _init() -> void:
	title = "Minigolf"
	cost = 200


func describe() -> String:
	return "Sechs knifflige Bahnen mit Windmühle und Entenhaus. 2,00 € an der Minigolf-Hütte."


static func area_center() -> Vector2:
	return ParkLayout.AREAS["minigolf"]["pos"]


## Static decoration, built once when the park is set up.
static func build_course(world: World) -> Vector3:
	var c := area_center()
	var y := world.map.height_at(c.x, c.y)
	var kit := MeshKit.new()
	for i in HOLES.size():
		var h: Dictionary = HOLES[i]
		var poly := PackedVector2Array()
		for p: Vector2 in h["poly"]:
			poly.append(p)
		# Felt surface on a low base.
		kit.prism(poly, 0.0, LANE_Y, Color("8a7a5a"), FELT if not h.get("bridge", false) else FELT)
		for e in _border_segments(h):
			kit.beam(Vector3(e[0].x, LANE_Y, e[0].y), Vector3(e[1].x, LANE_Y, e[1].y), Vector2(0.06, 0.12), BORDER)
		for w: Array in h.get("walls", []):
			kit.beam(Vector3(w[0].x, LANE_Y, w[0].y), Vector3(w[1].x, LANE_Y, w[1].y), Vector2(0.06, 0.12), BORDER)
		for p: Vector2 in h.get("posts", []):
			kit.box(Vector3(p.x, LANE_Y + 0.1, p.y), Vector3(0.22, 0.2, 0.22), Color("d8463a"))
		var cup: Vector2 = h["cup"]
		kit.disc(Vector3(cup.x, LANE_Y + 0.004, cup.y), 0.07, 10, Color("111111"))
		kit.cylinder(Vector3(cup.x, LANE_Y, cup.y), 0.9, 0.012, 0.012, 4, Color("dddddd"))
		kit.prism(PackedVector2Array([Vector2(cup.x, cup.y), Vector2(cup.x + 0.32, cup.y + 0.01), Vector2(cup.x, cup.y + 0.02)]),
			LANE_Y + 0.68, LANE_Y + 0.88, Color("d8463a"))
		var tee: Vector2 = h["tee"]
		kit.box(Vector3(tee.x, LANE_Y + 0.005, tee.y), Vector3(0.35, 0.01, 0.35), Color("2f7a46"))
		if h.get("bridge", false):
			# Pond under the bridge, planks on top.
			kit.use("water")
			kit.box(Vector3(9.0, 0.03, 4.5), Vector3(3.0, 0.02, 1.4), Color("3d8aa0"))
			kit.use("solid")
			for k in 8:
				kit.box(Vector3(7.6 + k * 0.4, LANE_Y + 0.012, 4.5), Vector3(0.34, 0.02, 0.52), PropModels.WOOD_LIGHT)
		if h.has("duckhouse"):
			var d: Vector2 = h["duckhouse"]
			kit.box(Vector3(d.x + 0.25, LANE_Y + 0.35, d.y - 0.62), Vector3(0.9, 0.7, 0.12), Color("f2c230"))
			kit.box(Vector3(d.x + 0.25, LANE_Y + 0.35, d.y + 0.62), Vector3(0.9, 0.7, 0.12), Color("f2c230"))
			kit.lathe(PackedVector2Array([Vector2(0.95, LANE_Y + 0.7), Vector2(0.0, LANE_Y + 1.15)]), 4, Color("d8463a"), PI / 4)
			kit.sphere(Vector3(d.x + 0.25, LANE_Y + 1.25, d.y), Vector3(0.22, 0.2, 0.22), Color("f2c230"), 3, 7)
			kit.box(Vector3(d.x - 0.0, LANE_Y + 1.22, d.y), Vector3(0.18, 0.05, 0.12), Color("f28a2a"))
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.position = Vector3(c.x, y, c.y)
	mi.name = "MinigolfCourse"
	world.static_root.add_child(mi)
	course_root = mi
	# Windmill with turning blades.
	var wm: Vector2 = HOLES[2]["windmill"]
	var house := MeshKit.new()
	house.box(Vector3(0, 0.75 + LANE_Y, -0.75), Vector3(1.0, 1.5, 0.3), Color("e8dcc0"))
	house.box(Vector3(0, 0.75 + LANE_Y, 0.75), Vector3(1.0, 1.5, 0.3), Color("e8dcc0"))
	house.box(Vector3(0, 1.4 + LANE_Y, 0), Vector3(1.0, 0.3, 1.8), Color("e8dcc0"))
	house.lathe(PackedVector2Array([Vector2(0.95, 1.55 + LANE_Y), Vector2(0.0, 2.3 + LANE_Y)]), 4, Color("8a3b2b"), PI / 4)
	var hm := MeshInstance3D.new()
	hm.mesh = house.commit()
	hm.position = Vector3(c.x + wm.x, y, c.y + wm.y)
	world.static_root.add_child(hm)
	windmill_blades = Node3D.new()
	windmill_blades.position = Vector3(c.x + wm.x - 0.55, y + 1.3 + LANE_Y, c.y + wm.y)
	var bk := MeshKit.new()
	for i in 4:
		bk.push(Transform3D(Basis(Vector3.RIGHT, i * PI / 2), Vector3.ZERO))
		bk.box(Vector3(0, 0.7, 0), Vector3(0.04, 1.3, 0.28), Color("f4f4f4"))
		bk.pop()
	var bm := MeshInstance3D.new()
	bm.mesh = bk.commit()
	windmill_blades.add_child(bm)
	world.static_root.add_child(windmill_blades)
	# Course numbers.
	for i in HOLES.size():
		var tee: Vector2 = HOLES[i]["tee"]
		var l := Label3D.new()
		l.text = str(i + 1)
		l.font_size = 64
		l.pixel_size = 0.005
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.outline_size = 10
		l.position = Vector3(c.x + tee.x - 0.2, y + 0.9, c.y + tee.y - 0.95)
		world.static_root.add_child(l)
	return Vector3(c.x, y, c.y)


static func _border_segments(h: Dictionary) -> Array:
	var poly: Array = h["poly"]
	var out := []
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		# The bridge part has no rails (fall into the water!).
		if h.get("bridge", false) and absf(a.y - b.y) < 0.01 and minf(a.x, b.x) >= 7.49 and maxf(a.x, b.x) <= 10.51 and absf(a.y - 4.5) < 0.3:
			continue
		out.append([a, b])
	return out


static func windmill_closed(time: float) -> bool:
	return fmod(time, 3.0) < 1.1


func begin() -> void:
	center = area_center()
	base_y = world.map.height_at(center.x, center.y) + LANE_Y
	hole = 0
	total = 0
	hole_scores.clear()
	set_info("Links/Rechts: zielen · Aktion oder Klick: schlagen. Bei der Windmühle auf den Moment achten!")
	add_button("<", func() -> void: aim -= 4.0, 90)
	add_button("Schlagen!", func() -> void: _putt(), 200)
	add_button(">", func() -> void: aim += 4.0, 90)
	actor.set_item("putter")
	_start_hole()


func _start_hole() -> void:
	var h: Dictionary = HOLES[hole]
	sim = BallSim.new()
	sim.restitution = 0.7
	poly_world = PackedVector2Array()
	for p: Vector2 in h["poly"]:
		poly_world.append(center + p)
	for e in _border_segments(h):
		sim.add_wall(center + e[0], center + e[1])
	for w: Array in h.get("walls", []):
		sim.add_wall(center + w[0], center + w[1])
	for p: Vector2 in h.get("posts", []):
		var q := center + p
		var s := 0.11
		sim.add_wall(q + Vector2(-s, -s), q + Vector2(s, -s))
		sim.add_wall(q + Vector2(s, -s), q + Vector2(s, s))
		sim.add_wall(q + Vector2(s, s), q + Vector2(-s, s))
		sim.add_wall(q + Vector2(-s, s), q + Vector2(-s, -s))
	if h.has("windmill"):
		var wm: Vector2 = center + h["windmill"]
		var me := self
		sim.movers.append(func() -> Array:
			if MinigolfGame.windmill_closed(me.t):
				return [wm + Vector2(0, -0.6), wm + Vector2(0, 0.6)]
			return [Vector2(9999, 9999), Vector2(9999, 9999.1)])
	cup_world = center + h["cup"]
	var tee: Vector2 = center + h["tee"]
	ball = sim.add_ball(tee, BALL_R, FRICTION)
	_last_safe = tee
	if ball_node == null:
		ball_node = MeshInstance3D.new()
		ball_node.mesh = PropModels.ball(Color("ffffff"), BALL_R)
		add_child(ball_node)
	strokes = 0
	aim = rad_to_deg((cup_world - tee).angle()) if hole != 1 else 0.0
	state = "aim"
	_place_actor()
	_update_score()


func _place_actor() -> void:
	var dir := Vector2.RIGHT.rotated(deg_to_rad(aim))
	var side := Vector2(-dir.y, dir.x)
	var stand := ball.p - dir * 0.35 + side * 0.45
	actor.global_position = Vector3(stand.x, world.map.walk_height(stand.x, stand.y), stand.y)
	actor.face(Vector3(ball.p.x, 0, ball.p.y) + Vector3(dir.x, 0, dir.y) * 2.0, true)
	actor.rotation.y = actor.yaw
	var cam_from := Vector3(ball.p.x, base_y, ball.p.y) - Vector3(dir.x, 0, dir.y) * 3.2 + Vector3(0, 2.4, 0)
	look(cam_from, Vector3(ball.p.x, base_y, ball.p.y) + Vector3(dir.x, 0, dir.y) * 3.0)


func _putt() -> void:
	if state != "aim":
		return
	var power := pingpong(t, 0.75)
	var dir := Vector2.RIGHT.rotated(deg_to_rad(aim))
	ball.v = dir * (0.5 + power * 5.2)
	strokes += 1
	state = "rolling"
	actor.play_anim("throw", 0.5)
	Sound.play("hit", Vector3(ball.p.x, base_y, ball.p.y), -4.0)
	show_power(-1.0)
	_update_score()


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	if windmill_blades:
		windmill_blades.rotation.x = -t * TAU / 3.0
	if state == "aim":
		if Input.is_action_pressed("move_left"):
			aim -= delta * 40.0
		if Input.is_action_pressed("move_right"):
			aim += delta * 40.0
		show_power(pingpong(t, 0.75))
		_draw_aim()
	elif state == "rolling":
		sim.step(delta)
		var speed := ball.v.length()
		if ball.p.distance_to(cup_world) < 0.075 and speed < 2.6:
			_holed()
		elif not Geometry2D.is_point_in_polygon(ball.p, poly_world):
			# Fell off the bridge into the water.
			Sound.play("splash", Vector3(ball.p.x, base_y, ball.p.y))
			set_info("Platsch! Der Ball ist im Wasser. +1 Strafschlag.")
			strokes += 1
			ball.p = _last_safe
			ball.v = Vector2.ZERO
			state = "aim"
			_place_actor()
		elif speed < 0.02:
			ball.v = Vector2.ZERO
			_last_safe = ball.p
			if strokes >= 6:
				set_info("Sechs Schläge – weiter zur nächsten Bahn.")
				_hole_done()
			else:
				state = "aim"
				aim = rad_to_deg((cup_world - ball.p).angle())
				_place_actor()
		_update_score()
	elif state == "between":
		_between -= delta
		if _between <= 0.0:
			hole += 1
			if hole >= HOLES.size():
				_finish()
			else:
				_start_hole()
	if aim_node:
		aim_node.visible = state == "aim"
	var h := 0.0 if state != "between" else -0.05
	if ball_node:
		ball_node.global_position = Vector3(ball.p.x, base_y + BALL_R + h, ball.p.y)


func _draw_aim() -> void:
	if aim_node == null:
		aim_node = MeshInstance3D.new()
		var kit := MeshKit.new()
		kit.use("unshaded")
		for i in 6:
			kit.box(Vector3(0.25 + i * 0.25, 0, 0), Vector3(0.1, 0.01, 0.03), Color(1, 1, 1))
		aim_node.mesh = kit.commit()
		add_child(aim_node)
	aim_node.global_position = Vector3(ball.p.x, base_y + 0.02, ball.p.y)
	aim_node.rotation.y = -deg_to_rad(aim)


func _holed() -> void:
	Sound.play("success")
	ball.v = Vector2.ZERO
	ball.p = cup_world
	if strokes == 1:
		GameState.add_stat("hole_in_one")
		set_info("ASS! Hole-in-One!")
		actor.play_anim("cheer", 2.0)
	else:
		var par: int = HOLES[hole]["par"]
		set_info(["Eagle!", "Birdie!", "Par.", "Bogey.", "Doppel-Bogey."][clampi(strokes - par + 2, 0, 4)] + " (%d Schläge)" % strokes)
	_hole_done()


func _hole_done() -> void:
	hole_scores.append(strokes)
	total += strokes
	state = "between"
	_between = 2.0


func _update_score() -> void:
	var h: Dictionary = HOLES[mini(hole, HOLES.size() - 1)]
	set_score("Bahn %d/6: %s  ·  Par %d  ·  Schläge %d  ·  Gesamt %d" % [mini(hole + 1, 6), h["name"], h["par"], strokes, total])


func _finish() -> void:
	var par := 0
	for h: Dictionary in HOLES:
		par += h["par"]
	var diff := total - par
	if diff < 0:
		GameState.add_stat("minigolf_under_par")
	var text := "Runde beendet: %d Schläge bei Par %d (%s)." % [total, par, ("%+d" % diff) if diff != 0 else "genau Par"]
	end({"won": diff <= 0, "money": maxi(0, -diff) * 100 + (200 if diff <= 0 else 0), "joy": 30.0, "text": text})


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not UI.point_blocked((event as InputEventMouseButton).position)):
		_putt()


func cleanup() -> void:
	actor.set_item("")
	if ball_node:
		ball_node.queue_free()
		ball_node = null
	if aim_node:
		aim_node.queue_free()
		aim_node = null
