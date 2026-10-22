extends Scenario
## The Ritterburg (doc/burg.md): its ground, walls and ways, the gates from the Westpark and the
## Nordwald (split and not split), its people at their posts, the secret passage to the
## dwarves' mine, the map.

const GATE_S := Vector3(-260, 0, -90)
const GATE_E := Vector3(-130, 0, -200)


func _init() -> void:
	start_areas = "all"   # the gates load the castle on the way; split tests ask for it


func _split(on: bool) -> void:
	GameState.settings["areas"] = "split" if on else "all"
	await world.set_split(on)
	await frames(2)


func _in(id: String) -> bool:
	return world.player_area == id and not world.switching and not world.loading()


func _v(p: Vector2) -> Vector3:
	return Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)


## The hill: the inner square 7 m and the top 9 m up; everything on the ways reachable from the
## Westpark's gate; the walls and the rock solid.
func test_ground_ways_and_walls() -> void:
	await burg()
	var m := world.map
	check(m.height_at(-265, -214) > 6.5 and m.height_at(-265, -250) > 8.5, "square %.1f m, top %.1f m" % [m.height_at(-265, -214), m.height_at(-265, -250)])
	check(absf(m.height_at(-260, -91) - m.height_at(-260, -89)) < 0.3, "no step at the Westpark's gate")
	check(absf(m.height_at(-131, -200) - m.height_at(-129, -200)) < 0.3, "no step at the Nordwald's gate")
	var from := _v(BurgLayout.GATE_SOUTH + Vector2(0, -2))
	for id: String in ["gatehouse", "tavern", "square", "inner_gate", "exhibition", "tower", "herb_witch", "alchemist", "smithy",
			"paddock", "sword_ring", "archery", "herb_slope", "hedges", "passage"]:
		var p := BurgLayout.place(id)
		var c := world.nav.nearest_open(p)
		var path := world.nav.find_path(from, _v(ParkMap.cell_center(c)))
		check(not path.is_empty() and path[path.size() - 1].distance_to(_v(p)) < BurgLayout.PLACES[id]["r"] + 6.0,
			"%s reachable from the gate" % id)
	check(m.is_solid(Vector2(-300, BurgLayout.WALL_S)) and m.is_solid(Vector2(-346, -190)) and m.is_solid(Vector2(-326, -157)),
		"the outer wall (south, west, the slanting corner) is solid")
	var arc := BurgLayout.INNER_C + Vector2(cos(PI * 0.62), sin(PI * 0.62)) * BurgLayout.INNER_R
	check(m.is_solid(arc), "the inner wall is solid")
	check(m.is_solid(Vector2(-265, -250)) and m.is_solid(Vector2(-300, -252)), "the mountain's rock is solid")
	check(m.is_solid(Vector2(-200, -90)) and m.is_solid(Vector2(-130, -150)), "the fences to the Westpark and the Nordwald are solid")
	check(not m.is_solid(Vector2(-260, -91)) and not m.is_solid(Vector2(-131, -200)), "the gates are open")
	await shot("burg_gate")


## Not split: walking up to a gate builds the castle in time; through the Westpark's gate and
## the Nordwald's gate without a question.
func test_gates_load_it_on_the_way() -> void:
	await fair()
	var built := world.burg != null
	await put_player(GATE_S + Vector3(0, 0, 14))
	check(await walk_to(GATE_S + Vector3(0, 0, -6), 60.0), "walked through the Burgpforte")
	check(world.burg != null, "the castle is built (it was %s)" % ("already" if built else "not yet"))
	check(await wait_until(func() -> bool: return _in("burg"), 20.0), "in the castle area")
	check(dialog_text() == "", "no question when not split")
	check(await walk_to(_v(Vector2(-150, -192)), 120.0), "across to the Nordwald's gate")
	check(await walk_to(GATE_E + Vector3(8, 0, 0), 60.0), "through the Waldweg into the Nordwald")
	check(await wait_until(func() -> bool: return _in("park"), 20.0), "back in the park's area (Nordwald)")


## Split: the gates ask; yes swaps the areas, the castle wakes and the Westpark sleeps.
func test_split_gates_ask() -> void:
	await put_player(GATE_S + Vector3(0, 0, 10))
	await _split(true)
	check(await wait_until(func() -> bool: return _in("fair"), 60.0), "in the Westpark")
	check(await walk_to(GATE_S + Vector3(0, 0, 1.4), 30.0, true, 1.0), "up to the Burgpforte")
	check(await wait_until(func() -> bool: return dialog_text().contains("Ritterburg"), 3.0), "the gate asks (%s)" % dialog_text())
	check(await choose("Ja, zur Burg"), "say yes")
	check(await wait_until(func() -> bool: return _in("burg"), 60.0), "in the castle")
	await wait(0.5)
	check(player().global_position.z < -91.0, "the player stands in the castle area (z %.1f)" % player().global_position.z)
	check(not world.map.fair_open and world.map.burg_open, "the Westpark sleeps, the castle is awake")
	check(world.map.is_solid(Vector2(-260, -88)), "nobody walks into the sleeping Westpark")
	check(world.actors.all(func(a: Actor) -> bool: return a.dormant or a.controlled or World.home_area(a) == "burg"), "only castle people are awake")
	# East through the Waldweg into the Nordwald.
	await put_player(GATE_E + Vector3(-8, 0, 0))
	check(await walk_to(GATE_E + Vector3(-1.4, 0, 0), 30.0, true, 1.0), "up to the Waldweg")
	check(await wait_until(func() -> bool: return dialog_text().contains("Park"), 3.0), "the gate asks (%s)" % dialog_text())
	check(await choose("Ja, in den Park"), "say yes")
	check(await wait_until(func() -> bool: return _in("park"), 60.0), "in the park's area")
	await wait(0.5)
	check(player().global_position.x > ParkLayout.FAIR_EDGE, "the player stands in the Nordwald")
	check(not world.map.burg_open and world.burg_backdrop.visible, "the castle sleeps, its backdrop shows")


## The castle's people come to work: at 14:00 the performers and traders are at their posts.
func test_people_at_their_posts() -> void:
	Clock.set_time(9.5)
	await burg()
	Clock.set_time(14.0)
	for a in world.actors:
		if a.home_region == "burg" and a.brain:
			UI.game.place_by_schedule(a)
	await wait(20.0)
	var away: Array[String] = []
	for id: String in ["kunibert", "adelheid", "eckhard", "walburga", "quirin", "brunhild", "wirtin", "ferkelsepp", "mechthild",
			"fiete", "wuerfelfritz", "hannes", "ludwig", "jo", "liesel", "morwen", "ottilie", "jolanda", "gernot"]:
		var a := world.find_actor(id)
		var post := (a.brain as HumanBrain).work_pos()
		if a.inside or post == Vector3.INF or a.global_position.distance_to(post) > 25.0:
			away.append(id)
	check(away.size() <= 2, "at their posts (away: %s)" % str(away))


## Benches along the castle's ways, inside and outside the walls: each can be walked up to
## from the Burgpforte, and one by the way takes the player with "Aktion".
func test_benches_along_the_ways() -> void:
	await burg()
	var m := world.map
	var ground: Array[Bench] = []
	for b in world.burg_benches:
		if b.bench_id.begins_with("burg_bench_") and b.position.y < m.height_at(b.position.x, b.position.z) + 0.3:
			ground.append(b)
	var inside := ground.filter(func(b: Bench) -> bool: return BurgLayout.in_castle(Vector2(b.position.x, b.position.z)))
	check(ground.size() >= 30 and inside.size() >= 15, "%d benches on the ground, %d inside the walls" % [ground.size(), inside.size()])
	var from := _v(BurgLayout.GATE_SOUTH + Vector2(0, -2))
	var unreachable: Array[String] = []
	for b in ground:
		var front := b.position + Vector3(sin(b.rotation.y), 0, cos(b.rotation.y)) * 1.2
		var path := world.nav.find_path(from, front)
		if path.is_empty() or path[path.size() - 1].distance_to(front) > 1.5:
			unreachable.append("%s %v" % [b.bench_id, Vector2(b.position.x, b.position.z).round()])
	check(unreachable.is_empty(), "every bench reachable (not: %s)" % str(unreachable))
	var a := player()
	var gh := BurgLayout.place("gatehouse")
	var by_way: Bench = inside[0]
	for b: Bench in inside:
		if Vector2(b.position.x, b.position.z).distance_to(gh) < Vector2(by_way.position.x, by_way.position.z).distance_to(gh):
			by_way = b
	var front := by_way.position + Vector3(sin(by_way.rotation.y), 0, cos(by_way.rotation.y)) * 1.2
	await put_player(_v(BurgLayout.place("gatehouse") + Vector2(0, -3)))
	check(await walk_to(front), "walked from the gate house to %s" % by_way.bench_id)
	a.face(by_way.position, true)
	await wait(0.4)
	check(prompt().begins_with("Hinsetzen"), "prompt offers sitting (got '%s')" % prompt())
	await press("interact")
	await wait(1.0)
	check(a.seat != null and a.seat.owner_id == by_way.bench_id, "sits on the bench")
	check(not GameState.has_in_set("benches", by_way.bench_id), "not counted for Bankdrücker (the park's benches)")


## The storage chest at the castle's campfire is the lumber camp's: what lies in one is in the
## other.
func test_storage_chest_at_the_campfire() -> void:
	await burg()
	GameState.storage["board"] = 3
	var a := player()
	a.add_item("stone", 5)
	var spot: Vector3 = world.burg.spots["chest"]
	var c := world.nav.nearest_open(Vector2(spot.x, spot.z))
	check(not world.nav.find_path(_v(BurgLayout.GATE_SOUTH + Vector2(0, -2)), _v(ParkMap.cell_center(c))).is_empty(), "the chest is reachable")
	await put_player(spot)
	await wait(0.3)
	check(prompt().contains("Lagerkiste"), "prompt at the chest (%s)" % prompt())
	await press("interact")
	var bag := UI.bag_screen
	check(bag.visible and bag.chest_box.visible, "the chest opens next to the bag")
	check(bag.chest_grid.find_child("Item_board", false, false) != null, "the boards put in at the lumber camp are here")
	await click_at((bag.bag_grid.find_child("Item_stone", false, false) as Button).get_global_rect().get_center())
	check_eq(int(GameState.storage.get("stone", 0)), 5, "the stones went into the one chest")
	await shot("burg_chest")
	UI.close_screens()


## The secret passage: from the door at the top through the mountain to the mine; the mine's
## door then leads back.
func test_secret_passage() -> void:
	await burg()
	GameState.set_stat("passage", 0)
	await put_player(_v(BurgPassage.CASTLE_OUT + Vector2(0, 1.0)), _v(BurgPassage.CASTLE))
	await wait(0.3)
	check(prompt() == "Durch den Geheimgang", "prompt at the door (%s)" % prompt())
	await press("interact")
	check(await wait_until(func() -> bool: return player().global_position.distance_to(_v(BurgPassage.MINE_OUT)) < 2.0, 15.0),
		"out at the dwarves' mine")
	check(_in("park"), "in the park's area")
	check(GameState.stat("passage") == 1, "passage counted")
	await wait(2.0)
	player().face(_v(BurgPassage.MINE), true)
	await wait(0.3)
	check(prompt() == "Durch die Felsentür", "the mine's door opens now (%s)" % prompt())
	await press("interact")
	check(await wait_until(func() -> bool: return player().global_position.distance_to(_v(BurgPassage.CASTLE_OUT)) < 2.0, 15.0),
		"back at the top of the castle")
	await wait(2.0)


## The map: the castle's view with its places, on the whole map too.
func test_map() -> void:
	await burg()
	await put_player(_v(BurgLayout.place("square") + Vector2(0, 8)))
	await press("map")
	await frames(3)
	var ms: MapScreen = UI.map_screen
	check(ms.view == MapImage.BURG_VIEW, "the map opens on the castle")
	check(ms.title.text.contains("Ritterburg"), "title (%s)" % ms.title.text)
	await shot("map_burg")
	check(await click_button("Gesamtkarte"), "the whole map")
	var at := ms.tex_rect.get_global_transform_with_canvas() * ms.world_to_map(Vector3(-265, 0, -200))
	await click_at(at)
	check(ms.view == MapImage.BURG_VIEW, "a tap on the castle opens its map")
	UI.close_screens()


## The castle's animals: a raven (player) flies a short way with the special action, a falcon
## further and higher; the horses stay in their paddock.
func test_ravens_falcons_and_horses() -> void:
	await burg()
	for id: String in ["rudolf", "fenja"]:
		var bird := present(id)
		var start := _v(BurgLayout.place("square") + Vector2(0, 6))
		bird.teleport(start)
		game.player.control(bird)
		await frames(3)
		bird.face(start + Vector3(0, 0, -1), true)
		var top := [0.0]
		var f0 := GameState.stat("bird_flights")
		game.player.special()
		check(await wait_until(func() -> bool:
			top[0] = maxf(top[0], bird.global_position.y - start.y)
			return (bird.brain as AnimalBrain).state != "fly", 6.0), "%s lands" % id)
		var flown := Vector2(bird.global_position.x - start.x, bird.global_position.z - start.z).length()
		check(flown > (14.0 if id == "fenja" else 8.0), "%s flew %.1f m" % [id, flown])
		check(top[0] > (6.0 if id == "fenja" else 3.0), "%s flew up %.1f m" % [id, top[0]])
		check(GameState.stat("bird_flights") == f0 + 1, "flight counted")
		check(not world.map.is_solid(Vector2(bird.global_position.x, bird.global_position.z), ParkMap.Nav.ANIMAL), "landed on open ground")
	await frames(2)
	for id: String in ["blitz", "donner", "hafer", "wolke"]:
		var h := world.find_actor(id)
		check(not h.def.get("playable", true), "%s is not playable" % id)
	await wait(30.0)
	for id: String in ["blitz", "donner", "hafer", "wolke"]:
		var h := world.find_actor(id)
		check(ParkMap.in_rect(Vector2(h.global_position.x, h.global_position.z), BurgLayout.PADDOCK, BurgLayout.PADDOCK_SIZE, 0.0),
			"%s stays in the paddock" % id)


## With the castle built and all areas awake, the Nordwald's people keep to the Nordwald: the
## Waldweg goes on behind the gate, and a wander target there took Willi into the castle's area
## (found by the all-areas simulation).
func test_nordwald_people_stay_out_of_the_castle() -> void:
	await burg()
	var willi := present("willi")
	for i in 200:
		var p := world.random_path_point(willi)
		if ParkLayout.region_of(Vector2(p.x, p.z)) != "forest":
			check(false, "a wander target outside the Nordwald (%.0f, %.0f)" % [p.x, p.z])
			return
	check(true, "200 wander targets in the Nordwald")
