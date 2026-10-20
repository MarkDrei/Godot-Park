extends Scenario
## The Ritterburg's stories and quests (doc/burg.md, phase 4): Der Sternenstab across the castle
## and the Kirmes, Zwei Gespenster, the single quests, Lumpen-Ludwig's riddles, the exhibition's
## boards, Esmeralda's new hints and the achievements.


## Talks to `id` (put next to the player) and picks the option containing `option`.
func _talk(id: String, option: String) -> bool:
	var npc := present(id)
	if npc.brain is HumanBrain:
		var post := (npc.brain as HumanBrain).work_pos()
		if post != Vector3.INF:
			npc.teleport(post)
	clear_around(npc.global_position, 5.0, [id])
	await next_to(id)
	await press("talk")
	await wait(0.3)
	var ok := await choose(option)
	if not ok:
		check(false, "%s offers '%s' (options %s)" % [id, option, str(dialog_options())])
	await wait(0.3)
	return ok


func _close() -> void:
	UI.close_dialog("")
	await frames(2)


func test_star_staff() -> void:
	await fair()
	await burg()
	Clock.set_time(16.0)
	GameState.set_stat("crystal_best", 4)
	var a := player()
	await _talk("morwen", "Was ist mit Ihrem Stab?")
	check(BurgStories.staff() == 1 and a.has_item("morwen_staff"), "Morwen tells and gives his staff")
	await _close()
	await _talk("zambini", "Kennen Sie Meister Morwen?")
	check(BurgStories.staff() == 2, "Zambini gets nervous")
	await _close()
	await _talk("esmeralda", "Wer war Zambini früher?")
	check(BurgStories.staff() == 3 and dialog_text().contains("Bruder"), "Esmeralda: Morwen is her brother")
	await _close()
	GameState.set_stat("assistant_step", 4)
	await _talk("zambini", "Darf ich in Ihren Zylinder schauen?")
	check(BurgStories.staff() == 3 and not a.has_item("star_splinter"), "not while Hoppel is missing")
	await _close()
	GameState.set_stat("assistant_step", 6)
	await _talk("zambini", "Darf ich in Ihren Zylinder schauen?")
	check(BurgStories.staff() == 4 and a.has_item("star_splinter"), "the splinter was in the hat")
	await _close()
	a.add_item("ore", 2)
	a.add_item("gem", 1)
	GameState.add_money(1000)
	await _talk("brunhild", "Etwas schmieden lassen")
	var b := UI.craft_screen.find_child("Make_star_staff", true, false) as Button
	check(b != null and not b.disabled, "Brunhild can mend the staff")
	if b:
		b.pressed.emit()
		await frames(2)
	check(a.has_item("star_staff") and BurgStories.staff() == 5, "the staff shines")
	UI.close_screens()
	await _talk("morwen", "Ihr Stab leuchtet wieder!")
	check(BurgStories.staff() == 6 and a.has_item("morwen_letter"), "Morwen writes a letter")
	await _close()
	var money := GameState.money
	await _talk("zambini", "Ein Brief von Meister Morwen")
	check(BurgStories.staff() == 7 and GameState.money >= money + 2000, "the two wizards are reconciled, 20 €")
	check(GameState.is_unlocked("two_wizards"), "Zwei Zauberer")
	await _close()
	check(Gameplay.stories.hints().any(func(h: Array) -> bool: return not h[0] and h[1].contains("Brüder im Geiste")), "Esmeralda now speaks of the two brothers")


func test_two_ghosts() -> void:
	await fair()
	await burg()
	GameState.set_stage("ghost", QuestModule.DONE)
	Clock.set_time(23.0)
	var a := player()
	var hedwig := Vector3(BurgStories.HEDWIG_AT.x, 0, BurgStories.HEDWIG_AT.y + 1.4)
	await put_player(hedwig)
	await wait(0.3)
	check(prompt() == "Das Gespenst ansprechen", "Hedwig is out at night (%s)" % prompt())
	await press("interact")
	await wait(0.2)
	check(BurgStories.ghosts() == 1 and a.has_item("hedwig_letter"), "Hedwig's letter")
	await _close()
	var gisbert := Vector3(FairStories.GHOST_AT.x, 0, FairStories.GHOST_AT.y + 1.2)
	await put_player(gisbert)
	await wait(0.3)
	await press("interact")
	await wait(0.2)
	check(BurgStories.ghosts() == 2 and a.has_item("gisbert_letter"), "Gisbert answers")
	await _close()
	await put_player(hedwig)
	await wait(0.3)
	await press("interact")
	await wait(0.2)
	check(BurgStories.ghosts() == 3, "Hedwig wants a lantern")
	await _close()
	Clock.set_time(12.0)
	a.add_item("ore", 2)
	a.add_item("board", 1)
	GameState.add_money(500)
	await _talk("brunhild", "Etwas schmieden lassen")
	var b := UI.craft_screen.find_child("Make_ghost_lantern", true, false) as Button
	check(b != null and not b.disabled, "Brunhild forges a ghost lantern")
	if b:
		b.pressed.emit()
		await frames(2)
	UI.close_screens()
	check(a.has_item("ghost_lantern"), "the lantern")
	Clock.set_time(23.0)
	await put_player(hedwig)
	await wait(0.3)
	await press("interact")
	await wait(0.2)
	check(BurgStories.ghosts() == 4 and a.has_item("hedwig_lantern"), "Hedwig in the lantern")
	await _close()
	var ride: FerrisRide = Gameplay.minigames["ride_ferris"]
	ride.actor = a
	ride.gondola = 3
	var text := Gameplay.stories.at_wheel_top(ride)
	check(text.contains("Gisbert") and BurgStories.ghosts() == 5, "they meet on top of the Ferris wheel (%s)" % text)
	check(not a.has_item("hedwig_lantern"), "the lantern is empty")
	check(GameState.is_unlocked("two_ghosts"), "Geisterstunde zu zweit")


func test_single_quests() -> void:
	await fair()
	await burg()
	Clock.set_time(14.5)
	var a := player()
	for q: Dictionary in BurgStories.QUESTS:
		check(await _talk(q["npc"], "Kann ich helfen?"), "%s: asks" % q["title"])
		check(GameState.stage("bq_" + q["id"]) == QuestModule.ACTIVE, "%s: taken on" % q["title"])
		await _close()
		if q["id"] == "kasper":
			GameState.add_money(500)
			await _talk("fairkid_0", "Hast du eine Kasperpuppe?")
			check(await choose("1,50 € geben"), "pay Finn")
			await wait(0.3)
			await _close()
			check(a.has_item("kasper"), "Kasper from the Kirmes")
		else:
			for item: String in q["needs"]:
				a.add_item(item, int(q["needs"][item]))
		var money := GameState.money
		check(await _talk(q["npc"], "Hier, bitte!"), "%s: delivered" % q["title"])
		check(GameState.stage("bq_" + q["id"]) == QuestModule.DONE and GameState.money >= money + int(q["money"]), "%s: done and paid" % q["title"])
		await _close()


func test_riddles_and_boards() -> void:
	await burg()
	Clock.set_time(14.5)
	for i in BurgStories.RIDDLES.size():
		await _talk("ludwig", "Ein Rätsel hören")
		var r: Array = BurgStories.RIDDLES[i]
		check(await choose(r[1][r[2]]), "answer riddle %d" % (i + 1))
		await wait(0.3)
		await _close()
		check(GameState.stat("riddles") == i + 1, "riddle %d solved" % (i + 1))
		if i < BurgStories.RIDDLES.size() - 1:
			await _talk("ludwig", "Ein Rätsel hören")
			check(dialog_text().contains("morgen"), "one a day")
			await _close()
		Clock.advance(24 * 60)
		Clock.set_time(14.5)
	check(GameState.is_unlocked("riddle_friend"), "Rätselfreund")
	for i in BurgStories.BOARDS.size():
		var p: Vector2 = BurgStories.BOARDS[i][0] + Vector2(0, 1.2)
		await put_player(Vector3(p.x, 0, p.y))
		await wait(0.3)
		check(prompt().begins_with("Tafel lesen"), "board %d (%s)" % [i + 1, prompt()])
		await press("interact")
		await wait(0.2)
		await _close()
	check(GameState.is_unlocked("castle_history"), "Burggeschichte")


func test_esmeralda_knows_the_castle() -> void:
	var texts := []
	for h: Array in Gameplay.stories.hints():
		texts.append(h[1])
	check(texts.any(func(t: String) -> bool: return t.contains("Burg")), "hints about the castle")
	GameState.add_stat("passage")
	check(GameState.is_unlocked("through_the_mountain"), "Durch den Berg")
