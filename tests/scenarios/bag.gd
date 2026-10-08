extends Scenario
## The bag ("Rucksack"): opening it, eating from it, throwing things away, a full bag,
## the storage chest at the lumber camp, and every character keeping their own things.


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


func test_throw_away() -> void:
	player().add_item("twig", 4)
	await press("bag")
	await click_at(_tile("twig").get_global_rect().get_center())
	await click_button("Wegwerfen")
	check_eq(int(player().inventory.get("twig", 0)), 3, "one twig thrown away")
	UI.close_screens()


func test_bag_full() -> void:
	var a := player()
	for id: String in ["twig", "log", "stone", "ore", "board", "slab", "berries", "apple", "mushroom", "fish", "carving", "birdhouse"]:
		a.add_item(id, Items.stack_size(id))
	check_eq(Items.slots_used(a.inventory), 12, "twelve full slots")
	check_eq(a.add_item("gem"), 0, "a full bag takes nothing new")
	check(toasted("Rucksack ist voll"), "toast: bag full")
	a.take_item("apple", 1)
	check_eq(a.add_item("apple", 3), 1, "a stack with room takes only what fits")
	a.add_item("big_bag")  # replaces nothing: needs a free slot itself
	check_eq(a.bag_slots(), 12, "no room for the big bag either")
	a.take_item("carving", Items.stack_size("carving"))
	a.add_item("big_bag")
	check_eq(a.bag_slots(), 18, "the dwarf bag gives six more slots")


func test_storage_chest() -> void:
	var a := player()
	a.add_item("log", 7)
	var chest: Interactable = spots_with_prompt("Lagerkiste")[0]
	await put_player(chest.global_position + Vector3(0, 0, 1.6), chest.global_position)
	await wait(0.3)
	check(prompt().contains("Lagerkiste"), "prompt at the chest (%s)" % prompt())
	await press("interact")
	check(_bag().visible and _bag().chest_box.visible, "the chest opens next to the bag")
	await click_at(_tile("log").get_global_rect().get_center())
	check(not a.has_item("log") and int(GameState.storage.get("log", 0)) == 7, "logs moved into the chest")
	await shot("chest")
	await click_at(_tile("log", true).get_global_rect().get_center())
	check_eq(int(a.inventory.get("log", 0)), 7, "logs taken back")
	UI.close_screens()


## Every character has their own bag; switching does not move things.
func test_own_bag_per_character() -> void:
	var jens := player()
	jens.add_item("stone", 5)
	var herbert := present("herbert")
	herbert.teleport(jens.global_position + Vector3(2, 0, 0))
	game.player.control(herbert)
	await frames(2)
	check(not herbert.has_item("stone"), "Herbert does not have Jens' stones")
	herbert.add_item("berries", 2)
	game.player.control(jens)
	check(jens.has_item("stone") and not jens.has_item("berries"), "Jens keeps his own things")


func test_bag_saved() -> void:
	player().add_item("gem", 2)
	GameState.storage["board"] = 4
	GameState.save_game()
	player().inventory.clear()
	GameState.storage.clear()
	GameState.load_game()
	player().load_state()
	check_eq(int(player().inventory.get("gem", 0)), 2, "bag restored from the save")
	check_eq(int(GameState.storage.get("board", 0)), 4, "chest restored from the save")
	check(player().inventory["gem"] is int, "counts are whole numbers after loading")
