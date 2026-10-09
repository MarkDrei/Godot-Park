class_name AxeThrowGame
extends Minigame
## Axe throwing with Holzfäller Holger at the lumber camp: five throws at the target.
## The crosshair wanders over the disc; Action (or the button) throws where it is, the
## wind pushes the axe a little. Rings: 10, 8, 6, 4, 2 points.

const THROWS := 5
const RINGS := [0.14, 0.28, 0.42, 0.56, 0.7]
const POINTS := [10, 8, 6, 4, 2]
const GOAL := 30

var center := Vector3.ZERO           # middle of the target disc (world)
var stand := Vector3.ZERO            # throwing line
var throws_left := THROWS
var score := 0
var state := "aim"                   # aim, flying, done
var t := 0.0
var aim := Vector2.ZERO              # crosshair offset on the disc (right, up), metres
var wind := 0.0
var crosshair: MeshInstance3D
var flying_axe: Node3D
var stuck: Array[Node3D] = []
var _fly_from := Vector3.ZERO
var _fly_to := Vector3.ZERO
var _fly_t := 0.0
var last_points := -1


func _init() -> void:
	title = "Axtwerfen mit Holger"
	host_id = "holger"
	cost = 100


func describe() -> String:
	return "Fünf Würfe auf die Zielscheibe im Holzfällerlager. Schaffe %d Punkte! Einsatz 1 €." % GOAL


## Right and up on the target, as world directions (the disc faces +X).
func _right() -> Vector3:
	return Vector3(0, 0, -1)


func begin() -> void:
	var tp := Vector2(-51, -151)
	var gy := world.map.height_at(tp.x, tp.y)
	center = Vector3(tp.x + 0.08, gy + 1.5, tp.y)
	stand = Vector3(tp.x + 8.0, world.map.height_at(tp.x + 8.0, tp.y), tp.y)
	actor.teleport(stand + Vector3(0, 0, 0.5))
	actor.face(center, true)
	actor.set_item("axe")
	var h := host()
	if h:
		h.teleport(stand + Vector3(-2.0, 0, 3.0))
		h.face(center)
		host_say("Ruhig atmen, dann werfen!", 3.0)
	look(stand + Vector3(1.4, 1.6, -1.9), center + Vector3(0, -0.15, 0))
	crosshair = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.use("glow")
	kit.push(Transform3D(Basis(Vector3.BACK, PI / 2), Vector3.ZERO))
	kit.torus(Vector3.ZERO, 0.11, 0.025, 14, 3, Color("ff3b30"))
	kit.pop()
	kit.box(Vector3.ZERO, Vector3(0.02, 0.05, 0.05), Color("ff3b30"))
	crosshair.mesh = kit.commit()
	add_child(crosshair)
	throws_left = THROWS
	score = 0
	stuck.clear()
	_next_throw()
	set_info("Das Fadenkreuz wandert. Aktion, Leertaste oder „Werfen!“ – der Wind treibt die Axt etwas ab.")
	add_button("Werfen!", func() -> void: throw(), 220)


func _next_throw() -> void:
	state = "aim"
	t = randf() * 10.0
	wind = randf_range(-0.12, 0.12)
	_update_score()


func _update_score() -> void:
	var w := "Wind: %s %d" % ["von rechts" if wind < 0.0 else "von links", int(absf(wind) * 100.0)] if absf(wind) > 0.02 else "Kein Wind"
	set_score("Punkte: %d  ·  Würfe übrig: %d  ·  %s" % [score, throws_left, w])


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	match state:
		"aim":
			var speed := 1.0 + (THROWS - throws_left) * 0.12
			aim = Vector2(sin(t * 1.7 * speed) * 0.55, sin(t * 2.3 * speed + 1.0) * 0.45)
			crosshair.visible = true
			crosshair.global_position = _on_disc(aim) + Vector3(0.05, 0, 0)
		"flying":
			_fly_t += delta / 0.45
			var k := clampf(_fly_t, 0.0, 1.0)
			flying_axe.global_position = _fly_from.lerp(_fly_to, k) + Vector3(0, sin(k * PI) * 0.6, 0)
			flying_axe.rotation.z = -k * TAU * 2.0
			if k >= 1.0:
				_land()


func _on_disc(off: Vector2) -> Vector3:
	return center + _right() * off.x + Vector3(0, off.y, 0)


## Throws at the crosshair (plus wind and a little shake).
func throw() -> void:
	if state != "aim" or not active:
		return
	state = "flying"
	crosshair.visible = false
	var hit := aim + Vector2(wind, 0) + Vector2(randf_range(-0.03, 0.03), randf_range(-0.03, 0.03))
	_fly_from = actor.global_position + Vector3(0, 1.6, 0)
	_fly_to = _on_disc(hit)
	_fly_t = 0.0
	flying_axe = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = PropModels.item("axe")
	flying_axe.add_child(mi)
	add_child(flying_axe)
	flying_axe.set_meta("hit", hit)
	actor.play_anim("throw", 0.6)
	actor.set_item("")
	Sound.play("whistle", actor.global_position, -6.0)


func points_for(off: Vector2) -> int:
	var d := off.length()
	for i in RINGS.size():
		if d <= RINGS[i]:
			return POINTS[i]
	return 0


func _land() -> void:
	var hit: Vector2 = flying_axe.get_meta("hit")
	last_points = points_for(hit)
	score += last_points
	throws_left -= 1
	if last_points > 0:
		flying_axe.global_position = _on_disc(hit) + Vector3(0.25, 0, 0)
		flying_axe.rotation = Vector3(0, 0, PI / 2)
		stuck.append(flying_axe)
		Sound.play("hit", center)
		host_say(["Volltreffer!", "Nicht schlecht!", "Sauber!"][0 if last_points >= 10 else (1 if last_points <= 4 else 2)], 2.0)
	else:
		flying_axe.queue_free()
		Sound.play("click", center)
		host_say("Daneben! Die Axt liegt im Gras.", 2.0)
	flying_axe = null
	actor.set_item("axe")
	if throws_left <= 0:
		state = "done"
		_update_score()
		GameState.set_stat_max("axe_best", score)
		var won := score >= GOAL
		end_after(1.6, {"won": won, "money": score * 10, "joy": 20.0 if won else 10.0,
			"text": "%d Punkte! %s" % [score, "Holger klopft dir auf die Schulter." if won else "Holger meint: „Übung macht den Meister.“"]})
	else:
		_next_throw()


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_SPACE):
		throw()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if not UI.point_blocked((event as InputEventMouseButton).position):
			throw()


func cleanup() -> void:
	for n in stuck:
		if is_instance_valid(n):
			n.queue_free()
	stuck.clear()
	if is_instance_valid(flying_axe):
		flying_axe.queue_free()
	if is_instance_valid(crosshair):
		crosshair.queue_free()
	if actor:
		actor.set_item("")
