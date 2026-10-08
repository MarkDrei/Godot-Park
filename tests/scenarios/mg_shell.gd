extends Scenario
## Hütchenspiel with Harry: watch the nut, shuffling, pick with keys 1-3, a click or the
## buttons; win pays 4 €, Adlerauge after three wins in a row.


func _shell() -> ShellGame:
	var m := await in_minigame("shell") as ShellGame
	check(await wait_until(func() -> bool: return m.state == "pick", 30.0), "shuffling ends, pick phase")
	return m


func test_shows_nut_then_shuffles() -> void:
	var m := await in_minigame("shell") as ShellGame
	check_eq(m.state, "show", "first the nut is shown")
	check(await wait_until(func() -> bool: return m.state == "shuffle", 5.0), "then the cups are shuffled")
	check(m.swaps_left > 0, "swaps planned")


func test_right_pick_with_key_wins() -> void:
	var m := await _shell()
	var money := GameState.money
	var slot := m.slots.find(m.nut_cup)
	await key([KEY_1, KEY_2, KEY_3][slot])
	check_eq(m.state, "reveal", "cups are lifted")
	check(await wait_until(func() -> bool: return not m.active, 5.0), "game ends")
	check_eq(GameState.money - money, 400, "4 € for the right cup")
	check_eq(GameState.stat("shell_streak_now"), 1, "streak 1")


func test_wrong_pick_with_button_loses() -> void:
	var m := await _shell()
	var money := GameState.money
	var slot := (m.slots.find(m.nut_cup) + 1) % 3
	check(await click_button(["Links", "Mitte", "Rechts"][slot]), "pick button")
	check(await wait_until(func() -> bool: return not m.active, 5.0), "game ends")
	check_eq(GameState.money, money, "no money for the wrong cup")
	check_eq(GameState.stat("shell_streak_now"), 0, "streak reset")


func test_pick_by_clicking_the_cup() -> void:
	var m := await _shell()
	await wait(0.5)
	var slot := m.slots.find(m.nut_cup)
	await click_at(game.camera.unproject_position(m._slot_pos(slot)))
	check_eq(m.picked, slot, "click picks the cup under the cursor")


func test_eagle_eye_after_three_wins() -> void:
	for i in 3:
		var m := await _shell()
		await key([KEY_1, KEY_2, KEY_3][m.slots.find(m.nut_cup)])
		await wait_until(func() -> bool: return not m.active, 5.0)
		UI.close_dialog("")
	check(GameState.is_unlocked("eagle_eye"), "Adlerauge after three wins in a row")


func test_no_pick_while_shuffling() -> void:
	var m := await in_minigame("shell") as ShellGame
	await wait_until(func() -> bool: return m.state == "shuffle", 5.0)
	await key(KEY_1)
	check_eq(m.picked, -1, "picking is ignored while shuffling")
