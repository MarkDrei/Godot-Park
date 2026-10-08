extends Scenario
## Frisbee with Balu: as a human aim and throw, Balu runs; as Balu catch the disc yourself.


func test_throw_and_balu_runs() -> void:
	var m := await in_minigame("frisbee") as FrisbeeGame
	check_eq(m.state, "aim", "aiming")
	var a0 := m.aim
	await hold("move_right", 0.4)
	check(m.aim > a0, "aim right")
	await press("interact")
	check_eq(m.state, "flying", "disc flies")
	check_eq(m.throws, 1, "one throw")
	check(m.dog.is_moving(), "Balu runs after it")
	check(await wait_until(func() -> bool: return m.state == "result", 10.0), "disc lands")


func test_five_throws_end_the_game() -> void:
	var m := await in_minigame("frisbee") as FrisbeeGame
	var result := await play_until_done(m, func() -> void:
		if m.state == "aim":
			_action("interact", true)
			_action("interact", false), 200.0)
	check_eq(m.throws, 5, "five throws")
	check(result.has("won"), "result reported")
	check_eq(GameState.stat("frisbee_catches"), m.catches, "catches saved")


func test_play_as_balu_and_catch() -> void:
	await reset("balu")
	present("lukas").brain.suspend()
	await next_to("lukas")
	await press("interact")
	await wait(0.2)
	check(await choose("Frisbee"), "Lukas offers frisbee to Balu (%s)" % str(dialog_options()))
	var m: FrisbeeGame = Gameplay.minigames["frisbee"]
	check(m.active and m.as_dog, "dog mode")
	check(game.player.input_enabled, "Balu can run")
	check(await wait_until(func() -> bool: return m.state == "flying", 10.0), "Lukas throws")
	player().go_to(m.land, true)
	check(await wait_until(func() -> bool: return m.state == "result", 10.0), "disc lands")
	check_eq(m.catches, 1, "Balu caught it")
	m.quit()
