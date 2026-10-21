extends Scenario
## The bag ("Rucksack"): opening it, eating from it, throwing things away, a full and an
## overfull bag, the storage chest at the lumber camp, and the bag being the player's.


func _bag() -> BagScreen:
	return UI.bag_screen


func _tile(id: String, in_chest := false) -> Button:
	var grid: GridContainer = _bag().chest_grid if in_chest else _bag().bag_grid
	return grid.find_child("Item_" + id, false, false) as Button


func test_open_with_key_and_button() -> void:
	player().add_item("bread", 3)
	await press("bag")
	check(_bag() != null and _bag().visible, "I opens the bag")
	check(_tile("bread") != null, "the bread has a tile")
	check(_bag().capacity.text.begins_with("1 / 12"), "capacity shows 1 of 12 slots (%s)" % _bag().capacity.text)
	await shot("bag_bread")
	await press("bag")
	check(not _bag().visible, "I closes it again")
	await click_button("Rucksack")
	check(_bag().visible, "the HUD button opens the bag")
	UI.close_screens()


func _trait(name: String) -> String:
	var g := _bag().stats_grid
	for i in range(0, g.get_child_count() - 1, 2):
		if (g.get_child(i) as Label).text == name:
			return (g.get_child(i + 1) as Label).text
	return ""


## With nothing selected the bag shows the character's traits: Jens runs fast and tires
## twice as fast, Herbert is slow and his mood sinks slowly, a duck swims; a Lauftrank is
## listed while it runs. Tapping an item hides them.
func test_character_traits() -> void:
	var a := player()
	a.needs.hunger = 42.0
	a.add_item("apple")
	await press("bag")
	check(_bag().stats.visible and _bag().stats_title.text == "Eigenschaften von Jogger Jens", "traits shown (%s)" % _bag().stats_title.text)
	check_eq(_trait("Renntempo"), "×1,4", "Jens runs fast")
	check_eq(_trait("Wird müde"), "×2", "Jens tires twice as fast")
	check_eq(_trait("Wird hungrig"), "×1,1", "Jens' hunger")
	check_eq(_trait("Schwimmen"), "nein", "Jens doesn't swim")
	check(_trait("Gerade").contains("Hunger 42 %"), "needs right now (%s)" % _trait("Gerade"))
	check_eq(_trait("Lauftrank"), "", "no Lauftrank")
	await shot("bag_traits")
	await click_at(_tile("apple").get_global_rect().get_center())
	check(not _bag().stats.visible, "an item hides the traits")
	UI.close_screens()
	var herbert := present("herbert")
	herbert.teleport(a.global_position + Vector3(2, 0, 0))
	game.player.control(herbert)
	await frames(2)
	GameState.buffs["speed"] = Gathering.now() + 2.0
	await press("bag")
	check_eq(_trait("Gehtempo"), "×0,7", "Herbert walks slowly")
	check_eq(_trait("Laune sinkt"), "×0,7", "Herbert's mood sinks slowly")
	check(_trait("Lauftrank").begins_with("Tempo ×1,5, noch 2 h"), "the Lauftrank (%s)" % _trait("Lauftrank"))
	UI.close_screens()
	GameState.buffs.erase("speed")
	var duck := BagScreen.traits(world.find_actor("frieda"))
	check(duck.any(func(r: Array) -> bool: return r[0] == "Schwimmen" and r[1] == "ja"), "a duck swims")


func test_eat_from_bag() -> void:
	var a := player()
	a.needs.hunger = 70.0
	a.add_item("apple", 2)
	await press("bag")
	await click_at(_tile("apple").get_global_rect().get_center())
	check(_bag().detail_name.text == "Apfel", "tapping a tile shows the item (%s)" % _bag().detail_name.text)
	await shot("bag_apple")
	await click_button("Essen")
	check(not _bag().visible, "eating closes the bag")
	await wait(4.5)
	check(a.needs.hunger < 70.0 - 8.0, "the apple filled the stomach (%.0f)" % a.needs.hunger)
	check_eq(int(a.inventory.get("apple", 0)), 1, "one apple left")


func test_eat_two_in_a_row() -> void:
	var a := player()
	a.needs.hunger = 80.0
	a.add_item("apple", 2)
	for i in 2:
		await press("bag")
		await click_at(_tile("apple").get_global_rect().get_center())
		await click_button("Essen")
		await wait(0.5)
	await wait(4.5)
	var two: float = 2.0 * Food.ITEMS["apple"]["hunger"]
	check(a.needs.hunger < 80.0 - two + 2.0, "the second apple does not swallow the first (%.0f)" % a.needs.hunger)
	check_eq(int(a.inventory.get("apple", 0)), 0, "both apples eaten")


func test_throw_away() -> void:
	player().add_item("twig", 4)
	await press("bag")
	await click_at(_tile("twig").get_global_rect().get_center())
	await click_button("Wegwerfen")
	check_eq(int(player().inventory.get("twig", 0)), 3, "one twig thrown away")
	UI.close_screens()


func _fill_twelve(a: Actor) -> void:
	for id: String in ["twig", "log", "stone", "ore", "board", "slab", "berries", "apple", "mushroom", "fish", "carving", "birdhouse"]:
		a.add_item(id, Items.stack_size(id))


## A full bag refuses what the player chooses to take (buying, picking up).
func test_bag_full() -> void:
	var a := player()
	_fill_twelve(a)
	check_eq(Items.slots_used(a.inventory), 12, "twelve full slots")
	check(not a.overfull(), "full, not overfull")
	check(not a.room_for("gem"), "no room for something new")
	check(toasted("Rucksack ist voll"), "toast: bag full")
	a.take_item("apple", 1)
	check_eq(a.room("apple"), 1, "a stack with room takes one more apple")
	check(not a.room_for("big_bag"), "no room for the big bag either")
	a.take_item("carving", Items.stack_size("carving"))
	a.add_item("big_bag")
	check_eq(a.bag_slots(), 18, "the dwarf bag gives six more slots")


## A haul bigger than the room left loses nothing: the bag gets overfull, and the player
## stands still (on foot and by tap) with a clear message until something is gone.
func test_overfull_bag_holds_the_player() -> void:
	var a := player()
	_fill_twelve(a)
	toasts.clear()
	check_eq(a.add_item("gem", 2), 2, "the gems go in anyway")
	check(a.overfull() and Items.slots_used(a.inventory) == 13, "overfull: 13 of 12 slots")
	check(toasted("übervoll (13 / 12 Plätze)"), "toast says why (%s)" % str(toasts))
	var start := a.global_position
	toasts.clear()
	await hold("move_forward", 1.0)
	check(a.global_position.distance_to(start) < 0.2, "can't walk (moved %.1f m)" % a.global_position.distance_to(start))
	check(toasted("sonst kommst du nicht vom Fleck"), "walking says why")
	await click_at(get_viewport().get_visible_rect().size * Vector2(0.5, 0.35))
	await wait(1.0)
	check(a.global_position.distance_to(start) < 0.2, "tap to walk doesn't walk either")
	check(UI.hud.inventory_label.text.begins_with("Übervoll!"), "the HUD says so (%s)" % UI.hud.inventory_label.text)
	await press("bag")
	check(_bag().capacity.text.contains("übervoll"), "the bag says so (%s)" % _bag().capacity.text)
	check(_tile("gem") != null, "the gems have a tile")
	await shot("bag_overfull")
	await click_at(_tile("twig").get_global_rect().get_center())
	for i in Items.stack_size("twig"):
		await click_button("Wegwerfen")
	UI.close_screens()
	check(not a.overfull(), "twigs thrown away: not overfull any more")
	await hold("move_forward", 1.0)
	check(a.global_position.distance_to(start) > 1.0, "walks again")


func test_storage_chest() -> void:
	var a := player()
	a.add_item("log", 27)
	a.add_item("fishing_rod", 2)
	var chest: Interactable = spots_with_prompt("Lagerkiste")[0]
	await put_player(chest.global_position + Vector3(0, 0, 1.6), chest.global_position)
	await wait(0.3)
	check(prompt().contains("Lagerkiste"), "prompt at the chest (%s)" % prompt())
	await press("interact")
	check(_bag().visible and _bag().chest_box.visible, "the chest opens next to the bag")
	# One tap moves one slot: a full stack of 20 logs, one rod.
	await click_at(_tile("log").get_global_rect().get_center())
	check_eq(int(a.inventory.get("log", 0)), 7, "one stack of logs left the bag")
	check_eq(int(GameState.storage.get("log", 0)), 20, "one stack of logs in the chest")
	await click_at(_tile("fishing_rod").get_global_rect().get_center())
	check_eq(int(a.inventory.get("fishing_rod", 0)), 1, "one rod left the bag")
	check_eq(int(GameState.storage.get("fishing_rod", 0)), 1, "one rod in the chest")
	await click_at(_tile("log").get_global_rect().get_center())
	check(not a.has_item("log") and int(GameState.storage.get("log", 0)) == 27, "the rest of the logs moved")
	await shot("chest")
	# The chest shows stacks too; a tap takes one of them back.
	await click_at(_tile("log", true).get_global_rect().get_center())
	check_eq(int(a.inventory.get("log", 0)), 20, "one stack of logs taken back")
	check_eq(int(GameState.storage.get("log", 0)), 7, "the rest stays in the chest")
	await click_at(_tile("fishing_rod", true).get_global_rect().get_center())
	check_eq(int(a.inventory.get("fishing_rod", 0)), 2, "the rod taken back")
	check(not GameState.storage.has("fishing_rod"), "no rod left in the chest")
	UI.close_screens()


## The bag is the player's: it goes with every switch, and what the new character carried
## (bread for the ducks) is added. The character left behind keeps nothing.
func test_bag_goes_along() -> void:
	var jens := player()
	jens.add_item("stone", 5)
	jens.add_item("teddy")
	var herbert := present("herbert")
	herbert.teleport(jens.global_position + Vector3(2, 0, 0))
	herbert.inventory = {"bread": 6}
	game.player.control(herbert)
	await frames(2)
	check(herbert.has_item("stone") and herbert.has_item("teddy"), "Herbert has the stones and the teddy")
	check_eq(int(herbert.inventory.get("bread", 0)), 6, "and his own bread")
	check(jens.inventory.is_empty(), "Jens keeps nothing")
	check(is_same(herbert.inventory, GameState.inventory), "the bag is the player's")
	game.player.control(jens)
	check(jens.has_item("stone") and jens.has_item("bread") and herbert.inventory.is_empty(), "back to Jens with everything")


## Switching to someone whose things don't fit makes the bag overfull; the question says so.
func test_switch_into_an_overfull_bag() -> void:
	var jens := player()
	_fill_twelve(jens)
	var herbert := present("herbert")
	herbert.teleport(jens.global_position + jens.forward() * 3.0)
	herbert.brain.suspend()
	herbert.inventory = {"bread": 6}
	await frames(3)
	UI.confirm_switch(herbert)
	await frames(2)
	check(dialog_text().contains("übervoll"), "the question warns (%s)" % dialog_text())
	await choose("Wechseln")
	check(player() == herbert and herbert.overfull(), "playing Herbert, bag overfull")
	check(toasted("übervoll"), "toast says why")


func test_bag_saved() -> void:
	player().add_item("gem", 2)
	GameState.storage["board"] = 4
	GameState.save_game()
	player().inventory.clear()
	GameState.storage.clear()
	GameState.load_game()
	check(is_same(player().inventory, GameState.inventory), "still the same bag after loading")
	check_eq(int(player().inventory.get("gem", 0)), 2, "bag restored from the save")
	check_eq(int(GameState.storage.get("board", 0)), 4, "chest restored from the save")
	check(player().inventory["gem"] is int, "counts are whole numbers after loading")
