class_name DuckFishing
extends BoothGame
## Entenangeln with Enten-Erna: rubber ducks swim round the pool, the hook hangs at the front.
## Pull when a duck is right under it; every duck has a number of tickets on its bottom. Five
## tries. Once in a while a glitter duck swims along (fifteen tickets).

const TRIES := 5
const R := Vector2(1.45, 0.5)     # the ducks' round in the pool
var ducks: Array[MeshInstance3D] = []
var values: Array[int] = []
var _angle := 0.0
var _hook: MeshInstance3D
var tries := TRIES
var caught := 0
var golden := -1
var _lift := -1                   # duck being lifted out
var _lift_t := 0.0


func _init() -> void:
	title = "Entenangeln"
	host_id = "erna"
	booth = "ducks"
	cost = 100


func describe() -> String:
	return "Angel dir Gummienten: Unter jeder steht, wie viele Tickets sie bringt. Fünf Versuche, 1 € bei Enten-Erna im Westpark."


func booth_begin() -> void:
	ducks.clear()
	values.clear()
	golden = randi() % 8 if randf() < 0.08 else -1
	for i in 8:
		var gold := i == golden
		var d := add_prop(_duck_mesh(gold), Vector3.ZERO)
		ducks.append(d)
		values.append(15 if gold else [1, 1, 2, 2, 3, 3, 4, 5][randi() % 8])
	var hk := MeshKit.new()
	hk.beam(Vector3(0, 0, 0), Vector3(0, 0.9, 0), Vector2(0.01, 0.01), Color("f1eee6"))
	hk.torus(Vector3(0, 0, 0), 0.04, 0.008, 8, 3, Color("c8ccd0"))
	hk.beam(Vector3(0, 0.9, 0), Vector3(0.4, 1.3, 0.8), Vector2(0.03, 0.03), Color("b98a57"))
	_hook = add_prop(hk.commit(), lp(0, 1.32, 0.3))
	tries = TRIES
	caught = 0
	_lift = -1
	_angle = randf() * TAU
	set_score("Versuche: %d · Tickets: 0" % tries)
	set_info("Zieh, wenn eine Ente genau unter dem Haken ist! (Leertaste, Klick oder „Angeln“)")
	add_button("Angeln", _pull, 160)
	host_say("Jede Ente gewinnt. Fast jede.")


func _duck_mesh(gold: bool) -> Mesh:
	var kit := MeshKit.new()
	var col := Color("e2c050") if gold else Color("f2c230")
	if gold:
		kit.use("glow")
	kit.sphere(Vector3(0, 0.05, 0), Vector3(0.14, 0.11, 0.17), col, 3, 6)
	kit.sphere(Vector3(0, 0.18, 0.08), Vector3(0.08, 0.08, 0.08), col, 3, 6)
	kit.use("solid")
	kit.box(Vector3(0, 0.17, 0.17), Vector3(0.06, 0.03, 0.06), Color("e67e22"))
	kit.torus(Vector3(0, 0.27, 0.08), 0.03, 0.008, 6, 3, Color("c8ccd0"))
	return kit.commit()


func _duck_spot(i: int) -> Vector3:
	var a := _angle + TAU * i / ducks.size()
	return lp(cos(a) * R.x, 1.13, -0.2 + sin(a) * R.y)


func _process(delta: float) -> void:
	if not active:
		return
	_angle += delta * pace * (0.55 + (TRIES - tries) * 0.08)
	for i in ducks.size():
		if i == _lift or not ducks[i].visible:
			continue
		var p := _duck_spot(i)
		ducks[i].transform = Transform3D(basis() * Basis(Vector3.UP, -_angle - TAU * i / ducks.size()), p + Vector3.UP * sin(_angle * 3.0 + i) * 0.01)
	if _lift >= 0:
		_lift_t += delta
		ducks[_lift].global_position = _hook.global_position + Vector3.UP * minf(_lift_t, 0.6) * 0.8
		if _lift_t > 1.2:
			ducks[_lift].visible = false
			_lift = -1


## The duck under the hook (within a few centimetres), or -1.
func duck_under_hook() -> int:
	var h := _hook.global_position
	for i in ducks.size():
		if not ducks[i].visible or i == _lift:
			continue
		var p := ducks[i].global_position
		if Vector2(p.x - h.x, p.z - h.z).length() < 0.14:
			return i
	return -1


func _pull() -> void:
	if tries <= 0 or not active or _lift >= 0:
		return
	tries -= 1
	var i := duck_under_hook()
	if i >= 0:
		tickets += values[i]
		caught += 1
		_lift = i
		_lift_t = 0.0
		Sound.play("quack", _hook.global_position, -4.0)
		if i == golden:
			host_say("Die Glitzerente! Fünfzehn Tickets!", 3.0)
		else:
			host_say("Eine %d! Gut geangelt!" % values[i], 2.0)
	else:
		Sound.play("splash", _hook.global_position, -10.0)
		host_say(["Daneben – die Enten sind schnell!", "Fast!", "Geduld, Geduld."][randi() % 3], 2.0)
	set_score("Versuche: %d · Tickets: %d" % [tries, tickets])
	if tries == 0:
		finish_round("%d Ente%s geangelt." % [caught, "" if caught == 1 else "n"] if caught > 0 else "Keine Ente erwischt. Die Enten winken zum Abschied.", caught >= 2, 1.8)


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_SPACE):
		_pull()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not UI.point_blocked((event as InputEventMouseButton).position):
		_pull()
