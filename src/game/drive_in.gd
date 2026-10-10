class_name DriveIn
extends Node
## The drive-in burger "Zum Durchfahrer" (doc/oststadt.md): order at the post from the car,
## pay and pick up at the window, eat in the car. The family order is a memory game: the
## family on the back seat calls out what they want, the window asks it back in order.

const OPEN := [7, 24]
const FAMILY := ["Papa", "Mama", "Oma", "Opa", "Lotta", "Ben", "Tante Inge"]

var world: World
var order: Array[String] = []      # waiting at the window (food ids)
var family: Array = []             # [[who, food], ...] of a family order
var family_step := 0
var order_spot: FunctionSpot
var window_spot: FunctionSpot
var rng := RandomNumberGenerator.new()


func setup(w: World) -> void:
	world = w
	name = "DriveIn"
	rng.randomize()
	var pts := CityBuilder.drive_in_points()
	order_spot = _spot("DriveInOrder", pts["order_car"], func(a: Actor) -> String: return _order_prompt(a), func(a: Actor) -> void: _order(a))
	window_spot = _spot("DriveInWindow", pts["window_car"], func(a: Actor) -> String: return _window_prompt(a), func(a: Actor) -> void: _window(a))
	# On foot at the post: a hint instead of an order.
	var foot := FunctionSpot.new()
	foot.name = "DriveInOnFoot"
	foot.position = Vector3(pts["order_post"].x, 0.0, pts["order_post"].y)
	foot.radius = 2.8
	foot.prompt_fn = func(_a: Actor) -> String: return "Bestellen nur im Auto (Drive-in)"
	foot.available_fn = func(_a: Actor) -> bool: return false
	world.city.add_child(foot)


func _spot(id: String, p: Vector2, prompt: Callable, action: Callable) -> FunctionSpot:
	var s := FunctionSpot.new()
	s.name = id
	s.position = Vector3(p.x, 0.0, p.y)
	s.radius = 2.6
	s.from_car = true
	s.prompt_fn = prompt
	s.action_fn = action
	s.available_fn = func(a: Actor) -> bool: return is_open() and a.vehicle != null and a.vehicle.is_standing()
	world.city.add_child(s)
	return s


static func is_open() -> bool:
	var h := Clock.hour()
	return h >= OPEN[0] and h < OPEN[1]


func _order_prompt(a: Actor) -> String:
	if a.vehicle == null:
		return ""
	if not is_open():
		return "Drive-in geschlossen (7–24 Uhr)"
	if not order.is_empty() or not family.is_empty():
		return "Bitte vorfahren zum Abholfenster"
	return "Bestellen" if a.vehicle.is_standing() else "Anhalten zum Bestellen"


func _window_prompt(a: Actor) -> String:
	if a.vehicle == null or not is_open():
		return ""
	if order.is_empty() and family.is_empty():
		return "Erst an der Säule bestellen"
	return "Bestellung abholen" if a.vehicle.is_standing() else "Anhalten zum Abholen"


func _order(a: Actor) -> void:
	if not order.is_empty() or not family.is_empty():
		return
	Sound.play("beep", order_spot.global_position)
	var options := []
	for f: String in Food.DRIVE_IN:
		var it: Dictionary = Food.ITEMS[f]
		options.append({"text": "%s – %s" % [it["name"], GameState.format_money(it["price"])], "id": f})
	options.append({"text": "Familienbestellung (Merkspiel)", "id": "family"})
	options.append({"text": "Nichts, danke.", "id": ""})
	UI.dialog("Drive-in „Zum Durchfahrer“", "Knister … Herzlich willkommen! Was darf's sein?", options, func(choice: String) -> void:
		if choice == "family":
			_start_family()
		elif choice != "":
			order.append(choice)
			GameState.toast.emit("%s bestellt. Bitte am Fenster abholen!" % Food.ITEMS[choice]["name"], "info"))


## The family calls out 3–6 dishes (more after each perfect order); remember them.
func _start_family() -> void:
	family.clear()
	family_step = 0
	var n := clampi(3 + GameState.stat("family_orders_perfect"), 3, 6)
	var who := FAMILY.duplicate()
	for i in n:
		var person: String = who.pop_at(rng.randi() % who.size())
		family.append([person, Food.DRIVE_IN[rng.randi() % Food.DRIVE_IN.size()]])
	var lines := []
	for f: Array in family:
		lines.append("%s: „%s!“" % [f[0], Food.ITEMS[f[1]]["name"]])
	UI.dialog("Auf dem Rücksitz", "Alle rufen durcheinander – merk dir die Reihenfolge!\n" + "\n".join(lines),
		[{"text": "Alles klar, gemerkt!", "id": "ok"}])


func _window(a: Actor) -> void:
	if not family.is_empty():
		_family_question(a)
		return
	if order.is_empty():
		return
	var total := 0
	for f: String in order:
		total += int(Food.ITEMS[f]["price"])
	if not GameState.spend(total):
		order.clear()
		GameState.toast.emit("Ohne Geld kein Burger – die Bestellung ist storniert.", "warn")
		return
	Sound.play("coin")
	for f: String in order:
		Food.apply(a, f)
		GameState.add_to_set("drive_in_food", f)
	GameState.add_stat("drive_in_orders")
	a.emote("happy")
	GameState.toast.emit("Bitte schön! %s – direkt im Auto verputzt." % ", ".join(order.map(func(f: String) -> String: return Food.ITEMS[f]["name"])), "info")
	order.clear()


## At the window: "What did <who> want?" – four choices, in the order of the call.
func _family_question(a: Actor) -> void:
	var entry: Array = family[family_step]
	var right: String = entry[1]
	var choices: Array[String] = [right]
	var pool := Food.DRIVE_IN.duplicate()
	pool.shuffle()
	for f: String in pool:
		if choices.size() >= 4:
			break
		if not f in choices:
			choices.append(f)
	choices.shuffle()
	var options := []
	for f: String in choices:
		options.append({"text": Food.ITEMS[f]["name"], "id": f})
	UI.dialog("Abholfenster", "Und was war für %s? (%d von %d)" % [entry[0], family_step + 1, family.size()], options, func(choice: String) -> void:
		if choice == "":
			return
		if choice != right:
			Sound.play("fail")
			GameState.toast.emit("Falsch! %s wollte %s. Die Familie murrt …" % [entry[0], Food.ITEMS[right]["name"]], "warn")
			a.needs.cheer(-3.0)
			family.clear()
			return
		family_step += 1
		if family_step < family.size():
			_family_question.call_deferred(a)   # after this dialog has closed
			return
		var tip := 150 + family.size() * 50
		GameState.add_money(tip, "Trinkgeld der Familie")
		GameState.add_stat("family_orders_perfect")
		a.needs.cheer(10.0)
		Food.apply(a, "shake")
		Sound.play("success")
		GameState.toast.emit("Alles richtig! Die Familie spendiert dir einen Milchshake.", "info")
		family.clear())
