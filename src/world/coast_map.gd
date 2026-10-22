class_name CoastMap
extends RefCounted
## Writes the Möwenbucht (CoastLayout) into the ParkMap when it is loaded (World.load_area):
## the sea's distance and the heights of beach, dunes and sea floor, paths, ground kinds (sand,
## water, the quay's and the mole's stone, rock), the decks of the pier and the jetty, the fence
## to the park and the groynes as obstacles.

const G := ParkMap.Ground


static func build(map: ParkMap) -> void:
	var x0 := ParkMap.PARK_X0
	var x1 := ParkMap.CITY_X0
	# Vertex row COAST_Z0 lies on the park's fence and belongs to the park.
	for vz in range(ParkMap.COAST_Z0 + 1, ParkMap.H + 1):
		for vx in range(x0, x1 + 1):
			var p := ParkMap.ORIGIN + Vector2(vx, vz)
			var idx := vz * (ParkMap.W + 1) + vx
			map.water_dist[idx] = CoastLayout.land_dist(p)
			map.heights[idx] = CoastLayout.height(p)
	_flatten(map)
	var polys := CoastLayout.path_polylines()
	map.paths.append_array(polys)
	map.raster_paths(polys, x0, x1)
	map.decks.append_array(CoastLayout.decks())
	map.compute_ground(x0, x1, ParkMap.COAST_Z0, ParkMap.H, CoastLayout.AREAS, CoastLayout.PLAZAS)
	for cz in range(ParkMap.COAST_Z0, ParkMap.H):
		for cx in range(x0, x1):
			var idx := cz * ParkMap.W + cx
			var p := ParkMap.cell_center(Vector2i(cx, cz))
			var kind := map.ground[idx]
			if not is_nan(map.deck_height(p)) or _on_boardwalk(p):
				map.ground[idx] = G.BRIDGE
			elif CoastLayout.in_rocks(p, -0.3):
				map.ground[idx] = G.ROCK
				map.solid[idx] |= ParkMap.BLOCK_ALL
			elif kind == G.WATER:
				continue
			elif CoastLayout.mole_dist(p) < CoastLayout.MOLE_HALF + 0.3:
				map.ground[idx] = G.PLAZA
			elif kind == G.GRASS or kind == G.BANK:
				map.ground[idx] = G.SAND if p.y > CoastLayout.PROMENADE_Z + 3.0 else G.GRASS
	_groynes(map)
	_fences(map)
	map.coast_ready = true


## Levels the round plazas (the forecourt, the bandstand).
static func _flatten(map: ParkMap) -> void:
	for key: String in CoastLayout.PLAZAS:
		var pl: Dictionary = CoastLayout.PLAZAS[key]
		var c: Vector2 = pl["pos"]
		var r: float = pl["r"]
		var reach := r + 3.0
		var y := CoastLayout.height(c)
		for vz in range(maxi(ParkMap.COAST_Z0 + 1, int(c.y - reach - ParkMap.ORIGIN.y)), mini(ParkMap.H, int(c.y + reach - ParkMap.ORIGIN.y) + 1) + 1):
			for vx in range(int(c.x - reach - ParkMap.ORIGIN.x), int(c.x + reach - ParkMap.ORIGIN.x) + 2):
				var d := (ParkMap.ORIGIN + Vector2(vx, vz)).distance_to(c)
				if d < reach:
					var idx := vz * (ParkMap.W + 1) + vx
					map.heights[idx] = lerpf(y, map.heights[idx], smoothstep(r, reach, d))


## The boardwalks over the dunes: from the promenade's edge to the beach.
static func _on_boardwalk(p: Vector2) -> bool:
	if p.y < CoastLayout.PROMENADE_Z + 2.0 or p.y > CoastLayout.DUNES.y + 1.5:
		return false
	for x: float in CoastLayout.BOARDWALKS:
		if absf(p.x - x) <= 1.2:
			return true
	return false


## The groynes: rows of posts from the beach into the sea, in the boats' way.
static func _groynes(map: ParkMap) -> void:
	for g: Array in CoastLayout.GROYNES:
		var a := groyne_start(g[0])
		map.add_obstacle_segment(a, a + Vector2(0, g[1]), 0.8, ParkMap.BLOCK_ALL)


## Where a groyne at x leaves the beach (a few metres above the water's edge).
static func groyne_start(x: float) -> Vector2:
	return Vector2(x, CoastLayout.shore_z(x) - 6.0)


## The fence to the park along z = COAST_EDGE, open at the Südtor.
static func _fences(map: ParkMap) -> void:
	var z := ParkLayout.COAST_EDGE
	var x := ParkLayout.COAST_MIN.x
	while x < ParkLayout.COAST_MAX.x:
		var x1 := minf(x + 1.0, ParkLayout.COAST_MAX.x)
		if absf((x + x1) * 0.5 - CoastLayout.GATE.x) >= 2.4:
			map.add_obstacle_rect(Vector2((x + x1) * 0.5, z), Vector2(x1 - x, 0.6), 0.0, ParkMap.BLOCK_WALKERS)
		x = x1


## The coast's paths (the smoothed polylines in map.paths).
static func paths(map: ParkMap) -> Array:
	return map.paths.filter(func(p: Dictionary) -> bool: return (p["id"] as String).begins_with("coast_"))


## A boat may be here: water inside the buoys, deep enough, not under the pier or the jetty,
## clear of the groynes, the mole and the sandbank.
static func sailable(map: ParkMap, p: Vector2) -> bool:
	if not (map.coast_ready and map.coast_open) or not CoastLayout.in_bay(p, 0.5) or not ParkMap.in_coast(p, 0.5):
		return false
	var c := ParkMap.to_cell(p)
	var idx := c.y * ParkMap.W + c.x
	if map.ground[idx] != G.WATER or (map.solid[idx] & ParkMap.BLOCK_CARS) != 0:
		return false
	return map.height_at(p.x, p.y) < ParkLayout.WATER_Y - 0.35
