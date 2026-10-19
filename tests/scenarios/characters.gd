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


## Answers the question before a switch ("Zu … wechseln?") with Wechseln.
func _confirm() -> bool:
	await frames(2)
	return dialog_text().contains("wechseln?") and await choose("Wechseln")


func test_switch_with_key_and_menu() -> void:
	var lena := await _in_front("lena")
	lena.brain.suspend()
	await press("switch")
	await wait(0.2)
	check(UI._modal == "switch", "Q opens the switch menu")
	check(await click_button("Lena"), "Lena is in the menu")
	await frames(2)
	check(dialog_text().contains("Zu Lena wechseln?"), "asks before switching (%s)" % dialog_text())
	check(player().actor_id == "jens", "not switched before the answer")
	check(await _confirm(), "Wechseln")
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
	# Abbrechen in the question, and Enter there (the focus is on Abbrechen): still Jens.
	await press("switch")
	await wait(0.2)
	await click_button("Lena")
	await frames(2)
	check(UI._dialog_buttons.size() == 2 and UI._dialog_buttons[1].has_focus(), "Abbrechen has the focus")
	await press("ui_accept")
	await frames(2)
	check(not UI.is_dialog_open() and player().actor_id == "jens", "Enter cancels: still Jens")
	await press("switch")
	await wait(0.2)
	await click_button("Lena")
	await frames(2)
	check(await choose("Abbrechen"), "Abbrechen in the question")
	check(player().actor_id == "jens", "Abbrechen: still Jens")
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
	check(player().actor_id == "jens", "asks first")
	check(await _confirm(), "Wechseln")
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


## Every character of all three areas can be talked to: the options of all quest modules and
## minigames are built without script errors, and there is always something to say.
func test_talk_to_everybody() -> void:
	await city()
	await fair()
	var me := player()
	var n := 0
	for npc in world.actors:
		if npc == me:
			continue
		Conversations.talk(me, npc)
		check(dialog_options().size() >= 1, "options for %s" % npc.actor_id)
		UI.close_dialog("")
		n += 1
	check(n > 100, "talked to %d characters" % n)


## Playing a vendor closes the stand; playing a minigame host closes the game.
func test_playing_a_vendor_or_host() -> void:
	var shop := await open_shop("donut_stand")
	check(shop != null and shop.is_open(), "the donut stand is open")
	await at_shop("donut_stand")
	await press("switch")
	await wait(0.2)
	var vendor := shop.vendor()
	check(await click_button(vendor.display_name), "%s is in the switch menu" % vendor.display_name)
	check(await _confirm(), "Wechseln")
	check(player() == vendor, "now playing %s" % vendor.display_name)
	await wait(0.5)
	check(not shop.is_open(), "the stand is closed while the player is the vendor")
	var m: Minigame = Gameplay.minigames["boule"]
	var host := hold_npc(m.host_id, minigame_spot("boule") + Vector3(2.5, 0, 0))
	await put_player(minigame_spot("boule") + Vector3(4.0, 0, 0), host.global_position)
	await press("switch")
	await wait(0.2)
	check(await click_button(host.display_name), "%s is in the switch menu" % host.display_name)
	check(await _confirm(), "Wechseln")
	check(player() == host and not m.host_available(), "playing the host: the game has no host")
	await put_player(minigame_spot("boule") + Vector3(0.6, 0, 0), minigame_spot("boule"))
	await wait(0.4)
	check(prompt().contains("ist nicht da"), "the spot says the host is away (got '%s')" % prompt())
	await press("interact")
	await wait(0.3)
	check(not m.active, "the game does not start")


## People walk slower right next to the player: half speed at 1 m, their own pace from 3 m.
func test_people_slow_down_near_the_player() -> void:
	var herbert := hold_npc("herbert")
	var me := player()
	herbert.teleport(me.global_position + Vector3(10, 0, 0))
	await frames(4)
	var far := herbert.current_speed()
	herbert.teleport(me.global_position + Vector3(1.0, 0, 0))
	await frames(4)
	var near := herbert.current_speed()
	check(near < far * 0.6, "slower next to the player (%.2f vs %.2f m/s)" % [near, far])


## Spoken to while walking, a person stops, turns to the player and goes on after the talk.
func test_talked_to_person_stops_and_faces_the_player() -> void:
	var herbert := await next_to("herbert")
	(herbert.brain as HumanBrain).think = 600.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var start := Vector2(herbert.global_position.x, herbert.global_position.z)
	var goal := start
	for i in 40:
		goal = world.nav.random_point_near(start, 40.0, rng)
		if goal.distance_to(start) > 15.0:
			break
	check(herbert.go_to(Vector3(goal.x, 0, goal.y)), "Herbert walks off")
	await press("interact")
	await wait(0.3)
	check(UI.is_dialog_open(), "talking to Herbert")
	await wait(0.8)
	var p := herbert.global_position
	await wait(1.0)
	check(herbert.global_position.distance_to(p) < 0.1, "stands still while talking (moved %.2f m)" % herbert.global_position.distance_to(p))
	var to_me := player().global_position - herbert.global_position
	check(absf(angle_difference(herbert.yaw, atan2(to_me.x, to_me.z))) < 0.35, "faces the player")
	check(await choose("Tschüss!"), "say goodbye")
	await wait(3.0)
	check(herbert.global_position.distance_to(p) > 0.5, "goes on after the talk (moved %.2f m)" % herbert.global_position.distance_to(p))
