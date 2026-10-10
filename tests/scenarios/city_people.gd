extends Scenario
## People of the Oststadt: the ten residents and the passers-by live in town (out of their
## front doors in the morning, home at night), work at their places; the three traders;
## Petra and the red lights.

const RESIDENTS := ["tanja", "kurt", "toni", "bodo", "karla", "friedrich", "siggi", "gianni", "petra", "egon"]


func test_residents_exist_and_live_in_town() -> void:
	await city()
	for id: String in RESIDENTS:
		var a := world.find_actor(id)
		check(a != null, "%s lives in the Oststadt" % id)
		if a:
			check(a.home_region == "city", "%s is a city person" % id)
			check(not World.allowed(a, Vector3(0, 0, 0)), "%s does not go into the park" % id)
	check(world.find_actor("citizen_0") != null and world.find_actor("kid_0") != null, "passers-by and children")


## A few hours of town life: everybody who is out stays in town, the workers get to work.
func test_city_life_stays_in_town() -> void:
	await city()
	await put_player(Vector3(240, 0, -51))
	Clock.set_time(9.5)
	await wait(150.0)
	var out := 0
	for a in world.actors:
		if a.home_region != "city" or a.inside:
			continue
		out += 1
		check(ParkLayout.region_of(a.ground_pos()) == "city", "%s stays in town (%s)" % [a.actor_id, a.ground_pos().round()])
	check(out >= 8, "people are out in town (%d)" % out)
	var tanja := world.find_actor("tanja")
	var hb := tanja.brain as HumanBrain
	check(not tanja.inside and hb.current != null, "Tanja is out and busy (%s)" % hb.doing())


func test_residents_go_home_at_night() -> void:
	await city()
	var egon := present("egon")
	egon.brain.suspend()
	(egon.brain as HumanBrain).think = 0.1
	Clock.set_time(21.0)
	check(await wait_until(func() -> bool: return egon.inside, 300.0), "Opa Egon went home (%s)" % (egon.brain as HumanBrain).doing())
	var door: Vector2 = world.city_house_of(egon)["door"]
	check(egon.ground_pos().distance_to(door) < 3.0, "into his own front door")


func test_petrol_shop() -> void:
	await city()
	var shop := await open_shop("petrol_shop")
	check(shop != null, "Toni opens the petrol station shop")
	await at_shop("petrol_shop")
	await press("interact")
	var money := GameState.money
	check(await choose("Kaffee"), "coffee on the menu (%s)" % str(dialog_options()))
	check_eq(money - GameState.money, 200, "paid the coffee")


func test_drive_in_counter_on_foot() -> void:
	await city()
	var shop := await open_shop("drive_in_counter")
	check(shop != null, "Bodo opens the counter")
	await at_shop("drive_in_counter")
	await press("interact")
	check(await choose("Hamburger"), "burger on foot at the counter (%s)" % str(dialog_options()))


func test_buy_a_horn_and_honk() -> void:
	await city()
	var shop := await open_shop("scrapyard")
	check(shop != null, "Siggi opens the scrapyard shop")
	await at_shop("scrapyard")
	GameState.money = 5000
	await press("interact")
	check(await choose("Fanfaren-Hupe"), "horns for sale (%s)" % str(dialog_options()))
	check(player().has_item("horn_fanfare"), "the horn is in the bag")
	var car := await in_car()
	check_eq(car.horn_sound(), "horn_fanfare", "the car honks with the new horn")


func test_petra_sees_a_red_light() -> void:
	var t: Traffic = (await city()).traffic
	var cr: Dictionary = t.crossings.filter(func(c: Dictionary) -> bool: return c["lights"] and c["pos"] == Vector2(210, -12))[0]
	cr["phase"] = 0     # north-south (z) green: cars along x see red
	cr["t"] = 0.0
	var petra := present("petra")
	petra.brain.suspend()
	(petra.brain as HumanBrain).think = 600.0
	petra.teleport(Vector3(218.5, 0, -2))
	var car := await in_car("small", Vector2(240.0, -12.0 - CityLayout.LANE_OFFSET), -PI / 2)   # westbound on the Parkallee
	await drive(1.0, 4.0)
	check(GameState.stat("red_lights") >= 1, "drove over the red light")
	check(petra.last_said.contains("rot") or petra.last_said.contains("Rot") or petra.last_said.contains("Verwarnung"), "Petra comments (%s)" % petra.last_said)
	(petra.brain as HumanBrain).think = 1.0
	check(car != null, "car")


func test_residents_look_right() -> void:
	await city()
	await put_player(Vector3(240, 0, -51))
	var i := 0
	for id: String in ["tanja", "kurt", "toni", "bodo", "karla"]:
		var a := present(id)
		a.brain.suspend()
		(a.brain as HumanBrain).think = 30.0
		a.teleport(Vector3(238 + i * 1.2, 0, -46))
		a.face(Vector3(238 + i * 1.2, 0, -40), true)
		i += 1
	await put_player(Vector3(240.4, 0, -41.5), Vector3(240.4, 0, -46))
	await shot("residents")
