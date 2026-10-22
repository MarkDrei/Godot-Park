class_name AreaGates
extends RefCounted
## The borders between the park (with the Nordwald), the Oststadt, the Westpark, the
## Ritterburg and the Möwenbucht (doc/arc42.md §8.8). What belongs to one area stays there: crossing ends the dog walk (the
## dog stays), lets go of every leash and ends a game of the other area; cars can't leave the
## town anyway. With split areas (setting "Bereiche") the gates ask first, then the areas swap
## behind a loading screen. Called every frame by the PlayerController.

const ASK_DIST := 2.5        # metres from the fence where a gate asks
const NEAR := 10.0           # metres from a gate where the area beyond is built (not split)
## The gates between two areas: where (pos), which way the border is crossed (axis 0: along x,
## the fence runs north-south; 1: along z), the area on the lower side of that axis (lo) and on
## the higher side (hi), the gate's name and the way there ("zum Osttor"). Positions as in
## ParkLayout and BurgLayout.
const GATES := {
	"gate_e": {"pos": Vector2(130, -12), "axis": 0, "lo": "park", "hi": "city", "name": "Osttor", "to": "zum Osttor"},
	"gate_forest_e": {"pos": Vector2(130, -160), "axis": 0, "lo": "park", "hi": "city", "name": "Waldweg Ost", "to": "zum Waldweg Ost"},
	"gate_w": {"pos": Vector2(-130, 5), "axis": 0, "lo": "fair", "hi": "park", "name": "Westtor", "to": "zum Westtor"},
	"gate_forest": {"pos": Vector2(-130, -200), "axis": 0, "lo": "burg", "hi": "park", "name": "Waldweg", "to": "zum Waldweg"},
	"gate_burg_s": {"pos": Vector2(-260, -90), "axis": 1, "lo": "burg", "hi": "fair", "name": "Burgpforte", "to": "zur Burgpforte"},
	"gate_coast": {"pos": Vector2(0, 90), "axis": 1, "lo": "park", "hi": "coast", "name": "Südtor", "to": "zum Südtor"},
}

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
		for id: String in world.areas:
			if not world.area(id).is_built() and approaching(id, p):
				world.load_area(id)        # built in time, so walking through is seamless
				break


static func gate_pos(id: String) -> Vector2:
	return GATES[id]["pos"]


## The gate near p ("" if none): within `dist` of the fence and in the gate's opening.
static func gate_at(p: Vector2, dist: float) -> String:
	for id: String in GATES:
		var d: Vector2 = p - gate_pos(id)
		if GATES[id]["axis"] == 1:
			d = Vector2(d.y, d.x)
		if absf(d.x) < dist and absf(d.y) < maxf(3.5, dist):
			return id
	return ""


## The area on the other side of `gate` from `here` ("" if the gate does not touch `here`).
static func beyond(gate: String, here: String) -> String:
	var g: Dictionary = GATES[gate]
	if here == g["lo"]:
		return g["hi"]
	return g["lo"] if here == g["hi"] else ""


## Close to `area` from outside: within NEAR of one of its gates, or a metre from its edge.
static func approaching(area: String, p: Vector2) -> bool:
	for id: String in GATES:
		if area in [GATES[id]["lo"], GATES[id]["hi"]] and p.distance_to(gate_pos(id)) < NEAR:
			return true
	for d: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		if World.area_of(Vector3(p.x + d.x, 0, p.y + d.y)) == area:
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
	var to := beyond(gate, here)
	if to == "":
		return
	_asked = true
	var text := "%s %s" % [world.area(to).go_question, world.area(here).sleeps_line]
	text += " Wer dort ist, steht bei deiner Rückkehr da, wo er um diese Uhrzeit hingehört."
	var lines := leave_behind(to, true, here)
	if not lines.is_empty():
		text += "\n\n" + "\n".join(lines)
	pc.actor.stop_moving()
	UI.dialog(GATES[gate]["name"], text, [{"text": world.area(to).go_yes, "id": "go"},
		{"text": "Nein, hierbleiben", "id": ""}], func(c: String) -> void:
			if c == "go":
				cross(gate, to))


## Through `gate` into area `to`: what belongs here stays, the areas swap, the player steps
## out on the other side of the gate.
func cross(gate: String, to: String) -> void:
	leave_behind(to)
	await world.enter_area(to)
	var g := gate_pos(gate)
	var dir := 1.0 if to == GATES[gate]["hi"] else -1.0
	var step := Vector2(dir, 0) if GATES[gate]["axis"] == 0 else Vector2(0, dir)
	var q := g + step * 3.0
	if world.map.is_solid(q):
		var c := world.nav.nearest_open(q)
		if c.x >= 0:
			q = ParkMap.cell_center(c)
	var a := pc.actor
	a.teleport(Vector3(q.x, 0, q.y))
	a.face(a.global_position + Vector3(step.x, 0, step.y), true)
	pc.camera.follow(a, false)
	_area = to
	_asked = true    # right at the gate on the other side: don't ask back at once
