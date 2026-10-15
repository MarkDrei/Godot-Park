class_name AreaGates
extends RefCounted
## The borders between the park (with the Nordwald), the Oststadt and the Westpark
## (doc/arc42.md §8.8). What belongs to one area stays there: crossing ends the dog walk (the
## dog stays), lets go of every leash and ends a game of the other area; cars can't leave the
## town anyway. With split areas (setting "Bereiche") the gates ask first, then the areas swap
## behind a loading screen. Called every frame by the PlayerController.

const ASK_DIST := 2.5        # metres from the fence where a gate asks
const NEAR := 10.0           # metres from a gate where the area beyond is built (not split)
## Gate -> the area beyond it as seen from the park.
const GATES := {"gate_e": "city", "gate_forest_e": "city", "gate_w": "fair"}

var pc: PlayerController
var world: World
var _actor: Actor
var _area := ""              # where the controlled actor stood last frame
var _asked := false          # answered at this gate: not again until the player steps away
var _car_hint := false


func _init(controller: PlayerController) -> void:
	pc = controller
	world = controller.world


func update() -> void:
	var a := pc.actor
	if a == null or world.switching or world.loading():
		return
	if a != _actor:
		_actor = a        # a switch is no crossing: the new character keeps its dogs
		_area = ""
	var here := World.area_of(a.global_position)
	if _area != "" and here != _area:
		for line in leave_behind(here, false, _area):
			GameState.toast.emit(line, "info")
	_area = here
	var others_awake := world.areas.keys().any(func(o: String) -> bool: return o != here and world.area_awake(o))
	if world.player_area != here or not world.area_awake(here) or (world.split_areas and others_awake):
		world.enter_area(here)   # put there (switch, test, dev option): no question
		return
	var p := a.ground_pos()
	if a.vehicle:
		_car_border(p)
	elif world.split_areas:
		_gate(p, here)
	else:
		for id: String in GATES.values():
			if not world.area(id).is_built() and approaching(id, p):
				world.load_area(id)        # built in time, so walking through is seamless
				break


## The gate near p ("" if none): within `dist` of the fence and in the gate's opening.
static func gate_at(p: Vector2, dist: float) -> String:
	for id: String in GATES:
		var g := ParkLayout.place(id)
		if absf(p.x - g.x) < dist and absf(p.y - g.y) < maxf(3.5, dist):
			return id
	return ""


## Close to `area` from the park: within NEAR of one of its gates, or a metre from its edge.
static func approaching(area: String, p: Vector2) -> bool:
	for id: String in GATES:
		if GATES[id] == area and p.distance_to(ParkLayout.place(id)) < NEAR:
			return true
	for dx: float in [-1.0, 1.0]:
		if World.area_of(Vector3(p.x + dx, 0, p.y)) == area:
			return true
	return false


## What stays behind when the player goes from area `from` into area `to`, as lines for the
## player. Unless `dry`, it also happens: the dog walk ends, leashes are let go, games of the
## old area end.
func leave_behind(to: String, dry := false, from := "") -> Array[String]:
	var out: Array[String] = []
	var a := pc.actor
	if from == "":
		from = World.area_of(a.global_position)
	var where: String = world.area(from).name_in
	var q := Gameplay.quests
	var walk_dog := q.walk_dog if q.walk_state != "" else null
	if walk_dog:
		out.append("%s bleibt %s, der Gassi-Auftrag endet." % [walk_dog.display_name, where])
		if not dry:
			q.cancel_walk()
	for d in a.leash_dogs.duplicate():
		if d != walk_dog:
			out.append("%s bleibt %s." % [d.display_name, where])
		if not dry:
			a.detach_leash(d)
	for id: String in Gameplay.minigames:
		var m: Minigame = Gameplay.minigames[id]
		if m.active and Gameplay.game_spots.has(id) and World.area_of(Gameplay.game_spots[id]) != to:
			out.append("%s endet." % m.title)
			if not dry:
				m.end({"won": false, "joy": 0.0})
	return out


func _car_border(p: Vector2) -> void:
	if gate_at(p, 12.0) == "":
		_car_hint = false
	elif not _car_hint and gate_at(p, 9.0) != "":
		_car_hint = true
		GameState.toast.emit("Autos bleiben in der Stadt. Steig aus, um in den Park zu gehen.", "info")


func _gate(p: Vector2, here: String) -> void:
	if gate_at(p, 5.0) == "":
		_asked = false
		return
	var gate := gate_at(p, ASK_DIST)
	if gate == "" or _asked or UI.blocks_game_input():
		return
	var beyond: String = GATES[gate]
	if here != "park" and here != beyond:
		return
	_asked = true
	var to := beyond if here == "park" else "park"
	var text := "%s %s" % [world.area(to).go_question, world.area(here).sleeps_line]
	text += " Wer dort ist, steht bei deiner Rückkehr da, wo er um diese Uhrzeit hingehört."
	var lines := leave_behind(to, true, here)
	if not lines.is_empty():
		text += "\n\n" + "\n".join(lines)
	pc.actor.stop_moving()
	UI.dialog(ParkLayout.PLACES[gate]["name"], text, [{"text": world.area(to).go_yes, "id": "go"},
		{"text": "Nein, hierbleiben", "id": ""}], func(c: String) -> void:
			if c == "go":
				cross(gate, to))


## Through `gate` into area `to`: what belongs here stays, the areas swap, the player steps
## out on the other side of the gate.
func cross(gate: String, to: String) -> void:
	leave_behind(to)
	await world.enter_area(to)
	var g := ParkLayout.place(gate)
	var dir := 1.0 if to == "city" or (to == "park" and GATES[gate] == "fair") else -1.0
	var q := Vector2(g.x + dir * 3.0, g.y)
	if world.map.is_solid(q):
		var c := world.nav.nearest_open(q)
		if c.x >= 0:
			q = ParkMap.cell_center(c)
	var a := pc.actor
	a.teleport(Vector3(q.x, 0, q.y))
	a.face(a.global_position + Vector3(dir, 0, 0), true)
	pc.camera.follow(a, false)
	_area = to
	_asked = true    # right at the gate on the other side: don't ask back at once
