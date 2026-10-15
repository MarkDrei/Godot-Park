class_name SwingGame
extends Minigame
## Schaukel-Duell with Finja at the playground (doc/playground.md): 25 seconds on the swing.
## Push (Aktion, Leertaste, „Schwung!“) right when the swing turns at the top: it swings
## higher. Pushing in the middle of the swing brakes it. Whoever swings higher wins.

const DURATION := 25.0
const MAX_AMP := 1.25          # radians at 100 %
const OMEGA := 2.3             # pendulum speed (rad/s of the phase)
const TOP := 0.8               # |sin(phase)| from here on counts as "at the top"
const SWING_SET := 0       # the first swing set: the player on one swing, Finja on the other

var seat: Seat
var pivot: Node3D
var host_seat: Seat
var host_pivot: Node3D
var phase := 0.0
var amp := 0.12
var best := 0.0
var host_phase := 1.3
var host_amp := 0.1
var host_goal := 0.85
var host_best := 0.0
var time_left := DURATION
var lockout := 0.0
var state := "play"


func _init() -> void:
	title = "Schaukel-Duell mit Finja"
	host_id = "finja"


func describe() -> String:
	return "Auf dem Spielplatz im Stadtpark: Schaukle höher als Finja – Schwung holen, wenn die Schaukel oben umkehrt."


func goal_done() -> bool:
	return GameState.stat("swing_wins") > 0


func can_start(a: Actor) -> bool:
	return super(a) and world.playground != null and _free_swing(a) != null


func _free_swing(a: Actor) -> Seat:
	for r: Dictionary in world.playground.riders:
		var s: Seat = r["seat"]
		if s.kind == "swing" and s.owner_id == "swings_%d" % SWING_SET and (s.is_free_for(a) or s.occupant == a):
			return s
	return null


func _pivot_of(s: Seat) -> Node3D:
	for r: Dictionary in world.playground.riders:
		if r["seat"] == s:
			return r["node"]
	return null


func begin() -> void:
	var pg := world.playground
	seat = _free_swing(actor)
	pivot = _pivot_of(seat)
	actor.sit_on(seat)
	host_seat = null
	host_pivot = null
	var h := host()
	if h:
		if h.seat:
			h.stand_up()
		pg.stop(h)
		for r: Dictionary in pg.riders:
			var s: Seat = r["seat"]
			if s != seat and s.owner_id == seat.owner_id and s.is_free_for(h):
				host_seat = s
				host_pivot = r["node"]
		if host_seat:
			h.sit_on(host_seat)
		host_say("Wer zuerst die Wolken anstupst!", 3.0)
	phase = 0.0
	amp = 0.12
	best = 0.0
	host_phase = 1.3
	host_amp = 0.1
	host_goal = randf_range(0.78, 0.9)
	host_best = 0.0
	time_left = DURATION
	lockout = 0.0
	state = "play"
	var set_pos: Vector2 = Playground.SWINGS[SWING_SET]
	var base := pg.ground(set_pos)
	look(base + Vector3(7.5, 2.4, 1.0), base + Vector3(0, 1.2, 0))
	set_info("Drück Aktion, Leertaste oder „Schwung!“, wenn die Schaukel oben umkehrt.")
	add_button("Schwung!", func() -> void: push(), 220)
	_update_score()


func _update_score() -> void:
	set_score("Du: %d %%  ·  Finja: %d %%  ·  noch %d s" % [roundi(best * 100.0), roundi(host_best * 100.0), int(ceil(time_left))])


func height() -> float:
	return clampf(amp / MAX_AMP, 0.0, 1.0)


func _process(delta: float) -> void:
	if not active or state != "play":
		return
	time_left -= delta
	lockout = maxf(0.0, lockout - delta)
	phase += OMEGA * delta
	amp = maxf(0.08, amp - 0.03 * delta)
	world.playground.swing_drive[pivot] = sin(phase) * amp
	best = maxf(best, height())
	# Finja pushes well, but not perfectly.
	host_phase += OMEGA * 1.03 * delta
	host_amp = move_toward(host_amp, host_goal * MAX_AMP, delta * 0.07)
	if host_pivot:
		world.playground.swing_drive[host_pivot] = sin(host_phase) * host_amp
	host_best = maxf(host_best, host_amp / MAX_AMP)
	show_power(height())
	if time_left <= 0.0:
		_finish()
	_update_score()


## Right at the top it gives height; in the middle of the swing it brakes.
func at_top() -> bool:
	return absf(sin(phase)) >= TOP


func push() -> void:
	if not active or state != "play" or lockout > 0.0:
		return
	lockout = 0.25
	if at_top():
		amp = minf(MAX_AMP, amp + 0.11 * (1.15 - height()))
		Sound.play("click", actor.global_position)
		set_info("Hui! Weiter so – immer oben, wenn die Schaukel umkehrt.")
	else:
		amp *= 0.85
		set_info("Zu früh! In der Mitte bremst das nur.")


func _finish() -> void:
	state = "done"
	var score := roundi(best * 100.0)
	var hs := roundi(host_best * 100.0)
	GameState.set_stat_max("swing_best", score)
	var won := score >= hs
	if won:
		GameState.add_stat("swing_wins")
	host_say("Boah, du warst ja fast im Himmel!" if won else "Ätsch, höher!", 2.5)
	end_after(1.6, {"won": won, "joy": 24.0 if won else 12.0,
		"text": "Du: %d %%, Finja: %d %%. %s" % [score, hs, "Gewonnen! Finja staunt." if won else "Finja war höher. Noch mal?"]})


func game_input(event: InputEvent) -> void:
	if primary_pressed(event) or clicked(event):
		push()


func cleanup() -> void:
	var pg := world.playground
	pg.swing_drive.erase(pivot)
	if host_pivot:
		pg.swing_drive.erase(host_pivot)
	if actor and actor.seat == seat:
		actor.stand_up()
	var h := host()
	if h and host_seat and h.seat == host_seat:
		h.stand_up()
