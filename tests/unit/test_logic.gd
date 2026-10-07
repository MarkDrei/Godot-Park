extends TestCase
## Pure logic: needs, achievements/state, tic-tac-toe AI, ball physics, clock.


func test_needs_decay_and_recovery() -> void:
	var n := Needs.new()
	n.hunger = 10.0
	n.fatigue = 10.0
	n.joy = 80.0
	n.update(120.0, "walk")
	check(n.hunger > 10.0, "hunger rises over time")
	check(n.fatigue > 10.0, "fatigue rises while walking")
	check(n.joy < 80.0, "joy decays")
	var f := n.fatigue
	n.update(60.0, "sit")
	check(n.fatigue < f, "sitting rests")
	n.hunger = 90.0
	check_near(n.speed_factor(), 0.55, 0.01, "starving makes slow")
	n.eat(60.0)
	check_near(n.hunger, 30.0, 0.01)
	n.joy = 10.0
	check(n.is_sad())
	n.rest_at_home(600.0)
	check(not n.is_sad(), "a night at home cheers up")


func test_money_and_achievements() -> void:
	GameState.new_game()
	check_eq(GameState.money, 500)
	check(GameState.spend(200))
	check(not GameState.spend(10000), "cannot overspend")
	check_eq(GameState.format_money(1234), "12,34 €")
	check_eq(GameState.format_money(5), "0,05 €")
	for i in 20:
		GameState.add_stat("ducks_fed")
	check(GameState.is_unlocked("duck_whisperer"), "20 ducks fed unlocks Entenflüsterer")
	check(GameState.money > 300, "achievement reward paid")
	check(GameState.add_to_set("gnomes", "g1"))
	check(not GameState.add_to_set("gnomes", "g1"), "sets ignore duplicates")
	check_eq(GameState.stat("gnomes"), 1)
	for id: String in ["donut", "hotdog", "icecream", "pretzel"]:
		GameState.add_to_set("foods", id)
	check(GameState.is_unlocked("gourmet"))
	for d: Dictionary in Achievements.DEFS:
		check(d.has("title") and d.has("desc") and d.has("stat"), "achievement %s complete" % d["id"])
	GameState.new_game()


func test_tic_tac_toe_ai() -> void:
	var b := [1, 1, 0, 0, 2, 0, 0, 0, 0]
	check_eq(TicTacToeGame.minimax(b, 2)[1], 2, "Boris blocks the open row")
	b = [2, 2, 0, 1, 1, 0, 0, 0, 0]
	check_eq(TicTacToeGame.minimax(b, 2)[1], 2, "Boris takes the win")
	check_eq(TicTacToeGame.winner([1, 1, 1, 0, 2, 2, 0, 0, 0]), 1)
	check_eq(TicTacToeGame.winner([1, 2, 1, 1, 2, 2, 2, 1, 1]), 3, "full board is a draw")
	# Perfect play from an empty board ends in a draw.
	var board := [0, 0, 0, 0, 0, 0, 0, 0, 0]
	var who := 1
	while TicTacToeGame.winner(board) == 0:
		board[TicTacToeGame.minimax(board.duplicate(), who)[1]] = who
		who = 3 - who
	check_eq(TicTacToeGame.winner(board), 3, "minimax vs minimax draws")


func test_ball_physics() -> void:
	var sim := BallSim.new()
	sim.add_box_walls(Vector2.ZERO, Vector2(4, 2))
	var b := sim.add_ball(Vector2(-1, 0), 0.05, 1.0)
	b.v = Vector2(3, 0)
	for i in 600:
		sim.step(1.0 / 60.0)
	check(sim.resting(), "friction stops the ball")
	check(absf(b.p.x) <= 2.0 and absf(b.p.y) <= 1.0, "walls keep the ball inside")
	var sim2 := BallSim.new()
	var a := sim2.add_ball(Vector2(0, 0), 0.05, 0.0)
	var c := sim2.add_ball(Vector2(0.3, 0), 0.05, 0.0)
	a.v = Vector2(1, 0)
	for i in 60:
		sim2.step(1.0 / 60.0)
	check(c.v.x > 0.8 and a.v.x < 0.2, "elastic collision transfers momentum")


func test_boule_throw_model_monotonic() -> void:
	var last := -1.0
	for i in 11:
		var d := BouleGame.predicted_distance(i / 10.0)
		check(d > last, "more power throws further")
		last = d


func test_clock_seasons() -> void:
	var saved := Clock.to_dict()
	Clock.set_time(23.9)
	var day := Clock.day
	Clock.advance(12.0)
	check_eq(Clock.day, day + 1, "midnight advances the day")
	check(Clock.is_night())
	Clock.set_time(12.0)
	check_near(Clock.daylight(), 1.0, 0.01)
	check_eq(Clock.time_string(), "12:00")
	Clock.from_dict(saved)


func test_food_effects() -> void:
	var it: Dictionary = Food.ITEMS["hotdog"]
	check(it["hunger"] > 40.0, "hot dogs are filling")
	check(Food.is_edible("donut"))
	check(not Food.is_edible("bread"), "duck bread is for ducks")
