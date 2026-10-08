extends Scenario
## Boule with Monsieur Jacques: reaching the game, aiming, throwing, camera, full game.


func _boule() -> BouleGame:
	return Gameplay.minigames["boule"] as BouleGame


## Reach: walk to the boule court and start the game with "Aktion" at the start spot.
func test_reach_by_walking_to_the_court() -> void:
	present("jacques")
	var spot := minigame_spot("boule")
	check(await walk_to(spot, 180.0), "walked to the boule court")
	await wait(0.4)
	check(prompt().contains("Boule"), "prompt offers boule (got '%s')" % prompt())
	await press("interact")
	await wait(0.5)
	check(_boule().active, "Aktion at the court starts boule")


## Reach: talk to Jacques and pick "Spielen: Boule …" in the dialog.
func test_reach_by_talking_to_jacques() -> void:
	var jacques := present("jacques")
	jacques.brain.suspend()
	await next_to("jacques")
	await press("interact")
	await wait(0.3)
	check(UI.is_dialog_open(), "talking opens a dialog")
	check(await choose("Boule"), "dialog offers boule (options %s)" % str(dialog_options()))
	await wait(0.5)
	check(_boule().active, "choosing starts boule")


func test_aim_with_keys_and_buttons() -> void:
	var m := await in_minigame("boule") as BouleGame
	check(await wait_until(func() -> bool: return m.turn == "player", 20.0), "player's turn comes")
	var a0 := m.aim
	await hold("move_left", 0.5)
	check(m.aim < a0 - 3.0, "holding left aims left (%.1f -> %.1f)" % [a0, m.aim])
	var a1 := m.aim
	check(await click_button(">"), "'>' button exists")
	check(is_equal_approx(m.aim, a1 + 3.0), "'>' turns 3° right")
	await hold("move_right", 10.0)
	check(m.aim <= 25.0, "aim is clamped (%.1f)" % m.aim)


func test_throw_with_action() -> void:
	var m := await in_minigame("boule") as BouleGame
	check(await wait_until(func() -> bool: return m.turn == "player", 20.0), "player's turn comes")
	await frames(2)
	check(m._power.visible, "power bar visible on the player's turn")
	await press("interact")
	check(m.player_left == BouleGame.BALLS - 1, "one ball used")
	check(m.turn == "wait", "waiting for the ball to settle")
	check(not m._power.visible, "power bar hidden after the throw")


## The camera moves close to the ball while it rolls and back to the overview afterwards.
func test_camera_follows_throw() -> void:
	var m := await in_minigame("boule") as BouleGame
	await wait_until(func() -> bool: return m.turn == "player", 20.0)
	var overview := m._goal_eye
	await press("interact")
	await wait(0.6)
	check(m._goal_eye.distance_to(overview) > 2.0, "camera goal moves to a close-up")
	check(await wait_until(func() -> bool: return m.turn in ["player", "ai", "done"], 30.0), "next turn after settling")
	await wait(1.5)
	check(m._goal_eye.distance_to(overview) < 0.5 or m.turn == "ai", "back to the overview")


func test_full_game_by_pressing_action() -> void:
	var m := await in_minigame("boule") as BouleGame
	var wins := GameState.stat("boule_wins")
	var money := GameState.money
	var finished := await wait_until(func() -> bool:
		if m.turn == "player":
			_action("interact", true)
			_action("interact", false)
		return not m.active, 240.0)
	check(finished, "game ends after six balls")
	check(UI.is_dialog_open(), "result dialog shown")
	if GameState.stat("boule_wins") > wins:
		check(GameState.money > money, "a win pays money")
	check(not UI.blocks_game_input() or UI.is_dialog_open(), "no stale modal")
	UI.close_dialog("")
	check(game.player.input_enabled, "player input back after the game")


func test_quit_with_pause() -> void:
	var m := await in_minigame("boule")
	await press("pause")
	check(not m.active, "Esc ends the game")
	check(UI.is_dialog_open(), "abort dialog shown")
	UI.close_dialog("")
	check(game.player.input_enabled, "player can walk again")
