extends TestCase

var map: ParkMap


func before_all() -> void:
	var t0 := Time.get_ticks_msec()
	map = ParkMap.new()
	var t1 := Time.get_ticks_msec()
	map.build_navigation()
	print("    ParkMap built in %d ms, navigation in %d ms, %d bridges" % [t1 - t0, Time.get_ticks_msec() - t1, map.bridges.size()])
	for b in map.bridges:
		print("    bridge %s at %s len %.1f style %s" % [b["name"], b["center"], b["length"], b["style"]])


func test_pond_is_water() -> void:
	check(map.is_water(ParkLayout.POND_CENTER + Vector2(-8, 0)), "pond centre-west should be water")
	check(not map.is_water(ParkLayout.ISLAND_CENTER), "island is land")
	check(map.height_at(30, -40) > ParkLayout.WATER_Y + 0.2, "meadow above water")


func test_bridges_cross_creek() -> void:
	check(map.bridges.size() >= 4, "expected at least 4 bridges, got %d" % map.bridges.size())
	for b in map.bridges:
		var deck := map.walk_height(b["center"].x, b["center"].y)
		check(deck > ParkLayout.WATER_Y + 0.3, "bridge deck above water")


func test_all_places_reachable() -> void:
	var grid := map.grid(ParkMap.Nav.HUMAN)
	var start := ParkMap.to_cell(ParkLayout.place("gate_s") + Vector2(0, -6))
	for id: String in ParkLayout.PLACES:
		if id in ["island", "pier"]:
			continue
		var target := ParkMap.to_cell(ParkLayout.place(id))
		if grid.is_point_solid(target):
			continue
		var path := grid.get_id_path(start, target)
		check(path.size() > 0, "no path to %s" % id)
	var island_path := grid.get_id_path(start, ParkMap.to_cell(ParkLayout.ISLAND_CENTER))
	check(island_path.size() > 0, "island reachable over stepping stones")


func test_navigator_paths_prefer_paths() -> void:
	var nav := Navigator.new(map)
	var a := Vector3(-3, 0, 9)
	var b := Vector3(6, 0, 48)
	var path := nav.find_path(a, b)
	check(path.size() >= 2, "path found between hub and food court")
	var on_path := 0
	for p in path:
		if map.path_dist_at(Vector2(p.x, p.z)) < 1.0:
			on_path += 1
	check(on_path >= path.size() * 0.6, "people mostly stay on paths (%d/%d)" % [on_path, path.size()])
	for i in range(1, path.size()):
		check(nav.line_clear(Vector2(path[i - 1].x, path[i - 1].z), Vector2(path[i].x, path[i].z)), "smoothed segment %d is clear" % i)


func test_water_navigation_for_ducks() -> void:
	var nav := Navigator.new(map)
	var a := Vector3(ParkLayout.POND_CENTER.x - 10, 0, ParkLayout.POND_CENTER.y)
	var b := Vector3(ParkLayout.POND_CENTER.x + 10, 0, ParkLayout.POND_CENTER.y + 3)
	var path := nav.find_path(a, b, ParkMap.Nav.WATER)
	check(path.size() >= 1, "ducks can swim across the pond")
	for p in path:
		check(map.is_water(Vector2(p.x, p.z)), "water path stays in water")


func test_heights_continuous() -> void:
	var worst := 0.0
	for i in 2000:
		var x := randf_range(-125, 125)
		var z := randf_range(-85, 85)
		worst = maxf(worst, absf(map.height_at(x, z) - map.height_at(x + 0.25, z)))
	check(worst < 0.6, "terrain has no cliffs (max step %.2f)" % worst)
