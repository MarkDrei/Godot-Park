class_name CoastVolleyball
extends Minigame
## Beachvolleyball with Strandbar-Piet (doc/moewenbucht.md): you against Piet over the net, seen
## from the side. The ball comes over in an arc; a ring in the sand shows where it lands and you
## run there by yourself. While it drops into reach of your arms it glows green with "JETZT!"
## (the reaction included): "Baggern!" (Aktion) plays it back. Too early: a swing into the air
## ("Zu früh!"); not at all: it lands ("Verpasst!"); while it is far away a press does nothing.
## Piet misses now and then. First to five points.

const WIN := 5
const NET_Z := 150.0
const REACH := Vector2(0.4, 2.2)       # the ball's height (m) while the arms reach it (~0.4 s)
const REACT := 0.15
const BALL_R := 0.22

var court := Vector2.ZERO
var me := 0
var piet := 0
var state := "wait"                    # wait, in (coming to the player), out (to Piet), point, done
var ball: MeshInstance3D
var marker: MeshInstance3D
var opponent: Actor
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _apex := 0.0
var _dur := 1.0
var _t := 0.0
var _swing := 0.0                      # > 0: the player's bump animation runs
var _gold: StandardMaterial3D
var _green: StandardMaterial3D
var _white: StandardMaterial3D
var _cue_t := 0.0
var _rally := 0
var pace := 1.0                        # < 1 slows the ball (tests)


func _init() -> void:
	title = "Beachvolleyball"
	host_id = "piet"
	cost = 0


func describe() -> String:
	return "Beachvolleyball gegen Strandbar-Piet: Baggern, wenn der Ball grün leuchtet. Wer zuerst fünf Punkte hat, gewinnt."


func goal_done() -> bool:
	return GameState.stat("volleyball_wins") > 0


func can_start(a: Actor) -> bool:
	return a.is_human() and not active and world.coast != null


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Beachvolleyball spielen"


func begin() -> void:
	court = CoastLayout.place("volleyball")
	me = 0
	piet = 0
	_rally = 0
	opponent = host()
	if opponent:
		opponent.teleport(_v(court + Vector2(0, 3.5)))
		opponent.face(_v(court), true)
	actor.teleport(_v(court + Vector2(0, -3.5)))
	actor.face(_v(court), true)
	_gold = _mat(Color("f2c230"))
	_green = _mat(Color("4ee05a"))
	_white = _mat(Color("f4f1ea"))
	ball = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.sphere(Vector3.ZERO, Vector3(BALL_R, BALL_R, BALL_R), Color.WHITE, 5, 10)
	ball.mesh = kit.commit()
	ball.material_override = _white
	world.add_child(ball)
	marker = MeshInstance3D.new()
	var mk := MeshKit.new()
	mk.torus(Vector3.ZERO, 0.5, 0.06, 20, 3, Color.WHITE)
	marker.mesh = mk.commit()
	marker.material_override = _gold
	world.add_child(marker)
	look(_v(court) + Vector3(11.5, 3.6, 0.0), _v(court) + Vector3(0, 1.3, 0))
	host_say("Ich schlag auf! Baggern, wenn er grün leuchtet!", 3.0)
	set_info("Der Ring im Sand zeigt, wo der Ball landet – du läufst von selbst hin. Leuchtet der Ball GRÜN, drück „Baggern!“ (Aktion). Zu früh geht in die Luft, gar nicht ist ein Punkt für Piet. Wer zuerst 5 Punkte hat, gewinnt.")
	add_button("Baggern!", func() -> void: bump(), 220)
	_update_score()
	_serve_in(1.2)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.4
	return m


func _v(p: Vector2) -> Vector3:
	return Vector3(p.x, world.map.height_at(p.x, p.y), p.y)


func _update_score() -> void:
	set_score("Du %d : %d Piet" % [me, piet])


## Piet plays the ball over to the player after `secs`.
func _serve_in(secs: float) -> void:
	state = "wait"
	var s := session
	get_tree().create_timer(secs, false).timeout.connect(func() -> void:
		if still_running(s) and state == "wait":
			_to_player())


func _to_player() -> void:
	var land := court + Vector2(rng.randf_range(-3.0, 3.0), -rng.randf_range(2.2, 3.8))
	_from = (opponent.global_position if opponent else _v(court + Vector2(0, 3.5))) + Vector3(0, 1.3, 0)
	_to = _v(land) + Vector3(0, BALL_R, 0)
	_apex = 2.8
	_dur = 2.0 / pace
	_t = 0.0
	state = "in"
	marker.position = _v(land) + Vector3(0, 0.03, 0)
	marker.visible = true
	ball.material_override = _white


## The ball at flight time `at` (an arc from _from to _to with its top `_apex` above the line).
func ball_at(at: float) -> Vector3:
	var k := clampf(at / _dur, 0.0, 1.0)
	return _from.lerp(_to, k) + Vector3(0, _apex * 4.0 * k * (1.0 - k), 0)


func _ball_height(at: float) -> float:
	return ball_at(at).y - _v(Vector2(_to.x, _to.z)).y


## A bump now would reach the ball, and one a moment later (the reaction) still would: it drops
## through the arms' reach.
func in_reach() -> bool:
	if state != "in" or _t / _dur <= 0.5:
		return false
	for at: float in [_t, _t + REACT]:
		var h := _ball_height(at)
		if h < REACH.x or h > REACH.y:
			return false
	return true


func _process(delta: float) -> void:
	if not active:
		return
	_cue_t -= delta
	_swing = maxf(0.0, _swing - delta)
	match state:
		"in", "out":
			_t += delta
			ball.position = ball_at(_t)
			if state == "in":
				# The player runs to the ring.
				var target := Vector3(_to.x, 0, _to.z - 0.6)
				var p := actor.global_position
				var step := Vector3(target.x - p.x, 0, target.z - p.z)
				if step.length() > 0.05:
					var mv := step.normalized() * minf(step.length(), 5.0 * delta)
					var q := Vector2(p.x + mv.x, p.z + mv.z)
					actor.global_position = Vector3(q.x, world.map.walk_height(q.x, q.y), q.y)
					actor.anim = "run"
				else:
					actor.anim = "idle" if _swing <= 0.0 else actor.anim
				actor.face(Vector3(court.x, 0, NET_Z), true)
				var near := in_reach()
				ball.material_override = _green if near else _white
				if _cue_t <= 0.0:
					set_cue("JETZT!" if near else "", Color("4ee05a"))
				if _t >= _dur:
					_point(false, "Verpasst!")
			elif _t >= _dur:
				_piet_plays()


## "Baggern!": while the ball is in reach it goes back over the net; earlier it is a swing into
## the air; while it is on Piet's side nothing happens.
func bump() -> void:
	if not active or state != "in":
		return
	var h := _ball_height(_t)
	if _t / _dur < 0.35:
		return   # still far away (on Piet's side or just over the net): nothing
	actor.play_anim("throw", 0.4)
	_swing = 0.4
	if _t / _dur > 0.5 and h >= REACH.x and h <= REACH.y:
		Sound.play("hit", ball.position)
		_rally += 1
		_flash("Gebaggert!", Color("4ee05a"))
		_to_piet()
	elif h > REACH.y:
		_point(false, "Zu früh!")
	else:
		_point(false, "Zu spät!")


func _to_piet() -> void:
	marker.visible = false
	ball.material_override = _white
	_from = ball.position
	var land := court + Vector2(rng.randf_range(-3.0, 3.0), rng.randf_range(2.0, 3.6))
	_to = _v(land) + Vector3(0, 1.2, 0)
	_apex = 3.6
	_dur = 1.4 / pace
	_t = 0.0
	state = "out"
	if opponent:
		opponent.teleport(_v(land + Vector2(0, 0.6)))
		opponent.face(_v(court), true)


func _piet_plays() -> void:
	# Piet returns most balls, fewer the longer the rally.
	if rng.randf() < 0.3 + 0.08 * _rally:
		if opponent:
			opponent.play_anim("throw", 0.5)
		_point(true, "Piet verfehlt!")
		return
	if opponent:
		opponent.play_anim("throw", 0.5)
	Sound.play("hit", ball.position, -4.0)
	_to_player()


func _point(mine: bool, text: String) -> void:
	state = "point"
	marker.visible = false
	ball.material_override = _white
	_rally = 0
	if mine:
		me += 1
		Sound.play("coin", ball.position)
	else:
		piet += 1
		Sound.play("click", ball.position)
		host_say(["Punkt für mich!", "Hab ich!", "Nächstes Mal!"][piet % 3], 1.4)
	_flash("%s\n%s" % [text, "Punkt für dich!" if mine else "Punkt für Piet"], Color("4ee05a") if mine else UiTheme.RED, 1.4)
	_update_score()
	if me >= WIN or piet >= WIN:
		_finish()
	else:
		_serve_in(1.6)


func _flash(text: String, color: Color, secs := 0.9) -> void:
	set_cue(text, color)
	_cue_t = secs


func _finish() -> void:
	state = "done"
	var won := me >= WIN
	if won:
		GameState.add_stat("volleyball_wins")
	end_after(1.5, {"won": won, "money": 200 if won else 0, "joy": 22.0 if won else 12.0,
		"text": "%d : %d.\n\nPiet: „%s“" % [me, piet, "Respekt! Der Shake geht auf mich. Also, fast." if won else "Gutes Spiel! Revanche, wann du willst."]})


func cleanup() -> void:
	set_cue("")
	for n: Node in [ball, marker]:
		if is_instance_valid(n):
			n.queue_free()
	ball = null
	marker = null
	actor.anim = "idle"


func game_input(event: InputEvent) -> void:
	if primary_pressed(event):
		bump()
