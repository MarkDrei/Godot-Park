class_name WhackAMole
extends BoothGame
## Hau den Maulwurf with Maulwurf-Moritz: 30 seconds, six holes, moles pop up and duck away
## again ever faster. Hit them with the keys 1–6 (like the number pad), a tap or a click.
## Very rarely the golden mole shows up (five points).

const ROUND := 30.0
const HOLES := 6
## Two rows of three like on the number pad: 4 5 6 at the back, 1 2 3 at the front.
const KEYS := [KEY_4, KEY_5, KEY_6, KEY_1, KEY_2, KEY_3]
const PAD_KEYS := [KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_1, KEY_KP_2, KEY_KP_3]
const BOARD_Y := 1.12             # top of the board right behind the counter
var moles: Array[MeshInstance3D] = []
var _up: Array[float] = []        # seconds a mole stays up (0 = down)
var _gold: Array[bool] = []
var score := 0
var _left := ROUND
var _spawn := 0.5
var _mallet: MeshInstance3D
var _mallet_t := 0.0
var _mesh_brown: Mesh
var _mesh_gold: Mesh


func _init() -> void:
	title = "Hau den Maulwurf"
	host_id = "moritz"
	booth = "moles"
	cost = 100


func describe() -> String:
	return "30 Sekunden, sechs Löcher: Hau die Maulwürfe, bevor sie wieder abtauchen. Ein Ticket für zwei Treffer. 1 € bei Maulwurf-Moritz im Westpark."


## Hole i on the board: the back row stands on a step, offset by half a hole, so every mole
## is seen between the front ones.
func hole(i: int) -> Vector3:
	var back := i < 3
	return lp(-0.75 + (i % 3) * 0.75 + (0.2 if back else -0.2), BOARD_Y + (0.14 if back else 0.0), 0.35 if back else 0.95)


## Close over the counter onto the board, the player at its left.
func camera() -> Array:
	return [lp(0.1, 2.0, 3.0), lp(0.0, 1.05, 0.5)]


func booth_begin() -> void:
	moles.clear()
	_up.clear()
	_gold.clear()
	_mesh_brown = _mole_mesh(false)
	_mesh_gold = _mole_mesh(true)
	actor.teleport(lp(-1.9, 0, 1.95))
	actor.face(lp(-0.4, 0, 0.8), true)
	var board := MeshKit.new()
	board.box(Vector3(0, (BOARD_Y + 0.12) * 0.5, 0.95), Vector3(2.6, BOARD_Y - 0.12, 0.6), Color("d9a441"), Color("8cc152"))
	board.box(Vector3(0, (BOARD_Y + 0.26) * 0.5, 0.35), Vector3(2.6, BOARD_Y + 0.02, 0.6), Color("d9a441"), Color("7fb347"))
	add_prop(board.commit(), lp(0, 0, 0))
	for i in HOLES:
		var ring := MeshKit.new()
		ring.cylinder(Vector3.ZERO, 0.015, 0.2, 0.2, 12, Color("2a1d14"))
		ring.torus(Vector3(0, 0.02, 0), 0.2, 0.025, 12, 3, Color("6b4a2a"))
		add_prop(ring.commit(), hole(i))
		var m := add_prop(_mesh_brown, hole(i) - Vector3.UP * 0.42)
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
	set_info("Tasten 1–6 (hinten 4 5 6, vorne 1 2 3), tippen oder klicken!")
	for i in [3, 4, 5, 0, 1, 2]:
		add_button(_key_label(i), func() -> void: whack(i), 80)
	host_say("Die sind heute schnell, die Burschen!")


func _key_label(i: int) -> String:
	return ["4", "5", "6", "1", "2", "3"][i]


## A cheerful mole (origin at the hole): brown fur, light snout, pink nose, eyes, little paws.
func _mole_mesh(gold: bool) -> Mesh:
	var kit := MeshKit.new()
	var fur := Color("e2c050") if gold else Color("a8754a")
	var face := Color("f3dfa0") if gold else Color("e0b88a")
	if gold:
		kit.use("glow")
	kit.sphere(Vector3(0, 0.16, 0), Vector3(0.17, 0.22, 0.17), fur, 3, 8)
	kit.use("solid")
	kit.sphere(Vector3(0, 0.15, 0.11), Vector3(0.11, 0.1, 0.08), face, 2, 6)
	kit.sphere(Vector3(0, 0.2, 0.18), Vector3(0.05, 0.04, 0.04), Color("f28db2"), 2, 5)
	for x: float in [-0.065, 0.065]:
		kit.sphere(Vector3(x, 0.27, 0.13), Vector3(0.03, 0.035, 0.02), Color("1a1a1a"), 2, 4)
		kit.sphere(Vector3(x + 0.008, 0.28, 0.145), Vector3(0.008, 0.008, 0.006), Color.WHITE, 1, 3)
		kit.sphere(Vector3(x * 1.8, 0.2, 0.13), Vector3(0.05, 0.03, 0.04), face, 2, 4)
	return kit.commit()


func _process(delta: float) -> void:
	if not active or _left <= 0.0:
		return
	_left -= delta
	_spawn -= delta * pace
	var k := 1.0 - (_left / ROUND)   # later in the round, faster
	if _spawn <= 0.0:
		_spawn = lerpf(0.8, 0.45, k) * randf_range(0.7, 1.3)
		var free: Array[int] = []
		for i in HOLES:
			if _up[i] <= 0.0:
				free.append(i)
		if not free.is_empty():
			var i: int = free[randi() % free.size()]
			_up[i] = lerpf(1.05, 0.65, k)
			_gold[i] = randf() < 0.025
			moles[i].mesh = _mesh_gold if _gold[i] else _mesh_brown
	for i in HOLES:
		var target := 0.0
		if _up[i] > 0.0:
			_up[i] -= delta
			target = 0.0 if _up[i] <= 0.0 else 1.0
		var y := moles[i].global_position.y
		var want := hole(i).y - 0.42 + target * 0.42
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
			k = PAD_KEYS.find((event as InputEventKey).keycode)
		if k >= 0:
			whack(k)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var pos := (event as InputEventMouseButton).position
		if UI.point_blocked(pos):
			return
		var best := -1
		var best_d := 90.0
		for i in HOLES:
			var sp: Vector2 = game.camera.unproject_position(hole(i) + Vector3.UP * 0.1)
			if sp.distance_to(pos) < best_d:
				best_d = sp.distance_to(pos)
				best = i
		if best >= 0:
			whack(best)
