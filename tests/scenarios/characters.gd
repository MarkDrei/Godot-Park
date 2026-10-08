extends Scenario
## Switching characters and the special action (F / "Spezial") of every species,
## dancing (R) and the achievements that come from them.


## Puts an NPC `dist` m in front of the player, visible on screen.
func _in_front(id: String, dist := 4.0) -> Actor:
	var a := player()
	var o := present(id)
	o.teleport(a.global_position + a.forward() * dist)
	await frames(3)
	return o


func test_switch_with_key_and_menu() -> void:
	var lena := await _in_front("lena")
	lena.brain.suspend()
	await press("switch")
	await wait(0.2)
	check(UI._modal == "switch", "Q opens the switch menu")
	check(await click_button("Lena"), "Lena is in the menu")
	check(player() == lena, "now playing Lena")
	check(GameState.has_in_set("characters", "lena"), "Lena counted as played")
	check(not world.find_actor("jens").controlled, "Jens is an NPC again")


func test_switch_menu_cancel_and_nobody_near() -> void:
	await _in_front("lena")
	await press("switch")
	await wait(0.2)
	check(await click_button("Abbrechen"), "Abbrechen button")
	check(UI._modal == "", "menu closed")
	check(player().actor_id == "jens", "still Jens")
	# Far away from everybody: no menu, a toast instead.
	await put_player(Vector3(120, 0, -80))
	for o in world.actors:
		if o != player() and o.distance_to(player().global_position) < 30.0:
			o.teleport(place("great_meadow"))
	await press("switch")
	check(UI._modal == "", "no menu without candidates")
	check(toasted("Niemand in der Nähe"), "toast says nobody is near")


func test_switch_by_talking() -> void:
	var minka := await _in_front("minka", 1.5)
	minka.brain.suspend()
	await press("interact")
	await wait(0.2)
	check(await choose("Zu Katze Minka wechseln") or await choose("wechseln"), "talk offers switching (%s)" % str(dialog_options()))
	check(player() == minka, "now playing Minka")


func test_touch_switch_button() -> void:
	Controls.set_touch_mode(true)
	await _in_front("lena")
	await wait(0.2)
	check(await tap_button("Wechseln"), "Wechseln button")
	await wait(0.2)
	check(UI._modal == "switch", "touch Wechseln opens the menu")


func test_shape_shifter_achievement() -> void:
	var ids := ["herbert", "peggy", "lena", "bello", "minka", "nussi", "erwin", "pieps", "gurrmann", "stachel"]
	for id: String in ids:
		var o := await _in_front(id, 3.0)
		game.player.control(o)
		await wait(0.2)
	check(GameState.is_unlocked("shape_shifter"), "Verwandlungskünstler after 10 characters (%d)" % GameState.stat("characters"))


func test_human_waves_and_neighbour_waves_back() -> void:
	var lena := await _in_front("lena", 3.0)
	lena.brain.suspend()
	for o in world.actors_near(player().global_position, 8.0):
		if o != lena and o != player():
			o.teleport(place("great_meadow") + Vector3(30, 0, 0))
	await press("special")
	check(player().current_anim() == "wave", "Jens waves")
	check(lena.last_said in ["Hallo!", "Moin!", "Servus!", "Grüß Gott!", "Hi!"], "Lena greets back (said '%s')" % lena.last_said)


func test_dog_bark_scares_cat_and_pigeon() -> void:
	await reset("bello")
	var minka := await _in_front("minka", 3.0)
	var pigeon := await _in_front("gurrmann", 2.0)
	await press("special")
	check(player().last_said == "Wuff!", "Bello barks")
	check((minka.brain as AnimalBrain).state in ["flee", "up", "climb"], "cat flees (%s)" % (minka.brain as AnimalBrain).state)
	check((pigeon.brain as AnimalBrain).state == "fly", "pigeon flies away (%s)" % (pigeon.brain as AnimalBrain).state)


func test_cat_and_mouse_achievement() -> void:
	await reset("minka")
	await press("special")
	check(player().current_anim() == "groom", "without a mouse the cat grooms")
	for i in 3:
		var mouse := await _in_front(["pieps", "fiep", "kruemelmaus"][i], 2.0)
		(mouse.brain as AnimalBrain).state = "wander"
		await press("special")
		await wait(0.3)
	check(GameState.stat("mice_scared") >= 3, "three mice scared (%d)" % GameState.stat("mice_scared"))
	check(GameState.is_unlocked("cat_and_mouse"), "Katz und Maus unlocked")


func test_squirrel_climbs_trees() -> void:
	await reset("nussi")
	await press("special")
	var far_from_trees := world.nearest_tree(player().global_position, 3.5).is_empty()
	if far_from_trees:
		check(toasted("Kein Baum"), "no tree: toast")
	var trees := world.trees.duplicate()
	var here := Vector2(player().global_position.x, player().global_position.z)
	trees.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return here.distance_to(x["pos"]) < here.distance_to(y["pos"]))
	for i in 5:
		var t: Dictionary = trees[i]
		await put_player(Vector3(t["pos"].x + 1.2, 0, t["pos"].y))
		await press("special")
		var b := player().brain as AnimalBrain
		check(await wait_until(func() -> bool: return b.state == "up", 20.0), "climbed tree %d" % i)
		await press("special")
		check(await wait_until(func() -> bool: return not b.is_up_tree(), 20.0), "F climbs down again")
	check(GameState.is_unlocked("squirrel_climber"), "Kletterass after five trees (%d)" % GameState.stat("trees_climbed"))


func test_duck_goose_mouse_pigeon_hedgehog_fox_specials() -> void:
	var cases := {"erwin": "Quak!", "klecks": "Quak!", "gustav": "Schnatter!", "pieps": "Piep!", "gurrmann": "Gurr!"}
	for id: String in cases:
		await reset(id)
		await press("special")
		check_eq(player().last_said, cases[id], "%s special" % id)
	for pair: Array in [["stachel", "lie"], ["fridolin", "sniff"]]:
		await reset(pair[0])
		await press("special")
		check_eq(player().current_anim(), pair[1], "%s special anim" % pair[0])


func test_dance_and_rain_dancer() -> void:
	await press("emote")
	check(player().current_anim() == "dance", "R dances")
	check_eq(GameState.stat("rain_dance"), 0, "no rain dance in the sun")
	Clock.set_weather(Clock.Weather.RAIN, 100000.0)
	await wait(4.5)
	await press("emote")
	check(GameState.is_unlocked("rain_dancer"), "Regentänzer when dancing in the rain")


func test_dog_rolls_on_emote() -> void:
	await reset("bello")
	await press("emote")
	check(player().current_anim() == "roll", "dog rolls on R")
