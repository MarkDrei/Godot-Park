class_name Navigator
extends RefCounted
## Path queries on the ParkMap grids, with cost-aware string pulling so that
## people still prefer paths while not walking in staircase patterns.

var map: ParkMap

## Path searches of the current physics tick (busy): a search in the town can take tens of ms
## in the browser, and a crowd deciding at once stalled the game for a few hundred.
const TICK_BUDGET_US := 4000
## Scenario tests (DevOptions scenario=) count searches instead of timing them: the wall clock
## depends on the machine's load, and with three test jobs at once the brains waited other ticks
## than alone, so the same seed played differently. One search per tick is what the time budget
## allows natively (a search takes ~4–5 ms). (Godot keeps --fixed-fps out of get_cmdline_args.)
const TICK_BUDGET_SEARCHES := 1
static var counted := false
static var _tick := -1
static var _tick_us := 0
static var _tick_n := 0


## This physics tick's path searches used the budget already: brains wait a tick.
static func busy() -> bool:
	if _tick != Engine.get_physics_frames():
		return false
	return _tick_n >= TICK_BUDGET_SEARCHES if counted else _tick_us >= TICK_BUDGET_US


func _init(park_map: ParkMap) -> void:
	map = park_map


## Returns world-space waypoints (y = walk height) from `from` to `to`, or empty.
func find_path(from: Vector3, to: Vector3, nav := ParkMap.Nav.HUMAN) -> PackedVector3Array:
	var t0 := Time.get_ticks_usec()
	var out := _find_path(from, to, nav)
	var tick := Engine.get_physics_frames()
	if tick != _tick:
		_tick = tick
		_tick_us = 0
		_tick_n = 0
	_tick_us += Time.get_ticks_usec() - t0
	_tick_n += 1
	return out


func _find_path(from: Vector3, to: Vector3, nav: int) -> PackedVector3Array:
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


## String pulling: from each waypoint, jump to (nearly) the farthest of the next 24 that a
## straight line reaches without costing more than walking along the cells (_shortcut_ok).
## This was the cost of a path (~95 %, A* itself is native): long paths in the town took
## 25 ms and more natively, several times that in the browser. The samples therefore read the
## map's arrays directly (_open_at, _cost) instead of calling is_solid and cell_cost.
func _smooth(pts: PackedVector2Array, nav: int) -> PackedVector2Array:
	if pts.size() <= 2:
		return pts
	_begin(nav)
	# Cost of walking along the cells up to each waypoint: a shortcut's alternative is the
	# difference of two of these.
	var along := PackedFloat64Array([0.0])
	for k in pts.size() - 1:
		along.append(along[k] + _cost(_cell_index(pts[k + 1])) * pts[k].distance_to(pts[k + 1]))
	var out := PackedVector2Array([pts[0]])
	var i := 0
	while i < pts.size() - 1:
		# The farthest shortcut first; else a binary search between the next waypoint (always
		# fine) and the farthest that failed: ~5 tests instead of up to 23 (a path of the town
		# took ~4 ms natively). Not always the farthest one that works, nearly as straight.
		var best := i + 1
		var bad := mini(pts.size() - 1, i + 24)
		if bad > best and _shortcut_ok(pts[i], pts[bad], (along[bad] - along[i]) * 1.02, nav):
			best = bad
		else:
			while bad - best > 1:
				var j := (best + bad) / 2
				if _shortcut_ok(pts[i], pts[j], (along[j] - along[i]) * 1.02, nav):
					best = j
				else:
					bad = j
		out.append(pts[best])
		i = best
	return out


## A straight line from a to b is clear (with room on both sides) and costs at most `limit`.
## Hot loop (~20 samples per path cell): the map lookups are written out here.
func _shortcut_ok(a: Vector2, b: Vector2, limit: float, nav: int) -> bool:
	var length := a.distance_to(b)
	var steps := int(length / 0.3) + 1
	var step_len := length / steps
	# Walkers switch to the next waypoint before reaching the corner and cut it by up to
	# ~0.6 m: a shortcut needs that much room on both sides (Sabine at the playground).
	var side := (b - a).normalized().orthogonal() * 0.65
	var ground := _ground
	var areas := _areas
	var costs := _costs
	var direct := 0.0
	for s in steps:
		var p := a.lerp(b, (s + 0.5) / steps)
		var idx := clampi(int(floor(p.y - ParkMap.ORIGIN.y)), 0, ParkMap.H - 1) * ParkMap.W \
			+ clampi(int(floor(p.x - ParkMap.ORIGIN.x)), 0, ParkMap.W - 1)
		if _human:
			var c := costs[ground[idx]]
			direct += (c if c >= 0.0 else map.cell_cost(ground[idx], nav, _path_dist[idx])) * step_len
		else:
			direct += step_len
		# The cost only grows: stop as soon as walking along the cells is cheaper.
		if direct > limit:
			return false
		var area := areas[idx]
		if area >= Area.PARK and _area_open[area] and nav != ParkMap.Nav.WATER:
			if ground[idx] == ParkMap.Ground.WATER or (_solid[idx] & _block) != 0:
				return false
		elif not _open_at(p, idx, nav):
			return false
		var q := p + side
		if not _open_at(q, _cell_index(q), nav):
			return false
		q = p - side
		if not _open_at(q, _cell_index(q), nav):
			return false
	return true


# --- Fast map lookups for _smooth (same answers as ParkMap.is_solid and cell_cost) ---------

enum Area { UNKNOWN, EDGE, PARK, CITY, FAIR, BURG }

## Per cell, lazily: the area its every point belongs to for is_solid, or EDGE where a cell
## lies near a world edge (in_bounds' margin) or on an area border; those ask is_solid.
var _areas := PackedByteArray()
var _area_open := [false, false, false, false, false, false]   # by Area, set by _begin
var _ground: PackedByteArray
var _solid: PackedByteArray
var _path_dist: PackedFloat32Array
var _block := 0
var _human := true
var _costs := PackedFloat32Array()   # HUMAN cost by ground kind (-1: depends on path_dist)


func _begin(nav: int) -> void:
	if _areas.is_empty():
		_areas.resize(ParkMap.W * ParkMap.H)
		for kind in ParkMap.Ground.size():
			var near := map.cell_cost(kind, ParkMap.Nav.HUMAN, 0.0)
			_costs.append(near if near == map.cell_cost(kind, ParkMap.Nav.HUMAN, 99.0) else -1.0)
	_area_open[Area.PARK] = map.park_open
	_area_open[Area.CITY] = map.city_ready and map.city_open
	_area_open[Area.FAIR] = map.fair_ready and map.fair_open
	_area_open[Area.BURG] = map.burg_ready and map.burg_open
	_ground = map.ground
	_solid = map.solid
	_path_dist = map.path_dist
	_human = nav == ParkMap.Nav.HUMAN
	_block = ParkMap.BLOCK_ANIMALS if nav == ParkMap.Nav.ANIMAL else ParkMap.BLOCK_PEOPLE


static func _cell_index(p: Vector2) -> int:
	return clampi(int(floor(p.y - ParkMap.ORIGIN.y)), 0, ParkMap.H - 1) * ParkMap.W \
		+ clampi(int(floor(p.x - ParkMap.ORIGIN.x)), 0, ParkMap.W - 1)


func _cost(idx: int) -> float:
	if not _human:
		return 1.0
	var c := _costs[_ground[idx]]
	return c if c >= 0.0 else map.cell_cost(_ground[idx], ParkMap.Nav.HUMAN, _path_dist[idx])


## not map.is_solid(p, nav), p in cell idx.
func _open_at(p: Vector2, idx: int, nav: int) -> bool:
	var area := _areas[idx]
	if area == Area.UNKNOWN:
		area = _area_of(idx)
		_areas[idx] = area
	if area == Area.EDGE:
		return not map.is_solid(p, nav)
	if not _area_open[area]:
		return false
	var kind := _ground[idx]
	if nav == ParkMap.Nav.WATER:
		return kind == ParkMap.Ground.WATER
	return kind != ParkMap.Ground.WATER and (_solid[idx] & _block) == 0


## Every point of a 1 m cell lies within 0.71 m of its centre: the centre 0.6 + 0.71 m inside
## the world means each point passes in_bounds; 0.51 m off the area borders keeps the cell in one area.
func _area_of(idx: int) -> int:
	var c := ParkMap.cell_center(Vector2i(idx % ParkMap.W, idx / ParkMap.W))
	if absf(c.x - ParkLayout.CITY_EDGE) < 0.51 or absf(c.x - ParkLayout.FAIR_EDGE) < 0.51 \
			or (c.x < ParkLayout.FAIR_EDGE + 0.51 and absf(c.y - ParkLayout.FOREST_EDGE) < 0.51) \
			or not ParkMap.in_bounds(c, 0.6 + 0.71):
		return Area.EDGE
	match ParkLayout.area_at(c):
		"city":
			return Area.CITY
		"fair":
			return Area.FAIR
		"burg":
			return Area.BURG
	return Area.PARK


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
