class_name BurgMap
extends RefCounted
## Writes the Ritterburg (BurgLayout) into the ParkMap when it is loaded (World.load_area):
## heights of the hill, levelled plazas, paths, ground kinds of its cells, the walls, the rock
## and the fences as obstacles. The same rules as the city park (ParkMap), only with the
## castle's data.


static func build(map: ParkMap) -> void:
	var flats := []
	for key: String in BurgLayout.PLAZAS:
		var pl: Dictionary = BurgLayout.PLAZAS[key]
		flats.append([pl["pos"], float(pl["r"]), 3.0, BurgLayout.height(pl["pos"])])
	for key: String in ["lists", "paddock", "stable", "tug", "smithy"]:
		var area: Dictionary = BurgLayout.AREAS[key]
		flats.append([area["pos"], (area["size"] as Vector2).length() * 0.5, 4.0, BurgLayout.height(area["pos"])])
	# Vertex column PARK_X0 lies on the Nordwald's fence and belongs to the park, vertex row
	# FAIR_Z0 on the Westpark's fence and belongs to the Westpark.
	map.compute_heights(0, ParkMap.PARK_X0 - 1, 0, ParkMap.FAIR_Z0 - 1, flats)
	var polys := BurgLayout.path_polylines()
	map.paths.append_array(polys)
	map.raster_paths(polys, 0, ParkMap.PARK_X0)
	map.compute_ground(0, ParkMap.PARK_X0, 0, ParkMap.FAIR_Z0, BurgLayout.AREAS, BurgLayout.PLAZAS)
	_rock(map)
	_walls(map)
	_fences(map)
	map.burg_ready = true


## The castle's paths (the smoothed polylines in map.paths).
static func paths(map: ParkMap) -> Array:
	return map.paths.filter(func(p: Dictionary) -> bool: return (p["id"] as String).begins_with("burg_"))


## North of the castle the hill turns into the mountain: rock, nobody walks there.
static func _rock(map: ParkMap) -> void:
	for cz in range(0, ParkMap.FAIR_Z0):
		for cx in range(0, ParkMap.PARK_X0):
			var p := ParkMap.cell_center(Vector2i(cx, cz))
			var steep := p.y < BurgLayout.ROCK_Z and p.x > BurgLayout.WALL_W - 6.0 and p.x < BurgLayout.WALL_E + 6.0
			if steep or p.y < -266.0:
				map.ground[cz * ParkMap.W + cx] = ParkMap.Ground.ROCK
				map.solid[cz * ParkMap.W + cx] |= ParkMap.BLOCK_WALKERS


## The outer wall with the gate house, the inner wall with its gate (BurgLayout); the steps
## of the terrain under them stay hidden in the wall.
static func _walls(map: ParkMap) -> void:
	var t := BurgLayout.WALL_THICK
	for seg: Array in walls():
		map.add_obstacle_segment(seg[0], seg[1], t)


## Wall segments [a, b] with the openings left out: the outer wall (south with the gate house,
## west, east) and the inner wall.
static func walls() -> Array:
	var w := BurgLayout.WALL_W
	var e := BurgLayout.WALL_E
	var s := BurgLayout.WALL_S
	var top := BurgLayout.ROCK_Z
	var gx := BurgLayout.place("gatehouse").x
	var ig := BurgLayout.place("inner_gate").x
	var iz := BurgLayout.INNER_Z
	return [
		[Vector2(w, s), Vector2(gx - BurgLayout.GATE_HALF, s)], [Vector2(gx + BurgLayout.GATE_HALF, s), Vector2(e, s)],
		[Vector2(w, s), Vector2(w, top)], [Vector2(e, s), Vector2(e, top)],
		[Vector2(w, iz), Vector2(ig - BurgLayout.INNER_GATE_HALF, iz)], [Vector2(ig + BurgLayout.INNER_GATE_HALF, iz), Vector2(e, iz)],
	]


## The fences on the area's borders: Westpark (south) and Nordwald (east) with their gates, the
## west fence with the castle people's path.
static func _fences(map: ParkMap) -> void:
	var lo := ParkLayout.BURG_MIN
	var hi := ParkLayout.BURG_MAX
	var x := lo.x
	while x < hi.x:
		var x1 := minf(x + 1.0, hi.x)
		if absf((x + x1) * 0.5 - BurgLayout.GATE_SOUTH.x) >= 2.4:
			map.add_obstacle_rect(Vector2((x + x1) * 0.5, hi.y), Vector2(x1 - x, 0.6), 0.0, ParkMap.BLOCK_WALKERS)
		x = x1
	var z := lo.y
	while z < hi.y:
		var z1 := minf(z + 1.0, hi.y)
		if absf((z + z1) * 0.5 - BurgLayout.GATE_EAST.y) >= 2.4:
			map.add_obstacle_rect(Vector2(hi.x, (z + z1) * 0.5), Vector2(0.6, z1 - z), 0.0, ParkMap.BLOCK_WALKERS)
		z = z1
