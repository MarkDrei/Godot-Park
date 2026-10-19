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


## The mountain's front reaches into the area from the north: rock, nobody walks there.
static func _rock(map: ParkMap) -> void:
	for cz in range(0, ParkMap.FAIR_Z0):
		for cx in range(0, ParkMap.PARK_X0):
			var p := ParkMap.cell_center(Vector2i(cx, cz))
			if BurgLayout.in_mountain(p, -0.5) or p.y < -266.0:
				map.ground[cz * ParkMap.W + cx] = ParkMap.Ground.ROCK
				map.solid[cz * ParkMap.W + cx] |= ParkMap.BLOCK_WALKERS


## The outer wall with the gate house, the inner wall with its gate (BurgLayout); the steps
## of the terrain under them stay hidden in the wall.
static func _walls(map: ParkMap) -> void:
	var t := BurgLayout.WALL_THICK
	for seg: Array in walls():
		map.add_obstacle_segment(seg[0], seg[1], t)


## Wall segments [a, b] with the openings left out: the outer wall (its polygon, the gate
## house's gap in the south wall) and the inner wall's arc (pieces of ~4 m, its gate's gap).
static func walls() -> Array:
	var out := []
	var o: Array = BurgLayout.OUTER
	var gx := BurgLayout.place("gatehouse").x
	for i in o.size() - 1:
		var a: Vector2 = o[i]
		var b: Vector2 = o[i + 1]
		if absf(a.y - BurgLayout.WALL_S) < 0.1 and absf(b.y - BurgLayout.WALL_S) < 0.1:
			var l := minf(a.x, b.x)
			var r := maxf(a.x, b.x)
			out.append([Vector2(l, a.y), Vector2(gx - BurgLayout.GATE_HALF, a.y)])
			out.append([Vector2(gx + BurgLayout.GATE_HALF, a.y), Vector2(r, a.y)])
		else:
			out.append([a, b])
	for side: float in [-1.0, 1.0]:
		var prev := Vector2.INF
		for k in 13:
			# From the gate (straight south of the centre) round to the rock.
			var ang := PI / 2 + side * (deg_to_rad(7.5) + k * deg_to_rad(5.5))
			var q := BurgLayout.INNER_C + Vector2(cos(ang), sin(ang)) * BurgLayout.INNER_R
			if BurgLayout.in_mountain(q, 1.0):
				break
			if prev != Vector2.INF:
				out.append([prev, q])
			prev = q
	return out


## Towers: at the outer wall's corners and where the walls meet the rock.
static func towers() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in BurgLayout.OUTER.size():
		if i == 1 or i == BurgLayout.OUTER.size() - 2:
			continue
		out.append(BurgLayout.OUTER[i])
	return out


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
