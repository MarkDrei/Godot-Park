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
