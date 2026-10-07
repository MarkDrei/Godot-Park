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
