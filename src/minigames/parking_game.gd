class_name ParkingGame
extends DriveJob
## Parking practice with Fahrlehrer Friedrich on the driving school's lot: forwards into a
## gap, backwards into a gap, and parallel parking between two cars. Stand still inside the
## box: the closer to its middle and the straighter, the more stars; touching a car costs one.

## Tasks: name, box centre, box yaw (the way the car must face), start position and yaw,
## the two neighbour cars [pos, yaw].
const TASKS := [
	{"name": "Vorwärts einparken", "box": Vector2(331, -135), "yaw": PI / 2, "start": Vector2(310, -135), "start_yaw": PI / 2,
		"cars": [[Vector2(331, -131.6), PI / 2], [Vector2(331, -138.4), PI / 2]]},
	{"name": "Rückwärts einparken", "box": Vector2(331, -122), "yaw": -PI / 2, "start": Vector2(313, -122), "start_yaw": -PI / 2,
		"cars": [[Vector2(331, -118.6), -PI / 2], [Vector2(331, -125.4), -PI / 2]]},
	{"name": "Längs einparken", "box": Vector2(312, -144.6), "yaw": PI / 2, "start": Vector2(319, -140.4), "start_yaw": PI / 2,
		"cars": [[Vector2(304.6, -144.6), PI / 2], [Vector2(319.4, -144.6), PI / 2]]},
]
const BOX := Vector2(2.6, 5.4)          # width, length
const TIME := 50.0

var task := 0
var stars: Array[int] = []
var time_left := 0.0
var still := 0.0
var touched := false
var neighbours: Array[Car] = []
var lines: MeshInstance3D


func _init() -> void:
	super()
	title = "Einparken üben"
	host_id = "friedrich"
	vehicle_kind = ""


func describe() -> String:
	return "Bei Fahrlehrer Friedrich auf dem Übungsplatz der Fahrschule: vorwärts, rückwärts und längs einparken. Je mittiger und gerader, desto mehr Sterne."


## Talking to Friedrich is enough: he puts you into the driving school's car.
func can_start(a: Actor) -> bool:
	return a.is_human() and not active


func begin() -> void:
	var learner: Car = world.city.find_car("learner")
	if actor.vehicle and actor.vehicle != learner:
		game.player.exit_car(true)
	if learner and actor.vehicle == null:
		learner.locked = false
		learner.place(TASKS[0]["start"], TASKS[0]["start_yaw"])
		game.player.enter_car(learner)
	start_driving()
	stars.clear()
	task = 0
	_setup_task()


func _setup_task() -> void:
	_clear_neighbours()
	var t: Dictionary = TASKS[task]
	var c := car()
	c.speed = 0.0
	c.place(t["start"], t["start_yaw"])
	for n: Array in t["cars"]:
		var nc := world.city.spawn_car(CarSpecs.ORDINARY[neighbours.size() % 3], CarSpecs.COLORS[(task * 2 + neighbours.size()) % CarSpecs.COLORS.size()], n[0], n[1])
		nc.locked = true
		nc.job = "parking"
		neighbours.append(nc)
	_draw_box(t)
	show_target(t["box"], t["name"], Color(0.5, 1.0, 0.6))
	time_left = TIME
	still = 0.0
	touched = false
	bumps = 0
	set_info("%s (%d/3): stell das Auto gerade in das grüne Feld und halte an. %s" % [t["name"], task + 1, "Rückwärts: S / Bremse halten." if task > 0 else ""])
	host_say(["Ganz ruhig, vorwärts in die Lücke.", "Jetzt rückwärts. Schulterblick!", "Und nun die Königsdisziplin: längs einparken."][task], 3.0)


func _draw_box(t: Dictionary) -> void:
	if lines:
		lines.queue_free()
	var kit := MeshKit.new()
	var w := BOX.x * 0.5
	var l := BOX.y * 0.5
	var col := Color("7fe08a")
	for s: float in [-1.0, 1.0]:
		kit.box(Vector3(s * w, 0.02, 0), Vector3(0.14, 0.01, BOX.y), col)
		kit.box(Vector3(0, 0.02, s * l), Vector3(BOX.x, 0.01, 0.14), col)
	kit.box(Vector3(0, 0.021, l - 0.6), Vector3(0.6, 0.01, 0.6), Color("f4f4f0"))   # where the nose goes
	lines = MeshInstance3D.new()
	lines.mesh = kit.commit()
	var b: Vector2 = t["box"]
	lines.transform = Transform3D(Basis(Vector3.UP, t["yaw"]), Vector3(b.x, 0.0, b.y))
	world.add_child(lines)


## Stars for the car standing at its pose (0 = not in the box).
func rate(p: Vector2, yaw: float, t: Dictionary) -> int:
	var b: Vector2 = t["box"]
	var f := Vector2(sin(t["yaw"]), cos(t["yaw"]))
	var r := Car.right_of(f)
	var d := p - b
	var along := absf(d.dot(f))
	var side := absf(d.dot(r))
	var angle := absf(angle_difference(yaw, t["yaw"]))
	if task == 2:
		angle = minf(angle, absf(angle_difference(yaw + PI, t["yaw"])))   # either way along the curb
	if along > 1.2 or side > 0.5 or angle > 0.35:
		return 0
	if along < 0.45 and side < 0.22 and angle < 0.08:
		return 3
	if along < 0.8 and side < 0.35 and angle < 0.18:
		return 2
	return 1


func job_tick(delta: float) -> void:
	time_left -= delta
	var c := car()
	set_score("Aufgabe %d/3 · %d s · %d Sterne" % [task + 1, maxi(0, int(time_left)), _total()])
	if bumps > 0 and not touched:
		touched = true
		host_say("Autsch! Das war das Nachbarauto.", 2.0)
	if c.is_standing() and absf(c.throttle_input) < 0.05:
		still += delta
	else:
		still = 0.0
	var s := rate(c.pos2(), c.yaw, TASKS[task])
	if (still > 1.2 and s > 0) or time_left <= 0.0:
		_finish_task(s if time_left > 0.0 else 0)


func _finish_task(s: int) -> void:
	if touched:
		s = maxi(0, s - 1)
	stars.append(s)
	host_say(["Das üben wir noch.", "Na ja, steht.", "Gut gemacht!", "Perfekt! Wie aus dem Lehrbuch."][s], 2.5)
	Sound.play("success" if s >= 2 else "click")
	task += 1
	if task >= TASKS.size():
		var total := _total()
		GameState.set_stat_max("parking_best", total)
		end({"won": total >= 7, "money": total * 50, "joy": 15.0 + total,
			"text": "Einparken: %d von 9 Sternen. %s" % [total, "Friedrich ist stolz auf dich!" if total >= 7 else "Friedrich: „Üben, üben, üben.“"]})
	else:
		_setup_task()


func _total() -> int:
	var n := 0
	for s in stars:
		n += s
	return n


func _clear_neighbours() -> void:
	for n in neighbours:
		if is_instance_valid(n):
			world.city.remove_car(n)
	neighbours.clear()


func job_left() -> void:
	end({"won": false, "joy": 3.0, "text": "Einparken abgebrochen – du bist ausgestiegen."})


func cleanup() -> void:
	super()
	_clear_neighbours()
	if lines:
		lines.queue_free()
		lines = null
