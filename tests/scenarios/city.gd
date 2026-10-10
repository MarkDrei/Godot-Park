extends Scenario
## The Oststadt (doc/oststadt.md): loading at the fence, the street grid, low houses, ways
## for walkers, the fence, the map.


## Walking up to the Osttor loads the town (loading screen), then the gate leads into it.
func test_town_loads_at_the_east_gate() -> void:
	var already := world.city_loaded()
	await put_player(Vector3(100, 0, -12), Vector3(140, 0, -12))
	check(await walk_to(Vector3(124, 0, -12), 60.0), "walked up to the Osttor")
	check(await wait_until(func() -> bool: return world.city_loaded() and not world.city_loading, 60.0), "the Oststadt is loaded")
	if not already:
		check(not UI.blocks_game_input(), "loading screen gone")
	check(await walk_to(Vector3(138, 0, -16), 60.0), "walked through the Osttor onto the Parkstraße sidewalk")
	check(ParkLayout.region_of(player().ground_pos()) == "city", "player is in the Oststadt")
	await shot("osttor_city", {"player": head(player())})


func test_houses_are_low() -> void:
	await city()
	var high := []
	for h: Dictionary in CityLayout.houses():
		if h["h"] > 10.0:
			high.append(h["id"])
	check(high.is_empty(), "houses at most 10 m (%s)" % str(high))
	check(CityLayout.houses().size() >= 90, "a real town: %d houses" % CityLayout.houses().size())
	for b: Dictionary in CityLayout.BUILDINGS:
		check(b["h"] <= 10.0 or b["id"] == "church_tower", "%s is low (%.1f m)" % [b["id"], b["h"]])


## Every road, crossing and lot entrance can be reached by car from every other.
func test_streets_form_a_closed_grid() -> void:
	await city()
	var m := world.map
	var start := ParkMap.to_cell(Vector2(210 - CityLayout.LANE_OFFSET, -40))
	var seen := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if seen.has(n) or not m.is_drivable(ParkMap.cell_center(n)):
				continue
			seen[n] = true
			todo.append(n)
	for r: Rect2 in CityLayout.roads():
		check(seen.has(ParkMap.to_cell(r.get_center())), "road %s reachable" % str(r))
	for id: String in CityLayout.LOTS:
		for d: Rect2 in CityLayout.LOTS[id].get("drives", []):
			check(seen.has(ParkMap.to_cell(d.get_center())), "driveway of %s reachable" % id)
	for c: Dictionary in CityLayout.crossings():
		check(seen.has(ParkMap.to_cell(c["pos"])), "crossing %s/%s reachable" % [c["x_street"], c["z_street"]])


## People walk on sidewalks and cross at the crosswalks.
func test_walkers_use_sidewalks() -> void:
	await city()
	var path := world.nav.find_path(Vector3(100, 0, -12), Vector3(240, 0, -51))
	check(path.size() > 1, "a way from the park to the Marktplatz")
	var on_street := 0
	var total := 0
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1].x, path[i - 1].z)
		var b := Vector2(path[i].x, path[i].z)
		var n := int(a.distance_to(b))
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			if p.x < ParkLayout.CITY_EDGE:
				continue
			total += 1
			if world.map.ground_at(p) == ParkMap.Ground.STREET:
				on_street += 1
	check(total > 50 and on_street < total * 0.08, "mostly on sidewalks and crosswalks (%d of %d m on the road)" % [on_street, total])


func test_fence_between_park_and_town() -> void:
	await city()
	var m := world.map
	check(m.is_solid(Vector2(130, 30)), "fence at the park")
	check(m.is_solid(Vector2(130, -200)), "fence at the Nordwald")
	check(not m.is_solid(Vector2(130, -12)), "the Osttor is open")
	check(not m.is_solid(Vector2(130, -160)), "the forest gate east is open")


func test_park_people_stay_out_of_town() -> void:
	await city()
	var p := Vector3(240, 0, -51)
	check(not World.allowed(world.find_actor("herbert"), p), "Opa Herbert does not go into town")
	check(not World.allowed(world.find_actor("holger"), p), "Holger stays in the Nordwald")
	check(World.allowed(player(), p), "the player goes anywhere")
	check(ParkLayout.region_of(Vector2(-50, -150)) == "forest" and ParkLayout.region_of(Vector2(200, -150)) == "city", "regions")


func test_map_shows_the_town() -> void:
	await city()
	await put_player(Vector3(240, 0, -40))
	await press("map")
	await frames(3)
	var ms: MapScreen = UI.map_screen
	check(ms.visible, "map open")
	check(ms.view == MapImage.CITY_SOUTH_VIEW, "map opens on the town's south half")
	check(ms.title.text.contains("Oststadt"), "title names the Oststadt (%s)" % ms.title.text)
	check(await click_button("Oststadt Nord"), "button for the north half")
	check(ms.view == MapImage.CITY_NORTH_VIEW, "north half shown")
	await shot("map_city")
	UI.close_screens()


## While driving around corners the camera never sits inside a house.
func test_camera_stays_out_of_houses() -> void:
	var car := await in_car("small", Vector2(210 - CityLayout.LANE_OFFSET, -70.0), 0.0)
	var bad := [0]
	var cam: Camera3D = game.camera
	var watch := func() -> bool:
		var p := cam.global_position
		var roof := world.map.roof_at(Vector2(p.x, p.z))
		if roof > 0.0 and p.y < roof:
			bad[0] += 1
		return false
	Input.action_press("move_forward")
	await wait_until(func() -> bool:
		watch.call()
		return car.pos2().y > -30.0, 20.0)
	Input.action_press("move_right")
	await wait_until(func() -> bool:
		watch.call()
		return false, 2.5)
	_release_all()
	await wait_until(func() -> bool:
		watch.call()
		return false, 2.0)
	check(bad[0] == 0, "camera never inside a house (%d frames)" % bad[0])
