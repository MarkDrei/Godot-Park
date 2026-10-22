extends Scenario
## The Möwenbucht's beach life (doc/moewenbucht.md, phase 2): fishing on the pier, from a rowing
## boat and with the surf rod, shells and amber on the beach, the stands and who buys what, the
## coast's people at their posts.


func _v(p: Vector2) -> Vector3:
	return Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)


func _spots(kind: String) -> Array:
	return Gameplay.gathering.spots.filter(func(s: Dictionary) -> bool: return s["kind"] == kind and ParkMap.in_coast(Vector2(s["pos"].x, s["pos"].z)))


## Opens the stand's trade dialog ("Aktion" at the counter) and chooses an option.
func _trade(option: String) -> void:
	UI.close_dialog("")
	await press("interact")
	await wait(0.2)
	check(await choose(option), "option '%s' (%s)" % [option, str(dialog_options())])
	UI.close_dialog("")


## Waits for the bite like a player (the prompt turns to "Biss!") and reels in with "Aktion".
func _wait_for_bite(timeout := 12.0) -> bool:
	if not await wait_until(func() -> bool: return prompt().begins_with("Biss!"), timeout):
		return false
	await press("interact")
	return true


## The coast's people come to work: at 15:00 the vendors and the hosts are at their posts.
func test_people_at_their_posts() -> void:
	Clock.set_time(9.5)
	await coast()
	Clock.set_time(15.5)
	for a in world.actors:
		if a.home_region == "coast" and a.brain:
			UI.game.place_by_schedule(a)
	await wait(20.0)
	var away: Array[String] = []
	for id: String in ["uwe", "giulia", "inge", "soenke", "piet", "ole", "hinnerk", "svenja", "fietje", "klaus"]:
		var p := present(id)
		var post := (p.brain as HumanBrain).work_pos()
		if p.inside or post == Vector3.INF or p.global_position.distance_to(post) > 15.0:
			away.append(id)
	check(away.size() <= 1, "at their posts (away: %s)" % str(away))
	await put_player(_v(Vector2(-60, 106)), _v(Vector2(-40, 100)))
	await shot("coast_stands")


## On the pier head with a rod: "Angeln", wait for the bite, reel in: a sea fish (or the old
## boot); too early costs the try.
func test_fishing_on_the_pier() -> void:
	await coast()
	var a := player()
	a.add_item("fishing_rod")
	var spots := _spots("fishing")
	check(spots.size() >= 8, "%d fishing places at the coast" % spots.size())
	var pier: Dictionary = spots.filter(func(s: Dictionary) -> bool: return s.get("catch", "") == "pier")[0]
	await put_player(pier["pos"], pier["face"])
	await wait(0.4)
	check(prompt() == "Angeln", "prompt to fish (%s)" % prompt())
	await press("interact")
	check(prompt().begins_with("Angeln …"), "waiting for a bite (%s)" % prompt())
	await press("interact")
	check(toasted("Zu früh"), "too early: nothing")
	var got := []
	for i in 4:
		await wait(0.3)
		await press("interact")
		var before := a.inventory.duplicate()
		check(await _wait_for_bite(), "a bite comes (try %d)" % i)
		for id: String in Gathering.CATCH["pier"]:
			if a.inventory.get(id, 0) > before.get(id, 0):
				got.append(id)
	check(got.size() == 4, "four catches from the pier's table (%s)" % str(got))
	check(not a.has_item("fish"), "no trout in the sea")
	check(GameState.stat("fish_caught") >= 4, "counted")
	await shot("coast_fishing_pier")


## The surf rod (tier 2) bites sooner than the simple rod.
func test_surf_rod_bites_sooner() -> void:
	await coast()
	var a := player()
	var pier: Dictionary = _spots("fishing")[0]
	var waits := {}
	for rod: String in ["fishing_rod", "sea_rod"]:
		a.inventory.erase("fishing_rod")
		a.inventory.erase("sea_rod")
		a.add_item(rod)
		var total := 0.0
		for i in 6:
			await put_player(pier["pos"], pier["face"])
			Gameplay.gathering.start(a, pier)
			total += float(Gameplay.gathering.fishing["bite_in"])
			Gameplay.gathering.fishing = {}
		waits[rod] = total / 6.0
	check(waits["sea_rod"] < waits["fishing_rod"] - 1.0, "bites sooner: %.1f s against %.1f s" % [waits["sea_rod"], waits["fishing_rod"]])


## From a rowing boat lying still on the open water: "Angeln" while sitting, a bite, a fish of the
## deep bay; the angler stays in the boat.
func test_fishing_from_a_rowboat() -> void:
	var c := await coast()
	c.moor_boats()
	var boat := c.boats[5]
	game.player.enter_car(boat)
	await frames(3)
	boat.place(Vector2(40, 215), 0.0)
	await wait(0.4)
	check(prompt() == "Angeln – dafür brauchst du eine Angel", "needs a rod (%s)" % prompt())
	var a := player()
	a.add_item("fishing_rod")
	await wait(0.3)
	check(prompt() == "Angeln", "prompt to fish from the boat (%s)" % prompt())
	await press("interact")
	var before := a.inventory.duplicate()
	check(await _wait_for_bite(), "a bite")
	var got := ""
	for id: String in Gathering.CATCH["boat"]:
		if a.inventory.get(id, 0) > before.get(id, 0):
			got = id
	check(got != "", "caught a fish of the deep bay (%s)" % got)
	check(a.vehicle == boat, "still sitting in the boat")
	await shot("coast_fishing_boat", {"boat": boat.global_position + Vector3(0, 1, 0)})
	game.player.exit_car(true)
	c.moor_boats()


## Shells along the water's edge: "Muscheln sammeln" gives two, the spot is gone for a day;
## now and then a piece of amber.
func test_shells_and_amber() -> void:
	await coast()
	var a := player()
	var spots := _spots("shells")
	check(spots.size() >= 10, "%d places with shells" % spots.size())
	var s: Dictionary = spots[0]
	await put_player(s["pos"] + Vector3(0.8, 0, 0), s["pos"])
	await wait(0.4)
	check(prompt() == "Muscheln sammeln", "prompt (%s)" % prompt())
	await press("interact")
	check(await wait_until(func() -> bool: return a.inventory.get("shell", 0) >= 2, 5.0), "two shells in the bag")
	check(not Gameplay.gathering.is_ready(s), "the spot regrows")
	var amber := 0
	Gameplay.gathering.rng.seed = 5
	for i in 60:
		amber += int(Gameplay.gathering._yields(s, 1).get("amber", 0))
	check(amber >= 3 and amber <= 15, "amber now and then (%d in 60)" % amber)


## The stands open with their vendors; a Fischbrötchen, a Spaghettieis and a Kokos-Shake.
func test_stands_sell_food() -> void:
	await coast()
	Clock.set_time(14.0)
	GameState.money = 3000
	for f: Array in [["coast_fish", "fish_roll"], ["coast_ice", "spaghetti_ice"], ["coast_bar", "coconut_shake"]]:
		var spent := await buy(f[0], f[1])
		check_eq(spent, int(Food.ITEMS[f[1]]["price"]), "%s costs its price" % f[1])
		UI.close_dialog("")
	await shot("coast_beach_bar")


## Who buys what: Gesche at the cutter buys every fish (a lobster is worth a lot) and sells the
## surf rod; Uwe buys herring; Sönke buys shells and amber; the kiosk sells a rod; Räucher-Fiete
## at the castle takes sea fish too.
func test_who_buys_what() -> void:
	await coast()
	Clock.set_time(11.0)
	var a := player()
	a.add_item("lobster", 1)
	a.add_item("cod", 2)
	a.add_item("amber", 1)
	a.add_item("shell", 6)
	await open_shop("coast_cutter")
	await at_shop("coast_cutter")
	check(prompt().begins_with("Handeln"), "trade at the cutter (%s)" % prompt())
	var money := GameState.money
	await _trade("Verkaufen: Hummer")
	check_eq(GameState.money - money, Items.value("lobster"), "Gesche pays 15 € for the lobster")
	await _trade("Verkaufen: Dorsch")
	check(not a.has_item("cod"), "and buys the cod")
	GameState.money = 2000
	await _trade("Kaufen: Brandungsangel")
	check(a.has_item("sea_rod"), "the surf rod bought")
	await open_shop("coast_souvenirs")
	await at_shop("coast_souvenirs")
	money = GameState.money
	await _trade("Verkaufen: Bernstein")
	check_eq(GameState.money - money, Items.value("amber"), "Sönke pays 6 € for the amber")
	await _trade("Verkaufen: Muschel")
	check(not a.has_item("shell"), "and takes the shells")
	check(Shop.SHOPS["coast_kiosk"]["goods"].has("fishing_rod"), "the kiosk sells rods")
	check("herring" in Shop.SHOPS["coast_fish"]["buys"] and "mackerel" in Shop.SHOPS["burg_fish"]["buys"],
		"Uwe and Räucher-Fiete buy sea fish")
