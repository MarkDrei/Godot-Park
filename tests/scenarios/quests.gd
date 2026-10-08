extends Scenario
## Jobs and quests: dog walk for Mia, the mime in the invisible box, troll Bruno's riddles.


func _talk_to(id: String) -> void:
	var npc := present(id)
	npc.brain.suspend()
	await next_to(id)
	await press("interact")
	await wait(0.2)


## Full dog walk by playing: accept at Mia, walk to the dog meadow, wait, bring the dog back.
func test_dog_walk() -> void:
	var mia := present("mia")
	for d: String in mia.def["dogs"]:
		present(d)
	mia.teleport(place("great_meadow") + Vector3(4, 0, 0))
	await _talk_to("mia")
	check(await choose("Gassi-Auftrag annehmen"), "Mia offers the job (%s)" % str(dialog_options()))
	var q := Gameplay.quests
	check_eq(q.walk_state, "to_meadow", "walk started")
	var dog: Actor = q.walk_dog
	check(dog != null and dog.leash_owner == player(), "dog on the player's leash")
	var meadow := world.dog_meadow.get_center()
	check(await walk_to(Vector3(meadow.x, 0, meadow.y), 200.0), "walked to the dog meadow")
	check(await wait_until(func() -> bool: return q.walk_state == "playing", 30.0), "dog plays on the meadow")
	check(await wait_until(func() -> bool: return q.walk_state == "back", 40.0), "playtime over, bring it back")
	check(await walk_to(mia.global_position, 200.0, true, 4.0), "walked back to Mia")
	await _talk_to("mia")  # she keeps walking her other dogs: step next to her
	var money := GameState.money
	check(await choose("zurückbringen"), "Mia takes the dog back (%s)" % str(dialog_options()))
	check_eq(GameState.money - money, 400, "4 € for the walk")
	check_eq(GameState.stat("dog_walks"), 1, "walk counted")
	check_eq(q.walk_state, "", "job finished")


## Switching to another character cancels the job; the dog goes back to Mia.
func test_dog_walk_cancelled_by_switching() -> void:
	var mia := present("mia")
	for d: String in mia.def["dogs"]:
		present(d)
	mia.teleport(place("great_meadow") + Vector3(4, 0, 0))
	await _talk_to("mia")
	await choose("Gassi-Auftrag annehmen")
	var dog: Actor = Gameplay.quests.walk_dog
	UI.close_dialog("")
	game.player.control(present("lena"))
	await wait(0.5)
	check_eq(Gameplay.quests.walk_state, "", "job cancelled after switching")
	check(dog.leash_owner == mia, "dog back on Mia's leash")
	check(not world.find_actor("jens").leash_dogs.has(dog), "Jens no longer holds the leash")


func test_dog_walk_only_for_humans() -> void:
	await reset("minka")
	await _talk_to("mia")
	check(not dialog_options().any(func(t: String) -> bool: return t.contains("Gassi")), "a cat gets no dog walk job")


func test_dog_walker_achievement() -> void:
	for i in 5:
		GameState.add_stat("dog_walks")
	check(GameState.is_unlocked("dog_walker"), "Gassi-Profi after five walks")


## The mime gets stuck at some full hour (50 %), Lena has the invisible key.
func test_mime_quest() -> void:
	present("pierre")
	var hours := 0
	while not GameState.flag("mime_stuck") and hours < 30:
		Clock.set_time(11.0 + (hours % 6))
		hours += 1
		await frames(2)
	check(GameState.flag("mime_stuck"), "Pierre got stuck after %d hours" % hours)
	await _talk_to("pierre")
	check(await choose("Was ist los, Pierre?"), "Pierre explains without the key")
	UI.close_dialog("")
	await _talk_to("lena")
	check(await choose("Hast du etwas gefunden?"), "Lena offers something")
	check(await choose("Ja, gerne!"), "accept the key")
	check(player().has_item("invisible_key"), "invisible key in the inventory")
	await _talk_to("pierre")
	check(await choose("Den unsichtbaren Schlüssel geben"), "give the key")
	UI.close_dialog("")
	check(GameState.flag("mime_freed"), "mime freed")
	check(not player().has_item("invisible_key"), "key handed over")
	check(GameState.is_unlocked("mime_saver"), "Unsichtbare Hilfe unlocked")


## Troll Bruno at night: the right answer unlocks the achievement.
func test_troll_riddle_right() -> void:
	await reset("jens", 23.0)
	await _talk_to("bruno")
	check(await choose("Ein Rätsel lösen"), "Bruno offers a riddle")
	var text := dialog_text()
	var answer := ""
	for r: Dictionary in Quests.RIDDLES:
		if text.contains(r["q"]):
			answer = r["a"][r["ok"]]
	check(answer != "", "riddle recognised")
	check(await choose(answer), "answer '%s' offered" % answer)
	check(GameState.is_unlocked("troll"), "Brückenrätsel unlocked")
	UI.close_dialog("")
	await _talk_to("bruno")
	check(not dialog_options().any(func(t: String) -> bool: return t.contains("Rätsel")), "no more riddles once solved")


func test_troll_riddle_wrong_blocks_the_day() -> void:
	await reset("jens", 23.0)
	await _talk_to("bruno")
	await choose("Ein Rätsel lösen")
	var text := dialog_text()
	var wrong := ""
	for r: Dictionary in Quests.RIDDLES:
		if text.contains(r["q"]):
			wrong = r["a"][(int(r["ok"]) + 1) % 3]
	await choose(wrong)
	check(not GameState.is_unlocked("troll"), "wrong answer: no achievement")
	UI.close_dialog("")
	await _talk_to("bruno")
	await choose("Ein Rätsel lösen")
	check(dialog_text().contains("genug geraten"), "no second try the same night")
