class_name BalloonDarts
extends BoothGame
## Ballon-Darts with Darts-Dieter: a wall of balloons, a wobbling crosshair, five darts. Two
## tickets per balloon, five extra for five out of five.

const DARTS := 5
var balloons: Array[MeshInstance3D] = []
var _cross: MeshInstance3D
var _dart: MeshInstance3D
var darts := DARTS
var popped := 0
var _t := 0.0
var _fly := -1.0
var _aim := Vector2.ZERO
var _to := Vector3.ZERO


func _init() -> void:
	title = "Ballon-Darts"
	host_id = "dieter"
	booth = "darts"
	cost = 100


func describe() -> String:
	return "Lass Ballons platzen: zwei Tickets pro Ballon, fünf extra für fünf von fünf. 1 € bei Darts-Dieter im Westpark."


func booth_begin() -> void:
	balloons.clear()
	for k in 24:
		var col: Color = FairModels.COLORS[(k * 3) % FairModels.COLORS.size()]
		var kit := MeshKit.new()
		kit.sphere(Vector3.ZERO, Vector3(0.2, 0.25, 0.14), col, 3, 7)
		kit.cylinder(Vector3(0, -0.29, 0), 0.05, 0.02, 0.04, 4, col.darkened(0.2))
		balloons.append(add_prop(kit.commit(), lp(-1.9 + (k % 8) * 0.55, 1.0 + (k / 8) * 0.55, -1.2)))
	var ck := MeshKit.new()
	ck.use("unshaded")
	ck.torus(Vector3.ZERO, 0.09, 0.012, 14, 3, Color("ff3030"))
	ck.box(Vector3.ZERO, Vector3(0.02, 0.02, 0.24), Color("ff3030"))
	ck.box(Vector3.ZERO, Vector3(0.24, 0.02, 0.02), Color("ff3030"))
	_cross = add_prop(ck.commit(), Vector3.ZERO)
	_cross.rotate_object_local(Vector3.RIGHT, PI / 2)
	var dk := MeshKit.new()
	dk.rod(Vector3(0, 0, -0.12), Vector3(0, 0, 0.12), 0.012, 0.012, 4, Color("c8ccd0"))
	dk.box(Vector3(0, 0, 0.13), Vector3(0.06, 0.06, 0.04), Color("e8442e"))
	_dart = add_prop(dk.commit(), Vector3.ZERO)
	_dart.visible = false
	darts = DARTS
	popped = 0
	_fly = -1.0
	set_score("Pfeile: %d · Ballons: 0" % darts)
	set_info("Das Fadenkreuz wackelt – wirf im richtigen Moment! (Leertaste, Klick oder „Werfen“)")
	add_button("Werfen", _throw, 160)
	host_say("Ziel – und loslassen!")


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta * pace * (1.0 + (DARTS - darts) * 0.12)
	_aim = Vector2(sin(_t * 1.3) * 1.5 + sin(_t * 3.7) * 0.25, 1.55 + sin(_t * 1.9 + 1.0) * 0.55 + sin(_t * 4.3) * 0.12)
	if _fly < 0.0:
		_cross.global_position = lp(_aim.x, _aim.y, -1.08)
		return
	_fly += delta / 0.3
	var from := actor.global_position + Vector3.UP * 1.5
	_dart.global_position = from.lerp(_to, minf(_fly, 1.0))
	_dart.look_at(_dart.global_position + (from - _to), Vector3.UP)
	if _fly >= 1.0:
		_fly = -1.0
		_hit()


func _throw() -> void:
	if _fly >= 0.0 or darts <= 0 or not active:
		return
	darts -= 1
	_to = _cross.global_position + Vector3(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03), 0)
	_fly = 0.0
	_dart.visible = true
	actor.play_anim("throw", 0.5)


func _hit() -> void:
	var best: MeshInstance3D = null
	var best_d := 0.24
	for b in balloons:
		if b.visible and b.global_position.distance_to(_to) < best_d:
			best_d = b.global_position.distance_to(_to)
			best = b
	if best:
		best.visible = false
		popped += 1
		tickets += 2
		Sound.play("hit", _to, 2.0)
		host_say(["Peng!", "Getroffen!", "Der war fällig!"][randi() % 3], 1.5)
	else:
		host_say(["Daneben!", "Knapp!", "Der Ballon lacht."][randi() % 3], 1.5)
	_dart.visible = false
	set_score("Pfeile: %d · Ballons: %d" % [darts, popped])
	if darts == 0:
		if popped == DARTS:
			tickets += 5
		finish_round("Fünf von fünf – Volltreffer!" if popped == DARTS else "%d Ballon%s geplatzt." % [popped, "" if popped == 1 else "s"], popped >= 3)


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_SPACE):
		_throw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not UI.point_blocked((event as InputEventMouseButton).position):
		_throw()
