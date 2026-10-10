extends Scenario
## Minigames of the Oststadt, part 1: taxi, tow truck, parking practice, petrol pump.


func _host(id: String, at: Vector3) -> Actor:
	var h := present(id)
	h.brain.suspend()
	(h.brain as HumanBrain).think = 600.0
	h.teleport(at)
	return h


## Drives the player's car to p by teleporting it there standing (the driving itself is
## covered by driving.gd); returns after the job saw it.
func _arrive_at(p: Vector2, yaw := NAN) -> void:
	var c: Car = player().vehicle
	c.speed = 0.0
	c.place(p, c.yaw if is_nan(yaw) else yaw)
	await wait(0.6)


# --- Taxi -----------------------------------------------------------------------------

func test_taxi_shift_from_the_taxi_company() -> void:
	await city()
	_host("tanja", Vector3(166, 0, 5))
	var taxi: Car = world.city.find_car("taxi")
	var spot := taxi.pos2() - Car.right_of(taxi.forward2()) * 1.8
	await put_player(Vector3(spot.x, 0, spot.y), taxi.global_position)
	await wait(0.3)
	await press("interact")
	check(player().vehicle == taxi, "in the taxi")
	await wait(0.4)
	check(prompt() == "Taxi-Schicht beginnen", "prompt to start a shift (%s)" % prompt())
	await press("interact")
	var job: TaxiJob = Gameplay.minigames["taxi"]
	check(job.active and job.state == "pickup", "shift started, a fare waits")
	check(job.passenger != null, "somebody waves")
	await shot("taxi_pickup", {"taxi": taxi.global_position + Vector3(0, 1, 0)})
	var money := GameState.money
	for i in TaxiJob.FARES:
		await _arrive_at(job.target)
		check(job.state == "ride", "fare %d got in" % (i + 1))
		check(job.destination.has("street"), "has an address")
		await _arrive_at(job.target)
	check(not job.active, "shift over after four fares")
	check(GameState.stat("taxi_fares") == 4, "four fares counted")
	check(GameState.money - money >= 4 * 300, "paid for the rides (%s)" % GameState.format_money(GameState.money - money))
	UI.close_dialog("")


func test_taxi_only_in_a_taxi() -> void:
	await city()
	_host("tanja", Vector3(166, 0, 5))
	await in_car("small", Vector2(188, 6), 0.0)
	await wait(0.4)
	check(prompt() != "Taxi-Schicht beginnen", "no shift in an ordinary car (%s)" % prompt())


func test_taxi_fare_and_tip() -> void:
	var job: TaxiJob = Gameplay.minigames["taxi"]
	job.ride_dist = 200.0
	job.ride_time = 10.0
	job.bumps = 0
	var quick := job.fare()
	check_eq(quick["base"], 800, "3 € plus 2,50 € per 100 m")
	check(quick["tip"] > 0, "tip for a quick gentle ride")
	job.ride_time = 200.0
	job.bumps = 3
	check_eq(job.fare()["tip"], 0, "no tip when slow and bumpy")


func test_taxi_ends_when_getting_out() -> void:
	await city()
	_host("tanja", Vector3(166, 0, 5))
	var taxi: Car = world.city.find_car("taxi2")
	var job: TaxiJob = Gameplay.minigames["taxi"]
	game.player.enter_car(taxi)
	job.try_start(player())
	check(job.active, "shift running")
	var waving := job.passenger
	await press("interact")
	await wait(0.3)
	check(not job.active, "getting out ends the shift")
	check(waving == null or waving.visible, "the fare is not left invisible")
	UI.close_dialog("")


# --- Tow truck --------------------------------------------------------------------------

func test_tow_three_cars() -> void:
	await city()
	_host("kurt", Vector3(240, 0, -132))
	var tow: Car = world.city.find_car("tow")
	game.player.enter_car(tow)
	await _arrive_at(Vector2(240, -114), PI / 2)
	check(prompt() == "Abschleppdienst starten", "prompt in the yard (%s)" % prompt())
	await press("interact")
	var job: TowJob = Gameplay.minigames["tow"]
	check(job.active and job.broken != null, "a car broke down somewhere")
	for i in TowJob.CARS:
		var b := job.broken
		# Back the truck up to the broken car's rear end.
		var bf := b.forward2()
		var rear := b.pos2() - bf * (b.length() * 0.5)
		var truck_pos := rear - bf * (tow.length() * 0.5 + 0.5)
		await _arrive_at(truck_pos, atan2(-bf.x, -bf.y))
		check(prompt() == "Ankoppeln", "hook prompt at car %d (%s)" % [i + 1, prompt()])
		await press("interact")
		check(job.towing, "hooked on")
		# Tow it a bit by driving, then into the yard.
		tow.place(tow.pos2() + tow.forward2() * 1.0, tow.yaw)
		await drive(1.0, 1.0)
		check(b.pos2().distance_to(tow.pos2()) < tow.length() * 0.5 + b.length() * 0.5 + 1.5, "the car hangs behind the truck")
		await brake_to_stop()
		var yard_pos := TowJob.YARD.get_center() + Vector2(3, -2)
		tow.place(yard_pos, PI / 2)
		b.place(yard_pos - Vector2(1, 0) * (tow.length() * 0.5 + 0.4 + b.length() * 0.5 + 0.3), PI / 2)
		await wait(0.6)
		check(prompt() == "Abkoppeln", "unhook prompt in the yard (%s)" % prompt())
		await press("interact")
	check(not job.active, "shift over")
	check_eq(GameState.stat("cars_towed"), 3, "three cars towed")
	UI.close_dialog("")


# --- Parking -----------------------------------------------------------------------------

func test_parking_by_talking_to_friedrich() -> void:
	await city()
	_host("friedrich", Vector3(305, 0, -121))
	await next_to("friedrich")
	await press("interact")
	check(await choose("Einparken"), "Friedrich offers parking practice (%s)" % str(dialog_options()))
	var job: ParkingGame = Gameplay.minigames["parking"]
	check(job.active, "practice started")
	check(player().vehicle != null and player().vehicle.kind == "learner", "in the driving school's car")
	await shot("parking", {"car": player().vehicle.global_position + Vector3(0, 1, 0)})
	# Perfect parking in all three boxes (placed directly), then one more round badly.
	for i in ParkingGame.TASKS.size():
		var t: Dictionary = ParkingGame.TASKS[i]
		await _arrive_at(t["box"], t["yaw"])
		await wait(1.6)
	check(not job.active, "all three done")
	check_eq(GameState.stat("parking_best"), 9, "nine stars")
	UI.close_dialog("")


## Forward into the first gap by driving.
func test_parking_forward_by_driving() -> void:
	await city()
	_host("friedrich", Vector3(305, 0, -121))
	var job: ParkingGame = Gameplay.minigames["parking"]
	job.try_start(player())
	await wait(0.5)
	var c: Car = player().vehicle
	var box: Vector2 = ParkingGame.TASKS[0]["box"]
	Input.action_press("move_forward", 0.6)
	await wait_until(func() -> bool: return c.pos2().x > box.x - 2.6, 15.0)
	_release_all()
	await brake_to_stop()
	await wait(1.6)
	check(job.stars.size() == 1 and job.stars[0] >= 1, "stars for the first box (%s, car at %s)" % [str(job.stars), c.pos2()])
	job.quit()
	UI.close_dialog("")


func test_parking_rating() -> void:
	var job: ParkingGame = Gameplay.minigames["parking"]
	job.task = 0
	var t: Dictionary = ParkingGame.TASKS[0]
	check_eq(job.rate(t["box"], t["yaw"], t), 3, "middle and straight: three stars")
	check_eq(job.rate(t["box"] + Vector2(0.6, 0), t["yaw"] + 0.15, t), 2, "a bit off: two")
	check_eq(job.rate(t["box"] + Vector2(0, 2.0), t["yaw"], t), 0, "beside the box: none")


# --- Petrol pump ----------------------------------------------------------------------------

func test_fuel_game_at_the_pump() -> void:
	await city()
	var toni := _host("toni", Vector3(162.7, 0, -128))
	await in_car("small", Vector2(176.0, -125.0), 0.0)
	await wait(0.4)
	check(prompt() == "Punktlandung mit Toni", "prompt at the pump (%s)" % prompt())
	await press("interact")
	var g: FuelGame = Gameplay.minigames["fuel"]
	check(g.active, "game started")
	await shot("fuel", {"pump": Vector3(172, 2.6, -125)})
	var money := GameState.money
	Engine.time_scale = 1.0     # finer steps: the counter runs up to 9 € a second
	for i in FuelGame.ROUNDS:
		await wait_until(func() -> bool: return g.state == "wait", 6.0)
		await wait(0.5)
		_action("interact", true)    # held: a real press event, released below
		await frames(2)
		var tgt := g.target
		# Let go half a step (1/60 s) early.
		await wait_until(func() -> bool: return g.amount >= tgt - FuelGame.fill_rate(g.held_time) / 30.0, 30.0)
		_action("interact", false)
		await frames(3)
		check(g.points.size() == i + 1 and g.points[i] > 40, "round %d close (%s)" % [i + 1, str(g.points)])
	Engine.time_scale = Scenario.TIME_SCALE
	await wait_until(func() -> bool: return not g.active, 8.0)
	check(GameState.money > money, "Toni pays for the points")
	check(GameState.stat("fuel_best") > 40, "best round counted")
	check(toni != null, "toni")
	UI.close_dialog("")


func test_fuel_points() -> void:
	check_eq(FuelGame.round_points(2000, 2000), 100, "exact: 100 points")
	check_eq(FuelGame.round_points(2000, 2037), 63, "37 cents off")
	check_eq(FuelGame.round_points(2000, 1800), 0, "two euros short: nothing")
	check_eq(FuelGame.round_points(2000, 2400), 0, "overflowed: nothing")


func test_city_games_in_the_notebook() -> void:
	var titles := TaskBoard.entries().map(func(e: Dictionary) -> String: return e["title"])
	for t: String in ["Taxi fahren", "Abschleppdienst", "Einparken üben", "Punktlandung an der Zapfsäule"]:
		check(titles.any(func(x: String) -> bool: return x.contains(t)), "notebook lists %s" % t)
