class_name CoastBoatRace
extends DriveJob
## Tretbootrennen with boat renter Ole (doc/moewenbucht.md): in a pedal boat against two others
## round three yellow buoys in the bay, numbered 1, 2, 3, and back through the start between the
## two flags. The next buoy has the light pillar and glows; an arrow at the bottom of the screen
## points to it with the metres left (also when it is behind the boat); touching it (within
## REACH) counts. A countdown, then go; the other boats steer by themselves to their next buoy.

const BUOYS := [Vector2(52, 200), Vector2(34, 238), Vector2(76, 246)]
const START := Vector2(100, 190)          # between the flags; also the finish
const GRID := [[Vector2(100, 186), -PI / 2], [Vector2(100, 190), -PI / 2], [Vector2(100, 194), -PI / 2]]
const REACH := 6.0
const TOPS := [2.3, 2.15]

var boats: Array[Car] = []          # the player's first, then the two others
var next := {}                      # Car -> index of the next mark (3 = the finish)
var finished_boats: Array[Car] = []
var countdown := 0.0
var race_time := 0.0
var marks: Array[Node3D] = []
var pointer: TargetArrow
var _gold: StandardMaterial3D
var _green: StandardMaterial3D


func _init() -> void:
	super()
	title = "Tretbootrennen"
	host_id = "ole"
	host_needed = true
	on_radio = false
	cost = 100
	guide = false


func describe() -> String:
	return "Mit dem Tretboot um die gelben Bojen 1, 2 und 3 und zurück ins Ziel, gegen zwei andere Boote. Bei Bootsverleiher Ole, 1 €."


func goal_done() -> bool:
	return GameState.stat("boat_race_wins") > 0


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.coast != null


func blocked_text(_a: Actor) -> String:
	return "" if host_available() else unavailable_text()


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Tretbootrennen fahren (%s)" % GameState.format_money(cost)


func begin() -> void:
	if actor.vehicle:
		game.player.exit_car(true)
	var c := world.coast
	c.moor_boats()
	boats.clear()
	var pedalos := c.boats.filter(func(b: Car) -> bool: return b.kind == "pedalo" and b.driver == null)
	for i in 3:
		var b: Car = pedalos[i]
		b.speed = 0.0
		b.place(GRID[i][0], GRID[i][1])
		b.locked = i > 0
		boats.append(b)
		next[b] = 0
	game.player.enter_car(boats[0])
	start_driving()
	for i in range(1, 3):
		boats[i].activate()
	_build_marks()
	pointer = TargetArrow.new()
	pointer.name = "TargetArrow"
	hud.add_child(pointer)
	_place_pointer.call_deferred()
	finished_boats.clear()
	countdown = 3.0
	race_time = 0.0
	for b in boats:
		b.max_speed_factor = 0.0
	_show_next()
	host_say("Um die gelben Bojen, eins, zwei, drei – und zurück zu mir!", 3.5)
	set_info("Fahr um die gelben Bojen 1, 2, 3 und zurück durchs Ziel zwischen den Fahnen. Die nächste Boje leuchtet grün und hat die Lichtsäule. Gas: W / „Gas“, lenken: A/D oder Joystick.")


func _place_pointer() -> void:
	if pointer and hud:
		pointer.size = Vector2(150, 150)
		pointer.position = Vector2((hud.size.x - 150.0) * 0.5, hud.size.y - 260.0)


## The three race buoys (numbered, yellow; the next one green) and the two flags of the start.
func _build_marks() -> void:
	_gold = _glow(Color("f2c230"))
	_green = _glow(Color("4ee05a"))
	for i in BUOYS.size():
		var p: Vector2 = BUOYS[i]
		var m := MeshInstance3D.new()
		var kit := MeshKit.new()
		kit.sphere(Vector3(0, 0.1, 0), Vector3(0.8, 0.7, 0.8), Color.WHITE, 3, 10)
		kit.cylinder(Vector3(0, 0.6, 0), 1.6, 0.12, 0.12, 6, Color.WHITE)
		m.mesh = kit.commit()
		m.material_override = _gold
		m.position = Vector3(p.x, ParkLayout.WATER_Y - 0.1, p.y)
		m.add_to_group("bobbing")
		var l := Label3D.new()
		l.text = str(i + 1)
		l.font_size = 160
		l.pixel_size = 0.01
		l.outline_size = 24
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = Vector3(0, 3.4, 0)
		l.no_depth_test = true
		m.add_child(l)
		world.add_child(m)
		marks.append(m)
	for side: float in [-1.0, 1.0]:
		var f := MeshInstance3D.new()
		var kit := MeshKit.new()
		kit.cylinder(Vector3(0, -1.0, 0), 4.0, 0.08, 0.08, 6, Color.WHITE)
		kit.box(Vector3(0.45, 2.6, 0), Vector3(0.9, 0.6, 0.04), Color("c8352e"))
		f.mesh = kit.commit()
		f.position = Vector3(START.x, ParkLayout.WATER_Y, START.y + side * 7.0)
		world.add_child(f)
		marks.append(f)


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.7
	return m


## The light pillar and the green glow on the player's next mark.
func _show_next() -> void:
	var n: int = next.get(boats[0], 0)
	for i in BUOYS.size():
		(marks[i] as MeshInstance3D).material_override = _green if i == n else _gold
	show_target(BUOYS[n] if n < BUOYS.size() else START, "Boje %d" % (n + 1) if n < BUOYS.size() else "Ziel", Color("4ee05a"))


func mark_pos(i: int) -> Vector2:
	return BUOYS[i] if i < BUOYS.size() else START


func job_tick(delta: float) -> void:
	if countdown > 0.0:
		var before := ceili(countdown)
		countdown -= delta
		set_cue(str(maxi(1, ceili(countdown))) if countdown > 0.0 else "LOS!", UiTheme.GOLD)
		if ceili(countdown) != before:
			Sound.play("beep" if countdown > 0.0 else "bell")
		if countdown <= 0.0:
			for b in boats:
				b.max_speed_factor = 1.0
			var s := session
			get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
				if still_running(s):
					set_cue(""))
		return
	race_time += delta
	_point()
	for b in boats:
		_check_mark(b)
	for i in range(1, boats.size()):
		_ai(boats[i])
	var me := boats[0]
	var n: int = next[me]
	set_score("%s · Platz %d · %d s" % ["Boje %d von 3" % (n + 1) if n < 3 else "Ins Ziel!", place_of(me), int(race_time)])
	if finished_boats.has(me):
		_finish()


## The arrow: the next mark's direction as seen from the camera, and its distance.
func _point() -> void:
	if pointer == null or boats.is_empty():
		return
	var me := boats[0]
	var n: int = next[me]
	var v := mark_pos(n) - me.pos2()
	var cam := -game.camera.global_transform.basis.z
	var f := Vector2(cam.x, cam.z).normalized()
	pointer.angle = atan2(f.x * v.y - f.y * v.x, f.dot(v))
	pointer.text = "%s · %d m" % ["Boje %d" % (n + 1) if n < BUOYS.size() else "Ziel", int(v.length())]


func _check_mark(b: Car) -> void:
	var n: int = next[b]
	if n > BUOYS.size() or finished_boats.has(b):
		return
	if b.pos2().distance_to(mark_pos(n)) <= REACH:
		next[b] = n + 1
		if n == BUOYS.size():
			finished_boats.append(b)
		if b == boats[0]:
			Sound.play("coin" if n < BUOYS.size() else "success", b.global_position)
			if n < BUOYS.size():
				set_cue("Boje %d!" % (n + 1), Color("4ee05a"))
				var s := session
				get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
					if still_running(s):
						set_cue(""))
				_show_next()


## Place of a boat: finished_boats ones by order, the others by marks passed and the way to the next.
func place_of(b: Car) -> int:
	if finished_boats.has(b):
		return finished_boats.find(b) + 1
	var place := 1 + finished_boats.size()
	for o in boats:
		if o == b or finished_boats.has(o):
			continue
		if next[o] > next[b] or (next[o] == next[b] and o.pos2().distance_to(mark_pos(next[o])) < b.pos2().distance_to(mark_pos(next[b]))):
			place += 1
	return place


## The other boats steer straight for their next mark, a little to its outside.
func _ai(b: Car) -> void:
	if finished_boats.has(b):
		b.set_input(-0.6 if b.speed > 0.3 else 0.0, 0.0)
		return
	var target := mark_pos(next[b])
	var f := b.forward2()
	var to := target - b.pos2()
	var alpha := atan2(f.x * to.y - f.y * to.x, f.dot(to))
	var steer := clampf(alpha * 2.0, -1.0, 1.0)
	var top: float = TOPS[boats.find(b) - 1]
	b.max_speed_factor = top / float(b.spec["max"])
	b.set_input(1.0 if absf(alpha) < 1.2 else 0.3, steer)


func _finish() -> void:
	var place := place_of(boats[0])
	GameState.add_stat("boat_races")
	if place == 1:
		GameState.add_stat("boat_race_wins")
	var money: int = [300, 100, 0][place - 1]
	var line: String = ["Erster! Du trittst ja wie ein Weltmeister!", "Zweiter! Knapp war's!", "Dritter. Beim nächsten Mal schneller treten!"][place - 1]
	end({"won": place == 1, "money": money, "joy": [24.0, 16.0, 10.0][place - 1],
		"text": "Platz %d nach %d Sekunden.\n\nOle: „%s“" % [place, int(race_time), line]})


func job_left() -> void:
	end({"won": false, "joy": 2.0, "text": "Rennen abgebrochen – du bist ausgestiegen."})


func cleanup() -> void:
	super()
	set_cue("")
	if is_instance_valid(pointer):
		pointer.queue_free()
	pointer = null
	for m in marks:
		if is_instance_valid(m):
			m.queue_free()
	marks.clear()
	for b in boats:
		if is_instance_valid(b):
			b.max_speed_factor = 1.0
			b.locked = false
			b.set_input(0.0, 0.0)
	boats.clear()
	if world.coast:
		world.coast.moor_boats()


## An arrow pointing to the next mark (up = straight ahead), with its name and distance.
class TargetArrow extends Control:
	var angle := 0.0
	var text := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.42)
		draw_circle(c, 46.0, Color(0, 0, 0, 0.45))
		var pts := PackedVector2Array([Vector2(0, -38), Vector2(26, 6), Vector2(9, 6), Vector2(9, 30), Vector2(-9, 30), Vector2(-9, 6), Vector2(-26, 6)])
		var rot := PackedVector2Array()
		for p in pts:
			rot.append(c + p.rotated(angle))
		draw_colored_polygon(rot, Color("4ee05a"))
		rot.append(rot[0])
		draw_polyline(rot, Color(0, 0, 0, 0.8), 3.0)
		var f := get_theme_default_font()
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var at := Vector2(size.x * 0.5 - w * 0.5, size.y - 8.0)
		draw_string_outline(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.85))
		draw_string(f, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f4f1ea"))
