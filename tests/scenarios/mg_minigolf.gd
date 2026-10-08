extends Scenario
## Minigolf: aim with keys and buttons, putt with Aktion, ball rolls and stops, six holes,
## water penalty, result and money.


func _golf() -> MinigolfGame:
	return await in_minigame("minigolf") as MinigolfGame


func test_aim_keys_and_buttons() -> void:
	var m := await _golf()
	var a0 := m.aim
	await hold("move_left", 0.5)
	check(m.aim < a0, "left aims left")
	var a1 := m.aim
	await click_button(">")
	check(m.aim > a1, "'>' aims right")


func test_putt_with_action() -> void:
	var m := await _golf()
	check(m._power.visible, "power bar while aiming")
	await press("interact")
	check_eq(m.state, "rolling", "ball rolls")
	check_eq(m.strokes, 1, "one stroke")
	check(await wait_until(func() -> bool: return m.state != "rolling", 30.0), "ball stops or drops")


func test_hole_in_one_counts() -> void:
	var m := await _golf()
	m.strokes = 1  # start state: ball about to drop on the first stroke
	m._holed()
	check(GameState.is_unlocked("hole_in_one"), "Ass! unlocked")
	check(m._info_label.text.contains("Hole-in-One"), "info shows Hole-in-One")


func test_full_round_by_pressing_action() -> void:
	var m := await _golf()
	var result := await play_until_done(m, func() -> void:
		if m.state == "aim":
			_action("interact", true)
			_action("interact", false), 900.0)
	check(not m.active, "round over")
	check_eq(m.hole_scores.size(), 6, "six holes played")
	check(result.get("money", 0) >= 0, "result reported")
	check(dialog_text().contains("Runde beendet"), "result dialog")


func test_under_par_pays_and_unlocks_pro() -> void:
	var m := await _golf()
	m.total = 12  # start state: last hole done with 12 strokes
	var money := GameState.money
	m._finish()
	check(GameState.is_unlocked("minigolf_pro"), "Minigolf-Profi")
	check(GameState.money - money >= 400 + 200, "4 under par: 4 € + 2 € bonus")
