extends Scenario
## Pfandjagd: free roaming, bottles to pick up, return at the machine (25 ct each),
## time limit, "Beenden" button, Esc opens the pause menu instead of quitting.


func _hunt() -> BottleHuntGame:
	var m := await in_minigame("bottles") as BottleHuntGame
	return m


func test_collect_and_return_bottles() -> void:
	var m := await _hunt()
	check_eq(m.spawned.size(), BottleHuntGame.COUNT, "bottles spawned")
	check(game.player.input_enabled, "player walks freely")
	var collected := 0
	for b: Node3D in m.spawned.slice(0, 3):
		if not is_instance_valid(b):
			continue
		check(await walk_to(b.global_position, 120.0, true, 1.0), "walked to a bottle")
		player().face(b.global_position, true)
		await wait(0.3)
		check(prompt() == "Pfandflasche aufheben", "bottle prompt (got '%s')" % prompt())
		await press("interact")
		collected += 1
	check_eq(player().inventory.get("empty_bottle", 0), collected, "bottles in the bag")
	var money := GameState.money
	check(await walk_to(world.bottle_machine, 120.0, true, 1.2), "walked to the machine")
	await wait(0.3)
	check(prompt().begins_with("Pfandflaschen einwerfen"), "machine prompt (got '%s')" % prompt())
	await press("interact")
	check_eq(GameState.money - money, 25 * collected, "25 ct per bottle")
	check_eq(m.start_returned + collected, GameState.stat("bottles"), "returned bottles counted")


func test_esc_pauses_instead_of_quitting() -> void:
	var m := await _hunt()
	await press("pause")
	check(m.active, "game keeps running")
	check(UI._modal == "pause", "pause menu open")
	await click_button("Weiterspielen")


func test_beenden_button_and_timeout() -> void:
	var m := await _hunt()
	check(await click_button("Beenden"), "Beenden button")
	check(not m.active, "ended")
	UI.close_dialog("")
	m = await _hunt()
	m.time_left = 1.0
	check(await wait_until(func() -> bool: return not m.active, 5.0), "ends when time is up")
	check(dialog_text().contains("Zeit um"), "result dialog")
