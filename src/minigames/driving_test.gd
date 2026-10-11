class_name DrivingTest
extends DriveJob
## Driving test with Fahrlehrer Friedrich: a round through the Oststadt in the driving school
## car, checkpoint by checkpoint. Errors: red lights, speeding (50 km/h, 30 km/h south of the
## Parkallee), bumps. At most two errors: passed, the "Führerschein".

const MAX_ERRORS := 2
const LIMIT := 13.9              # 50 km/h
const LIMIT_30 := 8.3            # 30 km/h in the residential streets (south of the Parkallee)
const TOLERANCE := 1.1
## The route: points on the right lanes (from the driving school round the block and back).
const ROUTE := [Vector2(278.25, -106), Vector2(262, -91.75), Vector2(228, -91.75), Vector2(208.25, -72),
	Vector2(208.25, -30), Vector2(228, -10.25), Vector2(262, -10.25), Vector2(278.25, 10), Vector2(278.25, 42),
	Vector2(298, 61.75), Vector2(332, 61.75), Vector2(351.75, 42), Vector2(351.75, 0), Vector2(351.75, -60),
	Vector2(332, -91.75), Vector2(298, -91.75), Vector2(281.75, -110), Vector2(281.75, -122)]

var point := 0
var errors := 0
var notes: Array[String] = []
var _red_runs := 0
var _speeding := 0.0
var _speed_cool := 0.0
var _bumps_seen := 0
var time := 0.0


func _init() -> void:
	super()
	title = "Fahrprüfung"
	host_id = "friedrich"


func describe() -> String:
	return "Fahrprüfung bei Fahrlehrer Friedrich: eine Runde durch die Oststadt. Rote Ampeln, zu schnell (50, südlich der Parkallee 30) und Rempler sind Fehler – höchstens zwei."


func can_start(a: Actor) -> bool:
	return a.is_human() and not active


func begin() -> void:
	var learner: Car = world.city.find_car("learner")
	if actor.vehicle and actor.vehicle != learner:
		game.player.exit_car(true)
	if learner and actor.vehicle == null:
		learner.locked = false
		learner.speed = 0.0
		learner.place(Vector2(278.25, -126), 0.0)
		game.player.enter_car(learner)
	start_driving()
	point = 0
	errors = 0
	notes.clear()
	time = 0.0
	_red_runs = world.city.traffic.red_runs
	_bumps_seen = 0
	_speeding = 0.0
	host_say("Spiegel, Blinker, Schulterblick – und los. Fahr einfach den Lichtsäulen nach.", 3.5)
	_show_point()


func _show_point() -> void:
	show_target(ROUTE[point], "Prüfungsstrecke %d/%d" % [point + 1, ROUTE.size()], Color(0.5, 0.8, 1.0))


static func limit_at(p: Vector2) -> float:
	return LIMIT_30 if p.y > CityLayout.Z_STREETS[3]["z"] + 6.0 else LIMIT


func job_tick(delta: float) -> void:
	time += delta
	var c := car()
	set_score("Punkt %d/%d · Fehler %d/%d · %d km/h (max %d)" % [point + 1, ROUTE.size(), errors, MAX_ERRORS, CarSpecs.kmh(c.speed), CarSpecs.kmh(limit_at(c.pos2()))])
	# Red lights (counted by the traffic).
	var reds: int = world.city.traffic.red_runs
	if reds > _red_runs:
		_red_runs = reds
		_error("Über Rot gefahren!")
	# Speeding for more than a second counts once, then not again for a while.
	_speed_cool -= delta
	if absf(c.speed) > limit_at(c.pos2()) * TOLERANCE:
		_speeding += delta
		if _speeding > 1.0 and _speed_cool <= 0.0:
			_speed_cool = 6.0
			_error("Zu schnell!")
	else:
		_speeding = 0.0
	if bumps > _bumps_seen:
		_bumps_seen = bumps
		_error("Angeeckt!")
	if c.pos2().distance_to(ROUTE[point]) < 8.0 and (point < ROUTE.size() - 1 or c.is_standing()):
		point += 1
		Sound.play("click")
		if point >= ROUTE.size():
			_finish()
			return
		_show_point()
	if time > 300.0:
		_error("Zu langsam!")
		_finish()


func _error(text: String) -> void:
	errors += 1
	notes.append(text)
	host_say(text, 2.0)
	Sound.play("fail")


func _finish() -> void:
	var passed := errors <= MAX_ERRORS and point >= ROUTE.size()
	if passed:
		GameState.set_stat("license", 1)
	end({"won": passed, "money": 1000 if passed else 0, "joy": 25.0 if passed else 5.0,
		"text": ("Bestanden! Friedrich überreicht dir den Führerschein. (%d Fehler)" % errors) if passed
			else "Nicht bestanden: %s Friedrich: „Nächstes Mal!“" % " ".join(notes)})


func job_left() -> void:
	end({"won": false, "joy": 2.0, "text": "Prüfung abgebrochen – du bist ausgestiegen."})
