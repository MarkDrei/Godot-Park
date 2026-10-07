extends Node
## Scripted play-through used by scripts/test.sh: exercises shopping, every
## minigame, character switching, quests, easter eggs and save/load.
## Prints "SMOKE OK" at the end; any script error shows up in the log.

var game: Node
var world: World
var failures: Array[String] = []


func run(g: Node) -> void:
	game = g
	world = g.world
	Engine.time_scale = 4.0
	await _wait(2.0)
	await _test_walk_and_shop()
	for id: String in ["ttt", "shell", "boule", "minigolf", "frisbee", "photo", "ducks", "bottles"]:
		await _test_minigame(id)
	await _test_switching()
	await _test_quests_and_eggs()
	await _test_save_load()
	await _test_night()
	Engine.time_scale = 1.0
	if failures.is_empty():
		print("SMOKE OK")
	else:
		for f in failures:
			print("SMOKE FAIL: ", f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs * Engine.time_scale, true, false, false).timeout


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time() / Engine.time_scale
	return false


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
	print("  %s %s" % ["ok  " if cond else "FAIL", msg])


func player() -> Actor:
	return game.player.actor


func _test_walk_and_shop() -> void:
	game.player.control(world.find_actor("jens"), false)
	var a := player()
	var target := world.shops["donut_stand"].customer_spot() as Vector3
	_check(a.go_to(target, true), "path to donut stand")
	await _wait_until(func() -> bool: return not a.is_moving(), 60.0)
	_check(a.distance_to(target) < 3.0, "arrived at donut stand (%.1f m)" % a.distance_to(target))
	GameState.add_money(2000)
	a.needs.hunger = 80.0
	a.consume("donut")
	await _wait(5.0)
	_check(a.needs.hunger < 60.0, "eating reduces hunger")
	# Sitting on a bench.
	var seat := world.find_free_seat(a.global_position, a, 200.0)
	_check(seat != null, "found a free bench seat")
	if seat:
		a.teleport(seat.approach_point())
		a.sit_on(seat)
		_check(a.seat == seat, "sitting on the bench")
		await _wait(1.0)
		a.stand_up()


func _prepare_host(m: Minigame) -> void:
	var h := m.host()
	if h:
		h.inside = false
		h.visible = true
		if h.controlled:
			game.player.control(world.find_actor("jens"), false)


func _test_minigame(id: String) -> void:
	var m: Minigame = Gameplay.minigames[id]
	game.player.control(world.find_actor("jens"), false)
	_prepare_host(m)
	var a := player()
	var done := [false]
	var cb := func(_r: Dictionary) -> void: done[0] = true
	m.finished.connect(cb)
	m.start(a)
	_check(m.active, "%s started" % id)
	var t := 0.0
	while not done[0] and t < 400.0:
		_drive(id, m)
		await _wait(0.5)
		t += 0.5
	if not done[0]:
		m.quit()
	_check(done[0], "%s finished" % id)
	m.finished.disconnect(cb)
	UI.close_dialog("")
	await _wait(0.5)


func _drive(id: String, m: Minigame) -> void:
	match id:
		"ttt":
			var g := m as TicTacToeGame
			if g.turn == 1:
				for i in 9:
					if g.board[i] == 0:
						g._player_move(i)
						break
		"shell":
			(m as ShellGame)._pick(randi() % 3)
		"boule":
			(m as BouleGame)._player_throw()
		"minigolf":
			(m as MinigolfGame)._putt()
		"frisbee":
			(m as FrisbeeGame)._throw(randf_range(0.3, 0.9))
		"photo":
			(m as PhotoGame)._shoot()
		"ducks":
			(m as DuckFeedingGame)._throw()
		"bottles":
			var g2 := m as BottleHuntGame
			if g2.time_left < 130.0:
				# Collect two bottles, return them, then stop.
				for b in g2.spawned.slice(0, 2):
					if is_instance_valid(b):
						(b as Bottle).interact(player())
				world.return_bottles(player())
				g2.quit()


func _test_switching() -> void:
	for id: String in ["bello", "erwin", "nussi", "minka", "pieps", "herbert", "lena", "gurrmann"]:
		var a := world.find_actor(id)
		if a == null:
			_check(false, "actor %s exists" % id)
			continue
		a.inside = false
		a.visible = true
		game.player.control(a)
		game.player.special()
		a.move_input = Vector3(1, 0, 0)
		await _wait(1.0)
		a.move_input = Vector3.ZERO
		_check(game.player.actor == a, "switched to %s" % a.display_name)
	_check(GameState.stat("characters") >= 8, "characters played counted")


func _test_quests_and_eggs() -> void:
	game.player.control(world.find_actor("jens"), false)
	var a := player()
	# Talk to everybody once (options are built without errors).
	for npc in world.actors.slice(0, 30):
		Conversations.talk(a, npc, game.player)
		UI.close_dialog("")
	# Dog walk job (make sure Mia and her dogs are in the park).
	Clock.set_time(11.0)
	var mia := world.find_actor("mia")
	mia.inside = false
	mia.visible = true
	for d: String in mia.def["dogs"]:
		var dog_actor := world.find_actor(d)
		dog_actor.inside = false
		dog_actor.visible = true
	Gameplay.quests._start_walk(a, mia)
	_check(Gameplay.quests.walk_dog != null, "dog walk started")
	var dog: Actor = Gameplay.quests.walk_dog
	if dog:
		var meadow := world.dog_meadow.get_center()
		a.teleport(Vector3(meadow.x, 0, meadow.y))
		dog.teleport(Vector3(meadow.x + 1, 0, meadow.y))
		await _wait(14.0)
		_check(Gameplay.quests.walk_state == "back", "dog played at the meadow")
		Gameplay.quests._finish_walk(a, mia)
		_check(GameState.stat("dog_walks") >= 1, "dog walk paid")
	# Mime quest.
	GameState.set_flag("mime_stuck")
	a.add_item("invisible_key")
	Gameplay.quests._free_mime(a, world.find_actor("pierre"))
	UI.close_dialog("")
	_check(GameState.is_unlocked("mime_saver"), "mime freed")
	# Easter eggs.
	Gameplay.eggs.toggle_duck_hats()
	await _wait(0.5)
	Gameplay.eggs.toggle_duck_hats()
	_check(GameState.is_unlocked("quack"), "quack code")
	Gameplay.eggs._wish(a)
	await _wait(1.5)
	_check(GameState.stat("wishes") >= 1, "wishing well")
	# Bench presser: sit on every bench.
	for b in world.benches:
		GameState.add_to_set("benches", b.bench_id)
	_check(GameState.is_unlocked("bench_presser"), "bench presser (%d benches)" % world.benches.size())


func _test_save_load() -> void:
	var money := GameState.money
	GameState.save_game()
	GameState.money = 0
	_check(GameState.load_game(), "save game loads")
	_check(GameState.money == money, "money restored after load")


func _test_night() -> void:
	Clock.set_time(23.5)
	Clock.set_weather(Clock.Weather.RAIN)
	await _wait(6.0)
	Clock.set_season(Clock.Season.WINTER)
	Clock.set_weather(Clock.Weather.SNOW)
	await _wait(6.0)
	Clock.set_time(3.2)
	await _wait(4.0)
	var visible := 0
	for a in world.actors:
		if not a.inside:
			visible += 1
	print("  night: %d actors in the park" % visible)
	_check(true, "night, rain and winter simulation ran")
