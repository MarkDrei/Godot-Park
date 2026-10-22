class_name BurgJoust
extends BurgHorseGame
## Tjost with Ritter Kunibert (doc/burg.md), offered by stable master Jolanda: three runs on Blitz
## down the lists. Kunibert's shield is shown big at the side of the screen (ShieldAim) with its
## three zones: the gold middle 3 points, the red ring 2, the white rim 1. The lance's point (the
## crosshair) wanders over it, and the lance in the 3D view points there too. "Stoß!" (Aktion)
## holds the lance where it is (the crosshair stops and turns yellow); when the riders meet (the
## bar is full) that point counts. Without "Stoß!" the run scores nothing. Kunibert scores 0 to
## 3 a run. More points after three runs wins.

const RUNS := 3
const RUN_TIME := 6.0           # seconds from one end of the lists to the other
const MEET := 0.5               # fraction of the run where the riders meet
const RINGS := [0.13, 0.3, 0.45]
const POINTS := [3, 2, 1]
const ZONE_NAMES := ["Mitte", "roter Ring", "Rand"]

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
var pace := 1.0                 # < 1 slows the crosshair (tests)
var shield: ShieldAim
var _cue_t := 0.0


func _init() -> void:
	title = "Tjost"
	host_id = "jolanda"
	cost = 200


func describe() -> String:
	return "Reite drei Mal gegen Ritter Kunibert und triff seinen Schild mit der Lanze: goldene Mitte 3, roter Ring 2, Rand 1 Punkt. Einsatz 2 €."


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
	give_lance(actor)
	give_lance(knight)
	shield = ShieldAim.new()
	shield.name = "ShieldAim"
	hud.add_child(shield)
	_place_shield.call_deferred()
	run = 0
	score = 0
	knight_score = 0
	host_say("Lanze ruhig halten – und zustoßen, wenn sie auf der goldenen Mitte ist!", 3.5)
	set_info("Rechts siehst du Kuniberts Schild: Mitte 3, roter Ring 2, Rand 1 Punkt. Das Kreuz zeigt, wohin deine Lanze zielt. „Stoß!“ (Aktion) hält sie dort fest – wenn ihr euch begegnet (Balken voll), zählt der Treffer.")
	add_button("Stoß!", func() -> void: strike(), 220)
	_start_run()


func _place_shield() -> void:
	if shield and hud:
		var s := clampf(hud.size.y * 0.36, 150.0, 260.0)
		shield.size = Vector2(s, s)
		shield.position = Vector2(hud.size.x - s - 24.0, (hud.size.y - s) * 0.5)


func _start_run() -> void:
	run += 1
	t = 0.0
	locked = false
	last_points = -1
	state = "run"
	shield.hit = Vector2.INF
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


## The point on Kunibert's shield `off` metres from its middle (sideways as seen by the player).
func _on_shield(off: Vector2) -> Vector3:
	return _shield_center() + Vector3(0, off.y, -off.x)


func _process(delta: float) -> void:
	if not active:
		return
	_cue_t -= delta
	if _cue_t <= 0.0 and state == "run":
		set_cue("")
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
			var at := locked_aim if locked else aim
			shield.aim = at
			shield.locked = locked
			show_power(clampf(k / MEET, 0.0, 1.0) if last_points < 0 else -1.0)
			# The lances point where they will hit: the player's at the crosshair, Kunibert's
			# at the player's chest. After the meeting they are raised.
			if last_points < 0:
				point_lance(actor, _on_shield(at))
				point_lance(knight, actor.global_position + Vector3(0, 1.4, 0))
			else:
				point_lance(actor, lance_grip(actor) + Vector3(1.0, 0.9, 0))
				point_lance(knight, lance_grip(knight) + Vector3(-1.0, 0.9, 0))
			look(pos[0] + Vector3(-4.0, 2.8, 4.2), pos[0].lerp(pos[1], 0.7) + Vector3(0, 1.4, 0))
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


## Holds the lance where the crosshair is (before the riders meet).
func strike() -> void:
	if state != "run" or locked or last_points >= 0:
		return
	locked = true
	locked_aim = aim
	Sound.play("click", actor.global_position, -6.0)


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
	shield.hit = locked_aim if locked else Vector2.INF
	Sound.play("hit" if last_points > 0 else "click", actor.global_position)
	var mine := "Daneben!" if locked else "Nicht gestoßen!"
	if last_points > 0:
		mine = "+%d %s!" % [last_points, ZONE_NAMES[POINTS.find(last_points)]]
	set_cue("%s\nKunibert +%d" % [mine, kp], Color("4ee05a") if last_points >= 2 else (UiTheme.GOLD if last_points == 1 else UiTheme.RED))
	_cue_t = 2.0
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
	set_cue("")
	show_power(-1.0)
	if is_instance_valid(shield):
		shield.queue_free()
	shield = null
	drop_lances()
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


## Kunibert's shield, big at the side of the screen: the zones with their points, the lance's
## crosshair (red while it wanders, yellow once held), where the last run hit.
class ShieldAim extends Control:
	var aim := Vector2.ZERO
	var locked := false
	var hit := Vector2.INF

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		var k := r / 0.5   # pixels per metre: the shield is 1 m across
		draw_circle(c, r + 4.0, Color(0, 0, 0, 0.45))
		var cols := [Color("f1eee6"), Color("b8322a"), Color("e2c050")]
		for i in 3:
			draw_circle(c, BurgJoust.RINGS[2 - i] * k, cols[i])
		draw_arc(c, r, 0, TAU, 48, Color("2f5fa8"), 4.0)
		for i in 3:
			var y: float = -(BurgJoust.RINGS[i] + (BurgJoust.RINGS[i - 1] if i > 0 else 0.0)) * 0.5 * k
			var label := str(BurgJoust.POINTS[i])
			var f := get_theme_default_font()
			var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(f, c + Vector2(-w * 0.5, y + 7.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f1eee6") if i == 1 else Color("2a2a30"))
		if hit != Vector2.INF:
			var hp := c + Vector2(hit.x, -hit.y) * k
			draw_circle(hp, 9.0, Color("2a2a30"))
			draw_circle(hp, 5.0, Color("f1eee6"))
		var p := c + Vector2(aim.x, -aim.y) * k
		var col := Color("ffe14a") if locked else Color("ff3b30")
		draw_arc(p, 13.0, 0, TAU, 24, col, 4.0)
		draw_line(p + Vector2(-20, 0), p + Vector2(20, 0), col, 3.0)
		draw_line(p + Vector2(0, -20), p + Vector2(0, 20), col, 3.0)
