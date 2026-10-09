extends Scenario
## The Nordwald minigames with real input: axe throwing and wood chopping with Holger,
## the switchman game with Thrain; reaching them at their spots.


func test_axe_throw_full_game() -> void:
	var m: AxeThrowGame = await in_minigame("axes")
	check(m.active and m.crosshair.visible, "aiming at the target")
	await shot("axes_aim", {"target": m.center})
	var result := await play_until_done(m, func() -> void:
		# Throw when the crosshair plus the wind is near the bull's eye.
		if m.state == "aim" and (m.aim + Vector2(m.wind, 0)).length() < 0.1:
			_press_now("interact"), 120.0)
	check(m.score >= AxeThrowGame.GOAL, "a good thrower makes %d points (%d)" % [AxeThrowGame.GOAL, m.score])
	check(result.get("won", false), "won")
	check(GameState.stat("axe_best") == m.score, "best score saved")
	check(Gameplay.minigame_done("axes"), "goal reached")


func test_axe_miss_scores_nothing() -> void:
	var m: AxeThrowGame = await in_minigame("axes")
	check_eq(m.points_for(Vector2(0.05, 0.0)), 10, "bull's eye")
	check_eq(m.points_for(Vector2(0.5, 0.0)), 4, "outer ring")
	check_eq(m.points_for(Vector2(0.9, 0.2)), 0, "off the disc")
	m.wind = 0.3  # a gust: everything right of the middle misses the disc
	await wait_until(func() -> bool: return m.aim.x > 0.45, 20.0)
	await press("interact")
	await wait_until(func() -> bool: return m.state == "aim" and m.throws_left == 4, 5.0)
	check_eq(m.last_points, 0, "a wild throw misses")
	m.quit()


func test_chop_duel() -> void:
	var m: ChopGame = await in_minigame("chopping")
	await shot("chopping", {"block": m.block})
	var result := await play_until_done(m, func() -> void:
		if m.in_zone() and m.lockout <= 0.0 and absf(m.marker - 0.5) < 0.05:
			_press_now("interact"), 60.0)
	check(m.splits > m.holger_splits, "beats Holger with good timing (%d vs %d)" % [m.splits, m.holger_splits])
	check(result.get("won", false), "won")
	check(player().has_item("log"), "takes some firewood home")


func test_chop_miss_costs_time() -> void:
	var m: ChopGame = await in_minigame("chopping")
	await wait_until(func() -> bool: return not m.in_zone(), 5.0)
	await press("interact")
	check(m.lockout > 0.0 and m.splits == 0, "a miss: no split, short pause")
	m.quit()


func test_switchman() -> void:
	var m: SwitchGame = await in_minigame("switch")
	await wait(3.0)
	await shot("switch", {"junction": m.junction})
	var result := await play_until_done(m, func() -> void:
		var c := m.next_cart()
		if not c.is_empty() and m.switch_right != SwitchGame.wants_right(c["kind"]):
			_press_now("interact"), 400.0)
	check(m.mistakes == 0 and m.correct >= 15, "every cart on the right track (%d)" % m.correct)
	check(result.get("won", false), "won")
	check(GameState.stat("switch_best") >= 15, "enough for Thrain's job")


func test_switch_mistakes_end_shift() -> void:
	var m: SwitchGame = await in_minigame("switch")
	var result := await play_until_done(m, func() -> void:
		var c := m.next_cart()
		if not c.is_empty() and m.switch_right == SwitchGame.wants_right(c["kind"]):
			_press_now("interact"), 200.0)
	check_eq(m.mistakes, SwitchGame.MISTAKES, "three wrong carts end the shift")
	check(not result.get("won", true), "lost")


## The game spots: walk up and start with Action.
func test_reach_forest_games() -> void:
	GameState.money = 500
	for id: String in ["axes", "chopping", "switch"]:
		var m: Minigame = Gameplay.minigames[id]
		var h := m.host()
		h.inside = false
		h.visible = true
		h.brain.suspend()
		var spot := minigame_spot(id)
		check(spot != Vector3.INF, "%s has a start spot" % id)
		await put_player(spot)
		await wait(0.3)
		check(prompt() != "" and not prompt().contains("nicht da"), "%s prompt (%s)" % [id, prompt()])
		await press("interact")
		await wait(0.5)
		check(m.active, "%s starts" % id)
		m.quit()
		UI.close_dialog("")
		await wait(0.3)
	check_eq(GameState.money, 400, "axe throwing costs 1 €, the others nothing")


var _queued := false


## Presses an action from inside a play_until_done step (no await there).
func _press_now(action: String) -> void:
	if _queued:
		return
	_queued = true
	(func() -> void:
		await press(action)
		_queued = false).call()
