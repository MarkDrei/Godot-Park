extends Scenario
## The Möwenbucht's quests and stories (doc/moewenbucht.md, phase 4): the single quests, Svenja's
## sunglasses, Ole's drifted pedal boat, the seals' photo from a boat, the message in a bottle
## across the coast and the castle, the lighthouse's new lens from the castle's smithy, the
## achievements.


func _v(p: Vector2) -> Vector3:
	return Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)


## Talks to a person (at their work place) and chooses an option.
func _talk(id: String, option: String) -> bool:
	var npc := present(id)
	if npc.brain is HumanBrain and (npc.brain as HumanBrain).work_pos() != Vector3.INF:
		npc.teleport((npc.brain as HumanBrain).work_pos())
	npc.brain.suspend()
	await next_to(id)
	await press("talk")
	await wait(0.3)
	var ok := await choose(option)
	check(ok, "%s offers '%s' (options %s)" % [id, option, str(dialog_options())])
	await wait(0.3)
	UI.close_dialog("")
	return ok


func test_single_quests() -> void:
	Clock.set_time(14.0)
	await coast()
	var a := player()
	for q: Array in [["uwe", "herring", {"herring": 5}], ["giulia", "berries", {"berries": 6}], ["soenke", "amber", {"amber": 2}], ["klaus", "shells", {"shell": 6}]]:
		await _talk(q[0], "Kann ich helfen?")
		check_eq(CoastStories.quest_stage(q[1]), QuestModule.ACTIVE, "%s's quest taken" % q[0])
		var needs: Dictionary = q[2]
		for item: String in needs:
			a.add_item(item, int(needs[item]))
		var money := GameState.money
		await _talk(q[0], "Hier, bitte!")
		check_eq(CoastStories.quest_stage(q[1]), QuestModule.DONE, "%s's quest done" % q[0])
		check(GameState.money > money, "%s pays" % q[0])
	var titles := Gameplay.coast_stories.tasks().map(func(e: Dictionary) -> String: return e["title"])
	check(titles.has("Heringe für Uwe") and Gameplay.coast_stories.tasks().all(func(e: Dictionary) -> bool: return e["area"] == "coast"),
		"in the notebook under the Möwenbucht (%s)" % str(titles))


## Svenja's sunglasses: once asked, something glitters in the dunes; picked up and brought back.
func test_svenjas_sunglasses() -> void:
	Clock.set_time(13.0)
	await coast()
	await _talk("svenja", "Kann ich helfen?")
	var at := CoastStories.GLASSES_AT
	check(Gameplay.coast_stories.glasses.visible, "the glasses lie in the dunes")
	await put_player(_v(at + Vector2(1.0, 0)), _v(at))
	await wait(0.4)
	check(prompt() == "Etwas glitzert im Sand", "prompt (%s)" % prompt())
	await press("interact")
	check(player().has_item("svenja_glasses"), "picked up")
	await wait(0.2)
	check(not Gameplay.coast_stories.glasses.visible, "gone from the sand")
	await _talk("svenja", "Hier, bitte!")
	check_eq(CoastStories.quest_stage("glasses"), QuestModule.DONE, "Svenja has her glasses")


## Ole's drifted pedal boat: it lies at the beach by the rocks; boarded from the sand, taken
## to the jetty, out onto the planks, Ole told.
func test_drifted_boat() -> void:
	Clock.set_time(11.0)
	await coast()
	await _talk("ole", "Kann ich helfen?")
	await wait(0.2)
	var boat: Car = Gameplay.coast_stories.drift_boat
	check(boat != null and boat.pos2().distance_to(CoastStories.DRIFT_AT) < 1.0, "the boat lies at the beach")
	var sand := Vector2(CoastStories.DRIFT_AT.x, CoastLayout.shore_z(CoastStories.DRIFT_AT.x) - 0.6)
	await put_player(_v(sand), boat.global_position)
	await wait(0.4)
	check(prompt().begins_with("Einsteigen: Tretboot"), "boarded from the sand (%s)" % prompt())
	await press("interact")
	check(player().vehicle == boat, "in Ole's boat")
	await shot("coast_drifted_boat", {"boat": boat.global_position + Vector3(0, 1, 0)})
	boat.place(world.coast.mooring(7) + Vector2(0, 3.5), 0.0)
	await wait(0.4)
	await press("interact")
	check(player().vehicle == null, "out at the jetty")
	check(Gameplay.coast_stories.boat_back(), "the boat is back")
	await _talk("ole", "Dein Tretboot ist zurück!")
	check_eq(CoastStories.quest_stage("boat"), QuestModule.DONE, "Ole is happy")
	world.coast.moor_boats()


## The seals' photo: asked by Hinnerk; in a boat by the sandbank "Robben fotografieren"; the
## photo brought back; "Robbenfotograf".
func test_seal_photo() -> void:
	Clock.set_time(11.0)
	var c := await coast()
	await _talk("hinnerk", "Kann ich helfen?")
	c.moor_boats()
	var boat := c.boats[5]
	game.player.enter_car(boat)
	await frames(3)
	boat.place(CoastLayout.SANDBANK + Vector2(0, 30), PI)
	await wait(0.3)
	check(prompt() != "Robben fotografieren", "too far away (%s)" % prompt())
	boat.place(CoastLayout.SANDBANK + Vector2(4, 14), PI)
	await wait(0.3)
	check(prompt() == "Robben fotografieren", "close to the sandbank (%s)" % prompt())
	await press("interact")
	check(player().has_item("seal_photo"), "the photo in the bag")
	await shot("coast_seal_photo")
	game.player.exit_car(true)
	c.moor_boats()
	await _talk("hinnerk", "Hier, bitte!")
	check(GameState.is_unlocked("seal_photographer"), "Robbenfotograf")


## Flaschenpost: the bottle on the beach, Opa Fietje knows the boy, Räucher-Fiete at the castle
## reads his own letter and sends a smoked fish, Fietje gets it: "Flaschenpost".
func test_message_in_a_bottle() -> void:
	Clock.set_time(12.0)
	await coast()
	var at := CoastStories.BOTTLE_AT
	check(Gameplay.coast_stories.bottle.visible, "a bottle lies on the beach by the rocks")
	await put_player(_v(at + Vector2(1.2, 0)), _v(at))
	await wait(0.4)
	check(prompt() == "Eine Flaschenpost aufheben", "prompt (%s)" % prompt())
	await press("interact")
	check(dialog_text().contains("Onkel Fietje"), "the letter is read out (%s)" % dialog_text())
	UI.close_dialog("")
	check(player().has_item("message_bottle") and CoastStories.bottle_step() == 1, "the bottle in the bag")
	await _talk("fietje", "Kennen Sie einen Fiete?")
	check_eq(CoastStories.bottle_step(), 2, "to the castle")
	await burg()
	await _talk("fiete", "Eine Flaschenpost für Sie")
	check(player().has_item("fiete_fish") and CoastStories.bottle_step() == 3, "Fiete sends a smoked fish")
	await coast()
	var money := GameState.money
	await _talk("fietje", "Ein Gruß von Fiete")
	check_eq(CoastStories.bottle_step(), 4, "the story is done")
	check(GameState.money - money >= 1500, "15 € and more")
	check(GameState.is_unlocked("message_in_a_bottle"), "Flaschenpost")


## Leuchtfeuer: after the lighthouse's view Hinnerk tells of the cracked lens; the tower is dark at
## night; Brunhild makes a new lens at the castle's smithy; brought back, the beam turns again.
func test_beacon() -> void:
	Clock.set_time(11.0)
	var c := await coast()
	GameState.add_stat("lighthouse_view")
	await _talk("hinnerk", "Warum ist der Leuchtturm nachts dunkel?")
	var a := player()
	check(a.has_item("cracked_lens") and CoastStories.lamp_broken(), "the cracked lens, the lamp broken")
	Clock.set_time(23.0)
	await wait(0.2)
	check(not c.light_beam.visible, "dark at night")
	Clock.set_time(14.0)
	a.add_item("amber", 1)
	a.add_item("ore", 1)
	GameState.add_money(500)
	await burg()
	var smith := present("brunhild")
	smith.teleport((smith.brain as HumanBrain).work_pos())
	smith.brain.suspend()
	await next_to("brunhild")
	await press("talk")
	await wait(0.3)
	check(await choose("Etwas schmieden lassen"), "the smithy (%s)" % str(dialog_options()))
	await wait(0.3)
	var b := UI.craft_screen.find_child("Make_lighthouse_lens", true, false) as Button
	check(b != null and not b.disabled, "a new lens can be made")
	if b:
		b.pressed.emit()
	await frames(2)
	UI.close_screens()
	check(a.has_item("lighthouse_lens") and CoastStories.lamp_step() == 2, "the new lens")
	await coast()
	await _talk("hinnerk", "Die neue Linse!")
	check(GameState.is_unlocked("beacon"), "Leuchtfeuer")
	Clock.set_time(23.0)
	await wait(0.2)
	check(c.light_beam.visible, "the beam turns at night again")


## The coast's achievements follow their games' and catches' stats.
func test_achievements() -> void:
	await coast()
	GameState.add_to_set("boats_driven", "pedalo")
	check(GameState.is_unlocked("cast_off") and not GameState.is_unlocked("captain"), "Leinen los! after the first boat")
	GameState.add_to_set("boats_driven", "rowboat")
	check(GameState.is_unlocked("captain"), "Kapitän after both")
	for f: String in ["herring", "mackerel", "plaice", "cod"]:
		GameState.add_to_set("sea_fish", f)
	check(GameState.is_unlocked("sea_angler"), "Petri Heil an der Küste")
	GameState.add_stat("old_boots", 2)
	check(GameState.is_unlocked("pair_of_boots"), "Ein Paar Gummistiefel (hidden)")
