extends Scenario
## Food stands, kiosk and food effects: reaching a stand, buying every menu item,
## closed stands, money, achievements (Feinschmecker, Zuckerschock), deposit bottles.


## Opens the shop's dialog with "Aktion" (player at the counter).
func _open_menu(id: String) -> Shop:
	var shop := await open_shop(id)
	check(shop != null, "%s opens (vendor at work)" % id)
	await at_shop(id)
	check(prompt().begins_with("Einkaufen"), "%s prompt (got '%s')" % [id, prompt()])
	await press("interact")
	await wait(0.2)
	check(UI.is_dialog_open(), "%s menu dialog opens" % id)
	return shop


## Buys one item through the menu and waits until it is eaten. Returns the money spent.
func _buy(id: String, food: String) -> int:
	await _open_menu(id)
	var money := GameState.money
	check(await choose(Food.ITEMS[food]["name"] + " –"), "%s sells %s (options %s)" % [id, food, str(dialog_options())])
	var spent := money - GameState.money  # before eating: achievements pay rewards
	await wait(5.0)
	return spent


## Reach: walk from the meadow to the donut stand and buy a donut.
func test_reach_donut_stand_and_buy() -> void:
	var shop := await open_shop("donut_stand")
	check(shop != null, "donut stand opens")
	check(await walk_to(shop.customer_spot(), 180.0), "walked to the donut stand")
	player().face(shop.counter, true)
	await wait(0.4)
	check(prompt() == "Einkaufen: Donut-Stand", "prompt (got '%s')" % prompt())
	var hunger := 60.0
	player().needs.hunger = hunger
	await press("interact")
	await wait(0.2)
	check(await choose("Donut –"), "menu has Donut")
	check_eq(GameState.money, 500 - 150, "donut costs 1,50 €")
	await wait(5.0)
	check(player().needs.hunger < hunger - 25.0, "donut makes less hungry (%.0f)" % player().needs.hunger)


func test_every_menu_item_of_every_stand() -> void:
	for id: String in ["donut_stand", "hotdog_stand", "icecream_cart", "fries_stand", "kiosk", "vending_west", "vending_east"]:
		var shop: Shop = world.shops[id]
		for food: String in shop.menu:
			GameState.money = 1000
			var spent := await _buy(id, food)
			check_eq(spent, int(Food.ITEMS[food]["price"]), "%s: %s price" % [id, food])
			UI.close_dialog("")


func test_food_effects_on_needs() -> void:
	var cases := {"hotdog": "hotdog_stand", "fries": "fries_stand", "coffee": "icecream_cart"}
	for food: String in cases:
		var n := player().needs
		n.hunger = 70.0
		n.fatigue = 60.0
		n.joy = 50.0
		GameState.money = 1000
		await _buy(cases[food], food)
		var it: Dictionary = Food.ITEMS[food]
		check(absf(n.hunger - (70.0 - it["hunger"])) < 3.0, "%s hunger %.0f" % [food, n.hunger])
		check(absf(n.fatigue - (60.0 + it["fatigue"])) < 3.0, "%s fatigue %.0f" % [food, n.fatigue])
		check(n.joy > 50.0, "%s joy up" % food)


func test_closed_stand() -> void:
	var shop: Shop = world.shops["fries_stand"]
	var v := present(shop.vendor_id)
	var brain := v.brain
	v.brain = null
	v.inside = true
	v.visible = false
	await at_shop("fries_stand")
	check(prompt() == "Pommesbude (geschlossen)", "prompt says closed (got '%s')" % prompt())
	await press("interact")
	check(not UI.is_dialog_open(), "no menu when closed")
	check(toasted("Komm später wieder"), "toast explains it")
	v.brain = brain


## A vendor who is strolling when the working hours begin goes straight to the stand
## (before, the stand stayed closed until the stroll ended).
func test_stand_opens_on_time_after_a_stroll() -> void:
	var shop: Shop = world.shops["donut_stand"]
	var v := present(shop.vendor_id)
	var hours: Array = v.def["work"]["hours"]
	var b := v.brain as HumanBrain
	Clock.set_time(hours[0] - 0.6)
	v.teleport(shop.vendor_pos() + Vector3(5, 0, 5))  # 0.4 h on foot including the margin
	if b.current:
		b._finish()
	b._start(Activities.Wander.new())
	await wait(1.0)
	check(not shop.is_open(), "closed before the way to work")
	check(await wait_until(func() -> bool: return shop.is_open(), 60.0), "open before %d:00 (doing %s)" % [hours[0], b.current.kind if b.current else "-"])


func test_not_enough_money() -> void:
	GameState.money = 100
	await _open_menu("hotdog_stand")
	await choose("Hot Dog –")
	check_eq(GameState.money, 100, "no money taken")
	check(toasted("Nicht genug Geld"), "toast says not enough money")
	check(player().item != "hotdog", "no hot dog in hand")


func test_duck_bread_from_kiosk() -> void:
	await _buy("kiosk", "bread")
	check_eq(player().inventory.get("bread", 0), 5, "5 pieces of bread")
	check(toasted("Entenbrot"), "toast about the bread")


func test_water_gives_deposit_bottle_and_kiosk_takes_it_back() -> void:
	await _buy("icecream_cart", "water")
	check_eq(player().inventory.get("empty_bottle", 0), 1, "empty bottle after drinking water")
	await _open_menu("kiosk")
	var money := GameState.money
	check(await choose("Pfandflaschen abgeben (1)"), "kiosk offers the deposit return")
	check_eq(GameState.money - money, 25, "25 ct deposit")
	check_eq(player().inventory.get("empty_bottle", 0), 0, "bottle gone")


func test_balloon_and_newspaper_are_held() -> void:
	await _buy("kiosk", "balloon")
	check_eq(player().item, "balloon", "holds the balloon")
	await _buy("kiosk", "newspaper")
	check_eq(player().item, "newspaper", "holds the newspaper")


## Feinschmecker: all five snacks bought at the stands.
func test_gourmet_achievement() -> void:
	GameState.money = 3000
	for pair: Array in [["donut_stand", "donut"], ["hotdog_stand", "hotdog"], ["hotdog_stand", "pretzel"],
			["icecream_cart", "icecream"], ["fries_stand", "fries"]]:
		await _buy(pair[0], pair[1])
	check(GameState.is_unlocked("gourmet"), "Feinschmecker unlocked (foods %s)" % str(GameState.sets.get("foods", {}).keys()))


## Zuckerschock: five donuts in a row; anything else in between resets the streak.
func test_sugar_rush() -> void:
	GameState.money = 3000
	for i in 4:
		await _buy("donut_stand", "donut")
	await _buy("donut_stand", "coffee")
	check_eq(GameState.stat("donut_streak_now"), 0, "coffee resets the streak")
	for i in 5:
		await _buy("donut_stand", "donut")
	check(GameState.is_unlocked("sugar_rush"), "Zuckerschock after five donuts in a row")


func test_dog_begs_at_hotdog_stand() -> void:
	await reset("bello")
	var shop := await open_shop("hotdog_stand")
	check(shop != null, "hot dog stand opens")
	await at_shop("hotdog_stand")
	check(prompt() == "Betteln", "dog prompt is Betteln (got '%s')" % prompt())
	var hunger := 80.0
	player().needs.hunger = hunger
	var tries := 0
	while player().needs.hunger > hunger - 30.0 and tries < 12:
		shop._beg_cooldown = 0.0
		await press("interact")
		await wait(5.0)
		tries += 1
	check(player().needs.hunger < hunger - 30.0, "begging gets a sausage sooner or later (%d tries)" % tries)


## After a night on a bench, every stand opens on time in the morning (bug: the vendors
## came in at a random gate when the work began and needed up to 2.5 hours to the stand;
## Kemal still walked home from the evening after the skipped night).
func test_stands_open_after_a_night() -> void:
	await reset("jens", 21.0)
	await wait(60.0)  # the vendors close and walk home (the kiosk is still open)
	Clock.set_time(23.0)
	await on_bench(70.0)
	await press("special")
	check(await wait_until(func() -> bool: return Clock.hour() >= 6.0 and Clock.hour() < 8.0, 30.0), "slept until the morning")
	await press("interact")
	var opened := {}
	while Clock.hour() < 12.0:
		for id: String in world.shops:
			if not opened.has(id) and world.shops[id].is_open():
				opened[id] = Clock.hour()
		await wait(1.0)
	for id: String in world.shops:
		var shop: Shop = world.shops[id]
		if shop.is_machine():
			continue
		var v := shop.vendor()
		var start: float = v.def["work"]["hours"][0]
		check(opened.get(id, 99.0) <= start + 0.1, "%s open by %d:06 (opened %s; %s: %s, %.0f m from the stand)" % [id, start,
			"%.2f h" % opened[id] if opened.has(id) else "not", v.actor_id, v.brain.doing(), v.distance_to(shop.vendor_pos())])


## Carts: the vendor stands behind the cart, not in it; donut stand and kiosk: inside,
## behind the open window (browser screenshots show whether the vendor is visible).
func test_vendors_behind_the_counter() -> void:
	for id: String in ["donut_stand", "hotdog_stand", "icecream_cart", "fries_stand", "kiosk"]:
		var shop := await open_shop(id)
		check(shop != null, "%s opens (vendor %s)" % [id, present(world.shops[id].vendor_id).brain.doing()])
		if shop == null:
			continue
		var v := shop.vendor()
		var cart := id in ["hotdog_stand", "icecream_cart", "fries_stand"]
		var p := Vector2(v.global_position.x, v.global_position.z)
		if cart:
			check(not world.map.is_solid(p), "%s: vendor outside the cart" % id)
			check(v.distance_to(shop.customer_spot()) > 2.3, "%s: vendor behind the cart (%.1f m from the customer)" % [id, v.distance_to(shop.customer_spot())])
		else:
			check(v.distance_to(shop.customer_spot()) < 2.3, "%s: vendor right behind the window" % id)
		var front := shop.customer_spot() + (shop.customer_spot() - v.global_position).normalized() * 2.0
		await put_player(front, v.global_position)
		game.camera.follow(player(), false)
		await wait(0.3)
		await shot("vendor_" + id, {"vendor": head(v)})


## Snack machines: open at night without a vendor; reach one by walking and buy a snack.
func test_snack_machine_at_night() -> void:
	await reset("jens", 2.0)
	var shop: Shop = world.shops["vending_west"]
	check(shop.is_open(), "machine open at 2:00")
	check(not world.shops["hotdog_stand"].is_open(), "stands closed at night")
	await put_player(shop.customer_spot() + Vector3(6, 0, -4))
	check(await walk_to(shop.customer_spot(), 60.0), "walked to the machine")
	player().face(shop.counter, true)
	await wait(0.4)
	await put_player(shop.customer_spot() + (shop.customer_spot() - shop.vendor_pos()).normalized() * 3.0, shop.vendor_pos())
	await shot("snack_machine_night")
	await put_player(shop.customer_spot(), shop.vendor_pos())
	await wait(0.4)
	check(prompt() == "Einkaufen: Snackautomat", "prompt (got '%s')" % prompt())
	player().needs.hunger = 70.0
	await press("interact")
	await wait(0.2)
	check(UI.is_dialog_open(), "menu opens")
	check(await choose("Käse-Sandwich –"), "machine sells sandwiches (options %s)" % str(dialog_options()))
	check_eq(GameState.money, 500 - 290, "sandwich costs 2,90 €")
	check(toasted("Klonk"), "snack drops into the slot")
	await wait(5.0)
	check(player().needs.hunger < 40.0, "sandwich makes less hungry (%.0f)" % player().needs.hunger)
	check(world.shops["vending_east"].is_open(), "second machine in the east")
