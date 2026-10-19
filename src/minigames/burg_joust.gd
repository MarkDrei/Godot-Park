class_name BurgJoust
extends BurgHorseGame
## Tjost with Ritter Kunibert (doc/burg.md), offered by stable master Jolanda: three runs on Blitz
## down the lists. The crosshair wanders over Kunibert's shield; "Stoß!" (Aktion) aims the lance
## where it is, the hit counts when the horses meet: the middle 3 points, the shield 2, its rim 1.
## Kunibert scores 0 to 3 a run. More points after three runs wins.

const RUNS := 3
const RUN_TIME := 4.6           # seconds from one end of the lists to the other
const MEET := 0.5               # fraction of the run where the riders meet
const RINGS := [0.13, 0.3, 0.45]
const POINTS := [3, 2, 1]

var knight: Actor
var horse: Actor
var knight_horse: Actor
var run := 0
var t := 0.0
var state := "ready"           # ready, run, between, done
var aim := Vector2.ZERO        # crosshair on the shield (sideways, up), metres
var locked := false
var locked_aim := Vector2.ZERO
var score := 0
var knight_score := 0
var last_points := -1
var crosshair: MeshInstance3D
var pace := 1.0                 # < 1 slows the crosshair (tests)


func _init() -> void:
	title = "Tjost"
	host_id = "jolanda"
	cost = 200


func describe() -> String:
	return "Reite drei Mal gegen Ritter Kunibert und triff seinen Schild mit der Lanze. Einsatz 2 €."


func goal_done() -> bool:
	return GameState.stat("joust_wins") > 0


func talk_option(_player: Actor, _npc: Actor) -> String:
	return "Gegen Kunibert tjosten (%s)" % GameState.format_money(cost)


func begin() -> void:
	horse = take_horse("blitz")
	knight_horse = take_horse("donner")
	knight = world.find_actor("kunibert")
	knight.inside = false
	knight.visible = true
	if knight.brain:
		knight.brain.suspend()
	actor.set_item("lance")
	knight.set_item("lance")
	crosshair = MeshInstance3D.new()
	var kit := MeshKit.new()
	kit.use("glow")
	kit.push(Transform3D(Basis(Vector3.FORWARD, 0.0).rotated(Vector3.UP, PI / 2), Vector3.ZERO))
	kit.torus(Vector3.ZERO, 0.12, 0.025, 14, 3, Color("ff3b30"))
	kit.pop()
	crosshair.mesh = kit.commit()
	add_child(crosshair)
	run = 0
	score = 0
	knight_score = 0
	host_say("Lanze hoch, Blick nach vorn!", 3.0)
	set_info("Das Fadenkreuz wandert über Kuniberts Schild. „Stoß!“ (Aktion) richtet die Lanze aus – getroffen wird, wenn ihr euch begegnet.")
	add_button("Stoß!", func() -> void: strike(), 220)
	_start_run()


func _start_run() -> void:
	run += 1
	t = 0.0
	locked = false
	last_points = -1
	state = "run"
	_update_score()


func _update_score() -> void:
	set_score("Lauf %d von %d  ·  Du %d : %d Kunibert" % [mini(run, RUNS), RUNS, score, knight_score])


## Where the riders are this run: the player rides east, Kunibert west.
func _positions(k: float) -> Array:
	var px := lerpf(X0, X1, k)
	var kx := lerpf(X1, X0, k)
	return [lane(px, LANE_S), lane(kx, LANE_N)]


func _shield_center() -> Vector3:
	return knight.global_position + Vector3(0, 1.45, 0) + Vector3(0, 0, 0.35)


func _process(delta: float) -> void:
	if not active:
		return
	match state:
		"run":
			t += delta
			var k := clampf(t / RUN_TIME, 0.0, 1.0)
			var pos: Array = _positions(k)
			var speed := (X1 - X0) / RUN_TIME
			ride(actor, horse, pos[0], PI / 2, speed)
			ride(knight, knight_horse, pos[1], -PI / 2, speed)
			var tt := (t + run * 3.1) * pace
			# Fast enough that it crosses the middle in every run before the riders meet.
			aim = Vector2(sin(tt * 3.1) * 0.42, sin(tt * 4.3 + 0.7) * 0.36)
			crosshair.visible = not locked
			crosshair.global_position = _shield_center() + Vector3(0, aim.y, -aim.x)
			look(pos[0] + Vector3(-5.5, 2.8, 2.6), pos[0].lerp(pos[1], 0.7) + Vector3(0, 1.4, 0))
			if k >= MEET and last_points < 0:
				_meet()
			if k >= 1.0:
				state = "between"
				if run >= RUNS:
					_finish()
				else:
					var s := session
					get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
						if still_running(s):
							_start_run())


## Aims the lance where the crosshair is (before the riders meet).
func strike() -> void:
	if state != "run" or locked or last_points >= 0:
		return
	locked = true
	locked_aim = aim
	actor.play_anim("throw", 0.5)


func points_for(off: Vector2) -> int:
	var d := off.length()
	for i in RINGS.size():
		if d <= RINGS[i]:
			return POINTS[i]
	return 0


func _meet() -> void:
	last_points = points_for(locked_aim) if locked else 0
	var kp: int = [0, 1, 1, 2, 2, 3][rng.randi() % 6]
	score += last_points
	knight_score += kp
	Sound.play("hit" if last_points > 0 else "click", actor.global_position)
	if last_points == 3:
		host_say("Mitten auf den Schild! Die Lanze splittert!", 2.2)
	elif last_points > 0:
		host_say("Getroffen!", 1.8)
	else:
		host_say("Daneben!" if locked else "Zu spät gestoßen!", 1.8)
	_update_score()


func _finish() -> void:
	state = "done"
	var won := score > knight_score
	var draw := score == knight_score
	if won:
		GameState.add_stat("joust_wins")
	var money := 600 if won else (200 if draw else 0)
	end_after(1.2, {"won": won, "money": money, "joy": 24.0 if won else 12.0,
		"text": "%d : %d gegen Kunibert. %s" % [score, knight_score,
			"Du gewinnst den Tjost! Oma Hiltrud jubelt am lautesten." if won else ("Unentschieden – Kunibert verbeugt sich." if draw
			else "Kunibert gewinnt. „Beim nächsten Mal!“, ruft er und lüftet das Visier.")]})


func cleanup() -> void:
	if crosshair:
		crosshair.queue_free()
		crosshair = null
	var gate := lane(X0 - 4.0, LANE_S + 4.0)
	dismount(actor, gate)
	if knight:
		dismount(knight, lane(X1 + 4.0, LANE_N - 4.0))
		if knight.brain:
			knight.brain.resume()
	release_horses()
	state = "ready"


func game_input(event: InputEvent) -> void:
	if primary_pressed(event):
		strike()
