extends Scenario
## Minigames of the Oststadt, part 2: driving test, car wash, delivery, kart race, ice cream
## van, garbage collection, scrapyard crane, oldtimer rally.


## Takes a driving job's order from its host on foot (DriveJob.needs_order).
func _order_from(host_id: String, option: String) -> void:
	if player().vehicle:
		game.player.exit_car(true)
	await next_to(host_id)
	await press("talk")
	check(await choose(option), "%s gives the order (%s)" % [host_id, str(dialog_options())])
	await wait(0.3)


## Into a special vehicle of the town and to its start spot.
func _in_job_car(id: String) -> Car:
	await city()
	var c: Car = world.city.find_car(id)
	c.speed = 0.0
	game.player.enter_car(c)
	await wait(0.4)
	return c


# --- Driving test ------------------------------------------------------------------------

func test_driving_test_passed() -> void:
	await city()
	hold_npc("friedrich", Vector3(305, 0, -121))
	await next_to("friedrich")
	await press("interact")
	check(await choose("Fahrprüfung"), "Friedrich offers the test (%s)" % str(dialog_options()))
	var exam: DrivingTest = Gameplay.minigames["exam"]
	check(exam.active and player().vehicle != null, "in the driving school car")
	for p: Vector2 in DrivingTest.ROUTE:
		await car_to(p, NAN, 0.3)
	check(not exam.active, "test over")
	check_eq(GameState.stat("license"), 1, "passed: the licence")
	UI.close_dialog("")


func test_driving_test_speeding_is_an_error() -> void:
	await city()
	hold_npc("friedrich", Vector3(305, 0, -121))
	var exam: DrivingTest = Gameplay.minigames["exam"]
	exam.try_start(player())
	await wait(0.3)
	await car_to(Vector2(208.25, 8.0), 0.0)   # south of the Parkallee: 30 km/h
	await drive(1.0, 4.5)
	check(exam.errors >= 1, "too fast in the 30 zone (%s)" % str(exam.notes))
	exam.quit()
	UI.close_dialog("")


# --- Car wash ------------------------------------------------------------------------------

func test_car_wash_rhythm() -> void:
	await city()
	hold_npc("toni", Vector3(162.7, 0, -128))
	await in_car("small", CarWash.ENTRY + Vector2(0, -2.5), 0.0)
	await wait(0.4)
	check(prompt().begins_with("Waschstraße"), "prompt at the car wash (%s)" % prompt())
	var money := GameState.money
	await press("interact")
	var wash: CarWash = Gameplay.minigames["wash"]
	check(wash.active, "the car rolls in")
	check_eq(money - GameState.money, CarWash.PRICE, "paid")
	await shot("car_wash")
	for i in CarWash.BEATS:
		check(await wait_until(func() -> bool: return wash.beat == i and wash.window_open(), 6.0), "beat %d" % (i + 1))
		await key(KEY_1 + wash.current_step())
	await wait_until(func() -> bool: return not wash.active, 6.0)
	check_eq(GameState.stat("wash_best"), CarWash.BEATS, "all hits")
	check(GameState.money >= money, "a perfect wash is free (and Blitzblank pays)")
	UI.close_dialog("")


# --- Delivery ---------------------------------------------------------------------------------

func test_delivery_three_orders() -> void:
	hold_npc("bodo", Vector3(174, 0, -39.3))
	var van := await _in_job_car("delivery")
	check(prompt() == "Lieferdienst starten (erst den Auftrag bei Burger-Bodo holen)", "first the order from Bodo (%s)" % prompt())
	await press("interact")
	var job: DeliveryJob = Gameplay.minigames["delivery"]
	check(not job.active, "no orders without Bodo")
	await _order_from("bodo", "Lieferaufträge übernehmen")
	check(job.order_for == player(), "order taken")
	check(toasted("Burger-Express"), "the toast says where the van is")
	check(not job.active, "the orders wait in the van")
	game.player.enter_car(van)
	await wait(0.3)
	check(job.active, "getting into the van starts the orders")
	check(job._line_label.text.begins_with("Funk · Burger-Bodo: „"), "Bodo on the radio (%s)" % job._line_label.text)
	for i in DeliveryJob.ORDERS:
		check(job.house.has("street"), "order %d has an address" % (i + 1))
		await car_to(job.target)
	check(not job.active, "all delivered")
	check(job.order_for == null, "the order is done")
	check_eq(GameState.stat("deliveries_warm"), 3, "all still warm")
	UI.close_dialog("")


## The blue ring of a driving job lies under its vehicle, as big as the vehicle, and goes with
## it; an order job rings its host until the order is taken, then the vehicle.
func test_job_rings_under_the_vehicles() -> void:
	await city()
	if player().vehicle:
		game.player.exit_car(true)
	var taxi: Car = world.city.find_car("taxi")
	var r := _ring_of("taxi", taxi)
	check(not r.is_empty(), "a ring under the taxi")
	check(r.get("radius", 0.0) > taxi.length() * 0.5, "the ring reaches around the taxi (%.1f m)" % r.get("radius", 0.0))
	await put_player(taxi.global_position + Vector3(4, 0, 6), taxi.global_position)
	await wait(0.5)
	await shot("ring_taxi")
	hold_npc("bodo", Vector3(174, 0, -39.3))
	var van: Car = world.city.find_car("delivery")
	check(_ring_of("delivery", van).is_empty(), "no ring under the van before the order")
	check(not _ring_of("delivery", world.find_actor("bodo")).is_empty(), "the ring is at Bodo")
	await _order_from("bodo", "Lieferaufträge übernehmen")
	check(not _ring_of("delivery", van).is_empty(), "with the order the ring is under the van")
	check(_ring_of("delivery", world.find_actor("bodo")).is_empty(), "and no longer at Bodo")
	taxi.speed = 0.0
	game.player.enter_car(taxi)
	await wait(0.3)
	check(_ring_of("taxi", taxi).is_empty(), "no ring under the taxi the player drives")
	check(not _ring_of("taxi", world.city.find_car("taxi2")).is_empty(), "the other taxi keeps its ring")
	game.player.exit_car(true)
	(Gameplay.minigames["delivery"] as DeliveryJob).order_for = null


func _ring_of(id: String, node: Node3D) -> Dictionary:
	for t: Dictionary in Gameplay.markers.targets(player()):
		if t["what"] == id and t["node"] == node:
			return t
	return {}


# --- Kart race -------------------------------------------------------------------------------

func test_kart_race_win() -> void:
	await city()
	await put_player(Vector3(240, 0, -171.5), Vector3(240, 0, -176))
	await wait(0.4)
	check(prompt().begins_with("Kartrennen"), "prompt at the pit (%s)" % prompt())
	await press("interact")
	var race: KartRace = Gameplay.minigames["karts"]
	check(race.active and player().vehicle != null and player().vehicle.kind == "kart", "in a kart on the grid")
	await wait(1.0)
	check(player().vehicle.speed < 0.1, "waits for the countdown")
	await wait_until(func() -> bool: return race.countdown <= 0.0, 6.0)
	# Three laps by placing the kart along the centre line.
	var kart: Car = player().vehicle
	var s := race.arc_pos(kart.pos2())
	var goal := s + race.track_len * KartRace.LAPS + 3.0
	while s < goal and race.active:
		s += 6.0
		var a := race.point_at(s)
		var b := race.point_at(s + 1.0)
		kart.place(a, atan2(b.x - a.x, b.y - a.y))
		await frames(1)
	await wait(0.3)
	check(not race.active, "race over")
	check_eq(GameState.stat("kart_wins"), 1, "won")
	UI.close_dialog("")


func test_ai_karts_drive_the_track() -> void:
	await city()
	var race: KartRace = Gameplay.minigames["karts"]
	race.try_start(player())
	await wait_until(func() -> bool: return race.countdown <= 0.0, 6.0)
	player().vehicle.place(Vector2(244, -176), PI)   # out of the way, into the pit
	await wait(12.0)
	for i in range(1, 4):
		var k: Car = race.karts[i]
		check(CityMap.track_distance(k.pos2()) < CityLayout.TRACK_WIDTH * 0.5 + 0.5, "AI kart %d on the track" % i)
		check(race.progress[k] > 20.0 or race.laps[k] > 0, "AI kart %d got going (%.0f m)" % [i, race.progress[k]])
	race.quit()
	UI.close_dialog("")


# --- Ice cream van ------------------------------------------------------------------------------

func test_ice_cream_van() -> void:
	hold_npc("gianni", Vector3(298, 0, 49.6))
	await _in_job_car("icecream")
	check(prompt() == "Eiswagen-Tour starten", "prompt at the van (%s)" % prompt())
	await press("interact")
	var job: IceVanJob = Gameplay.minigames["icevan"]
	check(job.active, "tour started")
	await car_to(Vector2(208.25, 30.0), 0.0, 2.5)
	check(job.played_here != Vector2.INF, "the jingle played in the residential street")
	check(not job.queue.is_empty(), "children come running")
	for i in 2:
		var asked := await wait_until(func() -> bool: return job.queue.any(func(q: Dictionary) -> bool: return q["asked"]), 40.0)
		if not asked:
			break
		var q: Dictionary = job.queue.filter(func(x: Dictionary) -> bool: return x["asked"])[0]
		check(await click_button(IceVanJob.FLAVOURS[q["wish"]]), "flavour button")
		if job.queue.is_empty():
			job.played_here = Vector2.INF   # next stop
	check(job.served >= 1, "ice cream sold (%d)" % job.served)
	check(GameState.stat("ice_sold") >= 1, "counted")
	job.quit()
	UI.close_dialog("")


# --- Garbage collection ---------------------------------------------------------------------------

func test_garbage_round() -> void:
	await _in_job_car("garbage")
	check(prompt() == "Müllabfuhr starten", "prompt at the depot (%s)" % prompt())
	await press("interact")
	var job: GarbageJob = Gameplay.minigames["garbage"]
	check(job.active and job.bins.size() == GarbageJob.BINS, "eight bins on the round")
	for i in GarbageJob.BINS:
		await car_to(job.bins[i]["curb"], NAN, 2.4)
	check(not job.active, "round done")
	check_eq(GameState.stat("bins_emptied"), 8, "eight bins emptied")
	UI.close_dialog("")


# --- Crane ------------------------------------------------------------------------------------------

func test_crane_stacks_wrecks() -> void:
	await city()
	hold_npc("siggi", Vector3(296.5, 0, -177.3))
	await put_player(Vector3(322.0, 0, -191.0), Vector3(322, 0, -195))
	await wait(0.3)
	check(prompt() == "Schrottkran bedienen", "prompt at the crane (%s)" % prompt())
	await press("interact")
	var g: CraneGame = Gameplay.minigames["crane"]
	check(g.active, "at the crane")
	# Moving with the keys.
	var x0 := g.pos.x
	await hold("move_right", 0.6)
	check(g.pos.x > x0 + 1.0, "the magnet moves with the keys")
	for i in 5:
		var w: Dictionary = g.wrecks.filter(func(x: Dictionary) -> bool: return not x["stacked"])[0]
		g.pos = w["pos"]
		await press("interact")
		await wait_until(func() -> bool: return g.state == "move", 4.0)
		check(not g.held.is_empty(), "wreck %d grabbed" % (i + 1))
		g.pos = CraneGame.STACK
		await press("interact")
		await frames(2)
	check_eq(g.height, 5, "five on the stack")
	await shot("crane")
	g.time = CraneGame.TIME
	await wait_until(func() -> bool: return not g.active, 4.0)
	check_eq(GameState.stat("crane_best"), 5, "best stack counted")
	UI.close_dialog("")


func test_crane_off_the_stack_tumbles() -> void:
	await city()
	hold_npc("siggi", Vector3(296.5, 0, -177.3))
	var g: CraneGame = Gameplay.minigames["crane"]
	g.try_start(player())
	await wait(0.3)
	g.pos = g.wrecks[0]["pos"]
	g.grab()
	await wait_until(func() -> bool: return g.state == "move", 4.0)
	g.pos = CraneGame.STACK + Vector2(1.8, 0)
	g.grab()
	check_eq(g.height, 0, "too far off: no stack")
	g.quit()
	UI.close_dialog("")


# --- Rally ---------------------------------------------------------------------------------------------

func test_oldtimer_rally() -> void:
	hold_npc("egon", Vector3(314.6, 0, 77))
	var c := await _in_job_car("oldtimer")
	check(player().rig.visible, "the oldtimer is open: the driver is seen")
	check(prompt() == "Oldtimer-Rallye mit Opa Egon (erst den Auftrag bei Opa Egon holen)", "first ask Egon (%s)" % prompt())
	await _order_from("egon", "Oldtimer-Rallye fahren")
	game.player.enter_car(c)
	await wait(0.3)
	var job: RallyGame = Gameplay.minigames["rally"]
	check(job.active, "rally started when getting in")
	check(job._info_label.text.contains("„"), "first riddle shown (%s)" % job._info_label.text)
	check(job._radio.any(func(l: Dictionary) -> bool: return (l["text"] as String).contains(job.clue()[0])), "Egon reads the riddle out")
	for i in RallyGame.STAGES:
		await car_to(job.clue()[2], NAN, 0.4)
	check(not job.active, "rally done")
	check_eq(GameState.stat("rally_fast"), 1, "fast enough")
	check(c != null, "car")
	UI.close_dialog("")


func test_more_games_in_the_notebook() -> void:
	var titles := TaskBoard.entries().map(func(e: Dictionary) -> String: return e["title"])
	for t: String in ["Fahrprüfung", "Waschstraße", "Burger-Lieferdienst", "Kartrennen", "Eiswagen-Tour", "Müllabfuhr", "Schrottkran", "Oldtimer-Rallye"]:
		check(titles.any(func(x: String) -> bool: return x.contains(t)), "notebook lists %s" % t)
