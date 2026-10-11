extends Scenario
## Figures, quests and secrets of the Kirmes (doc/kirmes.md, phase 6): Madame Esmeralda's
## hints, the great Zambini's tricks and his lost rabbit, Gisbert the fair ghost, Lia's teddy,
## and the easter eggs (golden duck, golden gondola, the rose arbour's birds, Los-Lothar's
## third line, the retro code, the back room).


## Talks to a person of the Kirmes (who stays put meanwhile) and picks an option.
func _talk(id: String, option: String) -> bool:
	await fair()
	var who := present(id)
	clear_around(who.global_position, 8.0, [id] as Array[String])
	var npc := await next_to(id)
	(npc.brain as HumanBrain).think = 60.0
	await press("talk")
	await wait(0.2)
	return await choose(option)


func _ride(id: String) -> void:
	var m: Ride = Gameplay.minigames[id]
	m.start(player())
	await wait_until(func() -> bool: return not m.active, 120.0)
	await wait(0.2)
	UI.close_dialog("")


func test_fortune_teller() -> void:
	await fair()
	GameState.money = 500
	check(await _talk("esmeralda", "Die Zukunft lesen lassen"), "ask for the future")
	await wait(0.2)
	check(dialog_text().contains("rote Mützen"), "a hint about the gnomes (%s)" % dialog_text())
	check_eq(GameState.money, 400, "it costs 1 €")
	UI.close_dialog("")
	check(await _talk("esmeralda", "Die Zukunft lesen lassen"), "ask again")
	await wait(0.2)
	check(dialog_text().contains("müde"), "only once a day (%s)" % dialog_text())
	check_eq(GameState.money, 400, "nothing paid the second time")
	UI.close_dialog("")


func test_magician_tricks() -> void:
	await fair()
	# The mind reader: 13 is on cards 1, 3 and 4.
	check(await _talk("zambini", "Einen Zaubertrick sehen"), "a trick")
	await wait(0.2)
	check(await choose("Der Gedankenleser"), "the mind reader")
	await wait(0.2)
	check(await choose("Ich hab eine!"), "thought of a number")
	for card in 5:
		await wait(0.2)
		check(await choose("Ja" if 13 & (1 << card) else "Nein"), "card %d" % (card + 1))
	await wait(0.2)
	check(dialog_text().contains("die 13"), "he reads 13 (%s)" % dialog_text())
	check(await choose("Stimmt!"), "right")
	await wait(0.2)
	check(GameState.has_in_set("tricks", "cards") and GameState.tickets == 4, "four tickets for the first time")
	UI.close_dialog("")
	for trick: Array in [["Die magische 1089", 3, "1089"], ["Immer die Vier", 5, "die 4"]]:
		check(await _talk("zambini", "Einen Zaubertrick sehen"), "another trick")
		await wait(0.2)
		check(await choose(trick[0]), trick[0])
		for i in trick[1]:
			await wait(0.2)
			await choose("Weiter" if i < trick[1] - 1 else "Fertig")
		await wait(0.2)
		check(dialog_text().contains(trick[2]), "%s reveals (%s)" % [trick[0], dialog_text()])
		await choose("Stimmt!")
		await wait(0.2)
		UI.close_dialog("")
	check(await _talk("zambini", "Einen Zaubertrick sehen"), "the last trick")
	await wait(0.2)
	check(await choose("Die erratene Zahl"), "guess the number")
	await wait(0.2)
	await choose("6 bis 10")
	await wait(0.2)
	await choose("8")
	await wait(0.2)
	check(dialog_text().contains("die 3"), "8 means 3 (%s)" % dialog_text())
	await choose("Stimmt!")
	await wait(0.2)
	UI.close_dialog("")
	check(GameState.is_unlocked("magic_apprentice"), "Zauberlehrling")


## The magician's story, all five steps.
func test_lost_assistant() -> void:
	var f := await fair()
	Clock.set_time(16.0)
	GameState.add_to_set("tricks", "four")
	check(await _talk("zambini", "Wo ist eigentlich Ihr Assistent?"), "ask about the assistant")
	UI.close_dialog("")
	check_eq(FairStories.step(), 1, "the story is told")
	check(await _talk("esmeralda", "Nach Hoppel fragen"), "ask Esmeralda")
	await wait(0.2)
	check(dialog_text().contains("Gespenstern"), "the clue (%s)" % dialog_text())
	UI.close_dialog("")
	var gustav := present("geistgustav")
	await _ride("ride_ghost")
	check_eq(FairStories.step(), 3, "Hoppel seen in the ghost train")
	check(await _talk("geistgustav", "Haben Sie ein weißes Kaninchen gesehen?"), "ask Gustav")
	UI.close_dialog("")
	check_eq(FairStories.step(), 4, "the carrot trail")
	await wait(1.2)
	check(Gameplay.stories._hoppel.visible, "Hoppel sits at the rose arbour")
	await put_player(Vector3(FairStories.HOPPEL_AT.x + 1.0, 0, FairStories.HOPPEL_AT.y + 0.8), Vector3(FairStories.HOPPEL_AT.x, 0, FairStories.HOPPEL_AT.y))
	await wait(0.3)
	check(prompt() == "Hoppel einfangen", "prompt (%s)" % prompt())
	await press("interact")
	check(player().has_item("hoppel"), "Hoppel in the bag")
	var t0 := GameState.tickets
	check(await _talk("zambini", "Hoppel zurückgeben"), "give him back")
	UI.close_dialog("")
	check(GameState.is_unlocked("assistant"), "Der verschwundene Assistent")
	check_eq(GameState.tickets - t0, 30, "thirty tickets")
	check(gustav != null and f != null, "fine")


func test_ghost_and_his_watch() -> void:
	var f := await fair()
	Clock.set_time(22.5)
	var gp := FairStories.GHOST_AT
	await put_player(Vector3(gp.x, 0, gp.y + 2.0), Vector3(gp.x, 0, gp.y))
	await wait(0.4)
	check(Gameplay.stories.ghost.visible, "Gisbert floats there at night")
	check(prompt() == "Den Geist ansprechen", "prompt (%s)" % prompt())
	await press("interact")
	await wait(0.2)
	check(dialog_text().contains("Taschenuhr"), "he lost his watch (%s)" % dialog_text())
	UI.close_dialog("")
	await _ride("ride_ferris")
	check(player().has_item("pocket_watch"), "found the watch at the top")
	await put_player(Vector3(gp.x, 0, gp.y + 2.0), Vector3(gp.x, 0, gp.y))
	await wait(0.3)
	await press("interact")
	await wait(0.2)
	UI.close_dialog("")
	check(GameState.is_unlocked("ghost_hour"), "Geisterstunde")
	Clock.set_time(12.0)
	await wait(0.6)
	check(not Gameplay.stories.ghost.visible, "gone by day")
	check(f != null, "fine")


func test_lost_teddy() -> void:
	await fair()
	check(await _talk("fairkid_1", "Warum bist du so traurig?"), "ask Lia")
	UI.close_dialog("")
	await wait(1.2)
	var teddy: Node3D = Gameplay.stories._teddy
	check(teddy.visible, "the teddy lies somewhere")
	GameState.money = 500
	check(await _talk("esmeralda", "Die Zukunft lesen lassen"), "ask the fortune teller")
	await wait(0.2)
	check(dialog_text().contains("Teddy"), "she knows where (%s)" % dialog_text())
	UI.close_dialog("")
	await put_player(teddy.global_position + Vector3(0.8, 0, 0.5), teddy.global_position)
	await wait(0.3)
	check(prompt() == "Teddy aufheben", "prompt (%s)" % prompt())
	await press("interact")
	check(player().has_item("teddy"), "in the bag")
	check(await _talk("fairkid_1", "Den Teddy zurückgeben"), "give it back")
	UI.close_dialog("")
	check(GameState.is_unlocked("teddy"), "Teddy-Retter")


func test_golden_duck() -> void:
	await fair()
	await wait(1.2)
	var duck: Node3D = Gameplay.stories._duck
	check(duck.visible, "the golden duck is out today")
	await put_player(duck.global_position + Vector3(0.6, 0, 0.4), duck.global_position)
	await wait(0.3)
	if world.map.is_water(Vector2(duck.global_position.x, duck.global_position.z)):
		Gameplay.stories._pick_duck(player())   # on the pond: a duck swims there, the player can't
	else:
		check(prompt() == "Goldene Ente aufheben", "prompt (%s)" % prompt())
		await press("interact")
	check(player().has_item("golden_duck") and GameState.is_unlocked("golden_duck"), "found it")
	var old := duck.global_position
	Clock.day += 1
	await wait(1.2)
	check(duck.visible and duck.global_position.distance_to(old) > 1.0, "the next day somewhere else")


func test_golden_gondola() -> void:
	var f := await fair()
	Clock.set_time(14.0)
	f.wheel_angle = -PI / 2      # gondola 0 at the bottom
	f._update_wheel()
	var m: FerrisRide = Gameplay.minigames["ride_ferris"]
	m.start(player())
	check_eq(m.gondola, 0, "in the golden gondola")
	await wait_until(func() -> bool: return not m.active, 120.0)
	UI.close_dialog("")
	check(GameState.is_unlocked("golden_gondola"), "Goldene Gondel")


func test_rose_arbour_birds() -> void:
	var f := await fair()
	var seat: Seat = null
	for s in world.seats:
		if s.oasis == "oasis_roses" and s.owner_id == Gameplay.stories._rose_bench_id():
			seat = s
			break
	check(seat != null, "the bench under the rose arbour")
	for i in FairStories.ROSE_SITS:
		player().teleport(seat.approach_point())
		player().sit_on(seat)
		await frames(2)
		player().stand_up()
		await frames(2)
	check(Gameplay.stories._flock != null, "a flock of birds circles")
	check(GameState.is_unlocked("bird_flock"), "Vogelschwarm")
	check(f != null, "fine")


func test_lothar_third_line() -> void:
	await fair()
	for i in 2:
		check(await _talk("lothar", "Tschüss!"), "talk %d" % (i + 1))
	check(await _talk("lothar", "Psst, Lothar"), "the third time he has a secret")
	await wait(0.2)
	check(dialog_text().contains("Gondeln"), "about the gondolas (%s)" % dialog_text())
	UI.close_dialog("")


func test_retro_code_and_back_room() -> void:
	await fair()
	Clock.set_time(14.0)
	var m: ArcadeGame = Gameplay.minigames["arcade_bricks"]
	m.start(player())
	await frames(5)
	for k: Key in [KEY_W, KEY_W, KEY_S, KEY_S, KEY_A, KEY_D, KEY_A, KEY_D]:
		await key(k)
	check(m.bonus > 0.0, "the bonus picture shows")
	check(GameState.is_unlocked("retro_code"), "Retro-Code")
	m.quit()
	await wait(0.2)
	UI.close_dialog("")
	var hall := FairLayout.place("arcade")
	await put_player(Vector3(hall.x - 10.4, 0, hall.y - 4.5), Vector3(hall.x - 12, 0, hall.y - 4.5))
	await wait(0.3)
	check(prompt() == "Tür „Privat“", "the back door (%s)" % prompt())
	await press("interact")
	await wait(0.2)
	check(dialog_text().contains("Highscore-Könige"), "locked (%s)" % dialog_text())
	UI.close_dialog("")
	GameState.unlock("highscore_king")
	await press("interact")
	await wait(0.2)
	check(dialog_text().contains("RETRO RACER"), "the back room (%s)" % dialog_text())
	UI.close_dialog("")
	check(GameState.is_unlocked("back_room"), "Hinterzimmer")


## Der müde Budenbesitzer: Mandel-Manni naps, the player serves eight customers.
func test_almond_shift() -> void:
	var f := await fair()
	Clock.set_time(16.0)
	var manni := present("manni")
	manni.teleport(f.booths["almonds"]["vendor"])
	check(await _talk("manni", "Sie sehen müde aus"), "offer help")
	var m: AlmondShift = Gameplay.minigames["almond_shift"]
	await frames(3)
	check(m.active, "the shift runs")
	check(manni.seat != null, "Manni naps on a bench")
	var money := GameState.money
	for i in AlmondShift.CUSTOMERS:
		await wait(0.2)
		await key(KEY_1 if m._order["size"] == "klein" else KEY_2)
		await key(KEY_3 if m._order["cinnamon"] else KEY_4)
	check_eq(m.right, AlmondShift.CUSTOMERS, "every order right")
	await wait_until(func() -> bool: return not m.active, 5.0)
	UI.close_dialog("")
	check_eq(GameState.money - money, AlmondShift.CUSTOMERS * AlmondShift.PAY, "paid per order")
	check(GameState.tickets >= AlmondShift.CUSTOMERS + 5, "tickets (%d)" % GameState.tickets)
	check(not AlmondShift.tired_now(), "once a day")


## Hunger delivery: a hot dog and fries from the city park for Muskel-Max, still warm.
func test_hunger_delivery() -> void:
	await fair()
	Clock.set_time(13.0)
	check(await _talk("max", "Hast du Hunger, Max?"), "Max is hungry")
	UI.close_dialog("")
	check(FairStories.delivery_active(), "the delivery runs")
	GameState.money = 2000
	for pair: Array in [["hotdog_stand", "Hot Dog zum Mitnehmen"], ["fries_stand", "Pommes zum Mitnehmen"]]:
		await open_shop(pair[0])
		await at_shop(pair[0])
		await press("interact")
		await wait(0.2)
		check(await choose(pair[1]), "%s at %s (%s)" % [pair[1], pair[0], str(dialog_options())])
	check(player().has_item("takeaway_hotdog") and player().has_item("takeaway_fries"), "both in the bag")
	var money := GameState.money
	check(await _talk("max", "Hier, dein Essen"), "deliver")
	UI.close_dialog("")
	check_eq(GameState.money - money, 600, "paid for a warm delivery")
	check(not FairStories.delivery_active(), "done")
