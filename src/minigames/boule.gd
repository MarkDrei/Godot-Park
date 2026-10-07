class_name BouleGame
extends Minigame
## Pétanque against Monsieur Jacques: three boules each, closest to the jack wins.

const BALLS := 3
const R := 0.05
const FRICTION := 2.4
const PLAYER_COL := Color("aeb7c2")
const AI_COL := Color("c9a640")

var sim := BallSim.new()
var court_c: Vector2
var court_y := 0.0
var throw_from: Vector2
var jack: BallSim.Ball
var player_left := BALLS
var ai_left := BALLS
var turn := ""               # "player", "ai", "wait", "done"
var aim := 0.0
var t := 0.0
var flying: Array = []
var owners := {}             # Ball -> "player"/"ai"
var _ai_timer := 0.0


func _init() -> void:
	title = "Boule mit Monsieur Jacques"
	host_id = "jacques"


func describe() -> String:
	return "Wer seine Kugeln näher an die kleine Zielkugel wirft, gewinnt. Monsieur Jacques wartet am Boule-Platz."


func begin() -> void:
	var area: Dictionary = ParkLayout.AREAS["boule"]
	court_c = area["pos"]
	court_y = world.map.height_at(court_c.x, court_c.y)
	throw_from = court_c + Vector2(-7.5, 0)
	sim = BallSim.new()
	sim.add_box_walls(court_c, area["size"] - Vector2(0.2, 0.2))
	owners.clear()
	flying.clear()
	actor.teleport(Vector3(throw_from.x - 0.3, 0, throw_from.y + 0.7))
	actor.face(Vector3(court_c.x + 5, 0, court_c.y), true)
	var h := host()
	if h:
		h.teleport(Vector3(throw_from.x - 1.0, 0, throw_from.y - 2.2))
		h.face(Vector3(court_c.x, 0, court_c.y))
		h.say("Allez! Zeig mir, was du kannst!", 3.0)
	look(Vector3(throw_from.x - 4.0, court_y + 3.0, throw_from.y - 0.9), Vector3(court_c.x + 2.5, court_y, court_c.y))
	# The jack lands somewhere 6-10 m away.
	var jp := throw_from + Vector2(randf_range(6.0, 10.0), randf_range(-1.6, 1.6))
	jack = sim.add_ball(throw_from, 0.025, FRICTION, "jack")
	jack.node = _ball_node(Color("e8572a"), 0.035)
	_launch(jack, jp, 0.0, 0.8)
	player_left = BALLS
	ai_left = BALLS
	turn = "wait"
	_ai_timer = 1.4
	set_info("Links/Rechts: zielen · Aktion oder Klick: werfen, wenn die Kraft passt.")
	add_button("<", func() -> void: aim -= 3.0, 90)
	add_button("Werfen!", func() -> void: _player_throw(), 200)
	add_button(">", func() -> void: aim += 3.0, 90)
	_update_score()


func _ball_node(col: Color, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = PropModels.ball(col, r)
	add_child(mi)
	return mi


func _launch(b: BallSim.Ball, land: Vector2, roll_speed: float, dur: float) -> void:
	b.active = false
	var start := Vector3(throw_from.x, court_y + 1.1, throw_from.y)
	flying.append({"ball": b, "from": start, "land": land, "roll": roll_speed, "t": 0.0, "dur": dur,
		"dir": (land - throw_from).normalized()})


## Throw model shared by player and AI: power 0..1 and direction.
func _throw(power: float, dir: Vector2, owner: String) -> void:
	var b := sim.add_ball(throw_from, R, FRICTION, owner)
	b.node = _ball_node(PLAYER_COL if owner == "player" else AI_COL, R)
	owners[b] = owner
	var air := (2.0 + power * 11.0) * 0.6
	var roll := power * 2.8 + 0.6
	_launch(b, throw_from + dir * air, roll, 0.75 + power * 0.35)
	Sound.play("click")


static func predicted_distance(power: float) -> float:
	var air := (2.0 + power * 11.0) * 0.6
	var v0 := power * 2.8 + 0.6
	return air + v0 * v0 / (2.0 * FRICTION)


func _player_throw() -> void:
	if turn != "player":
		return
	var power := pingpong(t, 0.9)
	var dir := Vector2.RIGHT.rotated(deg_to_rad(aim))
	actor.play_anim("throw", 0.8)
	_throw(power, dir, "player")
	player_left -= 1
	turn = "wait"
	show_power(-1.0)


func _ai_throw() -> void:
	var target := jack.p
	var shoot := false
	var best_player := _closest("player")
	var best_ai := _closest("ai")
	if best_player >= 0.0 and (best_ai < 0.0 or best_player < best_ai) and ai_left >= 2 and randf() < 0.35:
		for b in sim.balls:
			if owners.get(b, "") == "player" and b.p.distance_to(jack.p) <= best_player + 0.001:
				target = b.p
				shoot = true
	var d := throw_from.distance_to(target)
	var lo := 0.0
	var hi := 1.0
	for i in 20:
		var mid := (lo + hi) * 0.5
		if predicted_distance(mid) < d:
			lo = mid
		else:
			hi = mid
	var power := clampf((lo + hi) * 0.5 + randf_range(-0.035, 0.035) + (0.03 if shoot else 0.0), 0.0, 1.0)
	var dir := (target - throw_from).normalized().rotated(deg_to_rad(randf_range(-2.2, 2.2)))
	var h := host()
	if h:
		h.play_anim("throw", 0.8)
		h.say("Ich schieße!" if shoot else ["Allez!", "Et voilà …", "Doucement …"][randi() % 3], 2.0)
	_throw(power, dir, "ai")
	ai_left -= 1
	turn = "wait"


func _closest(owner: String) -> float:
	var best := -1.0
	for b in sim.balls:
		if owners.get(b, "") != owner or not b.active:
			continue
		var d := b.p.distance_to(jack.p)
		if best < 0.0 or d < best:
			best = d
	return best


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	for i in range(flying.size() - 1, -1, -1):
		var f: Dictionary = flying[i]
		f["t"] += delta / f["dur"]
		var k: float = clampf(f["t"], 0.0, 1.0)
		var land: Vector2 = f["land"]
		var to := Vector3(land.x, court_y + (f["ball"] as BallSim.Ball).r, land.y)
		var pos: Vector3 = (f["from"] as Vector3).lerp(to, k) + Vector3(0, sin(k * PI) * 1.6, 0)
		var b: BallSim.Ball = f["ball"]
		b.node.global_position = pos
		if k >= 1.0:
			b.p = land
			b.v = (f["dir"] as Vector2) * f["roll"]
			b.active = true
			flying.remove_at(i)
			Sound.play("hit", pos, -6.0)
	sim.step(delta)
	for b in sim.balls:
		if b.active and b.node:
			b.node.global_position = Vector3(b.p.x, court_y + b.r, b.p.y)
			b.node.rotate_z(-b.v.x * delta / b.r * 0.2)
	if Input.is_action_pressed("move_left"):
		aim -= delta * 18.0
	if Input.is_action_pressed("move_right"):
		aim += delta * 18.0
	aim = clampf(aim, -25.0, 25.0)
	actor.yaw = -deg_to_rad(aim) + PI / 2
	actor.rotation.y = actor.yaw
	if turn == "player":
		show_power(pingpong(t, 0.9))
		_draw_aim()
	elif turn == "wait" and flying.is_empty() and sim.resting():
		_next_turn()
	elif turn == "ai":
		_ai_timer -= delta
		if _ai_timer <= 0.0:
			_ai_throw()
	_update_score()


var _aim_line: MeshInstance3D


func _draw_aim() -> void:
	if _aim_line == null:
		_aim_line = MeshInstance3D.new()
		var kit := MeshKit.new()
		kit.use("unshaded")
		for i in 8:
			kit.box(Vector3(0.6 + i * 0.5, 0, 0), Vector3(0.22, 0.02, 0.05), Color(1, 1, 1))
		_aim_line.mesh = kit.commit()
		add_child(_aim_line)
	_aim_line.visible = turn == "player"
	_aim_line.global_position = Vector3(throw_from.x, court_y + 0.03, throw_from.y)
	_aim_line.rotation.y = -deg_to_rad(aim)


func _next_turn() -> void:
	if _aim_line:
		_aim_line.visible = false
	if player_left == 0 and ai_left == 0:
		_finish()
		return
	# Petanque rule: the side that is not closest throws next.
	var bp := _closest("player")
	var ba := _closest("ai")
	var who := "player"
	if bp < 0.0 and ba < 0.0:
		who = "player"
	elif ai_left == 0:
		who = "player"
	elif player_left == 0:
		who = "ai"
	elif bp >= 0.0 and (ba < 0.0 or bp < ba):
		who = "ai"
	else:
		who = "player"
	turn = who
	if who == "ai":
		_ai_timer = 1.6
		set_info("Monsieur Jacques ist dran …")
	else:
		set_info("Du bist dran! Links/Rechts zielen, im richtigen Moment werfen.")


func _update_score() -> void:
	set_score("Deine Kugeln: %d   ·   Jacques: %d" % [player_left, ai_left])


func _finish() -> void:
	turn = "done"
	var bp := _closest("player")
	var ba := _closest("ai")
	var won := bp >= 0.0 and (ba < 0.0 or bp < ba)
	var points := 0
	var limit := ba if won else bp
	for b in sim.balls:
		var o: String = owners.get(b, "")
		if (won and o == "player") or (not won and o == "ai"):
			if b.p.distance_to(jack.p) < limit or limit < 0.0:
				points += 1
	var h := host()
	if won:
		GameState.add_stat("boule_wins")
		if h:
			h.say("Magnifique! Du hast gewonnen!", 3.0)
			h.play_anim("clap", 2.0)
		await get_tree().create_timer(1.5).timeout
		end({"won": true, "money": 300 + points * 50, "joy": 30.0,
			"text": "Gewonnen mit %d Punkt%s! Deine beste Kugel lag %.0f cm von der Zielkugel entfernt." % [points, "" if points == 1 else "en", bp * 100.0]})
	else:
		if h:
			h.say("Oh là là – diesmal gewinne ich!", 3.0)
			h.play_anim("cheer", 2.0)
		await get_tree().create_timer(1.5).timeout
		end({"won": false, "joy": 15.0, "text": "Monsieur Jacques gewinnt mit %d Punkt%s. Revanche?" % [points, "" if points == 1 else "en"]})


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not UI.point_blocked((event as InputEventMouseButton).position)):
		_player_throw()


func cleanup() -> void:
	for c in get_children():
		c.queue_free()
	_aim_line = null
	sim = BallSim.new()
	flying.clear()
