class_name WhackAMole
extends BoothGame
## Hau den Maulwurf with Maulwurf-Moritz: 30 seconds, nine holes, moles pop up and duck away
## again ever faster. Hit them with the keys 1–9 (like the number pad), a tap or a click.
## Very rarely the golden mole shows up (five points).

const ROUND := 30.0
## Number pad layout: 7 8 9 at the back, 1 2 3 at the front.
const KEYS := [KEY_7, KEY_8, KEY_9, KEY_4, KEY_5, KEY_6, KEY_1, KEY_2, KEY_3]
var moles: Array[MeshInstance3D] = []
var _up: Array[float] = []        # seconds a mole stays up (0 = down)
var _gold: Array[bool] = []
var score := 0
var _left := ROUND
var _spawn := 0.5
var _mallet: MeshInstance3D
var _mallet_t := 0.0


func _init() -> void:
	title = "Hau den Maulwurf"
	host_id = "moritz"
	booth = "moles"
	cost = 100


func describe() -> String:
	return "30 Sekunden, neun Löcher: Hau die Maulwürfe, bevor sie wieder abtauchen. Ein Ticket für zwei Treffer. 1 € bei Maulwurf-Moritz im Westpark."


func hole(i: int) -> Vector3:
	return lp(-1.0 + (i % 3) * 1.0, 1.06, -0.8 + (i / 3) * 0.6)


func booth_begin() -> void:
	moles.clear()
	_up.clear()
	_gold.clear()
	for i in 9:
		var m := add_prop(_mole_mesh(false), hole(i) - Vector3.UP * 0.3)
		moles.append(m)
		_up.append(0.0)
		_gold.append(false)
	var mk := MeshKit.new()
	mk.rod(Vector3(0, 0, 0), Vector3(0, 0.6, 0.3), 0.025, 0.025, 4, Color("b98a57"))
	mk.cylinder(Vector3(-0.15, 0.6, 0.3), 0.3, 0.1, 0.1, 8, Color("e8442e"))
	_mallet = add_prop(mk.commit(), Vector3.ZERO)
	_mallet.visible = false
	score = 0
	_left = ROUND
	_spawn = 0.6
	set_score("Treffer: 0 · Zeit: 30")
	set_info("Tasten 1–9 wie auf dem Ziffernblock, tippen oder klicken!")
	for i in [6, 7, 8, 3, 4, 5, 0, 1, 2]:
		add_button(_key_label(i), func() -> void: whack(i), 72)
	host_say("Die sind heute schnell, die Burschen!")


func _key_label(i: int) -> String:
	return ["7", "8", "9", "4", "5", "6", "1", "2", "3"][i]


func _mole_mesh(gold: bool) -> Mesh:
	var kit := MeshKit.new()
	var col := Color("e2c050") if gold else Color("7a5a3a")
	if gold:
		kit.use("glow")
	kit.sphere(Vector3(0, 0.12, 0), Vector3(0.16, 0.2, 0.16), col, 3, 7)
	kit.use("solid")
	kit.sphere(Vector3(0, 0.17, 0.15), Vector3(0.05, 0.04, 0.04), Color("f28db2"), 2, 4)
	kit.sphere(Vector3(-0.06, 0.24, 0.13), Vector3(0.025, 0.025, 0.02), Color("1a1a1a"), 2, 4)
	kit.sphere(Vector3(0.06, 0.24, 0.13), Vector3(0.025, 0.025, 0.02), Color("1a1a1a"), 2, 4)
	return kit.commit()


func _process(delta: float) -> void:
	if not active or _left <= 0.0:
		return
	_left -= delta
	_spawn -= delta * pace
	var pace := 1.0 - (_left / ROUND)
	if _spawn <= 0.0:
		_spawn = lerpf(0.75, 0.4, pace) * randf_range(0.7, 1.3)
		var free: Array[int] = []
		for i in 9:
			if _up[i] <= 0.0:
				free.append(i)
		if not free.is_empty():
			var i: int = free[randi() % free.size()]
			_up[i] = lerpf(1.0, 0.6, pace)
			_gold[i] = randf() < 0.025
			moles[i].mesh = _mole_mesh(_gold[i])
	for i in 9:
		var target := 0.0
		if _up[i] > 0.0:
			_up[i] -= delta
			target = 0.0 if _up[i] <= 0.0 else 1.0
		var y := moles[i].global_position.y
		var want := hole(i).y - 0.3 + target * 0.3
		moles[i].global_position = hole(i) + Vector3.UP * (lerpf(y, want, clampf(delta * 14.0, 0.0, 1.0)) - hole(i).y)
	if _mallet_t > 0.0:
		_mallet_t -= delta
		_mallet.visible = _mallet_t > 0.0
	set_score("Treffer: %d · Zeit: %d" % [score, ceili(maxf(_left, 0.0))])
	if _left <= 0.0:
		tickets = score / 2
		GameState.set_stat_max("moles_best", score)
		finish_round("%d Maulwürfe erwischt!" % score, score >= 15)


## Hits hole i: a mole that is up counts.
func whack(i: int) -> void:
	if not active or _left <= 0.0:
		return
	_mallet.global_position = hole(i) + Vector3.UP * 0.1
	_mallet_t = 0.15
	if _up[i] > 0.0 and moles[i].global_position.y > hole(i).y - 0.2:
		_up[i] = 0.0
		var points := 5 if _gold[i] else 1
		score += points
		GameState.add_stat("moles_hit", points)
		Sound.play("hit", hole(i), -2.0)
		if _gold[i]:
			GameState.set_stat("golden_mole", 1)
			host_say("Der goldene Maulwurf! Den gibt's fast nie!", 2.5)
	else:
		Sound.play("click", hole(i), -8.0)


func game_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		var k := KEYS.find((event as InputEventKey).keycode)
		if k < 0:
			k = [KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_1, KEY_KP_2, KEY_KP_3].find((event as InputEventKey).keycode)
		if k >= 0:
			whack(k)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position
		if UI.point_blocked(pos):
			return
		var best := -1
		var best_d := 70.0
		for i in 9:
			var sp: Vector2 = game.camera.unproject_position(hole(i) + Vector3.UP * 0.1)
			if sp.distance_to(pos) < best_d:
				best_d = sp.distance_to(pos)
				best = i
		if best >= 0:
			whack(best)
