extends Scenario
## Traffic in the Oststadt: AI cars follow the lanes, wait at red lights and for a free
## crossing, keep their distance, never overlap, never touch a person; the player may take
## a standing AI car.


func _traffic() -> Traffic:
	var c := await city()
	return c.traffic


## Two minutes of traffic: everybody moves, nobody overlaps or leaves the road.
func test_traffic_flows() -> void:
	var t := await _traffic()
	await put_player(Vector3(240, 0, -51))   # on the market square, out of the way
	check(t.agents.size() >= Traffic.COUNT - 1, "%d AI cars" % t.agents.size())
	var start := {}
	for a: Traffic.Agent in t.agents:
		start[a.car] = a.car.pos2()
	var overlaps := [0]
	var off_road := [0]
	var touched := [0]
	await wait_until(func() -> bool:
		var cars := world.city.cars
		for i in cars.size():
			var c: Car = cars[i]
			if c.is_parked() and not c.ai:
				continue
			if not world.map.is_drivable(c.pos2()):
				off_road[0] += 1
			for o in world.city.cars_near(c.pos2(), 12.0):
				if o != c and Car.overlap(c.pos2(), c.yaw, c.size2(), o.pos2(), o.yaw, o.size2()):
					overlaps[0] += 1
			for a in world.actors_near(c.position, 8.0):
				if a.vehicle == null and c.contains(a.ground_pos(), a.radius * 0.5):
					touched[0] += 1
		return false, 120.0)
	var moved := 0
	for a: Traffic.Agent in t.agents:
		if start.has(a.car) and is_instance_valid(a.car) and a.car.pos2().distance_to(start[a.car]) > 30.0:
			moved += 1
	check(moved >= Traffic.COUNT * 0.7, "most cars got somewhere (%d of %d)" % [moved, t.agents.size()])
	check(overlaps[0] == 0, "no overlapping cars (%d)" % overlaps[0])
	check(off_road[0] == 0, "no car off the road (%d)" % off_road[0])
	check(touched[0] == 0, "nobody touched (%d)" % touched[0])


## A car never drives into a crossing at red.
func test_cars_wait_at_red() -> void:
	var t := await _traffic()
	await put_player(Vector3(240, 0, -51))   # in town: in the park the traffic rests
	var violations := [0]
	var stopped := [0]
	await wait_until(func() -> bool:
		for a: Traffic.Agent in t.agents:
			if not is_instance_valid(a.car):
				continue
			var cr := a.crossing()
			if not cr["lights"] or cr["holder"] == a:
				continue
			var to_stop := (a.lane["b"] as Vector2 - a.car.pos2()).dot(a.lane["dir"])
			if Traffic.light(cr, a.lane["axis"]) == "red":
				if to_stop < -1.0 and a.state == "lane":
					violations[0] += 1
				if to_stop < 4.0 and to_stop > -0.5 and a.car.speed < 0.3:
					stopped[0] += 1
		return false, 90.0)
	check(violations[0] == 0, "no car past a red stop line (%d)" % violations[0])
	check(stopped[0] > 0, "cars waited at a red light")


## A car in a lane: AI traffic behind it waits, nobody drives into it.
func test_traffic_waits_for_the_player() -> void:
	var t := await _traffic()
	var lane: Dictionary = t.lanes[0]
	var p: Vector2 = (lane["a"] as Vector2).lerp(lane["b"], 0.7)
	var dir: Vector2 = lane["dir"]
	traffic_off(p, 40.0)   # nobody else in the lane between them
	var mine := await in_car("van", p, atan2(dir.x, dir.y))
	var ai := world.city.spawn_car("small", Color("2e86de"), (lane["a"] as Vector2).lerp(lane["b"], 0.1), atan2(dir.x, dir.y))
	_cars.append(ai)
	var agent := Traffic.Agent.new(t, ai, lane)
	ai.ai = agent
	ai.activate()
	t.agents.append(agent)
	await wait(12.0)
	check(not Car.overlap(ai.pos2(), ai.yaw, ai.size2(), mine.pos2(), mine.yaw, mine.size2()), "no crash")
	var gap := ai.pos2().distance_to(mine.pos2()) - (ai.length() + mine.length()) * 0.5
	check(gap > 1.0 and gap < 8.0, "waits behind the player's van (gap %.1f m)" % gap)


## AI cars stop for people crossing (the player on foot too).
func test_traffic_stops_for_the_player_on_foot() -> void:
	var t := await _traffic()
	var lane: Dictionary = t.lanes[3]
	var dir: Vector2 = lane["dir"]
	var p: Vector2 = (lane["a"] as Vector2).lerp(lane["b"], 0.75)
	await put_player(Vector3(p.x, 0, p.y))
	# Nobody else on the way: the car also waits for a person crossing (it stopped 10.7 m short).
	var from: Vector2 = (lane["a"] as Vector2).lerp(lane["b"], 0.05)
	for i in int(from.distance_to(p) / 8.0) + 1:
		var q := from.move_toward(p, i * 8.0)
		clear_around(Vector3(q.x, 0, q.y), 8.0)
	var ai := world.city.spawn_car("kombi", Color("27ae60"), (lane["a"] as Vector2).lerp(lane["b"], 0.05), atan2(dir.x, dir.y))
	_cars.append(ai)
	var agent := Traffic.Agent.new(t, ai, lane)
	ai.ai = agent
	ai.activate()
	t.agents.append(agent)
	var touched := [false]
	var n := [0]
	await wait_until(func() -> bool:
		if ai.contains(player().ground_pos(), player().radius):
			touched[0] = true
		# Keep the way clear: people walking onto the lane later stopped the car short (10.7 m,
		# with three parallel jobs).
		n[0] += 1
		if n[0] % 20 == 0:
			var car := ai.pos2()
			for i in int(car.distance_to(p) / 8.0):
				var q := car.move_toward(p, (i + 1) * 8.0)
				if q.distance_to(p) > 3.0:
					clear_around(Vector3(q.x, 0, q.y), 6.0)
		return false, 14.0)
	check(not touched[0], "the player is never run over")
	check(ai.speed < 0.5 and ai.pos2().distance_to(p) < 9.0, "the car waits in front of the player (%.1f m)" % ai.pos2().distance_to(p))


## Any standing car: take one waiting in the traffic; a new AI car comes instead.
func test_take_a_standing_ai_car() -> void:
	var t := await _traffic()
	var lane: Dictionary = t.lanes[5]
	var dir: Vector2 = lane["dir"]
	var ai := world.city.spawn_car("small", Color("8e44ad"), (lane["a"] as Vector2).lerp(lane["b"], 0.5), atan2(dir.x, dir.y))
	_cars.append(ai)
	var agent := Traffic.Agent.new(t, ai, lane)
	ai.ai = agent
	t.agents.append(agent)
	ai.speed = 0.0
	var spot := ai.pos2() - Car.right_of(dir) * (ai.width() * 0.5 + 0.9)
	await put_player(Vector3(spot.x, 0, spot.y), ai.global_position)
	ai.set_physics_process(false)    # stands for the moment (e.g. at a red light)
	await wait(0.3)
	check(prompt().begins_with("Einsteigen"), "prompt at the AI car (%s)" % prompt())
	await press("interact")
	check(player().vehicle == ai and ai.ai == null, "drives the former AI car")
	await wait(5.0)
	check(not t.agents.has(agent), "the agent is gone")


func test_lights_look_right() -> void:
	var t := await _traffic()
	var c: Dictionary = t.crossings.filter(func(x: Dictionary) -> bool: return x["lights"])[0]
	check(c["heads"].size() >= 3, "light heads at the crossing")
	var p: Vector2 = c["pos"]
	await put_player(Vector3(p.x + 8, 0, p.y + 16), Vector3(p.x, 0, p.y))
	game.camera.follow(player(), false)
	await wait(0.5)
	await shot("traffic_light", {"crossing": Vector3(p.x, 1, p.y)})




## The Kastanienallee has two lanes each way: from the inner lane cars go straight on or turn
## left, from the outer lane straight on or right; a turn into it ends in the nearest lane. Two
## AI cars side by side drive through a crossing without touching.
func test_allee_lanes() -> void:
	var t := await _traffic()
	var allee := t.lanes.filter(func(l: Dictionary) -> bool: return l["of"] == 2)
	check_eq(allee.size(), 2 * 2 * (CityLayout.Z_STREETS.size() - 1), "two lanes each way on every block of the Allee")
	var bad := 0
	for l: Dictionary in t.lanes:
		for n: Dictionary in t.next_lanes(l):
			var d1: Vector2 = l["dir"]
			var d2: Vector2 = n["dir"]
			var cross := d1.x * d2.y - d1.y * d2.x
			if d1.dot(d2) > 0.9:
				if l["of"] == 2 and n["lane"] != l["lane"]:
					bad += 1
			elif absf(cross) > 0.5:
				var right := cross > 0.0
				if l["of"] == 2 and l["lane"] != (1 if right else 0):
					bad += 1
				if n["of"] == 2 and n["lane"] != (1 if right else 0):
					bad += 1
	check_eq(bad, 0, "lane rules at the crossings")
	await put_player(Vector3(446, 0, -60))   # the town hall square, out of the way
	# Northbound towards the Parkallee, side by side.
	var pair: Array[Car] = []
	for l: Dictionary in allee:
		if (l["dir"] as Vector2).y < 0.0 and (l["b"] as Vector2).y > -12.0 and (l["b"] as Vector2).y < 40.0:
			traffic_off((l["a"] as Vector2).lerp(l["b"], 0.4), 40.0)
	for l: Dictionary in allee:
		if (l["dir"] as Vector2).y < 0.0 and (l["b"] as Vector2).y > -12.0 and (l["b"] as Vector2).y < 40.0:
			var dir: Vector2 = l["dir"]
			var ai := world.city.spawn_car("kombi", Color("2e86de"), (l["a"] as Vector2).lerp(l["b"], 0.4), atan2(dir.x, dir.y))
			_cars.append(ai)
			var agent := Traffic.Agent.new(t, ai, l)
			ai.ai = agent
			ai.activate()
			t.agents.append(agent)
			pair.append(ai)
	check_eq(pair.size(), 2, "two cars on the Allee")
	var touched := [0]
	await wait_until(func() -> bool:
		if Car.overlap(pair[0].pos2(), pair[0].yaw, pair[0].size2(), pair[1].pos2(), pair[1].yaw, pair[1].size2()):
			touched[0] += 1
		return pair.all(func(c: Car) -> bool: return c.pos2().y < -30.0 or absf(c.pos2().x - CityLayout.ALLEE_X) > 15.0), 50.0)
	check_eq(touched[0], 0, "the two cars never touched")
	for c: Car in pair:
		check(c.pos2().y < -30.0 or absf(c.pos2().x - CityLayout.ALLEE_X) > 15.0, "through the crossing (%s)" % str(c.pos2().round()))
		check(world.map.is_drivable(c.pos2()), "on the road")
