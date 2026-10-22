extends Scenario
## The Oststadt (doc/oststadt.md): loading at the fence, the street grid, low houses, ways
## for walkers, the fence, the map.


## Walking up to the Osttor loads the town (loading screen), then the gate leads into it.
func test_town_loads_at_the_east_gate() -> void:
	await all_areas()   # walking through without a question (split asks: areas.gd)
	var already := world.city != null
	await put_player(Vector3(100, 0, -12), Vector3(140, 0, -12))
	check(await walk_to(Vector3(124, 0, -12), 60.0), "walked up to the Osttor")
	check(await wait_until(func() -> bool: return world.city != null and not world.loading(), 60.0), "the Oststadt is loaded")
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
	check(CityLayout.houses().size() >= 160, "a real town: %d houses" % CityLayout.houses().size())   # the little parks took some plots
	for b: Dictionary in CityLayout.BUILDINGS:
		check(b["h"] <= 10.0 or String(b["id"]).ends_with("_tower"), "%s is low (%.1f m)" % [b["id"], b["h"]])


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
	await all_areas()   # split: the gates are closed and ask (areas.gd)
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


## The town is not empty: back gardens, the Apfelwiese and the playground with benches,
## street furniture and bus stops, shops with their names; none of it in the way of cars or
## at a house door.
func test_parks_gardens_and_street_furniture() -> void:
	var c := await city()
	var m := world.map
	for id: String in ["orchard", "playground"]:
		var lot: Dictionary = CityLayout.LOTS[id]
		check(m.ground_at((lot["rect"] as Rect2).position + Vector2(2.5, 2.5)) == ParkMap.Ground.GRASS, "%s is a lawn" % id)
		for r: Rect2 in lot["paths"]:
			check(m.ground_at(r.get_center()) == ParkMap.Ground.PLAZA, "%s has cobbled paths" % id)
		var benches := world.city_benches.filter(func(bn: Bench) -> bool: return (lot["rect"] as Rect2).has_point(Vector2(bn.global_position.x, bn.global_position.z)))
		check(benches.size() >= 3, "benches in the %s (%d)" % [id, benches.size()])
	check(world.city_benches.size() >= 60, "benches at the market, the parks, the bus stops and along the streets (%d)" % world.city_benches.size())
	var apples := world.gather_spots.filter(func(s: Dictionary) -> bool: return String(s["id"]).begins_with("town_apple"))
	check_eq(apples.size(), 8, "apple trees to pick on the Apfelwiese")
	check(Gameplay.gathering.spots.has(apples[0]), "the gathering knows them")
	var decor := c.get_parent().find_children("CityDecor_*", "MeshInstance3D", true, false)
	check(decor.size() >= 8, "decor meshes all over town (%d)" % decor.size())
	var shops := CityLayout.houses().filter(func(h: Dictionary) -> bool: return h.has("shop"))
	check_eq(shops.size(), CityLayout.SHOPS.size() + CityLayout.ALLEE_SHOPS.size(), "every shop has a house")
	for h: Dictionary in shops:
		check(h["street"] in CityLayout.SHOP_STREETS or h["street"] == "Kastanienallee", "%s on a shopping street" % h["shop"]["name"])
	# Lanes stay free, doors stay reachable.
	for s: Dictionary in CityLayout.X_STREETS:
		for z in range(int(CityLayout.Z_STREETS[0]["z"]), int(CityLayout.Z_STREETS[-1]["z"]), 2):
			for side: float in [-1.0, 1.0]:
				for k in CityLayout.lanes(s):
					var p := Vector2(s["x"] + side * CityLayout.lane_offset(s, k), z)
					check(m.is_drivable(p), "lane free at %s" % str(p))
	for s: Dictionary in CityLayout.Z_STREETS:
		for x in range(int(CityLayout.X_STREETS[0]["x"]), int(CityLayout.X_STREETS[-1]["x"]), 2):
			for side: float in [-1.0, 1.0]:
				var p := Vector2(x, s["z"] + side * CityLayout.LANE_OFFSET)
				check(m.is_drivable(p), "lane free at %s" % str(p))
	for h: Dictionary in CityLayout.houses():
		var door: Vector2 = h["door"]
		check(not m.is_solid(door) and not m.is_solid(door + (h["front"] as Vector2) * 1.5), "door of %s free" % h["id"])
	var path := world.nav.find_path(Vector3(212, 0, 60 - 7.5), Vector3(246, 0, 40))
	check(path.size() > 1, "a way from the Südring into the Apfelwiese")


## Apples from the Apfelwiese, picked by hand like in the Nordwald's orchard.
func test_pick_apples_on_the_apfelwiese() -> void:
	await city()
	var s: Dictionary = world.gather_spots.filter(func(sp: Dictionary) -> bool: return sp["id"] == "town_apple_4")[0]
	var p: Vector3 = s["pos"]
	var from := p + Vector3(1.6, 0, 0.3)
	if world.map.is_solid(Vector2(from.x, from.z)):
		from = p + Vector3(-1.6, 0, -0.3)
	await put_player(from, p)
	await wait(0.3)
	check_eq(prompt(), Gathering.KINDS["apple"]["verb"], "prompt at the apple tree")
	await press("interact")
	await wait_until(func() -> bool: return Gameplay.gathering.job.is_empty(), 15.0)
	await wait(0.2)
	check(player().has_item("apple"), "got apples")
	check(not Gameplay.gathering.is_ready(s), "the tree is picked")
	await shot("apfelwiese", {"player": head(player())})


## Cars are one surface of the car shader (paint, glass, chrome, rubber) plus their lights,
## with glass and chrome on it and a sensible number of triangles; further away a version
## without small details.
func test_cars_look_right() -> void:
	for kind: String in CarSpecs.KINDS:
		if kind == "scooter" or CarSpecs.spec(kind).get("water", false):
			continue   # the bumper car and the Möwenbucht's boats have their own models
		var mesh := CityModels.car(kind, Color("c0392b"))
		check(mesh.get_surface_count() <= 2, "%s: %d surfaces" % [kind, mesh.get_surface_count()])
		var mat := mesh.surface_get_material(0) as ShaderMaterial
		check(mat != null and mat.shader == Materials.CAR, "%s: car shader" % kind)
		var arrays := mesh.surface_get_arrays(0)
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var flags := {}
		for col in cols:
			flags[snappedf(col.a, 0.01)] = true
		for f: float in [CarModels.PAINT, CarModels.MATTE, CarModels.CHROME]:
			check(flags.has(snappedf(f, 0.01)), "%s: has finish %.2f" % [kind, f])
		if kind not in ["kart"]:
			check(flags.has(snappedf(CarModels.GLASS, 0.01)), "%s: has glass" % kind)
		var tris := _tris(mesh)
		check(tris < 2500, "%s: %d triangles" % [kind, tris])
		var far := _tris(CityModels.car(kind, Color("c0392b"), true))
		if kind in CarSpecs.ORDINARY or kind == "taxi":
			check(far < tris * 0.6, "%s: far version %d triangles" % [kind, far])   # the special ones exist once
		else:
			check(far <= tris, "%s: far version %d triangles" % [kind, far])
	var c := await in_car("small")
	check(c.mesh.visibility_range_end == Car.NEAR and c.far_mesh.visibility_range_begin == Car.NEAR, "near and far car meshes take turns")


func _tris(mesh: Mesh) -> int:
	var tris := 0
	for i in mesh.get_surface_count():
		tris += (mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


## The town reaches twice as far east: the Kastanienallee through the middle (two lanes each
## way, a median with chestnut trees, open at the crossings), three more streets east of it,
## the Rathausplatz, the fire station, the supermarket, the sports ground and the Rosengarten;
## walkers get from the Marktplatz to the Rathaus on sidewalks and crosswalks.
func test_kastanienallee_and_the_east() -> void:
	await city()
	var m := world.map
	var s := CityLayout.x_street(CityLayout.ALLEE_X)
	check_eq(CityLayout.lanes(s), 2, "two lanes each way")
	check(CityLayout.MAX.x - CityLayout.MIN.x >= 500.0, "the town is %d m wide" % int(CityLayout.MAX.x - CityLayout.MIN.x))
	for z: float in [-200.0, -50.0, 30.0]:
		check_eq(m.ground_at(Vector2(CityLayout.ALLEE_X, z)), ParkMap.Ground.GRASS, "median at z %d" % int(z))
		for side: float in [-1.0, 1.0]:
			for k in 2:
				check(m.is_drivable(Vector2(CityLayout.ALLEE_X + side * CityLayout.lane_offset(s, k), z)), "lane %d free at z %d" % [k, int(z)])
	for c: Dictionary in CityLayout.crossings():
		if c["x_street"] == "Kastanienallee":
			check(m.is_drivable(c["pos"]), "crossing with the %s open for turning" % c["z_street"])
			check(c["lights"], "traffic lights at the %s" % c["z_street"])
	for id: String in ["townhall", "fire", "supermarket", "sports", "rosegarden"]:
		var p := CityLayout.place(id)
		check(p.x > CityLayout.ALLEE_X and ParkLayout.region_of(p) == "city", "%s east of the Allee" % CityLayout.place_name(id))
	check_eq(m.ground_at(Vector2(440, -45)), ParkMap.Ground.PLAZA, "the Rathausplatz is paved")
	check(m.is_drivable(Vector2(520, -116)), "the supermarket's car park")
	check(CityLayout.houses().any(func(h: Dictionary) -> bool: return h["street"] == "Feldstraße"), "houses on the Feldstraße")
	var path := world.nav.find_path(Vector3(240, 0, -51), Vector3(446, 0, -58))
	check(path.size() > 1, "a way on foot from the Marktplatz to the Rathaus")
	var on_street := 0
	var total := 0
	for i in range(1, path.size()):
		var a := Vector2(path[i - 1].x, path[i - 1].z)
		var b := Vector2(path[i].x, path[i].z)
		for k in int(a.distance_to(b)):
			total += 1
			if m.ground_at(a.lerp(b, (k + 0.5) / int(a.distance_to(b)))) == ParkMap.Ground.STREET:
				on_street += 1
	check(on_street < total * 0.1, "on sidewalks and crosswalks (%d of %d m on the road)" % [on_street, total])
	await put_player(Vector3(432, 0, -40), Vector3(420, 0, -90))
	await shot("allee", {"player": head(player())})
