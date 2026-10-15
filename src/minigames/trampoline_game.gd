class_name TrampolineGame
extends Minigame
## Trampolin-Hüpfen with Robin at the playground (doc/playground.md): 20 seconds on the
## trampoline. Push off (Aktion, Leertaste, „Abspringen!“) just as you land: every good push
## takes you higher, a late or early one lets you sink. Each jump scores its height; from
## 2.4 m up you turn a somersault for a bonus. Beat Robin's points.

const DURATION := 20.0
const MAX_H := 3.0
const MIN_H := 0.5
const WINDOW := 0.2            # seconds before (and a bit after) landing a push counts
const SALTO_H := 2.4
const SALTO_BONUS := 15

var base := Vector3.ZERO
var h := MIN_H                 # height of the current jump
var k := 0.0                   # 0 take-off .. 1 landing
var pushed_at := -10.0         # game time of the last push
var t := 0.0
var points := 0
var jumps := 0
var saltos := 0
var robin_points := 0
var time_left := DURATION
var state := "play"
var _salto := false
var _landed_at := -10.0
var _grew := false


func _init() -> void:
	title = "Trampolin mit Robin"
	host_id = "robin"


func describe() -> String:
	return "Auf dem Spielplatz im Stadtpark: Hüpf auf dem Trampolin höher als Robin – abspringen genau beim Landen."


func goal_done() -> bool:
	return GameState.stat("trampoline_wins") > 0


func can_start(a: Actor) -> bool:
	return super(a) and world.playground != null and not world.playground.is_busy("jump")


func air_time(height: float) -> float:
	return 0.35 + sqrt(height) * 0.5


func begin() -> void:
	var pg := world.playground
	pg.stop(actor)
	base = pg.ground(Playground.TRAMPOLINE) + Vector3(0, 0.05, 0)
	actor.custom_motion = true
	actor.global_position = base
	actor.yaw = 0.0
	actor.rotation = Vector3.ZERO
	pg.busy["jump"] = actor
	h = MIN_H
	k = 0.0
	t = 0.0
	pushed_at = -10.0
	points = 0
	jumps = 0
	saltos = 0
	robin_points = randi_range(110, 150)
	time_left = DURATION
	state = "play"
	_salto = false
	var hst := host()
	if hst:
		pg.stop(hst)
		if hst.seat:
			hst.stand_up()
		hst.teleport(base + Vector3(2.4, -0.05, 0.6))
		hst.face(base, true)
		host_say("Ich hab %d Punkte geschafft. Das schaffst du nie!" % robin_points, 3.0)
	look(base + Vector3(6.5, 2.2, 3.5), base + Vector3(0, 1.4, 0))
	set_info("Drück Aktion, Leertaste oder „Abspringen!“, genau wenn du landest.")
	add_button("Abspringen!", func() -> void: push(), 220)
	_update_score()


func _update_score() -> void:
	set_score("Punkte: %d  ·  Robin: %d  ·  noch %d s" % [points, robin_points, int(ceil(time_left))])


func _process(delta: float) -> void:
	if not active or state != "play":
		return
	t += delta
	time_left -= delta
	k += delta / air_time(h)
	if k >= 1.0:
		_land()
	var y := h * 4.0 * k * (1.0 - k)
	# A somersault turns about the middle of the body, not the feet.
	var b := Basis(Vector3.UP, actor.yaw) * Basis(Vector3.RIGHT, -k * TAU if _salto else 0.0)
	var mid := Vector3(0, 0.75, 0)
	actor.global_transform = Transform3D(b, base + Vector3(0, y, 0) + mid - b * mid)
	actor.anim = "bounce"
	show_power(h / MAX_H)
	if time_left <= 0.0 and k < 0.2:
		_finish()
	_update_score()


## Seconds until the next landing.
func to_landing() -> float:
	return (1.0 - k) * air_time(h)


func push() -> void:
	if not active or state != "play":
		return
	pushed_at = t
	# Pushing just after landing still counts (_land looks back WINDOW seconds).
	if k < 0.1 and t - _landed_at < 0.12:
		_grow()


func _land() -> void:
	k = 0.0
	_landed_at = t
	jumps += 1
	points += roundi(h * 10.0)
	if _salto:
		saltos += 1
		points += SALTO_BONUS
		Sound.play("success", base)
	_grew = false
	if t - pushed_at <= WINDOW:
		_grow()
	else:
		h = maxf(MIN_H, h * 0.8)
	_salto = h >= SALTO_H


func _grow() -> void:
	if _grew:
		return
	_grew = true
	h = minf(MAX_H, h + 0.45)
	_salto = h >= SALTO_H
	Sound.play("click", base)
	set_info("Salto!" if _salto else "Hui! Höher!")


func _finish() -> void:
	state = "done"
	GameState.set_stat_max("trampoline_best", points)
	var won := points > robin_points
	if won:
		GameState.add_stat("trampoline_wins")
	host_say("Wow, voll hoch!" if won else "Hehe, gewonnen!", 2.5)
	end_after(1.4, {"won": won, "joy": 24.0 if won else 12.0,
		"text": "%d Sprünge, %d Saltos, %d Punkte – Robin hatte %d. %s" % [jumps, saltos, points, robin_points, "Gewonnen!" if won else "Robin hat gewonnen."]})


func game_input(event: InputEvent) -> void:
	if primary_pressed(event) or clicked(event):
		push()


func cleanup() -> void:
	var pg := world.playground
	if pg.busy.get("jump") == actor:
		pg.busy.erase("jump")
	if actor:
		actor.custom_motion = false
		actor.rotation = Vector3(0, actor.yaw, 0)
		actor.anim = "idle"
		actor.teleport(pg.ground(Playground.TRAMPOLINE + Vector2(0, -2.0)))
