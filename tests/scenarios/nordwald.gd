extends Scenario
## The Nordwald north of the park (doc/nordwald.md): reachable through the Waldtor,
## fenced in, with the dwarves' mountain at the north edge; park visitors stay out.


func test_walk_through_waldtor_to_lumber_camp() -> void:
	await put_player(place("gate_n") + Vector3(0, 0, 8), place("gate_n"))
	await shot("waldtor_from_park", {"player": head(player())})
	check(await walk_to(place("lumber_camp"), 200.0), "player walks from the park through the Waldtor to the lumber camp")
	check(ParkLayout.in_forest(player().ground_pos()), "player is in the Nordwald")
	await shot("lumber_camp", {"player": head(player())})


func test_walk_to_quarry_and_pond() -> void:
	await put_player(place("lumber_camp"))
	check(await walk_to(place("forest_pond") + Vector3(0, 0, 12), 200.0), "path to the forest pond")
	check(await walk_to(place("quarry"), 200.0), "path to the quarry")
	await shot("quarry", {"player": head(player())})


func test_mountain_and_fence_block() -> void:
	var m := ParkLayout.MOUNTAIN_CENTER
	var r := ParkLayout.MOUNTAIN_RADII
	check(world.map.is_solid(m + Vector2(0, r.y - 3.0)), "the mountain's foot is not walkable")
	check(not world.map.is_solid(place2("quarry")), "the quarry floor is walkable")
	# Walk north from the quarry into the mountain: the player stops at its foot.
	await put_player(place("mine_portal") + Vector3(0, 0, 10), place("mine_portal"))
	await move(Vector2(0, 1), 6.0)
	var p := player().ground_pos()
	check(((p - m) / r).length() > 0.98, "player stopped at the mountain (%.1f, %.1f)" % [p.x, p.y])
	# And the world ends at the north fence.
	await put_player(Vector3(-60, 0, ParkLayout.WORLD_MIN.y + 6.0), Vector3(-60, 0, ParkLayout.WORLD_MIN.y - 10.0))
	await move(Vector2(0, 1), 4.0)
	check(player().global_position.z > ParkLayout.WORLD_MIN.y, "player stays inside the north fence")


func test_forest_gate_open_and_map_view() -> void:
	await put_player(place("lumber_camp"))
	await press("map")
	check(UI.map_screen.visible and UI.map_screen.title.text.contains("Nordwald"), "map opens on the Nordwald view")
	await shot("map_forest")
	var ms := UI.map_screen
	var target := Vector3(-60, 0, -150)
	await click_at(ms.tex_rect.get_global_rect().position + ms.world_to_map(target))
	await wait(0.3)
	check(not ms.visible and player().is_moving(), "tapping the forest map walks there")
	UI.close_screens()
	await press("map")
	await click_button("Stadtpark")
	check(UI.map_screen.title.text.contains("Stadtpark"), "map switches to the city park")
	UI.close_screens()


## Visitors and park animals never go into the forest by themselves.
func test_visitors_stay_in_park() -> void:
	for t: Dictionary in [world.random_tree(), world.random_tree(), world.random_tree()]:
		check(not t["forest"], "random trees for squirrels and birds are in the park")
	var near_fence := Vector3(0, 0, ParkLayout.FOREST_EDGE + 4.0)
	var tree := world.nearest_tree(near_fence, 30.0)
	check(not tree.is_empty() and not tree["forest"], "nearest tree from the park side is a park tree")
	Clock.set_time(10.0)
	await wait(120.0)  # two game hours
	for a in world.actors:
		if not a.inside and not a.controlled:
			check(World.allowed(a, a.global_position), "%s stays out of the Nordwald" % a.actor_id)


func place2(id: String) -> Vector2:
	return ParkLayout.place(id)


## Park benches in the Nordwald: beside the roads, at the forest pond, in the berry glade and
## at the orchard. The player sits down on one (not counted for "Bankdrücker"), and a person
## of the Nordwald rests on one.
func test_forest_benches() -> void:
	var benches: Array[Bench] = []
	for b in world.forest_benches:
		if b.seats.size() == 3 and Vector2(b.position.x, b.position.z).distance_to(place2("forest_inn")) > 12.0:  # not the terrace
			benches.append(b)
	check(benches.size() >= 8, "park benches in the Nordwald (%d)" % benches.size())
	var near := func(p: Vector2, r: float) -> Bench:
		for b in benches:
			if Vector2(b.position.x, b.position.z).distance_to(p) < r:
				return b
		return null
	check(near.call(ParkLayout.FOREST_POND_CENTER, ParkLayout.FOREST_POND_RADII.x + 8.0) != null, "a bench at the forest pond")
	check(near.call(place2("orchard"), 15.0) != null, "a bench at the orchard")
	var glade: Bench = near.call(place2("berry_glade"), 6.0)
	check(glade != null, "a bench in the berry glade")
	var roadside := benches.filter(func(b: Bench) -> bool:
		for id: String in ["forest_pond", "orchard", "berry_glade"]:
			if Vector2(b.position.x, b.position.z).distance_to(place2(id)) < 20.0:
				return false
		return true)
	check(roadside.size() >= 4, "benches beside the forest roads (%d)" % roadside.size())
	for b in benches:
		var p := Vector2(b.position.x, b.position.z)
		var f := p + Vector2(sin(b.rotation.y), cos(b.rotation.y)) * 1.3
		check(ParkLayout.in_forest(p) and not world.map.is_solid(f), "%s can be reached from the front (%s)" % [b.bench_id, p])
	await shot("forest_bench", {"bench": glade.position + Vector3(0, 0.6, 0)})
	# The player sits down in the glade.
	var a := player()
	var front := glade.position + Vector3(sin(glade.rotation.y), 0, cos(glade.rotation.y)) * 1.2
	await put_player(front, glade.position)
	await wait(0.4)
	check(prompt().begins_with("Hinsetzen"), "prompt offers sitting (got '%s')" % prompt())
	await press("interact")
	await wait(1.0)
	check(a.seat != null and a.seat.owner_id == glade.bench_id, "the player sits on the glade bench")
	check(not GameState.has_in_set("benches", glade.bench_id), "not counted for Bankdrücker")
	await press("interact")
	await wait(0.5)
	# A person of the Nordwald rests on a forest bench.
	var hanna := present("hanna")
	var road: Bench = roadside[0]
	hanna.brain.suspend()
	hanna.teleport(road.position + Vector3(sin(road.rotation.y), 0, cos(road.rotation.y)) * 4.0)
	(hanna.brain as HumanBrain)._start(Activities.Sit.new(["bench"], 60.0, "idle", road.position))
	check(await wait_until(func() -> bool: return hanna.seat != null, 60.0), "Hanna sits down")
	check(hanna.seat != null and hanna.seat.owner_id == road.bench_id, "on the bench beside the road (%s)" % (hanna.seat.owner_id if hanna.seat else "-"))
