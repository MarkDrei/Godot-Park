extends Scenario
## Giant tic-tac-toe against Boris: keys 1-9 (numpad layout), mouse click on the board,
## Boris answers, win / draw / loss.

const KEYS := [KEY_7, KEY_8, KEY_9, KEY_4, KEY_5, KEY_6, KEY_1, KEY_2, KEY_3]  # cell 0..8


func _ttt() -> TicTacToeGame:
	return await in_minigame("ttt") as TicTacToeGame


func test_key_places_cross_and_boris_answers() -> void:
	var m := await _ttt()
	await key(KEY_5)
	check_eq(m.board[4], 1, "key 5 puts a cross in the middle")
	check_eq(m.turn, 2, "Boris' turn")
	check(await wait_until(func() -> bool: return m.turn == 1, 5.0), "Boris answers")
	check_eq(m.board.count(2), 1, "one circle on the board")
	await key(KEY_5)
	check_eq(m.board.count(1), 1, "occupied cell is ignored")


func test_click_on_board() -> void:
	var m := await _ttt()
	await wait(0.6)  # camera blend
	await click_at(game.camera.unproject_position(m.cell_pos(0)))
	check_eq(m.board[0], 1, "click on the top left cell")


func test_win_pays_four_euro() -> void:
	var m := await _ttt()
	m.board = [1, 1, 0, 2, 2, 0, 0, 0, 0] as Array[int]  # start state: one move from winning
	var money := GameState.money
	await key(KEY_9)
	check(await wait_until(func() -> bool: return not m.active, 5.0), "game ends")
	check_eq(GameState.stat("ttt_wins"), 1, "win counted")
	check(GameState.is_unlocked("boris_beaten"), "Großmeister unlocked")
	check(GameState.money - money >= 400, "4 € for the win")
	check(dialog_text().contains("Tic-Tac-Toe"), "result dialog")


func test_draw() -> void:
	var m := await _ttt()
	m.board = [1, 2, 1, 1, 2, 2, 2, 1, 0] as Array[int]
	var money := GameState.money
	await key(KEY_3)
	check(await wait_until(func() -> bool: return not m.active, 5.0), "game ends")
	check_eq(GameState.money - money, 100, "1 € for a draw")


func test_full_game_with_keys() -> void:
	var m := await _ttt()
	var result := await play_until_done(m, func() -> void:
		if m.turn == 1 and not m._over:
			var i := m.board.find(0)
			if i >= 0:
				_key_now(KEYS[i]), 60.0)
	check(not m.active, "game over after at most 5 moves")
	check(result.has("won"), "result reported")


func _key_now(code: Key) -> void:
	for down: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		Input.parse_input_event(ev)


func test_quit_with_pause() -> void:
	var m := await _ttt()
	await press("pause")
	check(not m.active, "Esc ends the game")
