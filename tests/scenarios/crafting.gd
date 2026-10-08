extends Scenario
## Workbench and campfire at the lumber camp: recipes, missing ingredients, cooking, and
## the whole loop from twigs and stones to the first axe and boards.


func _station(node_name: String) -> Interactable:
	return world.get_node(node_name) as Interactable


func _open(node_name: String) -> void:
	var st := _station(node_name)
	await put_player(st.global_position + Vector3(0, 0, 1.2), st.global_position)
	await wait(0.3)
	await press("interact")


func _make(id: String) -> bool:
	var b := UI.craft_screen.list.find_child("Make_" + id, true, false) as Button
	if b == null or b.disabled:
		return false
	await click_at(b.get_global_rect().get_center())
	return true


func test_workbench_stone_axe() -> void:
	var a := player()
	a.add_item("twig", 3)
	a.add_item("stone", 1)
	await _open("Workbench")
	check(UI.craft_screen.visible and UI.craft_screen.title.text.begins_with("Werkbank"), "the workbench opens")
	check(not await _make("stone_axe"), "one stone is not enough for the stone axe")
	await shot("workbench", {})
	UI.close_screens()
	a.add_item("stone", 1)
	await _open("Workbench")
	check(await _make("stone_axe"), "the button is enabled now")
	check(a.has_item("stone_axe") and not a.has_item("twig") and not a.has_item("stone"), "axe made, ingredients used")
	UI.close_screens()


func test_campfire_cooking() -> void:
	var a := player()
	a.add_item("fish", 1)
	a.add_item("twig", 1)
	a.add_item("mushroom", 3)
	await _open("Campfire")
	check(UI.craft_screen.title.text.begins_with("Lagerfeuer"), "the campfire opens")
	check(await _make("grilled_fish"), "grill the fish")
	check(await _make("mushroom_pan"), "fry the ceps")
	await shot("campfire", {})
	check(a.has_item("grilled_fish") and a.has_item("mushroom_pan") and not a.has_item("fish"), "cooked food in the bag")
	UI.close_screens()


## From nothing to boards: pick up twigs and stones, make an axe, fell a tree, saw boards.
func test_first_axe_loop() -> void:
	var a := player()
	var g := Gameplay.gathering
	var need := {"twigs": 1, "pebbles": 1}
	for kind: String in need:
		for s: Dictionary in g.spots:
			if s["kind"] == kind and g.is_ready(s):
				await put_player(s["pos"] + Vector3(1.0, 0, 0.3), s["pos"])
				await wait(0.3)
				await press("interact")
				await wait_until(func() -> bool: return g.job.is_empty(), 10.0)
				break
	check(int(a.inventory.get("twig", 0)) >= 3 and int(a.inventory.get("stone", 0)) >= 2, "twigs and stones gathered by hand")
	await _open("Workbench")
	check(await _make("stone_axe"), "first axe")
	UI.close_screens()
	var tree: Dictionary = {}
	for s: Dictionary in g.spots:
		if s["kind"] == "tree" and g.is_ready(s) and s["pos"].distance_to(player().global_position) < 40.0:
			tree = s
			break
	await put_player(tree["pos"] + Vector3(1.3, 0, 0.3), tree["pos"])
	await wait(0.3)
	await press("interact")
	await wait_until(func() -> bool: return g.job.is_empty(), 15.0)
	check(a.has_item("log"), "logs from the first tree")
	await _open("Workbench")
	check(await _make("board"), "a board from a log")
	UI.close_screens()


func test_no_room_for_result() -> void:
	var a := player()
	for id: String in ["twig", "log", "stone", "ore", "board", "slab", "berries", "apple", "mushroom", "fish", "carving", "gem"]:
		a.add_item(id, Items.stack_size(id))
	check(not Crafting.craft(a, "birdhouse"), "no room for a birdhouse")
	check(toasted("Rucksack ist voll"), "says so")
	a.take_item("slab", 3)
	check(Crafting.craft(a, "slab"), "a slab fits on its stack when it has room")
