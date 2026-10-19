extends Scenario
## Herbs, potions, smithy and the market of the Ritterburg (doc/burg.md, phase 2): where the
## herbs grow, picking them, brewing at the herb witch and the alchemist, the potions' effects
## (and that they are saved), forging, the market's food and who buys what.


func _herb_spots(item: String) -> Array:
	return Gameplay.gathering.spots.filter(func(s: Dictionary) -> bool: return s.get("item", "") == item)


## Talks to a master of the castle at work and opens what they make.
func _order(npc_id: String, option: String) -> void:
	Clock.set_time(14.0)
	var shop_id: String = {"walburga": "burg_witch", "quirin": "burg_alchemist"}.get(npc_id, "")
	if shop_id != "":
		await open_shop(shop_id)
	else:
		var npc := present(npc_id)
		npc.teleport((npc.brain as HumanBrain).work_pos())
		npc.brain.suspend()
		await wait(0.5)
	await next_to(npc_id)
	await press("talk")
	await wait(0.3)
	check(await choose(option), "%s offers '%s' (options %s)" % [npc_id, option, str(dialog_options())])
	await wait(0.3)


func test_herbs_grow_in_every_area() -> void:
	await fair()
	await burg()
	var want := {"chamomile": 4, "elder": 5, "woodruff": 6, "wild_garlic": 6, "lavender": 4, "st_johns_wort": 6, "rose_hip": 4}
	var area := {"chamomile": "park", "woodruff": "park", "wild_garlic": "park", "lavender": "fair", "st_johns_wort": "burg", "rose_hip": "burg"}
	for item: String in want:
		var spots := _herb_spots(item)
		check(spots.size() >= want[item], "%d spots of %s" % [spots.size(), item])
		for s: Dictionary in spots:
			var p: Vector3 = s["pos"]
			if area.has(item):
				check(World.area_of(p) == area[item], "%s %s in the %s" % [item, s["id"], area[item]])
			check(world.nav.nearest_open(Vector2(p.x, p.z), ParkMap.Nav.HUMAN, 3).x >= 0, "%s reachable" % s["id"])
	var park_woodruff := _herb_spots("woodruff").filter(func(s: Dictionary) -> bool: return s["pos"].z < ParkLayout.FOREST_EDGE)
	check(park_woodruff.size() == _herb_spots("woodruff").size(), "woodruff grows in the Nordwald")


## Picking: two of a herb, the spot regrows after a day; with the Kräutertrank four.
func test_picking_herbs() -> void:
	var s: Dictionary = _herb_spots("chamomile")[0]
	GameState.gather.erase(s["id"])
	Gameplay.gathering.show_spot(s, true)
	var p: Vector3 = s["pos"]
	await put_player(p + Vector3(1.0, 0, 0), p)
	await wait(0.3)
	check(prompt() == "Kamille pflücken", "prompt (%s)" % prompt())
	var before := int(player().inventory.get("chamomile", 0))
	await press("interact")
	check(await wait_until(func() -> bool: return int(player().inventory.get("chamomile", 0)) > before, 5.0), "picked")
	check(int(player().inventory.get("chamomile", 0)) == before + 2, "two pieces")
	check(not Gameplay.gathering.is_ready(s), "the spot regrows")
	check(GameState.sets.get("herbs_picked", {}).has("chamomile"), "counted for Kräuterkundig")
	# With the Kräutertrank: four.
	player().add_item("potion_herbs")
	check(Potions.drink(player(), "potion_herbs"), "drinks the Kräutertrank")
	var s2: Dictionary = _herb_spots("chamomile")[1]
	GameState.gather.erase(s2["id"])
	Gameplay.gathering.show_spot(s2, true)
	var p2: Vector3 = s2["pos"]
	await put_player(p2 + Vector3(1.0, 0, 0), p2)
	await wait(0.3)
	before = int(player().inventory.get("chamomile", 0))
	await press("interact")
	check(await wait_until(func() -> bool: return int(player().inventory.get("chamomile", 0)) > before, 5.0), "picked again")
	check(int(player().inventory.get("chamomile", 0)) == before + 4, "four with the Kräutertrank")
	GameState.buffs.clear()


## Brewing at Walburga: the ingredients and 1 € for the Lauftrank; nothing without ingredients.
func test_brewing_at_the_witch() -> void:
	await burg()
	var a := player()
	for item: String in ["woodruff", "chamomile", "berries", "st_johns_wort", "wild_garlic", "elder"]:
		if a.has_item(item):
			a.take_item(item, int(a.inventory[item]))
	await _order("walburga", "Einen Trank brauen lassen")
	check(UI._modal == "craft" and UI.craft_screen.station == "witch", "the witch's brewing opens")
	check(find_button("Brauen lassen") != null and find_button("Brauen lassen").disabled, "nothing to brew without herbs")
	UI.close_screens()
	a.add_item("woodruff", 2)
	a.add_item("chamomile", 2)
	a.add_item("berries", 2)
	GameState.add_money(500)
	await _order("walburga", "Einen Trank brauen lassen")
	var money := GameState.money
	var b := UI.craft_screen.find_child("Make_potion_speed", true, false) as Button
	check(b != null and not b.disabled, "the Lauftrank can be brewed")
	b.pressed.emit()
	await frames(2)
	check(int(a.inventory.get("potion_speed", 0)) == 1, "a Lauftrank in the bag")
	check(money - GameState.money == 100, "brewing cost 1 € (%d)" % (money - GameState.money))
	check(not a.has_item("woodruff") and not a.has_item("chamomile"), "the herbs are used")
	check(GameState.sets.get("potions_brewed", {}).has("potion_speed"), "counted for Braumeister")
	UI.close_screens()
	# Quirin brews the Abbautrank and buys potions for 8 €.
	a.add_item("rose_hip", 2)
	a.add_item("lavender", 2)
	a.add_item("ore", 1)
	await _order("quirin", "Einen Trank brauen lassen")
	var m := UI.craft_screen.find_child("Make_potion_mining", true, false) as Button
	check(m != null and not m.disabled, "Quirin brews the Abbautrank")
	m.pressed.emit()
	await frames(2)
	check(a.has_item("potion_mining"), "an Abbautrank in the bag")
	UI.close_screens()
	var shop: Shop = world.shops["burg_alchemist"]
	check(shop.buys.has("potion_speed") and int(Items.value("potion_speed") * shop.buy_rate) == 800, "Quirin pays 8 € for a potion")


## The Lauftrank: 50 % faster, running doesn't tire; it ends after 8 game hours. Saved.
func test_speed_potion() -> void:
	GameState.buffs.clear()
	var a := player()
	var normal := a.current_speed()
	a.add_item("potion_speed")
	UI.open_bag()
	await frames(2)
	UI.bag_screen.selected = "potion_speed"
	UI.bag_screen.refresh()
	check(await click_button("Trinken"), "Trinken in the bag")
	check(Potions.active("speed"), "the Lauftrank works")
	check(absf(a.current_speed() / normal - 1.5) < 0.01, "50 %% faster (%.2f)" % (a.current_speed() / normal))
	check(UI.hud.potion_label.visible and UI.hud.potion_label.text.contains("Lauftrank"), "the HUD shows it (%s)" % UI.hud.potion_label.text)
	a.needs.fatigue = 30.0
	await put_player(place("great_meadow"))
	Input.action_press("move_forward")
	Input.action_press("run")
	await wait(4.0)
	Input.action_release("run")
	Input.action_release("move_forward")
	check(a.needs.fatigue <= 30.01, "running did not tire (%.2f)" % a.needs.fatigue)
	# Saved and loaded.
	var ends: float = GameState.buffs["speed"]
	GameState.save_game()
	GameState.buffs.clear()
	GameState.load_game()
	check(absf(float(GameState.buffs.get("speed", 0.0)) - ends) < 0.01, "the potion's time is saved")
	Clock.advance(8 * 60 + 5)
	await frames(2)
	check(not Potions.active("speed"), "it ends after 8 hours")
	check(absf(a.current_speed() - normal) < 0.01, "normal speed again")
	GameState.buffs.clear()


## The Abbautrank: mining goes twice as fast.
func test_mining_potion() -> void:
	GameState.buffs.clear()
	var a := player()
	a.add_item("stone_pickaxe")
	var rock: Dictionary = Gameplay.gathering.spots.filter(func(s: Dictionary) -> bool: return s["kind"] == "rock")[0]
	GameState.gather.erase(rock["id"])
	Gameplay.gathering.show_spot(rock, true)
	await put_player(rock["pos"] + Vector3(1.6, 0, 0), rock["pos"])
	check(Gameplay.gathering.start(a, rock), "mining starts")
	var slow: float = Gameplay.gathering.job["step"]
	Gameplay.gathering.job = {}
	GameState.buffs["mining"] = Gathering.now() + 8.0
	check(Gameplay.gathering.start(a, rock), "mining starts again")
	check(absf(Gameplay.gathering.job["step"] - slow * 0.5) < 0.001, "twice as fast with the Abbautrank")
	Gameplay.gathering.job = {}
	GameState.buffs.clear()
	a.anim = "idle"


## The smithy forges a horseshoe from ore for 50 cents.
func test_smithy() -> void:
	await burg()
	var a := player()
	a.add_item("ore", 1)
	GameState.add_money(200)
	await _order("brunhild", "Etwas schmieden lassen")
	check(UI._modal == "craft" and UI.craft_screen.station == "smithy", "the smithy opens")
	var b := UI.craft_screen.find_child("Make_horseshoe", true, false) as Button
	check(b != null and not b.disabled, "a horseshoe can be forged")
	var money := GameState.money
	b.pressed.emit()
	await frames(2)
	check(a.has_item("horseshoe") and money - GameState.money == 50, "a horseshoe for 0,50 €")
	UI.close_screens()


## The market: stew at the tavern, smoked fish at Fiete's; Fiete buys trout.
func test_market_food() -> void:
	await burg()
	Clock.set_time(13.0)
	GameState.add_money(2000)
	var spent := await buy("burg_tavern", "stew_bread")
	check(spent == Food.ITEMS["stew_bread"]["price"], "stew in bread for %d" % spent)
	spent = await buy("burg_fish", "smoked_fish")
	check(spent == Food.ITEMS["smoked_fish"]["price"], "smoked fish for %d" % spent)
	check(world.shops["burg_fish"].buys.has("fish"), "Fiete buys trout")


func test_achievements() -> void:
	for item: String in ["chamomile", "elder", "woodruff", "wild_garlic", "lavender", "st_johns_wort", "rose_hip", "berries"]:
		GameState.add_to_set("herbs_picked", item)
	check(GameState.is_unlocked("herbalist"), "Kräuterkundig")
	for item: String in ["potion_speed", "potion_herbs", "potion_mining"]:
		GameState.add_to_set("potions_brewed", item)
	check(GameState.is_unlocked("brewmaster"), "Braumeister")
