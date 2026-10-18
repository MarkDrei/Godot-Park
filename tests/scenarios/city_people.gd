extends Scenario
## People of the Oststadt: the ten residents and the passers-by live in town (out of their
## front doors in the morning, home at night), work at their places; the three traders;
## Petra and the red lights.

const RESIDENTS := ["tanja", "kurt", "toni", "bodo", "karla", "friedrich", "siggi", "gianni", "petra", "egon", "kerstin", "conny", "deniz"]


func test_residents_exist_and_live_in_town() -> void:
	await city()
	for id: String in RESIDENTS:
		var a := world.find_actor(id)
		check(a != null, "%s lives in the Oststadt" % id)
		if a:
			check(a.home_region == "city", "%s is a city person" % id)
			check(not World.allowed(a, Vector3(0, 0, 0)), "%s does not go into the park" % id)
			# Those with a workplace live near it (the town is 520 m wide).
			var post: Array = CityLayout.POSTS.get(a.def.get("work", {}).get("spot", ""), [])
			if not post.is_empty():
				var d := (world.city_house_of(a)["door"] as Vector2).distance_to(post[0])
				check(d < 150.0, "%s lives %d m from work" % [id, int(d)])
	check(world.find_actor("citizen_15") != null and world.find_actor("kid_5") != null, "16 passers-by and 6 children")


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
	var petra := hold_npc("petra")
	petra.teleport(Vector3(218.5, 0, -2))
	traffic_off(Vector2(222, -12))   # no AI car in the way
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


## The Imbiss on the Rathausplatz: Currywurst at Conny's, Döner at Deniz's; the supermarket's
## till sells snacks and apples into the bag.
func test_imbiss_and_supermarket() -> void:
	await city()
	Clock.set_time(13.0)
	check(await open_menu("currywurst_stand") != null, "Conny's stand is open")
	player().needs.hunger = 80.0
	var money := GameState.money
	check(await choose("Currywurst mit Pommes"), "currywurst on the menu (%s)" % str(dialog_options()))
	check_eq(money - GameState.money, 420, "paid 4,20 €")
	await wait(4.0)
	check(player().needs.hunger < 40.0, "a currywurst fills you up (%.0f)" % player().needs.hunger)
	await shot("imbiss", {"stand": world.shops["currywurst_stand"].counter + Vector3(0, 1.5, 0)})
	UI.close_screens()
	check(await open_menu("doener_stand") != null, "Deniz's stand is open")
	check(dialog_options().any(func(o: String) -> bool: return o.ends_with("Döner – 5,50 €")), "Döner on the menu (%s)" % str(dialog_options()))
	UI.close_dialog("")
	check(await open_menu("supermarket") != null, "the supermarket is open")
	money = GameState.money
	check(await choose("Kaufen: Apfel"), "apples for the bag (%s)" % str(dialog_options()))
	check(player().has_item("apple") and money - GameState.money == 80, "an apple in the bag for 80 ct")


## Snack machines all over town, open at night; from every block one is not far away. One of
## them reached on foot and used.
func test_snack_machines_all_over_town() -> void:
	await city()
	Clock.set_time(3.0)
	await wait(0.2)
	var spots: Array[Vector2] = []
	for e: Array in CityLayout.MACHINES:
		var shop: Shop = world.shops[e[0]]
		check(shop.is_machine() and shop.is_open(), "%s open at night" % e[0])
		spots.append(Vector2(shop.counter.x, shop.counter.z))
		check(not world.map.is_solid(spots[-1]), "%s can be reached" % e[0])
	for blk: Dictionary in CityLayout.blocks():
		var c: Vector2 = (blk["rect"] as Rect2).get_center()
		var near := spots.reduce(func(best: float, q: Vector2) -> float: return minf(best, q.distance_to(c)), INF) as float
		check(near < 160.0, "a machine within %d m of block %s" % [int(near), blk["id"]])
	var shop: Shop = world.shops["vending_rosegarden"]
	await put_player(shop.customer_spot() + Vector3(0, 0, 8))
	check(await walk_to(shop.customer_spot(), 40.0), "walked to the machine in the Rosengarten")
	await put_player(shop.customer_spot(), shop.vendor_pos())
	await wait(0.3)
	check_eq(prompt(), "Einkaufen: Snackautomat", "prompt at the machine")
	await press("interact")
	await wait(0.2)
	check(await choose("Brezel"), "a pretzel from the machine (%s)" % str(dialog_options()))
	check(toasted("Klonk"), "it drops into the slot")
	await shot("snack_machine_town", {"machine": shop.vendor_pos() + Vector3(0, 1, 0)})


## A hungry person in the east of town eats nearby, not at the drive-in 300 m away.
func test_hungry_in_the_east_eat_nearby() -> void:
	await city()
	Clock.set_time(13.0)
	var a := present("citizen_3")
	a.teleport(Vector3(525, 0, 56))   # in front of the Rosengarten
	a.needs.hunger = 95.0
	a.brain.suspend()
	(a.brain as HumanBrain).think = 0.0
	check(await wait_until(func() -> bool: return (a.brain as HumanBrain).current is Activities.Eat, 20.0), "goes to eat (%s)" % (a.brain as HumanBrain).doing())
	var eat := (a.brain as HumanBrain).current as Activities.Eat
	if eat and eat.shop:
		check(eat.shop.counter.distance_to(Vector3(525, 0, 56)) < 120.0, "eats nearby: %s (%d m)" % [eat.shop.title, int(eat.shop.counter.distance_to(Vector3(525, 0, 56)))])
