class_name Navigator
extends RefCounted
## Path queries on the ParkMap grids, with cost-aware string pulling so that
## people still prefer paths while not walking in staircase patterns.

var map: ParkMap


func _init(park_map: ParkMap) -> void:
	map = park_map


## Returns world-space waypoints (y = walk height) from `from` to `to`, or empty.
func find_path(from: Vector3, to: Vector3, nav := ParkMap.Nav.HUMAN) -> PackedVector3Array:
	var grid := map.grid(nav)
	var a := nearest_open(Vector2(from.x, from.z), nav)
	var b := nearest_open(Vector2(to.x, to.z), nav)
	if a.x < 0 or b.x < 0:
		return PackedVector3Array()
	var cells := grid.get_id_path(a, b)
	if cells.is_empty():
		return PackedVector3Array()
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(ParkMap.cell_center(c))
	pts[pts.size() - 1] = Vector2(to.x, to.z) if not map.is_solid(Vector2(to.x, to.z), nav) else pts[pts.size() - 1]
	pts = _smooth(pts, nav)
	var out := PackedVector3Array()
	for p in pts:
		out.append(Vector3(p.x, map.walk_height(p.x, p.y), p.y))
	return out


## Closest non-solid cell (spiral search), or (-1, -1).
func nearest_open(p: Vector2, nav := ParkMap.Nav.HUMAN, max_radius := 8) -> Vector2i:
	var grid := map.grid(nav)
	var c := ParkMap.to_cell(p)
	if not grid.is_point_solid(c):
		return c
	for r in range(1, max_radius + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var q := c + Vector2i(dx, dz)
				if q.x < 0 or q.y < 0 or q.x >= ParkMap.W or q.y >= ParkMap.H:
					continue
				if grid.is_point_solid(q):
					continue
				var d := ParkMap.cell_center(q).distance_squared_to(p)
				if d < best_d:
					best_d = d
					best = q
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func _smooth(pts: PackedVector2Array, nav: int) -> PackedVector2Array:
	if pts.size() <= 2:
		return pts
	var out := PackedVector2Array([pts[0]])
	var i := 0
	while i < pts.size() - 1:
		var best := i + 1
		var j := mini(pts.size() - 1, i + 24)
		while j > i + 1:
			if _shortcut_ok(pts, i, j, nav):
				best = j
				break
			j -= 1
		out.append(pts[best])
		i = best
	return out


func _shortcut_ok(pts: PackedVector2Array, i: int, j: int, nav: int) -> bool:
	var a := pts[i]
	var b := pts[j]
	var length := a.distance_to(b)
	var steps := int(length / 0.5) + 1
	var direct := 0.0
	for s in steps:
		var p := a.lerp(b, (s + 0.5) / steps)
		if map.is_solid(p, nav):
			return false
		var c := ParkMap.to_cell(p)
		direct += map.cell_cost(map.ground[c.y * ParkMap.W + c.x], nav, map.path_dist[c.y * ParkMap.W + c.x]) * length / steps
	var along := 0.0
	for k in range(i, j):
		var c := ParkMap.to_cell(pts[k + 1])
		along += map.cell_cost(map.ground[c.y * ParkMap.W + c.x], nav, map.path_dist[c.y * ParkMap.W + c.x]) * pts[k].distance_to(pts[k + 1])
	return direct <= along * 1.02


## Straight line free of obstacles?
func line_clear(a: Vector2, b: Vector2, nav := ParkMap.Nav.HUMAN) -> bool:
	var steps := int(a.distance_to(b) / 0.5) + 1
	for s in steps + 1:
		if map.is_solid(a.lerp(b, float(s) / steps), nav):
			return false
	return true


## Random walkable point within `radius` of `center`.
func random_point_near(center: Vector2, radius: float, rng: RandomNumberGenerator, nav := ParkMap.Nav.HUMAN) -> Vector2:
	for i in 20:
		var p := center + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		if not map.is_solid(p, nav):
			return p
	return center
