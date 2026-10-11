extends Scenario
## The arcade hall of the Kirmes (doc/kirmes.md, phase 5): three machines with a little 2D game
## each, a high-score table with the fair people's scores, tickets by the score, a stamp.


func _start(id: String) -> ArcadeGame:
	await fair()
	Clock.set_time(14.0)
	var m: ArcadeGame = Gameplay.minigames[id]
	GameState.money = 1000
	await put_player(m.cabinet)
	await wait(0.3)
	check(prompt().contains(m.title), "%s prompt (%s)" % [id, prompt()])
	await press("interact")
	await frames(3)
	check(m.active, "%s runs" % id)
	check_eq(GameState.money, 1000 - m.cost, "%s costs %s" % [id, GameState.format_money(m.cost)])
	return m


func _over(m: ArcadeGame, timeout := 60.0) -> void:
	check(await wait_until(func() -> bool: return not m.active, timeout), "%s ends" % m.title)
	await wait(0.2)
	UI.close_dialog("")
	check(FairPass.has("arcade"), "the arcade stamped")
	check(m.best() == m.score, "best score kept (%d)" % m.best())
	check(m.table().any(func(e: Array) -> bool: return e[2]), "the player is in the high-score table")


func test_snake() -> void:
	var m := await _start("arcade_snake") as SnakeMachine
	# A cherry right ahead.
	m.food = m.body[0] + m.dir * 2
	check(await wait_until(func() -> bool: return m.score >= 10, 5.0), "ate the cherry (%d)" % m.score)
	check(m.body.size() == 4, "the snake grew")
	Input.action_press("move_back")      # down: towards the wall
	await wait(0.4)
	_release_all()
	await _over(m)


func test_astro() -> void:
	var m := await _start("arcade_astro") as AstroMachine
	m.rocks.append({"pos": Vector2(m.ship_x, 40.0), "vel": Vector2(0, 20), "r": 5.0})
	Input.action_press("interact")
	check(await wait_until(func() -> bool: return m.score >= 30, 5.0), "shot a meteor (%d)" % m.score)
	_release_all()
	# The cannon sits still and lets the meteors land.
	await _over(m, 120.0)
	check_eq(m.lives, 0, "three lives lost")


func test_bricks() -> void:
	var m := await _start("arcade_bricks") as BricksMachine
	Input.action_press("interact")
	await wait(0.2)
	_release_all()
	check(not m._stuck, "the ball is off")
	m.ball = Vector2(12.0, 50.0)
	m.vel = Vector2(0, -120.0)
	check(await wait_until(func() -> bool: return m.score > 0, 3.0), "a brick broke (%d)" % m.score)
	# Fire held: every new ball goes off at once; the paddle stays where it is.
	Input.action_press("interact")
	await _over(m, 240.0)
	_release_all()


## First place on all three machines: Highscore-König. The panel fits on every screen.
func test_highscore_king_and_layout() -> void:
	var m := await _start("arcade_astro") as AstroMachine
	await wait(0.5)
	for screen in screens():
		await set_screen(screen)
		await wait(0.2)
		check_layout("arcade " + screen)
	await set_screen("desktop")
	m.quit()
	await wait(0.2)
	UI.close_dialog("")
	for id: String in ArcadeGame.TABLE:
		GameState.set_stat_max("arcade_" + id, ArcadeGame.TABLE[id][0][1] + 10)
	var g: ArcadeGame = Gameplay.minigames["arcade_snake"]
	g.score = 0
	g.over = false
	check(g.first_place(), "first place on the snake machine")
	var firsts := 0
	for id: String in ArcadeGame.TABLE:
		if GameState.stat("arcade_" + id) > ArcadeGame.TABLE[id][0][1]:
			firsts += 1
	GameState.set_stat_max("arcade_firsts", firsts)
	check(GameState.is_unlocked("highscore_king"), "Highscore-König")
