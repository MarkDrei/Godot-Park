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


## The running quest is the first row in the notebook (a phone shows only the top rows).
func test_running_quest_on_top_of_the_notebook() -> void:
	var mia := present("mia")
	for d: String in mia.def["dogs"]:
		present(d)
	mia.teleport(place("great_meadow") + Vector3(4, 0, 0))
	await _talk_to("mia")
	await choose("Gassi-Auftrag annehmen")
	UI.close_dialog("")
	await press("tasks")
	await frames(2)
	var list: Node = UI.tasks_screen.tabs.get_child(0).get_child(0)
	var first := (list.get_child(0) as Control).find_children("*", "Label", true, false)[0] as Label
	check(first.text.begins_with("Gassi mit"), "first row is the dog walk (got '%s')" % first.text)
	UI.close_screens()


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


# --- Quest markers (glowing rings) ---------------------------------------------------

func _rings() -> Array[String]:
	var out: Array[String] = []
	var m: QuestMarkers = Gameplay.markers
	for i in m._rings.size():
		if m._rings[i].visible and (m._rings[i].material_override as ShaderMaterial).get_shader_parameter("strength") > 0.05:
			out.append(m._targets[i]["what"])
	return out


## A ring under Mia while she has a job, none from afar, none while the job runs; back
## at her with the dog, the ring shows where to hand it over.
func test_marker_on_quest_giver() -> void:
	var mia := present("mia")
	for d: String in mia.def["dogs"]:
		present(d)
	mia.brain.suspend()
	mia.teleport(place("great_meadow") + Vector3(4, 0, 0))
	await put_player(mia.global_position + Vector3(30, 0, 0))
	await wait(0.5)
	check(not _rings().has("mia"), "no ring from 30 m (%s)" % str(_rings()))
	await put_player(mia.global_position + Vector3(6, 0, 0), mia.global_position)
	await wait(0.5)
	check(_rings().has("mia"), "ring under Mia from 6 m (%s)" % str(_rings()))
	await shot("ring_mia")
	var r: MeshInstance3D = Gameplay.markers._rings[_rings().find("mia")]
	check(Vector2(r.position.x, r.position.z).distance_to(Vector2(mia.global_position.x, mia.global_position.z)) < 0.3, "ring at her feet")
	await _talk_to("mia")
	await choose("Gassi-Auftrag annehmen")
	UI.close_dialog("")
	await wait(0.5)
	check(not _rings().has("mia"), "no ring while the job runs")
	Gameplay.quests.walk_state = "back"
	await wait(0.5)
	check(_rings().has("mia"), "ring again to bring the dog back")


func test_marker_on_gnome_until_found() -> void:
	var g: Interactable = spots_with_prompt("Was ist das da?")[0]
	await put_player(g.global_position + Vector3(1.0, 0, 0), g.global_position)
	await wait(0.5)
	var id := ""
	for k: String in Gameplay.eggs.gnome_spots:
		if Gameplay.eggs.gnome_spots[k].distance_to(g.global_position) < 0.1:
			id = k
	check(_rings().has(id), "ring at the gnome %s (%s)" % [id, str(_rings())])
	await put_player(g.global_position + Vector3(4.0, 0, 0), g.global_position)
	await shot("ring_gnome")
	await put_player(g.global_position + Vector3(1.0, 0, 0), g.global_position)
	await press("interact")
	await wait(0.5)
	check(not _rings().has(id), "no ring once found")


func test_marker_on_minigame_until_done() -> void:
	var spot: Vector3 = Gameplay.game_spots["minigolf"]
	await put_player(spot + Vector3(3, 0, 0), spot)
	await wait(0.5)
	check(_rings().has("minigolf"), "ring at the minigolf start (%s)" % str(_rings()))
	await put_player(spot + Vector3(6, 0, 0), spot)
	await shot("ring_minigolf")
	GameState.unlock("minigolf_pro")
	await wait(0.5)
	check(not _rings().has("minigolf"), "no ring once the notebook goal is reached")


func test_markers_on_mime_quest_and_troll() -> void:
	GameState.set_flag("mime_stuck")
	for id: String in ["pierre", "lena"]:
		var npc := present(id)
		npc.brain.suspend()
		await put_player(npc.global_position + Vector3(5, 0, 0))
		await wait(0.5)
		check(_rings().has(id), "ring under %s (%s)" % [id, str(_rings())])
	await reset("jens", 23.0)
	var bruno := present("bruno")
	await put_player(bruno.global_position + Vector3(5, 0, 0), bruno.global_position)
	await wait(0.5)
	check(_rings().has("bruno"), "ring under troll Bruno (%s)" % str(_rings()))
	await shot("ring_bruno_night")
