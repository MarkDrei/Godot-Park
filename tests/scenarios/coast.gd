extends Scenario
## The Möwenbucht (doc/moewenbucht.md): its ground and the sea, the Südtor loading it on the way
## (split and not split), the pier, the boats (in, out, where they may go), the gulls, the
## visitors on the beach, the map.

const GATE := Vector3(0, 0, 90)


func _init() -> void:
	start_areas = "all"   # the Südtor loads the coast on the way; split tests ask for it


func _split(on: bool) -> void:
	GameState.settings["areas"] = "split" if on else "all"
	await world.set_split(on)
	await frames(2)


func _in(id: String) -> bool:
	return world.player_area == id and not world.switching and not world.loading()


func _v(p: Vector2) -> Vector3:
	return Vector3(p.x, world.map.walk_height(p.x, p.y), p.y)


## The bay: no step at the gate, the promenade, dunes, the beach falling into the sea, the sea
## deep further out; every place reachable from the Südtor, the pier's deck walkable, water,
## rocks and the fence solid.
func test_ground_beach_and_sea() -> void:
	await coast()
	var m := world.map
	check(absf(m.height_at(0, 89.5) - m.height_at(0, 91)) < 0.3, "no step at the Südtor")
	var dune := 0.0
	for x in range(-100, 70, 5):
		dune = maxf(dune, m.height_at(x, 124))
	check(dune > 1.6, "dunes up to %.1f m" % dune)
	check(m.height_at(0, 150) > ParkLayout.WATER_Y and m.height_at(0, 186) < ParkLayout.WATER_Y - 0.5, "the beach falls into the sea")
	check(m.height_at(0, 230) < -2.5 and m.is_water(Vector2(40, 230)), "the sea is deep further out (%.1f m)" % m.height_at(0, 230))
	var from := _v(CoastLayout.GATE + Vector2(0, 3))
	for id: String in ["forecourt", "bandstand", "fish_stand", "kiosk", "boat_rental", "playground", "volleyball", "lifeguard",
			"beach_bar", "sandcastles", "pier_head", "jetty", "harbour", "cutter", "lighthouse"]:
		var p := CoastLayout.place(id)
		var c := world.nav.nearest_open(p)
		var path := world.nav.find_path(from, _v(ParkMap.cell_center(c)))
		check(not path.is_empty() and path[path.size() - 1].distance_to(_v(p)) < CoastLayout.PLACES[id]["r"] + 6.0,
			"%s reachable from the Südtor" % id)
	var head := CoastLayout.PIER_HEAD
	check(absf(m.walk_height(head.x, head.y) - CoastLayout.PIER_Y) < 0.05 and not m.is_solid(head), "the pier head is a deck to walk on")
	check(absf(m.walk_height(CoastLayout.JETTY[1].x, CoastLayout.JETTY[1].y - 1.0) - CoastLayout.JETTY_Y) < 0.05, "the jetty too")
	check(m.is_solid(Vector2(30, 200)) and m.is_solid(Vector2(-115, 170)), "the sea and the rocks are solid for walkers")
	check(m.is_solid(Vector2(40, 90)) and not m.is_solid(Vector2(0, 90.5)), "the fence to the park is solid, the Südtor open")
	check(m.is_solid(Vector2(-4, 200)) and m.is_solid(Vector2(4, 200)), "beside the pier is water (railings, no falling off)")
	await put_player(_v(CoastLayout.place("forecourt") + Vector2(0, 5)), _v(Vector2(0, 160)))
	await shot("coast_forecourt")


## Not split: walking down to the Südtor builds the coast in time; through without a question.
func test_gate_loads_it_on_the_way() -> void:
	var built := world.coast != null
	await put_player(GATE + Vector3(0, 0, -14))
	check(await walk_to(GATE + Vector3(0, 0, 8), 60.0), "walked through the Südtor")
	check(world.coast != null, "the coast is built (it was %s)" % ("already" if built else "not yet"))
	check(await wait_until(func() -> bool: return _in("coast"), 20.0), "at the coast")
	check(dialog_text() == "", "no question when not split")
	check(await walk_to(GATE + Vector3(0, 0, -6), 60.0), "back into the park")
	check(await wait_until(func() -> bool: return _in("park"), 20.0), "in the park again")


## Split: the Südtor asks; yes swaps the areas, the coast wakes and the park sleeps.
func test_split_gate_asks() -> void:
	await put_player(GATE + Vector3(0, 0, -16))   # out of the gate's reach: not loaded on the way
	await _split(true)
	check(await wait_until(func() -> bool: return _in("park"), 60.0), "in the park")
	check(await walk_to(GATE + Vector3(0, 0, -1.4), 30.0, true, 1.0), "up to the Südtor")
	check(await wait_until(func() -> bool: return dialog_text().contains("Möwenbucht"), 3.0), "the gate asks (%s)" % dialog_text())
	check(await choose("Ja, ans Meer"), "say yes")
	check(await wait_until(func() -> bool: return _in("coast"), 60.0), "at the coast")
	await wait(0.5)
	check(player().global_position.z > 91.0, "the player stands at the coast (z %.1f)" % player().global_position.z)
	check(not world.map.park_open and world.map.coast_open, "the park sleeps, the coast is awake")
	check(world.actors.all(func(a: Actor) -> bool: return a.dormant or a.controlled or World.home_area(a) == "coast"), "only coast people are awake")
	check(not world.coast_backdrop.visible, "its stand-in is hidden")
	check(await walk_to(GATE + Vector3(0, 0, 8), 30.0), "a few steps away (the gate asks again)")
	check(await walk_to(GATE + Vector3(0, 0, 1.4), 30.0, true, 1.0), "back to the Südtor")
	check(await wait_until(func() -> bool: return dialog_text().contains("Park"), 3.0), "the gate asks (%s)" % dialog_text())
	check(await choose("Ja, in den Park"), "say yes")
	check(await wait_until(func() -> bool: return _in("park"), 60.0), "in the park")
	check(not world.map.coast_open and world.coast_backdrop.visible, "the coast sleeps, its stand-in shows")


## From the promenade over the boardwalk onto the pier and out to its head.
func test_walk_the_pier() -> void:
	await coast()
	await put_player(_v(Vector2(0, 104)))
	check(await walk_to(_v(CoastLayout.PIER_HEAD + Vector2(-3, 4)), 120.0), "walked out to the pier head")
	var a := player()
	check(absf(a.global_position.y - CoastLayout.PIER_Y) < 0.15, "standing on the deck (%.2f m)" % a.global_position.y)
	await shot("coast_pier_head")


## A pedal boat at the jetty: in, pedal out of the harbour, steer, glide; out only where there
## is land or a deck; back at the jetty out onto the planks.
func test_pedal_boat() -> void:
	var c := await coast()
	c.moor_boats()
	var boat := c.boats[1]
	check(boat.kind == "pedalo" and boat.on_water(), "a pedal boat lies at the jetty")
	var spot := Vector2(CoastLayout.JETTY[0].x + 0.4, boat.pos2().y)
	await put_player(_v(spot), boat.global_position)
	await wait(0.4)
	check(prompt().begins_with("Einsteigen: Tretboot"), "prompt to get in (%s)" % prompt())
	await press("interact")
	check(player().vehicle == boat, "sitting in the pedal boat")
	check(player().rig.visible, "the driver is seen pedalling")
	var x0 := boat.pos2().x
	await drive(1.0, 5.0)
	check(boat.pos2().x > x0 + 4.0, "pedalled out into the basin %.1f m" % (boat.pos2().x - x0))
	var glide := boat.pos2()
	await wait(1.0)
	check(boat.pos2().distance_to(glide) > 0.5, "it glides on when let go")
	var yaw0 := boat.yaw
	await drive(0.6, 3.0, 1.0)
	check(absf(angle_difference(boat.yaw, yaw0)) > 0.4, "steering turns it")
	check(CoastMap.sailable(world.map, boat.pos2()), "still on the water")
	await shot("coast_pedal_boat", {"boat": boat.global_position + Vector3(0, 1, 0)})
	# Out on the open water: no.
	boat.place(Vector2(40, 215), 0.0)
	boat.speed = 0.0
	await wait(0.3)
	check(prompt() != "Aussteigen", "no 'Aussteigen' on the open water (%s)" % prompt())
	await press("interact")
	check(player().vehicle == boat, "still in the boat")
	check(toasted("kein Land"), "told to go to a jetty or the beach")
	# At the jetty: out onto the planks.
	boat.place(c.mooring(1), c.mooring_yaw(1))
	await wait(0.3)
	check(prompt() == "Aussteigen", "prompt to get out at the jetty (%s)" % prompt())
	await press("interact")
	check(player().vehicle == null, "out of the boat")
	var p := player().ground_pos()
	check(world.map.ground_at(p) == ParkMap.Ground.BRIDGE and absf(player().global_position.y - world.map.walk_height(p.x, p.y)) < 0.1,
		"standing on the jetty")
	check(GameState.has_in_set("boats_driven", "pedalo"), "the boat is counted as a boat, not a car")


## From the beach: a boat run up to the water's edge can be boarded from the sand, and one gets
## out onto the sand again.
func test_boat_at_the_beach() -> void:
	var c := await coast()
	c.moor_boats()
	var boat := c.boats[6]
	var x := -20.0
	var at := Vector2(x, CoastLayout.shore_z(x) + 1.6)
	check(CoastMap.sailable(world.map, at), "the water by the beach is deep enough for a boat")
	boat.place(at, 0.0)
	var sand := Vector2(x, CoastLayout.shore_z(x) - 0.6)
	check(not world.map.is_solid(sand), "one stands on the sand there")
	await put_player(_v(sand), boat.global_position)
	await wait(0.4)
	check(prompt().begins_with("Einsteigen"), "get in from the sand (%s)" % prompt())
	await press("interact")
	check(player().vehicle == boat, "in the boat")
	await wait(0.3)
	check(prompt() == "Aussteigen", "and out again at the beach (%s)" % prompt())
	await press("interact")
	check(player().vehicle == null and world.map.ground_at(player().ground_pos()) == ParkMap.Ground.SAND, "standing on the sand")
	c.moor_boats()


## Enough benches: along the promenade and the stands, at the dunes' foot, on the pier, the mole
## and the quay, at the bandstand and the campfire (besides the Strandkörbe); every one reachable
## from the Südtor, and one taken with "Aktion".
func test_benches() -> void:
	await coast()
	# Benches have three seats, the logs at the fire two (Strandkörbe two, stools one: not counted).
	var plain := world.coast_benches.filter(func(b: Bench) -> bool: return b.seats.size() == 3 or b.bench_id.begins_with("coast_log_"))
	var on_pier := plain.filter(func(b: Bench) -> bool: return b.position.z > CoastLayout.PIER_Z.x + 20.0 and absf(b.position.x) < 3.0)
	var on_mole := plain.filter(func(b: Bench) -> bool: return b.position.x > 120.0)
	check(plain.size() >= 45, "%d benches besides the Strandkörbe" % plain.size())
	check(on_pier.size() >= 4 and on_mole.size() >= 3, "on the pier (%d) and the mole (%d)" % [on_pier.size(), on_mole.size()])
	var from := _v(CoastLayout.GATE + Vector2(0, 3))
	var unreachable: Array[String] = []
	for bench: Bench in plain:
		var front := bench.position + Vector3(sin(bench.rotation.y), 0, cos(bench.rotation.y)) * 1.1
		var path := world.nav.find_path(from, front)
		if path.is_empty() or path[path.size() - 1].distance_to(front) > 1.5:
			unreachable.append("%s %v" % [bench.bench_id, Vector2(bench.position.x, bench.position.z).round()])
	check(unreachable.is_empty(), "every bench reachable (not: %s)" % str(unreachable))
	var b: Bench = on_pier[0]
	var f := b.position + Vector3(sin(b.rotation.y), 0, cos(b.rotation.y)) * 1.1
	await put_player(f, b.position)
	await wait(0.4)
	check(prompt().begins_with("Hinsetzen"), "prompt to sit (%s)" % prompt())
	await press("interact")
	await wait(1.0)
	check(player().seat != null and player().seat.owner_id == b.bench_id, "sitting on the pier")
	await shot("coast_pier_bench")


## Where boats may not go: onto the beach, past the buoys, under the pier.
func test_boats_stay_on_the_water() -> void:
	var c := await coast()
	c.moor_boats()
	var boat := c.boats[5]
	check(boat.kind == "rowboat", "a rowing boat")
	game.player.enter_car(boat)
	await frames(3)
	for t: Array in [["the beach", Vector2(20, CoastLayout.shore_z(20) + 7.0), PI],
			["the buoys", Vector2(30, CoastLayout.BUOY_Z - 5.0), 0.0],
			["the pier", Vector2(CoastLayout.PIER_X - 7.0, 205), PI / 2],
			["the groyne", Vector2(CoastLayout.GROYNES[1][0] + 5.0, CoastLayout.shore_z(36) + 6.0), -PI / 2]]:
		boat.place(t[1], t[2])
		boat.speed = 0.0
		await drive(1.0, 7.0)
		var ok := true
		for q in boat.corners(boat.pos2(), boat.yaw):
			ok = ok and CoastMap.sailable(world.map, q)
		check(ok, "the boat stops before %s (at %v)" % [t[0], boat.pos2().round()])
	# The oars move while rowing.
	var oar := boat.oars[0]
	boat.place(Vector2(40, 215), 0.0)
	var r0 := oar.rotation
	await drive(1.0, 0.6)
	check(oar.rotation.distance_to(r0) > 0.05, "the oars move while rowing")
	await shot("coast_rowboat", {"boat": boat.global_position + Vector3(0, 1, 0)})
	game.player.exit_car(true)
	c.moor_boats()


## The gulls: on the coast, playable like the ravens with a short flight.
func test_gulls() -> void:
	await coast()
	for id: String in ["jonathan", "kreischa", "pommes", "emma"]:
		var g := present(id)
		check(g.species == "gull" and ParkMap.in_coast(g.ground_pos()), "%s is a gull at the coast" % id)
	var gull := present("jonathan")
	var start := _v(Vector2(-10, 150))
	gull.teleport(start)
	game.player.control(gull)
	await frames(3)
	gull.face(start + Vector3(0, 0, 1), true)
	game.player.special()
	check(await wait_until(func() -> bool: return (gull.brain as AnimalBrain).state != "fly", 6.0), "the gull lands")
	var flown := Vector2(gull.global_position.x - start.x, gull.global_position.z - start.z).length()
	check(flown > 6.0, "the gull flew %.1f m" % flown)


## Visitors come to the coast in summer clothes, stroll the beach and sit in the Strandkörbe;
## none of them leaves it.
func test_visitors_on_the_beach() -> void:
	Clock.set_time(13.0)
	await coast()
	for a in world.actors:
		if a.home_region == "coast" and a.brain:
			UI.game.place_by_schedule(a)
	await wait(40.0)
	var here := world.actors.filter(func(a: Actor) -> bool: return a.home_region == "coast" and a.is_human() and not a.inside)
	check(here.size() >= 8, "%d visitors at the coast" % here.size())
	check(here.all(func(a: Actor) -> bool: return ParkMap.in_coast(a.ground_pos(), -1.0)), "all of them stay there")
	var on_sand := here.filter(func(a: Actor) -> bool: return world.map.ground_at(a.ground_pos()) == ParkMap.Ground.SAND)
	var seated := here.filter(func(a: Actor) -> bool: return a.seat != null)
	check(on_sand.size() + seated.size() >= 2, "some on the beach (%d) or sitting (%d)" % [on_sand.size(), seated.size()])


## The map: opened at the coast it shows the Möwenbucht with its places, the sea blue and the
## beach sandy; on the whole map a tap on the bay opens its map.
func test_map() -> void:
	await coast()
	await put_player(_v(CoastLayout.place("forecourt") + Vector2(0, 6)))
	await press("map")
	await frames(3)
	var ms: MapScreen = UI.map_screen
	check(ms.view == MapImage.COAST_VIEW, "the map opens on the coast")
	check(ms.title.text == "Strandkarte – Möwenbucht", "title (%s)" % ms.title.text)
	MapImage.texture(world.map)
	var img: Image = MapImage._image
	var sea := img.get_pixelv(Vector2i((Vector2(30, 240) - ParkMap.ORIGIN) * MapImage.SCALE))
	var sand := img.get_pixelv(Vector2i((Vector2(30, 150) - ParkMap.ORIGIN) * MapImage.SCALE))
	check(sea.b > sea.r + 0.15 and sand.r > sand.b + 0.1, "the sea blue (%s), the beach sandy (%s)" % [sea, sand])
	await shot("map_coast")
	check(await click_button("Gesamtkarte"), "the whole map")
	var at := ms.tex_rect.get_global_transform_with_canvas() * ms.world_to_map(Vector3(0, 0, 180))
	await click_at(at)
	check(ms.view == MapImage.COAST_VIEW, "a tap on the bay opens its map")
	UI.close_screens()
