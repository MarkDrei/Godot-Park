class_name FuelGame
extends Minigame
## Tankwart Toni's game at the petrol station: fill up to the cent. Hold the nozzle (Action,
## Space or "Zapfen"), the counter runs faster and faster; let go at the target amount.
## Three rounds; points for every cent you are closer than one euro.

const ROUNDS := 3
const OVER := 300                 # cents too much: the tank overflows, round lost

var rng := RandomNumberGenerator.new()
var round_i := 0
var target := 0                   # cents
var amount := 0.0                 # cents
var held := false
var held_time := 0.0
var points: Array[int] = []
var state := "wait"               # wait (for the nozzle), fill, show
var _show := 0.0
var pump_label: Label3D
var _calm := 0.0                  # the press that started the game must not start the pump


func _init() -> void:
	title = "Punktlandung an der Zapfsäule"
	host_id = "toni"
	rng.randomize()


func describe() -> String:
	return "Bei Tankwart Toni: mit dem Auto an die Zapfsäule, dann genau auf den Cent tanken. Die Zapfsäule läuft immer schneller!"


func can_start(a: Actor) -> bool:
	return not active and a.vehicle != null and a.vehicle.is_standing()


## Amount after holding for t seconds (cents): slow at first, then faster.
static func fill_rate(t: float) -> float:
	return minf(900.0, 150.0 + 250.0 * t)


func begin() -> void:
	round_i = 0
	points.clear()
	var c := actor.vehicle
	var pump := _nearest_pump(c.pos2())
	pump_label = Label3D.new()
	pump_label.font_size = 140
	pump_label.pixel_size = 0.006
	pump_label.outline_size = 14
	pump_label.modulate = Color("9fe0a0")
	pump_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pump_label.position = Vector3(pump.x, 2.6, pump.y)
	world.add_child(pump_label)
	look(Vector3(pump.x, 0, pump.y) + Vector3(c.pos2().x - pump.x, 0, c.pos2().y - pump.y).normalized() * 4.5 + Vector3(0, 2.4, 0),
		Vector3(pump.x, 1.8, pump.y))
	var b := add_button("Zapfen", func() -> void: pass, 220)
	b.button_down.connect(func() -> void: _press(true))
	b.button_up.connect(func() -> void: _press(false))
	host_say("Volltanken kann jeder. Auf den Cent genau – das ist Kunst!", 3.0)
	_next_round()


static func _nearest_pump(p: Vector2) -> Vector2:
	var best := Vector2(172, -128)
	for q: Vector2 in [Vector2(172, -128), Vector2(172, -122), Vector2(180, -128), Vector2(180, -122)]:
		if q.distance_to(p) < best.distance_to(p):
			best = q
	return best


func _next_round() -> void:
	target = (rng.randi_range(10, 40) * 100 + rng.randi_range(0, 19) * 5)
	amount = 0.0
	held_time = 0.0
	state = "wait"
	_calm = 0.4
	set_info("Runde %d/3: Tanke genau %s! Halte Aktion, Leertaste oder „Zapfen“ und lass rechtzeitig los." % [round_i + 1, GameState.format_money(target)])
	_update()


func _press(down: bool) -> void:
	if not active:
		return
	if down and state == "wait" and _calm <= 0.0:
		state = "fill"
		held = true
		held_time = 0.0
	elif not down and state == "fill":
		held = false
		_judge()


func _process(delta: float) -> void:
	if not active:
		return
	_calm -= delta
	if state == "fill" and held:
		held_time += delta
		amount += fill_rate(held_time) * delta
		if amount > target + OVER:
			held = false
			_judge()
	elif state == "show":
		_show -= delta
		if _show <= 0.0:
			round_i += 1
			if round_i >= ROUNDS:
				_finish()
			else:
				_next_round()
	_update()


func _update() -> void:
	if pump_label:
		pump_label.text = GameState.format_money(int(round(amount)))
	set_score("Ziel %s · Zähler %s · Punkte %d" % [GameState.format_money(target), GameState.format_money(int(round(amount))), _total()])


## Points for a round: 100 minus the cents off (0 from one euro off, or when it overflowed).
static func round_points(target_ct: int, amount_ct: int) -> int:
	if amount_ct > target_ct + OVER:
		return 0
	return maxi(0, 100 - absi(amount_ct - target_ct))


func _judge() -> void:
	var a := int(round(amount))
	var p := round_points(target, a)
	points.append(p)
	GameState.set_stat_max("fuel_best", p)
	state = "show"
	_show = 2.0
	if a > target + OVER:
		host_say("Übergelaufen! Jetzt riecht alles nach Benzin.", 2.5)
	elif p >= 95:
		host_say("Punktlandung! Respekt!", 2.5)
		Sound.play("success")
	elif p > 50:
		host_say("Nicht schlecht, %d Cent daneben." % absi(a - target), 2.5)
	else:
		host_say("Das war wohl nichts.", 2.0)


func _total() -> int:
	var n := 0
	for p in points:
		n += p
	return n


func _finish() -> void:
	state = "done"
	var total := _total()
	end_after(0.5, {"won": total >= 200, "money": total * 3, "joy": 12.0 + total / 20.0,
		"text": "%d von 300 Punkten. %s" % [total, "Toni klatscht Beifall." if total >= 200 else "Toni: „Mehr Gefühl im Finger!“"]})


func game_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE and event.is_pressed() and not event.is_echo()):
		_press(true)
	elif event.is_action_released("interact") or (event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE and not event.is_pressed()):
		_press(false)


func cleanup() -> void:
	held = false
	if pump_label:
		pump_label.queue_free()
		pump_label = null
