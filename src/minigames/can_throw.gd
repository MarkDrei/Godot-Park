class_name CanThrow
extends BoothGame
## Dosenwerfen with Dosen-Doris: three balls at a pyramid of six cans. A marker wanders over
## the pyramid; throw when it is where you want to hit. A hit at the bottom middle can brings
## the whole pyramid down (Dosenkönig).

const CAN_R := 0.13
const CAN_H := 0.32
var cans: Array[MeshInstance3D] = []
var _down: Array[bool] = []
var _fall: Array[float] = []
var _marker: MeshInstance3D
var _ball: MeshInstance3D
var balls := 3
var knocked := 0
var _t := 0.0
var _flying := 0.0
var _hit := Vector2.ZERO          # where the ball goes (x, y on the pyramid's plane)
var _speed := 1.0


func _init() -> void:
	title = "Dosenwerfen"
	host_id = "doris"
	booth = "cans"
	cost = 100


func describe() -> String:
	return "Drei Bälle, sechs Dosen. Jede Dose bringt ein Ticket, die ganze Pyramide auf einmal fünf extra. 1 € bei Dosen-Doris im Westpark."


func goal_done() -> bool:
	return GameState.stat("cans_best") >= 6


func booth_begin() -> void:
	cans.clear()
	_down.clear()
	_fall.clear()
	var kit := MeshKit.new()
	kit.box(Vector3(0, 0.55, 0), Vector3(1.2, 1.1, 0.5), Color("8a5a34"), Color("b98a57"))
	add_prop(kit.commit(), lp(0, 0.1, -0.4))
	for i in 6:
		var c := add_prop(_can_mesh(i), Vector3.ZERO)
		cans.append(c)
		_down.append(false)
		_fall.append(0.0)
		_place_can(i)
	var mk := MeshKit.new()
	mk.use("unshaded")
	mk.torus(Vector3.ZERO, 0.07, 0.015, 12, 4, Color("ff3030"))
	_marker = add_prop(mk.commit(), Vector3.ZERO)
	_marker.rotate_object_local(Vector3.RIGHT, PI / 2)
	_ball = add_prop(PropModels.ball(Color("f1eee6"), 0.07), Vector3.ZERO)
	_ball.visible = false
	balls = 3
	knocked = 0
	_speed = 1.0
	_t = 0.0
	_flying = 0.0
	set_score("Bälle: 3 · Dosen: 0")
	set_info("Wirf, wenn der rote Kreis auf der Pyramide liegt! (Leertaste, Klick oder „Werfen“)")
	add_button("Werfen", _throw, 160)
	host_say("Ziel auf die untere Mitte!")


func _can_mesh(i: int) -> Mesh:
	var kit := MeshKit.new()
	kit.cylinder(Vector3(0, -CAN_H * 0.5, 0), CAN_H, CAN_R, CAN_R, 10, [Color("e8442e"), Color("c8ccd0"), Color("2e86de")][i % 3], true, Color("d8dcdf"))
	kit.cylinder(Vector3(0, -0.04, 0), 0.08, CAN_R + 0.005, CAN_R + 0.005, 10, Color("f1eee6"), false)
	return kit.commit()


func _can_xy(i: int) -> Vector2:
	var row := 0 if i < 3 else (1 if i < 5 else 2)
	var k: int = i - [0, 3, 5][row]
	var w := CAN_R * 2.15
	return Vector2((k - (2 - row) * 0.5) * w, 1.2 + CAN_H * 0.5 + row * CAN_H)


func _place_can(i: int) -> void:
	var q := _can_xy(i)
	var p := lp(q.x, q.y, -0.4)
	var tilt := _fall[i]
	cans[i].transform = Transform3D(basis() * Basis(Vector3.RIGHT, -tilt * 1.4), p + Vector3(0, -tilt * 0.4, 0) - fwd() * tilt * 0.35)


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta * _speed * pace
	# The marker wanders over the pyramid (and a bit beyond).
	var m := Vector2(sin(_t * 1.7) * 0.42, 1.2 + CAN_H * 1.5 + sin(_t * 2.3 + 0.7) * 0.42)
	if _flying <= 0.0:
		_marker.global_position = lp(m.x, m.y, -0.2)
	for i in 6:
		if _down[i] and _fall[i] < 1.0:
			_fall[i] = minf(1.0, _fall[i] + delta * 3.0)
			_place_can(i)
	if _flying > 0.0:
		_flying -= delta
		var k := 1.0 - _flying / 0.45
		var from := actor.global_position + Vector3.UP * 1.5
		var to := lp(_hit.x, _hit.y, -0.4)
		_ball.global_position = from.lerp(to, k) + Vector3.UP * sin(k * PI) * 0.3
		if _flying <= 0.0:
			_impact()


func _throw() -> void:
	if _flying > 0.0 or balls <= 0 or not active:
		return
	var m := _marker.global_position
	var c := lp(0, 0, -0.2)
	var rel := m - c
	_hit = Vector2(rel.dot(right()), m.y - world.map.height_at(c.x, c.z))
	balls -= 1
	_flying = 0.45
	_ball.visible = true
	actor.play_anim("throw", 0.6)
	Sound.play("click", actor.global_position, -6.0)


func _impact() -> void:
	_ball.visible = false
	var before := knocked
	var hits: Array[int] = []
	for i in 6:
		if not _down[i] and _can_xy(i).distance_to(_hit) < CAN_R * 1.5:
			hits.append(i)
	# The bottom middle can carries the pyramid: hit it squarely and everything falls.
	var king := 1 in hits and _can_xy(1).distance_to(_hit) < CAN_R * 0.9 and knocked == 0
	if king:
		hits.assign([0, 1, 2, 3, 4, 5])
	for i in hits:
		_down[i] = true
	# Cans on top of a fallen one fall too.
	var changed := true
	while changed:
		changed = false
		for i in [3, 4, 5]:
			if _down[i]:
				continue
			var below: Array = [[0, 1], [1, 2], [3, 4]][i - 3]
			if _down[below[0]] or _down[below[1]]:
				_down[i] = true
				changed = true
	knocked = _down.count(true)
	if knocked > before:
		Sound.play("hit", lp(0, 1.4, -0.4), 0.0)
	set_score("Bälle: %d · Dosen: %d" % [balls, knocked])
	if king:
		GameState.set_stat("can_king", 1)
		host_say("Alle auf einmal! Du bist der Dosenkönig!")
	elif knocked > before:
		host_say(["Treffer!", "Gut geworfen!", "Weiter so!"][randi() % 3], 2.0)
	else:
		host_say(["Daneben! Nochmal!", "Knapp vorbei.", "Die Dosen lachen dich aus."][randi() % 3], 2.0)
	_speed += 0.25
	if knocked == 6 or balls == 0:
		tickets = knocked + (5 if king else 0)
		GameState.set_stat_max("cans_best", knocked)
		finish_round("Alle sechs Dosen auf einmal – Dosenkönig!" if king else ("Alle sechs Dosen sind gefallen!" if knocked == 6 else "%d von 6 Dosen gefallen." % knocked), knocked >= 4)


func game_input(event: InputEvent) -> void:
	if primary_pressed(event) or clicked(event):
		_throw()
