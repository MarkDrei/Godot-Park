class_name IceVanJob
extends DriveJob
## Ice cream van for Eismann Gianni: drive through the residential streets (south of the
## Parkallee), stop and the jingle plays; children come running and call their flavour.
## Pick the right one with the buttons (or keys 1–4). Eight children, or five minutes.

const FLAVOURS := ["Erdbeere", "Schoko", "Vanille", "Pistazie"]
const KIDS := 8
const TIME := 300.0
const PRICE := 200

var rng := RandomNumberGenerator.new()
var served := 0
var wrong := 0
var queue: Array = []            # [{kid, wish}] waiting at the hatch or on the way
var stopped := 0.0
var played_here := Vector2.INF
var time := 0.0
var _flavour_buttons: Array[Button] = []


func _init() -> void:
	super()
	title = "Eiswagen-Tour"
	host_id = "gianni"
	vehicle_kind = "icecream"
	rng.randomize()


func describe() -> String:
	return "Mit Eismann Giannis Eiswagen (vor der Gelateria) durch die Wohnstraßen südlich der Parkallee: anhalten, Kinder kommen, die richtige Sorte reichen."


func begin() -> void:
	start_driving()
	served = 0
	wrong = 0
	time = 0.0
	queue.clear()
	played_here = Vector2.INF
	stopped = 0.0
	hide_target()
	set_info("Halte in einer Wohnstraße südlich der Parkallee an: die Melodie lockt die Kinder.")
	_flavour_buttons.clear()
	for i in FLAVOURS.size():
		_flavour_buttons.append(add_button(FLAVOURS[i], func() -> void: serve(i), 130))


## Residential: the streets south of the Parkallee.
static func residential(p: Vector2) -> bool:
	return p.y > CityLayout.Z_STREETS[3]["z"] + 4.0


func job_tick(delta: float) -> void:
	time += delta
	var c := car()
	set_score("Eis verkauft %d/%d · %d s" % [served, KIDS, maxi(0, int(TIME - time))])
	if c.is_standing() and residential(c.pos2()):
		stopped += delta
		if stopped > 1.5 and (played_here == Vector2.INF or played_here.distance_to(c.pos2()) > 25.0):
			_jingle()
	else:
		stopped = 0.0
	# Children at the hatch only wait while the van stands.
	for q: Dictionary in queue.duplicate():
		var kid: Actor = q["kid"]
		if not c.is_standing() and kid.distance_to(c.global_position) > 6.0:
			_send_away(q, false)
		elif not q["asked"] and kid.distance_to(Vector3(hatch().x, 0, hatch().y)) < (1.6 if kid.is_moving() else 4.0):
			q["asked"] = true
			kid.face(c.global_position)
			kid.say("%s, bitte!" % FLAVOURS[q["wish"]], 6.0)
	if served >= KIDS or time >= TIME:
		end({"won": served >= KIDS, "joy": 15.0 + served,
			"text": "%d Kinder glücklich gemacht%s." % [served, ", %d Mal die falsche Sorte" % wrong if wrong > 0 else ""]})


## Where the children stand: beside the hatch on the van's right side.
func hatch() -> Vector2:
	var c := car()
	return c.pos2() + Car.right_of(c.forward2()) * (c.width() * 0.5 + 0.7) - c.forward2() * 0.6


func _jingle() -> void:
	played_here = car().pos2()
	Sound.play("jingle", car().global_position)
	var n := 1 + rng.randi() % 2
	for kid in _free_kids():
		if n <= 0:
			break
		n -= 1
		var houses := CityLayout.houses().filter(func(h: Dictionary) -> bool: return (h["door"] as Vector2).distance_to(played_here) < 45.0)
		var door: Vector2 = (houses[rng.randi() % houses.size()] if not houses.is_empty() else {"door": played_here})["door"]
		kid.brain.suspend()
		(kid.brain as HumanBrain).think = 600.0
		kid.inside = false
		kid.visible = true
		kid.teleport(Vector3(door.x, 0, door.y))
		var h := hatch()
		# A parked car beside the van: the children wait on the sidewalk next to it.
		if world.city.car_at(h, 0.4) != null:
			h += Car.right_of(car().forward2()) * 2.6
		kid.go_to(Vector3(h.x, 0, h.y), true)
		queue.append({"kid": kid, "wish": rng.randi() % FLAVOURS.size(), "asked": false})


func _free_kids() -> Array[Actor]:
	var out: Array[Actor] = []
	for a in world.actors:
		if a.actor_id.begins_with("kid_") and not a.controlled and not queue.any(func(q: Dictionary) -> bool: return q["kid"] == a):
			out.append(a)
	out.shuffle()
	return out


## The child at the front of the queue gets flavour i.
func serve(i: int) -> void:
	if not active:
		return
	for q: Dictionary in queue:
		if q["asked"]:
			var kid: Actor = q["kid"]
			if i == q["wish"]:
				served += 1
				GameState.add_stat("ice_sold")
				GameState.add_money(PRICE, "Eis verkauft")
				kid.say(["Juhu!", "Lecker!", "Danke, Eismann!"][rng.randi() % 3], 2.0)
				kid.emote("happy")
				Sound.play("coin")
				_send_away(q, true)
			else:
				wrong += 1
				kid.say("Ich wollte doch %s!" % FLAVOURS[q["wish"]], 2.5)
				kid.emote("sad")
				_send_away(q, false)
			return


func _send_away(q: Dictionary, happy: bool) -> void:
	queue.erase(q)
	var kid: Actor = q["kid"]
	if happy:
		kid.set_item("icecream")
	(kid.brain as HumanBrain).think = 3.0


func job_left() -> void:
	end({"won": served >= KIDS, "joy": 5.0 + served, "text": "Tour beendet: %d Eis verkauft." % served})


func cleanup() -> void:
	super()
	for q: Dictionary in queue:
		_send_away(q, false)
	queue.clear()
	_flavour_buttons.clear()


## Keys 1–4 hand out the flavours (the job is free roam: the base class passes no keys on).
func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_4:
			serve(k - KEY_1)
			get_viewport().set_input_as_handled()
