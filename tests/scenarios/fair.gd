extends Scenario
## The Westpark with the Kirmes (doc/kirmes.md), phase 1: built on demand at the Westtor, its
## own area (the Westtor asks with "Bereiche: Getrennt"), walkable paths to every ride, the
## rides turn, the borders hold, the map has a Westpark view.

const WESTTOR := Vector3(-130, 0, 5)


func _in(id: String) -> bool:
	return world.player_area == id and not world.switching and not world.loading()


## Everything loaded (PC): walking up to the Westtor builds the Westpark in time, and you walk
## through without a question.
func test_walk_into_the_fair() -> void:
	await all_areas()   # built on the way, walking in without a question (split: test_split_westtor_asks)
	check(world.fair == null, "the Westpark is not built at the start")
	check(world.fair_backdrop.visible, "the park sees the backdrop with the Ferris wheel")
	check(world.map.is_solid(Vector2(-140, 5)), "until then the Westpark is solid")
	await put_player(WESTTOR + Vector3(24, 0, 0), WESTTOR)
	check(await walk_to(WESTTOR + Vector3(2, 0, 0), 60.0, true, 1.0), "walked up to the Westtor")
	check(await wait_until(func() -> bool: return world.fair != null and not world.loading(), 30.0), "built on the way")
	check(await walk_to(WESTTOR + Vector3(-6, 0, 0), 60.0, true, 1.0), "walked through the Westtor")
	check(world.fair != null and not world.fair_backdrop.visible, "the Westpark is built, the backdrop gone")
	check(dialog_text() == "", "no question with everything loaded (%s)" % dialog_text())
	check(player().global_position.x < ParkLayout.FAIR_EDGE, "the player stands in the Westpark (x %.1f)" % player().global_position.x)
	check(world.player_area == "fair" and world.area_awake("park") and world.area_awake("fair"), "both areas awake")
	var a0 := world.fair.wheel_angle
	await wait(1.0)
	check(world.fair.wheel_angle != a0, "the Ferris wheel turns")
	await shot("fair_arrival", {"wheel": Vector3(-264, 12, -8)})


## Every ride, booth and oasis can be reached on foot from the Westtor.
func test_everything_reachable() -> void:
	await fair()
	var from := WESTTOR + Vector3(-3, 0, 0)
	var targets: Dictionary = world.fair.spots.duplicate()
	for k: String in world.fair.booths:
		targets["booth " + k] = world.fair.booths[k]["pos"]
	for k: String in world.fair.oases:
		targets[k] = world.fair.oases[k] + Vector3(0, 0, FairLayout.PLACES[k]["r"] - 1.2)
	var missing: Array[String] = []
	for k: String in targets:
		var to: Vector3 = targets[k]
		var path := world.nav.find_path(from, to)
		if path.is_empty() or Vector2(path[path.size() - 1].x, path[path.size() - 1].z).distance_to(Vector2(to.x, to.z)) > 2.5:
			missing.append(k)
	check(missing.is_empty(), "reachable from the Westtor (missing: %s)" % str(missing))
	check(targets.size() >= 20, "%d places checked" % targets.size())
	check(world.map.is_solid(Vector2(-264, -8)), "the Ferris wheel's frame is solid")
	check(world.map.is_solid(Vector2(-200, -150)), "west of the Nordwald there is nothing")
	check(world.map.is_solid(Vector2(-130, 40)), "the fence between park and Westpark holds away from the gate")


## Benches and booths stand beside the paths, not on them; a bench has room in front.
func test_furniture_off_the_paths() -> void:
	await fair()
	var m := world.map
	var bad: Array[String] = []
	for b: Bench in world.fair_benches:
		if b.bench_id.begins_with("fair_table"):
			continue
		var yaw: float = b.seats[0].yaw
		var r := FairBuilder.right(yaw)
		var f := FairBuilder.fwd(yaw)
		var c := Vector2(b.position.x, b.position.z)
		for i in range(-3, 4):
			for j in [-1.0, 1.0]:
				if m.path_dist_at(c + r * (i * 0.3) + f * (j * 0.28)) <= 0.0:
					bad.append("%s %s" % [b.bench_id, c])
		if m.is_solid(c + f * 1.3):
			bad.append("%s %s blocked in front" % [b.bench_id, c])
	for bb: Array in FairBuilder.BOOTHS:
		var p: Vector2 = bb[1]
		for i in range(-10, 11):
			for j in range(-6, 7):
				if m.path_dist_at(p + Vector2(i * 0.25, j * 0.25)) <= 0.0:
					bad.append("booth " + bb[0])
	for id: String in ["swing_boat", "prize_counter", "high_striker"]:
		var p := FairLayout.place(id)
		if m.path_dist_at(p) <= 0.5:
			bad.append(id)
	# The gravestones and the pumpkin in front of the ghost train, solid and off the paths.
	var gt := FairLayout.place("ghost_train")
	for o: Vector2 in [Vector2(-10.95, 9.3), Vector2(10.05, 9.3), Vector2(8.2, 10.2)]:
		if m.path_dist_at(gt + o) <= 0.6 or not m.is_solid(gt + o):
			bad.append("ghost train prop %s" % (gt + o))
	var unique: Array[String] = []
	for x in bad:
		if not unique.has(x):
			unique.append(x)
	check(unique.is_empty(), "nothing on a path (%s)" % str(unique))


## The fair is painted, not flat: booths are wooden stalls with board walls, a canvas awning
## whose free edge flutters (and walls that don't), lacquer with gold frames and chasing bulbs, and
## a topper above the sign's crest; the rides' bulbs chase too. Few surfaces (draw calls) each.
func test_fair_finishes() -> void:
	var finish := func(mesh: ArrayMesh, name: String) -> ShaderMaterial:
		for i in mesh.get_surface_count():
			if mesh.surface_get_name(i) == name:
				return mesh.surface_get_material(i) as ShaderMaterial
		return null
	var alphas := func(mesh: ArrayMesh, name: String) -> Vector2:
		for i in mesh.get_surface_count():
			if mesh.surface_get_name(i) == name:
				var lo := 1.0
				var hi := 0.0
				for c: Color in mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]:
					lo = minf(lo, c.a)
					hi = maxf(hi, c.a)
				return Vector2(lo, hi)
		return Vector2(-1, -1)
	for bb: Array in FairBuilder.BOOTHS:
		var mesh := FairModels.booth(bb[0], bb[3]) as ArrayMesh
		for name: String in ["boards", "canvas", "lacquer", "bulbs"]:
			check(finish.call(mesh, name) != null, "booth %s has %s" % [bb[0], name])
		check(mesh.get_surface_count() <= 5, "booth %s: few surfaces (%d)" % [bb[0], mesh.get_surface_count()])
		check(mesh.get_aabb().end.y > FairModels.SIGN_Y + 1.3, "booth %s: a topper above the sign" % bb[0])
	var booth := FairModels.booth("cans", FairModels.RED) as ArrayMesh
	var canvas: ShaderMaterial = finish.call(booth, "canvas")
	check(canvas.shader == Materials.FAIR and canvas.get_shader_parameter("pattern") == Materials.FAIR_FINISHES.find("canvas"),
		"the awning is canvas")
	var flutter: Vector2 = alphas.call(booth, "canvas")
	check(flutter.x < 0.1 and flutter.y == 1.0, "the awning's edge and the pennants flutter, their tops are fixed (%s)" % flutter)
	check(alphas.call(booth, "boards") == Vector2(1, 1), "walls stay put")
	check(alphas.call(booth, "lacquer") == Vector2(0, 1), "lacquer and gold (metal) on one surface")
	check((finish.call(booth, "bulbs") as ShaderMaterial).shader == Materials.FAIR_LIGHTS, "chasing bulbs")
	for m: ArrayMesh in [FairModels.ferris_wheel(), FairModels.carousel_top(), FairModels.chain_crown(), FairModels.bumper_hall(),
			FairModels.swing_frame(), FairModels.high_striker(), FairModels.coaster_station(), FairModels.prize_counter()]:
		check(finish.call(m, "bulbs") != null and finish.call(m, "lacquer") != null, "a ride with lacquer and chasing bulbs")


## The Ferris wheel's gondolas stay upright; the carousel and the chain swing turn, the
## coaster runs.
func test_rides_move() -> void:
	var f := await fair()
	await put_player(Vector3(-262, 0, 20), Vector3(-264, 0, -8))
	var c0 := f.carousel.rotation.y
	var s0 := f.coaster_cars[0].global_position
	await wait(2.0)
	check(f.carousel.rotation.y != c0, "the carousel turns")
	check(f.coaster_cars[0].global_position.distance_to(s0) > 0.5 or f._coaster_wait > 0.0, "the coaster runs (or waits in the station)")
	for g in f.gondolas:
		check(g.global_transform.basis.y.dot(Vector3.UP) > 0.99, "gondola upright")
		break
	check(f.lowest_gondola() >= 0, "a gondola is at the bottom")
	var top := 0.0
	for g in f.gondolas:
		top = maxf(top, g.global_position.y)
	check(top > 20.0, "the wheel is high (%.1f m)" % top)


## Split areas (phones): the Westtor asks; yes swaps the areas, back again.
func test_split_westtor_asks() -> void:
	GameState.settings["areas"] = "split"
	await world.set_split(true)
	await put_player(WESTTOR + Vector3(10, 0, 0))
	check(await walk_to(WESTTOR + Vector3(1.4, 0, 0), 30.0, true, 1.0), "walked up to the Westtor")
	check(await wait_until(func() -> bool: return dialog_text().contains("Kirmes"), 3.0), "the gate asks (%s)" % dialog_text())
	check(await choose("Ja, zur Kirmes"), "say yes")
	check(await wait_until(func() -> bool: return _in("fair"), 60.0), "the Westpark is loaded")
	await wait(0.5)
	check(player().global_position.x < ParkLayout.FAIR_EDGE - 1.0, "the player stands in the Westpark (x %.1f)" % player().global_position.x)
	check(not world.map.park_open and not world.park_root.visible, "the park sleeps")
	check(world.west_backdrop != null and world.west_backdrop.visible, "a backdrop stands for the park")
	check(world.map.is_solid(Vector2(-120, 5)), "nobody walks into the sleeping park")
	check(await walk_to(WESTTOR + Vector3(-9, 0, 0), 30.0), "a bit into the Westpark")
	check(await walk_to(WESTTOR + Vector3(-1.4, 0, 0), 30.0, true, 1.0), "back to the Westtor")
	check(await wait_until(func() -> bool: return dialog_text().contains("zurück in den Park"), 3.0), "the gate asks (%s)" % dialog_text())
	check(await choose("Ja, in den Park"), "say yes")
	check(await wait_until(func() -> bool: return _in("park"), 30.0), "back in the park")
	await wait(0.5)
	check(player().global_position.x > ParkLayout.FAIR_EDGE + 1.0, "the player stands in the park")
	check(world.map.park_open and not world.map.fair_open, "the park is awake, the Westpark sleeps")
	check(not world.fair.visible and world.fair_backdrop.visible, "hidden, the backdrop is back")
	check(world.map.is_solid(Vector2(-140, 5)), "nobody walks into the sleeping Westpark")


## The dog walk ends at the Westtor too (the dog stays in the park).
func test_dog_walk_ends_at_the_westtor() -> void:
	await all_areas()   # walking through the gate (split asks first: areas.gd leaves the dogs behind)
	await fair()
	var mia := present("mia")
	mia.brain.suspend()
	for id: String in mia.def["dogs"]:
		var d := present(id)
		d.teleport(mia.global_position + Vector3(-1.5, 0, 0))
		mia.attach_leash(d)
	Gameplay.quests._start_walk(player(), mia)
	var dog: Actor = Gameplay.quests.walk_dog
	await put_player(WESTTOR + Vector3(4, 0, 0))
	dog.teleport(WESTTOR + Vector3(5, 0, 0))
	check(await walk_to(WESTTOR + Vector3(-5, 0, 0), 30.0, true, 1.2), "walked through the Westtor")
	await wait(0.3)
	check_eq(Gameplay.quests.walk_state, "", "dog walk ended")
	check(toasted("bleibt im Park"), "told why (%s)" % str(toasts))


## Park visitors never go to the Westpark on their own.
func test_park_people_stay_out() -> void:
	await fair()
	var v := world.find_actor("visitor_0")
	check(not World.allowed(v, Vector3(-200, 0, 5)), "a park visitor may not go there")
	for i in 40:
		var q := world.random_path_point(v)
		check(q.x > ParkLayout.FAIR_EDGE, "strolling stays in the park (%s)" % str(q))
		if q.x <= ParkLayout.FAIR_EDGE:
			break
	check_eq(World.area_of(Vector3(-200, 0, 0)), "fair", "the Westpark is its own area")


func test_map_view() -> void:
	await fair()
	await put_player(Vector3(-200, 0, 4))
	await press("map")
	check(UI.map_screen.visible, "map open")
	check(UI.map_screen.view == MapImage.FAIR_VIEW, "the map opens on the Westpark")
	check(UI.map_screen.title.text.contains("Westpark"), "title (%s)" % UI.map_screen.title.text)
	await shot("map_fair")
	UI.close_screens()


## The five oases have their benches.
func test_oases() -> void:
	await fair()
	for id: String in FairLayout.oases():
		var n := world.fair_benches.filter(func(b: Bench) -> bool: return b.oasis == id).size()
		check(n >= 2, "%s has benches (%d)" % [id, n])
