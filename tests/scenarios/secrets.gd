extends Scenario
## Easter eggs and secrets: gnomes, wishing fountain, duck statue / quack code, Nessie,
## UFO, Nussi's stash, bench plaques, info boards, night owl, seasons, saver, bench presser.


## Reach: walk to every garden gnome and press Aktion (7 hidden places, one on the island).
func test_find_all_gnomes_by_walking() -> void:
	var gnomes := spots_with_prompt("Was ist das da?")
	check_eq(gnomes.size(), 7, "seven gnomes in the park")
	for g in gnomes:
		check(await walk_to(g.global_position, 300.0, true, 1.2), "walked to a gnome at %s" % str(g.global_position))
		player().face(g.global_position, true)
		await wait(0.4)
		check(prompt() == "Was ist das da?", "gnome prompt (got '%s')" % prompt())
		await press("interact")
		check(prompt().begins_with("Gartenzwerg"), "gnome found, prompt shows its name")
	check_eq(GameState.stat("gnomes"), 7, "all gnomes counted")
	check(GameState.is_unlocked("gnome_hunter"), "Zwergenjäger unlocked")
	check(toasted("(7/7)"), "toast counts 7/7")


func test_gnome_found_twice() -> void:
	var g: Interactable = spots_with_prompt("Was ist das da?")[0]
	await put_player(g.global_position + Vector3(0.8, 0, 0), g.global_position)
	await press("interact")
	await press("interact")
	check_eq(GameState.stat("gnomes"), 1, "counted once")
	check(toasted("Mich hast du schon gefunden"), "second press: already found")


func test_wishing_fountain() -> void:
	clear_around(world.fountain_pos + Vector3(0, 0, -5))
	await put_player(world.fountain_pos + Vector3(0, 0, -5), world.fountain_pos)
	check(prompt().begins_with("Münze in den Brunnen werfen"), "fountain prompt (got '%s')" % prompt())
	await press("interact")
	check_eq(GameState.money, 480, "a wish costs 20 ct")
	await wait(1.5)
	check_eq(GameState.stat("wishes"), 1, "wish counted")
	check(GameState.is_unlocked("wishing_well"), "Wunschbrunnen unlocked")


func test_wishing_fountain_without_money() -> void:
	GameState.money = 10
	await put_player(world.fountain_pos + Vector3(0, 0, -5), world.fountain_pos)
	await press("interact")
	await wait(1.5)
	check_eq(GameState.stat("wishes"), 0, "no wish without 20 ct")


func test_animal_looks_into_fountain() -> void:
	await reset("bello")
	await put_player(world.fountain_pos + Vector3(0, 0, -5), world.fountain_pos)
	check(prompt() == "Ins Wasser schauen", "animal prompt (got '%s')" % prompt())


func test_pet_duck_statue_five_times() -> void:
	await put_player(world.statue_pos + Vector3(0, 0, 2.2), world.statue_pos)
	check(prompt() == "Die Bronze-Ente streicheln", "statue prompt (got '%s')" % prompt())
	for i in 5:
		await press("interact")
	check(Gameplay.eggs.duck_hats, "everybody wears duck hats")
	check(GameState.is_unlocked("quack"), "Quak! unlocked")
	check(toasted("Enten auf dem Kopf"), "toast about the hats")


func test_type_quak() -> void:
	await type_text("quak")
	check(Gameplay.eggs.duck_hats, "typing quak puts on duck hats")
	await type_text("quak")
	check(not Gameplay.eggs.duck_hats, "typing it again takes them off")


func test_nessie_in_fog() -> void:
	Clock.set_weather(Clock.Weather.FOG, 100000.0)
	await put_player(Vector3(45, 0, 22), Vector3(45, 0, 6))
	game.camera.follow(player(), false)
	Gameplay.eggs._nessie_next = 0.0
	check(await wait_until(func() -> bool: return GameState.is_unlocked("nessie"), 40.0), "Nessie seen from the pond shore")
	check(toasted("Ungeheuer"), "toast about the monster")


func test_no_nessie_on_a_sunny_day() -> void:
	Gameplay.eggs._nessie_t = -1.0
	Gameplay.eggs.nessie.visible = false
	await put_player(Vector3(45, 0, 22), Vector3(45, 0, 6))
	Gameplay.eggs._nessie_next = 0.0
	await wait(10.0)
	check(not Gameplay.eggs.nessie.visible, "Nessie stays hidden at 11:00 in the sun")


func test_ufo_at_night() -> void:
	await reset("jens", 0.55)
	var m := place("great_meadow")
	await put_player(m + Vector3(0, 0, 45), m)
	game.camera.follow(player(), false)
	game.camera.orbit(0, -250)  # look up, like dragging the camera
	check(await wait_until(func() -> bool: return GameState.is_unlocked("ufo"), 20.0), "UFO seen over the great meadow")


func test_nussi_stash() -> void:
	var t := world.stash_tree()
	var spot: Interactable = spots_with_prompt("Astloch untersuchen")[0]
	check(await walk_to(spot.global_position, 200.0, true, 1.2), "walked to the stash tree")
	player().face(Vector3(t["pos"].x, 0, t["pos"].y), true)
	await wait(0.4)
	check(prompt() == "Astloch untersuchen", "stash prompt (got '%s')" % prompt())
	await press("interact")
	check(dialog_text().contains("Donuts"), "dialog tells about donuts")
	UI.close_dialog("")
	check(GameState.is_unlocked("stash"), "Diebesgut unlocked")


func test_bench_plaque() -> void:
	var bench: Bench = null
	for b in world.benches:
		if b.plaque != "":
			bench = b
			break
	check(bench != null, "a bench with a plaque exists")
	var front := bench.position + Vector3(sin(bench.rotation.y), 0, cos(bench.rotation.y)) * 1.2
	await put_player(front, bench.position)
	check(prompt() == "Hinsetzen (Plakette lesen)", "plaque prompt (got '%s')" % prompt())
	await press("interact")
	check(toasted("Plakette: „%s“" % bench.plaque), "plaque text shown")


func test_info_board_opens_map() -> void:
	var b: Vector3 = world.info_boards[0]
	await put_player(b + Vector3(1.2, 0, 0), b)
	check(prompt() == "Parkplan ansehen", "info board prompt (got '%s')" % prompt())
	await press("interact")
	check(UI._modal == "map", "map opens")


func test_night_owl_at_midnight() -> void:
	await reset("jens", 23.9)
	check(await wait_until(func() -> bool: return GameState.is_unlocked("night_owl"), 30.0), "Nachteule at midnight")


func test_all_seasons() -> void:
	for s in 4:
		Clock.set_season(s)
		await wait(0.2)
	check(GameState.is_unlocked("all_seasons"), "Vier Jahreszeiten")
	Clock.set_season(Clock.Season.SUMMER)


func test_saver() -> void:
	GameState.add_money(4600, "Test")
	check(GameState.is_unlocked("saver"), "Sparschwein at 50 €")


## Bankdrücker: sit on 25 different park benches.
func test_bench_presser() -> void:
	var n := 0
	for b in world.benches:
		if n >= 25:
			break
		if not b.bench_id.begins_with("bench_") or b.free_seat(player()) == null:
			continue
		var front := b.position + Vector3(sin(b.rotation.y), 0, cos(b.rotation.y)) * 1.0
		await put_player(front, b.position)
		await wait(0.2)
		if not prompt().begins_with("Hinsetzen"):
			continue
		await press("interact")
		await press("interact")
		n += 1
	check(GameState.is_unlocked("bench_presser"), "Bankdrücker after %d benches (%d counted)" % [n, GameState.stat("benches")])
