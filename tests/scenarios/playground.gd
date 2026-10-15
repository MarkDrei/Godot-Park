extends Scenario
## The playground in the city park (doc/playground.md): the bigger area with the ring path
## through it, equipment for the player and the children, the gang's wishes (Robin, Finja,
## Mika), their three games and Bruno's chest.


func _pg() -> Playground:
	return world.playground


func _talk_to(id: String) -> void:
	var npc := present(id)
	npc.brain.suspend()
	await next_to(id)
	clear_around(npc.global_position, 4.0, [id])
	await press("interact")
	await wait(0.2)


## From the fountain path down to the hedge; the ring path stays paved through the lawn,
## sand lies under the equipment.
func test_bigger_playground_with_the_path_through() -> void:
	var m := world.map
	var area: Dictionary = ParkLayout.AREAS["playground"]
	var r := Rect2((area["pos"] as Vector2) - (area["size"] as Vector2) * 0.5, area["size"])
	check(r.size.x >= 32.0 and r.size.y >= 35.0, "bigger than before (%s)" % str(r.size))
	check(r.end.y >= 86.0, "down to the hedge at the fence (%.0f)" % r.end.y)
	check_eq(m.ground_at(Vector2(-44, 64)), ParkMap.Ground.GRASS, "a lawn between the equipment")
	for key: String in ParkLayout.AREAS:
		if key.begins_with("pg_sand_"):
			check_eq(m.ground_at(ParkLayout.AREAS[key]["pos"]), ParkMap.Ground.SAND, "sand under the equipment (%s)" % key)
	var ring := 0
	for x in range(-52, -24, 4):
		for z in range(72, 80):
			if m.ground_at(Vector2(x, z)) == ParkMap.Ground.PATH:
				ring += 1
				break
	check(ring == 7, "the ring path runs through the playground (%d of 7 columns)" % ring)
	var path := world.nav.find_path(Vector3(-38, 0, 52.5), Vector3(-38, 0, 80.5))
	check(path.size() > 1, "a way from the north entrance to the south part")
	for d: String in Playground.DEVICES:
		check(not m.is_solid(Vector2(_pg().start_point(d).x, _pg().start_point(d).z)), "the start of %s is free" % d)
	var kinds := {}
	for r2: Dictionary in _pg().riders:
		kinds[(r2["seat"] as Seat).kind] = true
	check_eq(kinds.size(), Playground.SEATS.size(), "seats of every kind")


## Swings, nest swing, seesaw, carousel and spring animal move with their rider.
func test_ride_the_seats() -> void:
	clear_around(place("playground"), 25.0)
	var seen := {}
	for r: Dictionary in _pg().riders:
		var seat: Seat = r["seat"]
		if seen.has(seat.kind) or not seat.is_free_for(player()):
			continue
		seen[seat.kind] = true
		await put_player(seat.approach_point(), seat.position)
		await wait(0.3)
		check(prompt().begins_with(Playground.SEATS[seat.kind]["verb"]), "%s: prompt (%s)" % [seat.kind, prompt()])
		await press("interact")
		check(player().seat != null and player().seat.kind == seat.kind, "%s: sitting on it" % seat.kind)
		var moved := [0.0]
		var last := [player().global_position]
		await wait_until(func() -> bool:
			moved[0] += player().global_position.distance_to(last[0])
			last[0] = player().global_position
			return false, 2.0)
		check(moved[0] > 0.3, "%s: moves with the rider (%.2f m)" % [seat.kind, moved[0]])
		await shot("ride_" + seat.kind, {"player": head(player())})
		check(player().pose_anim() in ["swing", "ride"], "%s: rides (%s)" % [seat.kind, player().pose_anim()])
		await press("interact")
		check(player().seat == null, "%s: off again" % seat.kind)
		check(absf(player().rotation.x) < 0.01 and absf(player().rotation.z) < 0.01, "%s: upright again" % seat.kind)
	check_eq(seen.size(), Playground.SEATS.size(), "tried every seat kind")


## Slide, climbing net, trampoline and balance beam: up and back down again.
func test_slide_climb_jump_and_balance() -> void:
	clear_around(place("playground"), 25.0)
	var pg := _pg()
	var tops := {"slide": PlaygroundModels.TOWER_TOP - 0.3, "climb": PlaygroundModels.CLIMB_TOP - 0.3, "jump": 0.7, "balance": PlaygroundModels.BEAM_TOP - 0.05}
	for d: String in Playground.DEVICES:
		var s: FunctionSpot = pg.spots[d]
		await put_player(s.global_position)
		await wait(0.3)
		check_eq(prompt(), Playground.PROMPTS[d], "%s: prompt" % d)
		var ground_y := player().global_position.y
		await press("interact")
		check(pg.is_using(player()), "%s: started" % d)
		var top := [0.0]
		await wait_until(func() -> bool:
			top[0] = maxf(top[0], player().global_position.y - ground_y)
			return top[0] >= tops[d] or not pg.is_using(player()), 20.0)
		await shot("device_" + d, {"player": head(player())})
		var ok := await wait_until(func() -> bool:
			top[0] = maxf(top[0], player().global_position.y - ground_y)
			return not pg.is_using(player()), 20.0)
		check(ok, "%s: done" % d)
		check(top[0] >= tops[d], "%s: up to %.1f m (%.2f)" % [d, tops[d], top[0]])
		check(not player().custom_motion and absf(player().global_position.y - world.map.walk_height(player().global_position.x, player().global_position.z)) < 0.05, "%s: back on the ground" % d)
		if d == "slide":
			check(player().global_position.x > Playground.TOWER.x + 3.5, "slide: came out at the bottom (x %.1f)" % player().global_position.x)
	check(GameState.is_unlocked("all_devices"), "Spielplatz-Profi unlocked")


## The children use the playground: within a while, Robin, Finja and Mika have ridden or
## used several different things.
func test_kids_play_on_the_devices() -> void:
	var kinds := {}
	for id: String in PlaygroundQuests.KIDS:
		var kid := present(id)
		kid.teleport(place("playground") + Vector3(randf_range(-4, 4), 0, randf_range(-6, -2)))
		kid.brain.suspend()
		(kid.brain as HumanBrain).think = 0.1
		kid.brain.resume()
	await wait_until(func() -> bool:
		for id: String in PlaygroundQuests.KIDS:
			var kid := world.find_actor(id)
			if kid.seat and kid.seat.kind in Playground.SEATS:
				kinds[kid.seat.kind] = true
			for m: Dictionary in _pg().motions:
				if m["actor"] == kid:
					kinds[m["device"]] = true
		return kinds.size() >= 3, 240.0)
	check(kinds.size() >= 3, "the children used %d kinds of equipment: %s" % [kinds.size(), str(kinds.keys())])
	var area: Dictionary = ParkLayout.AREAS["playground"]
	for id: String in PlaygroundQuests.KIDS:
		var p := world.find_actor(id).global_position
		check(ParkMap.in_rect(Vector2(p.x, p.z), area["pos"], area["size"] + Vector2(6, 6), 0.0), "%s stays at the playground" % id)


## Robin wants an apple, Finja a unicorn, Mika a toy car; each says where to find it.
func test_the_gangs_wishes() -> void:
	var hints := {"robin": "Apfelwiese", "finja": "Gewinnausgabe", "mika": "Kindermenü"}
	for id: String in PlaygroundQuests.KIDS:
		var kid := present(id)
		kid.teleport(place("playground") + Vector3(6, 0, 12))
		await _talk_to(id)
		check(await choose("Was ist los"), "%s asks (%s)" % [id, str(dialog_options())])
		check(dialog_text().contains(hints[id]), "%s says where to find it" % id)
		UI.close_dialog("")
		await wait(0.2)
		check(Gameplay.playground.has_quest(player(), kid) == false, "%s: nothing to hand over yet" % id)
		player().add_item(PlaygroundQuests.WANTS[id])
		check(Gameplay.playground.has_quest(player(), kid), "%s: a ring once you have it" % id)
		await _talk_to(id)
		check(await choose("Hier, für dich"), "%s takes it (%s)" % [id, str(dialog_options())])
		check(not player().has_item(PlaygroundQuests.WANTS[id]), "%s has it now" % id)
		UI.close_dialog("")
		await wait(0.2)
		kid.brain.resume()
	check_eq(PlaygroundQuests.step(), PlaygroundQuests.ALL_HAPPY, "all three wishes")
	check(GameState.is_unlocked("playground_gang"), "Spielplatzbande unlocked")
	await _talk_to("mika")
	check(await choose("Besonderes gefunden"), "after the wishes they tell of the sandbox treasure")
	check(dialog_text().contains("Troll"), "a troll played in the sand")


## The unicorn at the Kirmes's prize counter; the toy car in the drive-in's Kindermenü.
func test_unicorn_and_toy_car_can_be_had() -> void:
	GameState.add_tickets(12, "Test")
	check(FairTrade.redeem(player(), "plush_unicorn"), "the prize counter has the unicorn")
	check(player().has_item("plush_unicorn"), "unicorn in the bag")
	await city()
	var p: Vector2 = CityBuilder.drive_in_points()["order_car"]
	await in_car("small", p, 0.0)
	await wait(0.4)
	await press("interact")
	check(await choose("Kindermenü"), "the drive-in sells a Kindermenü (%s)" % str(dialog_options()))
	UI.close_dialog("")
	player().vehicle.place(CityBuilder.drive_in_points()["window_car"], 0.0)
	await wait(0.4)
	await press("interact")
	check(player().has_item("toy_car"), "a toy car came with it")
	check(toasted("Spielzeugauto"), "and the toast says so")


## Schaukel-Duell: pushing at the turning points swings to the top and beats Finja.
func test_swing_duel() -> void:
	var m: SwingGame = await in_minigame("swing_duel")
	check(m.active, "started")
	check(player().seat != null and player().seat.kind == "swing", "on the swing")
	await shot("swing_duel", {"player": head(player())})
	var r := await play_until_done(m, func() -> void:
		if m.at_top() and m.lockout <= 0.0:
			m.push(), 40.0)
	check(r.get("won", false), "won (best %d %%, Finja %d %%)" % [roundi(m.best * 100.0), roundi(m.host_best * 100.0)])
	check(GameState.stat("swing_best") >= 95, "swung to the top (%d %%)" % GameState.stat("swing_best"))
	check(player().seat == null, "off the swing afterwards")


## Pushing in the middle of the swing brakes it.
func test_swing_duel_wrong_timing_brakes() -> void:
	var m: SwingGame = await in_minigame("swing_duel")
	m.amp = 0.8
	m.phase = 0.0
	m.lockout = 0.0
	m.push()
	check(m.amp < 0.7, "pushed in the middle: slower (%.2f)" % m.amp)
	m.quit()


## Trampoline: pushing off on landing goes higher, up to somersaults, and beats Robin.
func test_trampoline_game() -> void:
	var m: TrampolineGame = await in_minigame("trampoline")
	check(m.active, "started")
	await shot("trampoline", {"player": head(player())})
	var r := await play_until_done(m, func() -> void:
		if m.to_landing() < 0.08:
			m.push(), 40.0)
	check(m.saltos > 0, "somersaults (%d)" % m.saltos)
	check(r.get("won", false), "beat Robin (%d to %d)" % [m.points, m.robin_points])
	check(not player().custom_motion, "back on the ground")


## Treasure hunt: walking to the key's cell and digging finds it.
func test_sand_dig_finds_the_key() -> void:
	var m: SandDigGame = await in_minigame("sanddig")
	check(m.active and m.free_roam, "started, walking about")
	var key := Vector2i(-1, -1)
	for c: Vector2i in m.hidden:
		if m.hidden[c] == -1:
			key = c
	check(key.x >= 0, "the key is in the sand")
	await shot("sanddig", {"player": head(player())})
	# A cell next to it first: "heiß".
	var near := Vector2i(key.x + (1 if key.x + 1 < SandDigGame.COLS else -1), key.y)
	if not m.hidden.has(near):
		await put_player(m.cell_center(near))
		await wait(0.2)
		check(prompt().begins_with("Hier graben"), "prompt to dig (%s)" % prompt())
		await press("interact")
		check(m.host().last_said.begins_with("Heiß"), "Mika: hot (%s)" % m.host().last_said)
	await put_player(m.cell_center(key))
	await wait(0.2)
	await press("interact")
	check(player().has_item("rusty_key"), "found the rusty key")
	m.quit()
	var again: SandDigGame = await in_minigame("sanddig")
	check(not again.hidden.values().has(-1), "the key is only found once")
	again.quit()


## Bruno knows the key; his chest by the Steinbrücke opens with it; he wants his crown.
func test_brunos_chest() -> void:
	await reset("jens", 23.0)
	player().add_item("rusty_key")
	await _talk_to("bruno")
	check(await choose("Kennst du diesen Schlüssel"), "Bruno is asked about the key (%s)" % str(dialog_options()))
	check_eq(PlaygroundQuests.troll_step(), 1, "Bruno told about his chest")
	UI.close_dialog("")
	var chest: FunctionSpot = Gameplay.playground.chest_spot
	await put_player(chest.global_position + Vector3(1.0, 0, 0), chest.global_position)
	await wait(0.3)
	check(prompt().contains("rostigen Schlüssel"), "the chest opens with the key (%s)" % prompt())
	var money := GameState.money
	await press("interact")
	check(player().has_item("troll_crown"), "the crown is in the bag")
	check_eq(GameState.money - money, 1500, "15 € troll gold")
	UI.close_dialog("")
	await _talk_to("bruno")
	check(await choose("Deine Krone"), "the crown goes back to Bruno")
	check(GameState.is_unlocked("troll_treasure"), "König Bruno unlocked")
	check(not player().has_item("troll_crown"), "Bruno has it now")
