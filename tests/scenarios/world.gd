extends Scenario
## Needs, day and night, weather and seasons as the player experiences them.


func test_hunger_and_fatigue_rise_over_time() -> void:
	var n := player().needs
	var h0 := n.hunger
	var j0 := n.joy
	await wait(60.0)  # one game hour
	check(n.hunger > h0 + 3.0, "hunger rises (%.1f -> %.1f)" % [h0, n.hunger])
	check(n.joy < j0, "joy decays")


func test_very_hungry_is_slower() -> void:
	var a := player()
	var p0 := a.global_position
	await move(Vector2(0, 1), 2.0)
	var normal := a.global_position.distance_to(p0)
	a.needs.hunger = 95.0
	p0 = a.global_position
	await move(Vector2(0, -1), 2.0)
	var hungry := a.global_position.distance_to(p0)
	check(hungry < normal * 0.7, "very hungry walks slower (%.1f vs %.1f m)" % [hungry, normal])


func test_hint_when_hungry() -> void:
	player().needs.hunger = 78.0
	game.player._hint_timer = 0.5
	await wait(1.0)
	check(toasted("hat Hunger"), "hunger hint toast")


func test_hint_when_tired_and_sad() -> void:
	player().needs.fatigue = 80.0
	game.player._hint_timer = 0.5
	await wait(1.0)
	check(toasted("ist müde"), "fatigue hint toast")
	player().needs.fatigue = 10.0
	player().needs.joy = 10.0
	game.player._hint_timer = 0.5
	await wait(1.0)
	check(toasted("ist traurig"), "sad hint toast")


func test_people_go_home_at_night() -> void:
	var before := _humans_in_park()
	Clock.set_time(23.0)
	await wait(240.0)
	var after := _humans_in_park()
	check(after < before / 2, "most people left the park (%d -> %d)" % [before, after])


## Vendors stop working after their hours, so the stands close at night.
func test_stands_close_at_night() -> void:
	var shop := await open_shop("donut_stand")
	check(shop != null, "donut stand open at 11:00")
	Clock.set_time(22.5)
	check(await wait_until(func() -> bool: return not shop.is_open(), 300.0), "donut stand closed at night")


func _humans_in_park() -> int:
	var n := 0
	for a in world.actors:
		if a.is_human() and not a.inside and not a.controlled:
			n += 1
	return n


func test_rain_sends_people_to_shelter() -> void:
	Clock.set_weather(Clock.Weather.RAIN, 100000.0)
	var count := func() -> int:
		var n := 0
		for a in world.actors:
			if a.brain is HumanBrain and (a.brain as HumanBrain).current and (a.brain as HumanBrain).current.kind == "shelter":
				n += 1
		return n
	await wait_until(func() -> bool: return count.call() >= 3, 120.0)
	check(count.call() >= 3, "people look for shelter in the rain (%d)" % count.call())


func test_frozen_pond_in_winter() -> void:
	Clock.season_locked = true
	Clock.day = 3 * Clock.DAYS_PER_SEASON + 1  # middle of winter
	Clock.set_season(Clock.Season.WINTER)
	await wait(2.0)
	check(world.ice > 0.5, "pond freezes (ice %.2f)" % world.ice)
	var duck := present("erwin")
	duck.teleport(Vector3(45, 0, 6))
	await wait(1.0)
	check(not duck.swimming, "duck stands on the ice")
	Clock.day = Clock.DAYS_PER_SEASON + 1
	Clock.set_season(Clock.Season.SUMMER)


func test_lamps_light_up_at_night() -> void:
	Clock.set_time(23.0)
	await wait(2.0)
	var lit := 0
	for l in world.env.lamp_lights:
		if l.visible and l.light_energy > 0.5:
			lit += 1
	check(lit > 0, "street lamps on at night (%d)" % lit)


## Bridge ends rest on the ground over the whole deck width, and walking from the path onto
## the bridge has no step (the creek is crossed at an angle, so one corner used to hang).
func test_bridge_ends_on_ground() -> void:
	var m := world.map
	for b: Dictionary in m.bridges:
		var dir: Vector2 = b["dir"]
		var side := Vector2(-dir.y, dir.x) * (float(b["width"]) * 0.5)
		for end: Array in [[b["a"], 0.0], [b["b"], 1.0]]:
			var e: Vector2 = end[0]
			var t: float = end[1]
			var deck: float = lerpf(b["h0"], b["h1"], t) + ParkMap.deck_lift(t, b["length"])
			for q: Vector2 in [e + side, e, e - side]:
				var gap := deck - m.height_at(q.x, q.y)
				check(gap > -0.1 and gap < 0.12, "%s: end corner on the ground (gap %.2f m)" % [b["name"], gap])
		# Walk the centre line from 2 m before to 2 m onto the bridge: no step.
		var a: Vector2 = b["a"]
		var prev := m.walk_height(a.x - dir.x * 2.0, a.y - dir.y * 2.0)
		var worst := 0.0
		for k in range(1, 41):
			var p := a - dir * 2.0 + dir * (k * 0.1)
			var h := m.walk_height(p.x, p.y)
			worst = maxf(worst, absf(h - prev))
			prev = h
		check(worst < 0.06, "%s: no step onto the bridge (%.2f m)" % [b["name"], worst])
	# The player walks over the Holzsteg.
	var br: Dictionary = m.bridges.filter(func(x: Dictionary) -> bool: return x["name"] == "Holzsteg")[0]
	var from: Vector2 = (br["a"] as Vector2) - (br["dir"] as Vector2) * 3.0
	var to: Vector2 = (br["b"] as Vector2) + (br["dir"] as Vector2) * 3.0
	await put_player(Vector3(from.x, 0, from.y))
	check(await walk_to(Vector3(to.x, 0, to.y), 30.0, false, 1.0), "walks over the Holzsteg")
	await shot("holzsteg", {"player": head(player())})


## Path surfaces are smooth strips: the 1 m ground cells under them are drawn as grass (no
## staircase at the edges), except in gravel and dirt yards and where no strip is drawn.
func test_smooth_path_edges() -> void:
	var m := world.map
	var tb := TerrainBuilder.new(m)
	var on_path := 0
	var hidden := 0
	for idx in range(0, ParkMap.W * ParkMap.H, 7):
		var x := idx % ParkMap.W
		var z := idx / ParkMap.W
		var kind: int = m.ground[idx]
		if m.path_dist[idx] <= 0.0 and kind == m._path_ground(idx):
			on_path += 1
			if tb._under_ribbon(x, z, kind):
				hidden += 1
	check(hidden > on_path * 0.9, "almost all path cells are under the smooth strip (%d of %d)" % [hidden, on_path])
	var boule: Vector2 = ParkLayout.AREAS["boule"]["pos"]
	var c := ParkMap.to_cell(boule)
	check(not tb._under_ribbon(c.x, c.y, m.ground[c.y * ParkMap.W + c.x]), "the boule yard keeps its gravel")
	var paths := world.find_child("Paths", true, false) as MeshInstance3D
	check(paths != null and paths.mesh.get_surface_count() > 0, "path strips are built")
