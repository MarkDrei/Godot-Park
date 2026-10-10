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
			for j in cars.size():
				var o: Car = cars[j]
				if j != i and Car.overlap(c.pos2(), c.yaw, c.size2(), o.pos2(), o.yaw, o.size2()):
					overlaps[0] += 1
			for a in world.actors:
				if not a.inside and a.visible and a.vehicle == null and c.contains(a.ground_pos(), a.radius * 0.5):
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
	var ai := world.city.spawn_car("kombi", Color("27ae60"), (lane["a"] as Vector2).lerp(lane["b"], 0.05), atan2(dir.x, dir.y))
	_cars.append(ai)
	var agent := Traffic.Agent.new(t, ai, lane)
	ai.ai = agent
	ai.activate()
	t.agents.append(agent)
	var touched := [false]
	await wait_until(func() -> bool:
		if ai.contains(player().ground_pos(), player().radius):
			touched[0] = true
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


