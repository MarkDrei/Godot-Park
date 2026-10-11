class_name AreaGates
extends RefCounted
## The border between the park (with the Nordwald) and the Oststadt (doc/arc42.md §8.8).
## What belongs to one area stays there: crossing ends the dog walk (the dog stays), lets go
## of every leash and ends a game of the other area; cars can't leave the town anyway. With
## split areas (setting "Bereiche") the gates ask first, then the areas swap behind a loading
## screen. Called every frame by the PlayerController.

const ASK_DIST := 2.5        # metres from the fence where a gate asks
const GATES := ["gate_e", "gate_forest_e"]

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
	if a == null or world.switching or world.city_loading:
		return
	if a != _actor:
		_actor = a        # a switch is no crossing: the new character keeps its dogs
		_area = ""
	var here := World.area_of(a.global_position)
	if _area != "" and here != _area:
		for line in leave_behind(here):
			GameState.toast.emit(line, "info")
	_area = here
	var other := "city" if here == "park" else "park"
	if world.area != here or not world.area_awake(here) or (world.split_areas and world.area_awake(other)):
		world.enter_area(here)   # put there (switch, test, dev option): no question
		return
	var p := a.ground_pos()
	if a.vehicle:
		_car_border(p)
	elif world.split_areas:
		_gate(p, here)
	elif world.city == null and PlayerController.near_city_gate(p):
		world.load_city()        # built in time, so walking through is seamless


## The gate near p ("" if none): within `dist` of the fence and in the gate's opening.
static func gate_at(p: Vector2, dist: float) -> String:
	for id: String in GATES:
		var g := ParkLayout.place(id)
		if absf(p.x - g.x) < dist and absf(p.y - g.y) < maxf(3.5, dist):
			return id
	return ""


## What stays behind when the player goes into area `to`, as lines for the player. Unless
## `dry`, it also happens: the dog walk ends, leashes are let go, games of the old area end.
func leave_behind(to: String, dry := false) -> Array[String]:
	var out: Array[String] = []
	var a := pc.actor
	var where := "im Park" if to == "city" else "in der Oststadt"
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
	_asked = true
	var to := "city" if here == "park" else "park"
	var text := "Willst du in die Oststadt gehen? Park und Nordwald werden solange entladen." if to == "city" \
		else "Willst du zurück in den Park? Die Oststadt wird solange entladen."
	text += " Wer dort ist, steht bei deiner Rückkehr da, wo er um diese Uhrzeit hingehört."
	var lines := leave_behind(to, true)
	if not lines.is_empty():
		text += "\n\n" + "\n".join(lines)
	pc.actor.stop_moving()
	UI.dialog(ParkLayout.PLACES[gate]["name"], text, [{"text": "Ja, in die Oststadt" if to == "city" else "Ja, in den Park", "id": "go"},
		{"text": "Nein, hierbleiben", "id": ""}], func(c: String) -> void:
			if c == "go":
				cross(gate, to))


## Through `gate` into area `to`: what belongs here stays, the areas swap, the player steps
## out on the other side of the gate.
func cross(gate: String, to: String) -> void:
	leave_behind(to)
	await world.enter_area(to)
	var g := ParkLayout.place(gate)
	var dir := 1.0 if to == "city" else -1.0
	var q := Vector2(ParkLayout.CITY_EDGE + dir * 3.0, g.y)
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
