extends Scenario
## Minigames of the Oststadt, part 1: taxi, tow truck, parking practice, petrol pump.


# --- Taxi -----------------------------------------------------------------------------

func test_taxi_shift_from_the_taxi_company() -> void:
	await city()
	hold_npc("tanja", Vector3(166, 0, 5))
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
		await car_to(job.target)
		check(job.state == "ride", "fare %d got in" % (i + 1))
		check(job.destination.has("street"), "has an address")
		await car_to(job.target)
	check(not job.active, "shift over after four fares")
	check(GameState.stat("taxi_fares") == 4, "four fares counted")
	check(GameState.money - money >= 4 * 300, "paid for the rides (%s)" % GameState.format_money(GameState.money - money))
	UI.close_dialog("")


func test_taxi_only_in_a_taxi() -> void:
	await city()
	hold_npc("tanja", Vector3(166, 0, 5))
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
	hold_npc("tanja", Vector3(166, 0, 5))
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


# --- Navigation arrow -------------------------------------------------------------------

## The route along the streets: from the Taxi-Zentrale to the Kirche over the crossings, a
## U-turn costs, a lot is left through its driveway; the hints name the next turn.
func test_route_along_the_streets() -> void:
	var r := CityRoute.route(Vector2(208.25, -40.0), Vector2(0, 1), Vector2(331.0, -84.75))
	check(r.size() >= 4, "a route with crossings (%d points)" % r.size())
	for i in range(2, r.size() - 1):
		var a := r[i - 1]
		var b := r[i]
		check(absf(a.x - b.x) < 0.5 or absf(a.y - b.y) < 0.5 or a.distance_to(b) < 8.0, "leg %d runs along a street" % i)
	check(CityRoute.length(r) < 260.0, "short way (%d m)" % int(CityRoute.length(r)))
	# Facing south on the Hauptstraße, the Kirche north-east: straight on south costs a detour,
	# so the guide says to turn round, facing north it says right at the Nordstraße.
	var south := CityRoute.guide(Vector2(208.25, -40.0), Vector2(0, 1), r)
	check(south["turn"] == "back", "facing away: turn round (%s)" % south["turn"])
	var north_r := CityRoute.route(Vector2(208.25, -40.0), Vector2(0, -1), Vector2(331.0, -84.75))
	var north := CityRoute.guide(Vector2(208.25, -40.0), Vector2(0, -1), north_r)
	check(north["turn"] == "right", "facing north: right at the Nordstraße (%s)" % north["turn"])
	check(absf(north["in"] - 50.0) < 6.0, "in about 50 m (%d)" % int(north["in"]))
	# Out of the drive-in's lot through a driveway.
	var out := CityRoute.route(Vector2(175.0, -50.0), Vector2.ZERO, Vector2(331.0, 5.25))
	var drives: Array = CityLayout.LOTS["drive_in"]["drives"]
	check(out[0] == Vector2(175.0, -50.0), "starts at the car")
	check(drives.any(func(d: Rect2) -> bool: return d.get_center() == out[1]), "leaves the drive-in by a driveway")


## Following only the arrow over the taxi's roof (real input, no traffic in the way) brings the
## car to the waving fare; the panel shows the metres and the next turn.
func test_arrow_leads_to_the_target() -> void:
	await city()
	traffic_off()
	hold_npc("tanja", Vector3(166, 0, 5))
	await wait(4.5)   # toasts of the earlier shifts run out
	var taxi: Car = world.city.find_car("taxi")
	taxi.speed = 0.0
	taxi.place(CityLayout.VEHICLES[0][2], CityLayout.VEHICLES[0][3])   # earlier tests left it at a kerb
	game.player.enter_car(taxi)
	await frames(3)
	var job: TaxiJob = Gameplay.minigames["taxi"]
	job.try_start(player())
	check(job.active and job.state == "pickup", "shift started")
	await wait(0.6)
	var arrow := job.arrow
	check(arrow != null and arrow.visible, "the arrow lies on the road")
	check(_arrow_in_front(arrow, taxi), "in front of the taxi (%s)" % str(arrow.path))
	check(job.way_text().contains(" m, "), "the panel shows the way (%s)" % job.way_text())
	await shot("taxi_arrow", {"arrow": _arrow_tip(arrow, taxi)})
	var start := taxi.pos2().distance_to(job.target)
	var hints := {}
	var ok := false
	var t0 := Engine.get_physics_frames()
	var time := 0.0   # game seconds (a drive() step takes whole frames, longer than asked)
	var stuck := 0.0
	while time < 240.0:
		var info := arrow.info
		hints[arrow.hint().split(" ")[0]] = true
		var c := taxi.pos2()
		var fwd := taxi.forward2()
		var aim: Vector2 = info["aim"]
		var to := aim - c
		var d := to.normalized()
		var side := d.dot(Car.right_of(fwd))
		var ahead := d.dot(fwd)
		var steer := clampf(side * 2.5, -1.0, 1.0) if ahead > 0.0 else (1.0 if side >= 0.0 else -1.0)
		var near_end: bool = job.target.distance_to(c) < 14.0
		var want := 4.0 if near_end or absf(steer) > 0.6 else 9.0
		var gas := 0.7 if taxi.speed < want else (-0.6 if taxi.speed > want + 2.0 else 0.0)
		if near_end and job.target.distance_to(c) < DriveJob.ARRIVE - 1.0:
			gas = -1.0 if taxi.speed > 0.3 else 0.0
		if absf(taxi.speed) < 0.3 and gas > 0.0:
			stuck += 0.12
		else:
			stuck = 0.0
		if stuck > 1.0:
			await drive(-0.8, 1.0, -steer)   # backed off the curb, like a player would
			stuck = 0.0
		await drive(gas, 0.12, steer)
		time = float(Engine.get_physics_frames() - t0) / Engine.physics_ticks_per_second
		if job.state == "ride":
			ok = true
			break
	check(ok, "the fare got in after following the arrow (%d s, %d m left of %d)" % [int(time), int(taxi.pos2().distance_to(job.target)), int(start)])
	check(hints.size() >= 2, "the hint changed on the way (%s)" % str(hints.keys()))
	await press("interact")
	await wait(0.3)
	check(not arrow.visible, "the arrow goes with the job")
	UI.close_dialog("")


func _arrow_in_front(arrow: RouteArrow, c: Car) -> bool:
	if arrow.path.size() < 2:
		return false
	# Along the route: ahead of the nose on a street, towards the driveway on a lot.
	var d := arrow.path[0] - c.pos2()
	return not c.contains(arrow.path[0]) and d.length() < c.length() + 3.0


func _arrow_tip(arrow: RouteArrow, c: Car) -> Vector3:
	var tip := arrow.path[arrow.path.size() - 1] if arrow.path.size() > 0 else c.pos2()
	return Vector3(tip.x, c.base_y, tip.y)


## The arrow is painted on the road in the car's lane: on a straight way a short arrow ahead;
## half a block before the crossing where the way turns right it runs to the crossing and bends
## into the right lane of the cross street ("straight on, then right"); facing away it is a U
## to the left.
func test_arrow_bends_before_a_turn() -> void:
	await city()
	traffic_off()
	# Northbound on the Hauptstraße, the Kirche (east of the Nordstraße crossing at z -90)
	# ahead to the right.
	var c := await in_car("taxi", Vector2(211.75, -40.0), PI)
	var arrow := RouteArrow.new()
	world.add_child(arrow)
	var kirche := Vector2(331.0, -84.75)
	arrow.show_for(c, kirche, Color(1.0, 0.82, 0.3))
	await frames(3)
	check(_arrow_in_front(arrow, c), "the arrow starts in front of the car")
	var tip := arrow.path[arrow.path.size() - 1]
	check(arrow.info["turn"] == "right" and float(arrow.info["in"]) > 40.0, "a turn 50 m ahead (%s in %d m)" % [arrow.info["turn"], int(arrow.info["in"])])
	check(absf(tip.x - 211.75) < 1.0 and tip.y < -40.0, "far from the crossing: straight on in the lane (%s)" % str(tip))
	await car_to(Vector2(211.75, -70.0), PI, 0.3)
	tip = arrow.path[arrow.path.size() - 1]
	check(float(arrow.info["in"]) < 38.0, "half a block before the crossing (%d m)" % int(arrow.info["in"]))
	check(tip.x > 216.0 and absf(tip.y - -88.25) < 1.0, "bent right into the eastbound lane of the Nordstraße (%s)" % str(tip))
	var straight := arrow.path.slice(0, 2)
	check(absf(straight[0].x - 211.75) < 0.6 and absf(straight[1].x - 211.75) < 0.6, "straight up the lane first")
	await shot("arrow_bend", {"tip": _arrow_tip(arrow, c)})
	# Facing south, away from the way: a U into the other lane.
	await car_to(Vector2(208.25, -40.0), 0.0, 0.5)
	tip = arrow.path[arrow.path.size() - 1]
	check(arrow.info["turn"] == "back", "turn round (%s)" % arrow.info["turn"])
	check(arrow.path[0].y > c.pos2().y, "the U starts in front of the car")
	check(tip.x > 210.5 and (tip - c.pos2()).dot(c.forward2()) < (arrow.path[0] - c.pos2()).dot(c.forward2()) - 2.0, "a U to the left, pointing back (%s)" % str(tip))
	arrow.queue_free()


# --- Tow truck --------------------------------------------------------------------------

func test_tow_three_cars() -> void:
	await city()
	hold_npc("kurt", Vector3(240, 0, -132))
	var tow: Car = world.city.find_car("tow")
	game.player.enter_car(tow)
	await car_to(Vector2(240, -114), PI / 2)
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
		await car_to(truck_pos, atan2(-bf.x, -bf.y))
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
	hold_npc("friedrich", Vector3(305, 0, -121))
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
		await car_to(t["box"], t["yaw"])
		await wait(1.6)
	check(not job.active, "all three done")
	check_eq(GameState.stat("parking_best"), 9, "nine stars")
	UI.close_dialog("")


## Forward into the first gap by driving.
func test_parking_forward_by_driving() -> void:
	await city()
	hold_npc("friedrich", Vector3(305, 0, -121))
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
	var toni := hold_npc("toni", Vector3(162.7, 0, -128))
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
