extends Scenario
## Futterchaos at the pier: move the target, throw bread, hungry ducks score, the goose
## steals, time runs out, result.


func _ducks() -> DuckFeedingGame:
	return await in_minigame("ducks") as DuckFeedingGame


func test_move_target_and_throw() -> void:
	var m := await _ducks()
	var t0 := m.target
	await hold("move_left", 0.5)
	check(m.target.x < t0.x - 1.0, "target moves left")
	var foods := world.foods.size()
	await press("interact")
	await wait(1.5)
	check(world.foods.size() > foods or m.score > 0, "bread landed in the water")
	check(m.hungry.size() > 0, "hungry ducks are marked")


func test_feeding_a_hungry_duck_scores() -> void:
	var m := await _ducks()
	var scored := await wait_until(func() -> bool:
		if not m.hungry.is_empty():
			m.target = m.hungry[0].global_position
			if m._cooldown <= 0.0:
				m._throw()
		return m.score > 0, 50.0)
	check(scored, "a hungry duck ate the bread (+1)")


func test_time_runs_out() -> void:
	var m := await _ducks()
	m.time_left = 1.0
	m.score = 9
	var money := GameState.money
	check(await wait_until(func() -> bool: return not m.active, 5.0), "game ends when time is up")
	check_eq(GameState.stat("duck_game_best"), 9, "best score saved")
	check_eq(GameState.money - money, 180, "20 ct per duck")
	check(dialog_text().contains("9 hungrige Enten"), "result dialog")


func test_bread_inventory_restored() -> void:
	player().add_item("bread", 2)
	var m := await _ducks()
	for i in 3:
		await press("interact")
		await wait(0.6)
	m.quit()
	check_eq(player().inventory.get("bread", 0), 2, "own bread untouched by the game")
