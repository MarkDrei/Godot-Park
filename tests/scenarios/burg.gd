extends Scenario
## The Ritterburg (doc/burg.md): its ground, walls and ways, the gates from the Westpark and the
## Nordwald (split and not split), its people at their posts, the secret passage to the
## dwarves' mine, the map.

const GATE_S := Vector3(-260, 0, -90)
const GATE_E := Vector3(-130, 0, -200)


func teardown() -> void:
	await super.teardown()
	if world.split_areas:
		GameState.settings["areas"] = "all"
		await world.set_split(false)


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
	check(m.is_solid(Vector2(-300, BurgLayout.WALL_S)) and m.is_solid(Vector2(BurgLayout.WALL_W, -200)), "the outer wall is solid")
	check(m.is_solid(Vector2(-300, BurgLayout.INNER_Z)), "the inner wall is solid")
	check(m.is_solid(Vector2(-265, -268)), "the rock behind the castle is solid")
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
