class_name AlmondShift
extends Minigame
## Der müde Budenbesitzer: Mandel-Manni is tired in the afternoon; the player takes over his
## stand. Customers ask for a small or a big bag, with or without extra cinnamon; get both
## right for each. Eight customers, a minute. Manni naps on a bench meanwhile.

const CUSTOMERS := 8
const ROUND := 60.0
const PAY := 150             # per right order (cents)
var served := 0
var right := 0
var _order := {}             # {"size": "klein"|"groß", "cinnamon": bool}
var _pick := {}
var _left := ROUND
var _customer: Actor
var _queue: Array[Actor] = []


func _init() -> void:
	title = "Schicht am Mandelstand"
	host_id = "manni"


func describe() -> String:
	return "Mandel-Manni ist nachmittags müde: Übernimm seinen Stand und bediene acht Kunden richtig. Lohn: Geld und Tickets."


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.fair != null and tired_now()


func host_available() -> bool:
	return super() and tired_now()


## Manni is tired between three and six in the afternoon (once a day).
static func tired_now() -> bool:
	var h := Clock.hour()
	return h >= 15.0 and h < 18.0 and GameState.stat("shift_day") != Clock.day + 1


func begin() -> void:
	served = 0
	right = 0
	_left = ROUND
	GameState.set_stat("shift_day", Clock.day + 1)
	var b: Dictionary = world.fair.booths["almonds"]
	var vendor: Vector3 = b["vendor"]
	var counter: Vector3 = b["pos"]
	actor.teleport(vendor)
	actor.face(counter, true)
	var h := host()
	if h:
		var seat := world.find_free_seat(counter, h, 40.0)
		if seat:
			h.teleport(seat.approach_point())
			h.sit_on(seat)
			h.anim = "sleep"
	var dir := (vendor - counter).normalized()
	look(vendor + dir * 1.6 + Vector3(0.8, 1.8, 0), counter + Vector3(0, 1.0, 0))
	_queue.clear()
	for a in world.actors:
		if a.home_region == "fair" and a.is_human() and not a.inside and not a.controlled and a.def.get("role", "") in ["visitor", "kid"]:
			_queue.append(a)
	_queue.shuffle()
	for btn: Array in [["Kleine Tüte", "size", "klein"], ["Große Tüte", "size", "groß"], ["Mit Zimt", "cinnamon", true], ["Ohne Zimt", "cinnamon", false]]:
		var key: String = btn[1]
		var val: Variant = btn[2]
		add_button(btn[0], func() -> void: pick(key, val), 150)
	_next_customer()


func _next_customer() -> void:
	if _customer and _customer.brain:
		_customer.brain.resume()
	_customer = null
	if served >= CUSTOMERS:
		_finish()
		return
	_order = {"size": ["klein", "groß"][randi() % 2], "cinnamon": randf() < 0.5}
	_pick = {}
	var counter: Vector3 = world.fair.booths["almonds"]["pos"]
	var who := "Kundin" if randf() < 0.5 else "Kunde"
	if not _queue.is_empty():
		_customer = _queue[served % _queue.size()]
		_customer.brain.suspend()
		_customer.teleport(counter + Vector3(randf_range(-0.3, 0.3), 0, 0))
		_customer.face(world.fair.booths["almonds"]["vendor"], true)
		who = _customer.display_name
	var line := "„Eine %s Tüte, %s Zimt bitte!“" % ["kleine" if _order["size"] == "klein" else "große", "mit extra" if _order["cinnamon"] else "ohne"]
	set_info("%s: %s" % [who, line])
	set_score("Kunde %d von %d · richtig: %d · Zeit: %d" % [served + 1, CUSTOMERS, right, ceili(_left)])


## A button: the bag's size or the cinnamon. Both chosen: served.
func pick(key: String, value: Variant) -> void:
	if not active or served >= CUSTOMERS:
		return
	_pick[key] = value
	if _pick.has("size") and _pick.has("cinnamon"):
		served += 1
		var ok: bool = _pick["size"] == _order["size"] and _pick["cinnamon"] == _order["cinnamon"]
		if ok:
			right += 1
			Sound.play("coin", null, -6.0)
			if _customer:
				_customer.say(["Danke!", "Lecker!", "Genau so!"][randi() % 3], 1.5)
		else:
			Sound.play("click", null, -4.0)
			if _customer:
				_customer.say(["Das wollte ich nicht …", "Hm, na gut.", "Falsche Tüte!"][randi() % 3], 1.5)
		_next_customer()


func _process(delta: float) -> void:
	if not active:
		return
	_left -= delta
	set_score("Kunde %d von %d · richtig: %d · Zeit: %d" % [mini(served + 1, CUSTOMERS), CUSTOMERS, right, ceili(maxf(_left, 0.0))])
	if _left <= 0.0 and served < CUSTOMERS:
		served = CUSTOMERS
		_next_customer()


func _finish() -> void:
	var money := right * PAY
	var tickets := right
	if right == CUSTOMERS:
		tickets += 5
	GameState.add_tickets(tickets, "Schicht am Mandelstand")
	GameState.set_stat_max("shift_best", right)
	var text := "%d von %d Kunden richtig bedient." % [right, CUSTOMERS]
	text += " Mandel-Manni wacht auf: „Was, schon vorbei? Danke dir!“" if right >= 5 else " Mandel-Manni gähnt: „Naja … Hauptsache, die Mandeln sind noch da.“"
	end_after(1.2, {"won": right >= 5, "money": money, "joy": 15.0 + right, "text": text})


func cleanup() -> void:
	if _customer and _customer.brain:
		_customer.brain.resume()
	_customer = null
	var h := host()
	if h:
		if h.seat:
			h.stand_up()
		h.anim = "idle"
	if actor:
		var counter: Vector3 = world.fair.booths["almonds"]["pos"]
		actor.teleport(counter + (counter - world.fair.booths["almonds"]["vendor"]).normalized() * 0.6)


func game_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_1: pick("size", "klein")
			KEY_2: pick("size", "groß")
			KEY_3: pick("cinnamon", true)
			KEY_4: pick("cinnamon", false)
