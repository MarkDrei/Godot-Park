class_name ParkMap
extends RefCounted
## Runtime representation of the park, derived from ParkLayout:
## height field, water distance, ground kinds, bridges, obstacles and the
## navigation grids. One instance per game, reachable through ParkMap.current.

enum Ground { GRASS, PATH, GRAVEL, SAND, WATER, BANK, PLAZA, TRAIL, BRIDGE, STONES, ROCK }

const CELL := 1.0
const W := 260
const H := 360
const ORIGIN := Vector2(-130, -270)
const BED_Y := -1.15

## Navigation profiles.
enum Nav { HUMAN, ANIMAL, WATER }

static var current: ParkMap

var heights := PackedFloat32Array()      # (W+1) * (H+1) vertex heights
var water_dist := PackedFloat32Array()   # (W+1) * (H+1) signed distance to water (negative = water)
var ground := PackedByteArray()          # W * H cell kinds
var path_dist := PackedFloat32Array()    # W * H distance to nearest path edge (<= 0 on a path)
var path_kind := PackedByteArray()       # W * H kind of the nearest path (0 main, 1 side, 2 trail)
var solid := PackedByteArray()           # W * H obstacle flags (bit 0 humans, bit 1 animals)
var bridges: Array[Dictionary] = []
var platforms: Array[Dictionary] = []    # raised walkable discs: {center, radius, height}
var paths: Array = []                     # smoothed path polylines from ParkLayout
var creek: PackedVector2Array
var creek_out: PackedVector2Array
var brook: PackedVector2Array            # Nordwald brook into the forest pond

var _grids := {}                          # Nav -> AStarGrid2D


func _init() -> void:
	current = self
	paths = ParkLayout.path_polylines()
	creek = ParkLayout.creek_polyline()
	creek_out = ParkLayout.creek_out_polyline()
	brook = ParkLayout.brook_polyline()
	_compute_water()
	_compute_heights()
	_compute_paths()
	_find_bridges()
	_compute_ground()
	solid.resize(W * H)
	solid.fill(0)


# --- Height and water -------------------------------------------------------

static func base_height(p: Vector2) -> float:
	var h := 0.22 * sin(p.x * 0.047 + 1.3) * cos(p.y * 0.066) + 0.14 * sin(p.x * 0.13 + p.y * 0.11) + 0.3
	for hill: Dictionary in ParkLayout.HILLS:
		var d2 := p.distance_squared_to(hill["pos"])
		var s: float = hill["s"]
		if d2 < 18.0 * s * s:  # beyond that the hill adds less than 0.01 %
			h += hill["h"] * exp(-d2 / (2.0 * s * s))
	# Fade towards street level at the fence.
	var lo := ParkLayout.WORLD_MIN
	var hi := ParkLayout.WORLD_MAX
	var edge := minf(minf(p.x - lo.x, hi.x - p.x), minf(p.y - lo.y, hi.y - p.y))
	return h * clampf(edge / 6.0, 0.0, 1.0)


## Creek, outflow and forest brook.
func water_lines() -> Array[PackedVector2Array]:
	return [creek, creek_out, brook]


func _compute_water() -> void:
	water_dist.resize((W + 1) * (H + 1))
	water_dist.fill(99.0)
	var reach := ParkLayout.CREEK_HALF_WIDTH + ParkLayout.BANK_WIDTH + 2.0
	for line: PackedVector2Array in water_lines():
		for i in line.size() - 1:
			_raster_segment_dist(line[i], line[i + 1], reach, i)
	for pond: Array in ParkLayout.ponds():
		_raster_pond(pond[0], pond[1])


## Signed distance of an elliptic pond (the city pond has the island).
func _raster_pond(c: Vector2, r: Vector2) -> void:
	var margin := ParkLayout.BANK_WIDTH + 2.0
	for vz in range(int(c.y - r.y - margin - ORIGIN.y), int(c.y + r.y + margin - ORIGIN.y) + 1):
		for vx in range(int(c.x - r.x - margin - ORIGIN.x), int(c.x + r.x + margin - ORIGIN.x) + 1):
			if vx < 0 or vz < 0 or vx > W or vz > H:
				continue
			var p := ORIGIN + Vector2(vx, vz)
			var q := (p - c) / r
			var k := q.length()
			var d := 0.0
			if k > 0.0001:
				d = (p - c).length() * (1.0 - 1.0 / k)
			else:
				d = -minf(r.x, r.y)
			var island := ParkLayout.ISLAND_RADIUS - p.distance_to(ParkLayout.ISLAND_CENTER)
			d = maxf(d, island)
			var idx := vz * (W + 1) + vx
			water_dist[idx] = minf(water_dist[idx], d)


func _raster_segment_dist(a: Vector2, b: Vector2, reach: float, index: int) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach) - ORIGIN
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach) - ORIGIN
	# Slightly varying creek width for a natural look.
	var half := ParkLayout.CREEK_HALF_WIDTH + 0.5 * sin(index * 0.37)
	for vz in range(maxi(0, int(lo.y)), mini(H, int(hi.y)) + 1):
		for vx in range(maxi(0, int(lo.x)), mini(W, int(hi.x)) + 1):
			var p := ORIGIN + Vector2(vx, vz)
			var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) - half
			var idx := vz * (W + 1) + vx
			if d < water_dist[idx]:
				water_dist[idx] = d


## Regions levelled for plazas and play areas: [centre, radius, blend, height].
func _flat_regions() -> Array:
	var out := []
	for key: String in ParkLayout.PLAZAS:
		var pl: Dictionary = ParkLayout.PLAZAS[key]
		out.append([pl["pos"], float(pl["r"]), 4.0, base_height(pl["pos"])])
	for key: String in ParkLayout.AREAS:
		var area: Dictionary = ParkLayout.AREAS[key]
		var size: Vector2 = area["size"]
		out.append([area["pos"], size.length() * 0.5, 4.0, base_height(area["pos"])])
	return out


func _compute_heights() -> void:
	heights.resize((W + 1) * (H + 1))
	for vz in H + 1:
		for vx in W + 1:
			heights[vz * (W + 1) + vx] = base_height(ORIGIN + Vector2(vx, vz))
	# Level plazas and play areas, each only within its own bounding box.
	for f: Array in _flat_regions():
		var c: Vector2 = f[0]
		var reach: float = f[1] + f[2]
		for vz in range(maxi(0, int(c.y - reach - ORIGIN.y)), mini(H, int(c.y + reach - ORIGIN.y) + 1) + 1):
			for vx in range(maxi(0, int(c.x - reach - ORIGIN.x)), mini(W, int(c.x + reach - ORIGIN.x) + 1) + 1):
				var d := (ORIGIN + Vector2(vx, vz)).distance_to(c)
				if d < reach:
					var idx := vz * (W + 1) + vx
					heights[idx] = lerpf(f[3], heights[idx], smoothstep(f[1], reach, d))
	for vz in H + 1:
		for vx in W + 1:
			var p := ORIGIN + Vector2(vx, vz)
			var idx := vz * (W + 1) + vx
			var base := heights[idx]
			var d := water_dist[idx]
			var shore := ParkLayout.WATER_Y - 0.12
			var h := base
			if d < 0.0:
				h = lerpf(shore, BED_Y, smoothstep(0.0, 2.2, -d))
			elif d < ParkLayout.BANK_WIDTH:
				h = lerpf(shore, base, smoothstep(0.0, ParkLayout.BANK_WIDTH, d))
			var island := ParkLayout.ISLAND_RADIUS - p.distance_to(ParkLayout.ISLAND_CENTER)
			if island > 0.0:
				h += 0.35 * smoothstep(0.0, 3.0, island)
			heights[idx] = h


## Terrain height (bilinear).
func height_at(x: float, z: float) -> float:
	var fx := clampf(x - ORIGIN.x, 0.0, W - 0.001)
	var fz := clampf(z - ORIGIN.y, 0.0, H - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i0 := iz * (W + 1) + ix
	var i1 := i0 + W + 1
	var top := lerpf(heights[i0], heights[i0 + 1], tx)
	var bottom := lerpf(heights[i1], heights[i1 + 1], tx)
	return lerpf(top, bottom, tz)


func water_dist_at(x: float, z: float) -> float:
	var fx := clampf(x - ORIGIN.x, 0.0, W - 0.001)
	var fz := clampf(z - ORIGIN.y, 0.0, H - 0.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var i0 := iz * (W + 1) + ix
	var i1 := i0 + W + 1
	return lerpf(lerpf(water_dist[i0], water_dist[i0 + 1], tx), lerpf(water_dist[i1], water_dist[i1 + 1], tx), tz)


## Height a walker stands at: bridges, pier and stepping stones override terrain.
func walk_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	for b: Dictionary in bridges:
		var deck := bridge_deck(b, p)
		if not is_nan(deck):
			return deck
	var pier := ParkLayout.PIER
	var pa: Vector2 = pier["from"]
	var pb: Vector2 = pier["to"]
	var closest := Geometry2D.get_closest_point_to_segment(p, pa, pb)
	if closest.distance_to(p) <= pier["width"] * 0.5 + 0.05:
		return maxf(height_at(x, z), ParkLayout.WATER_Y + pier["height"] + 0.45)
	if is_on_stones(p):
		return ParkLayout.WATER_Y + 0.18
	for pl: Dictionary in platforms:
		if p.distance_squared_to(pl["center"]) < pl["radius"] * pl["radius"]:
			return pl["height"]
	return height_at(x, z)


func is_on_stones(p: Vector2) -> bool:
	var stones := ParkLayout.STEPPING_STONES
	if p.distance_squared_to(stones[2]) > 36.0:
		return false
	for i in stones.size() - 1:
		var c := Geometry2D.get_closest_point_to_segment(p, stones[i], stones[i + 1])
		if c.distance_to(p) < 0.6:
			return true
	return false


## Deck height of a bridge at p, or NAN when p is not on it.
func bridge_deck(b: Dictionary, p: Vector2) -> float:
	var a: Vector2 = b["a"]
	var dir: Vector2 = b["dir"]
	var rel := p - a
	var t: float = rel.dot(dir) / b["length"]
	if t < 0.0 or t > 1.0:
		return NAN
	var lateral := absf(rel.cross(dir))
	if lateral > b["width"] * 0.5 + 0.1:
		return NAN
	return lerpf(b["h0"], b["h1"], t) + b["arch"] * sin(PI * t) + deck_lift(t, b["length"])


## Deck height over the line between the bridge ends: flush with the ground at both ends,
## 12 cm higher after the first metre.
static func deck_lift(t: float, length: float) -> float:
	return 0.02 + 0.10 * clampf(minf(t, 1.0 - t) * length, 0.0, 1.0)


# --- Paths and bridges ------------------------------------------------------

func _compute_paths() -> void:
	path_dist.resize(W * H)
	path_dist.fill(99.0)
	path_kind.resize(W * H)
	path_kind.fill(0)
	for path: Dictionary in paths:
		var pts: PackedVector2Array = path["points"]
		var half: float = path["width"] * 0.5
		var kind: int = ["main", "side", "trail"].find(path["kind"])
		var n := pts.size()
		var segs := n if path["closed"] else n - 1
		for i in segs:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(half + 3, half + 3) - ORIGIN
			var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(half + 3, half + 3) - ORIGIN
			for cz in range(maxi(0, int(lo.y)), mini(H - 1, int(hi.y)) + 1):
				for cx in range(maxi(0, int(lo.x)), mini(W - 1, int(hi.x)) + 1):
					var p := ORIGIN + Vector2(cx + 0.5, cz + 0.5)
					var d := Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) - half
					var idx := cz * W + cx
					if d < path_dist[idx]:
						path_dist[idx] = d
						path_kind[idx] = kind


func _find_bridges() -> void:
	for path: Dictionary in paths:
		var pts: PackedVector2Array = path["points"]
		var n := pts.size()
		var segs := n if path["closed"] else n - 1
		for i in segs:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			for line: PackedVector2Array in water_lines():
				for j in line.size() - 1:
					var hit = Geometry2D.segment_intersects_segment(a, b, line[j], line[j + 1])
					if hit == null:
						continue
					if _bridge_near(hit):
						continue
					_add_bridge(hit, (b - a).normalized(), path)


func _bridge_near(p: Vector2) -> bool:
	for b: Dictionary in bridges:
		if (b["center"] as Vector2).distance_to(p) < 6.0:
			return true
	return false


func _add_bridge(center: Vector2, dir: Vector2, path: Dictionary) -> void:
	# Both ends reach past the bank over the whole deck width: creeks are crossed at an
	# angle, so one corner of a square end would otherwise hang over the sloping bank.
	var half := (float(path["width"]) + 0.8) * 0.5
	var side := Vector2(-dir.y, dir.x) * half
	var t0 := _bank_end(center, -dir, side)
	var t1 := _bank_end(center, dir, side)
	var a := center - dir * t0
	var b := center + dir * t1
	var stone: bool = path["kind"] == "main"
	var bridge := {
		"name": _bridge_name(center),
		"center": center,
		"a": a,
		"b": b,
		"dir": dir,
		"length": t0 + t1,
		"width": float(path["width"]) + 0.8,
		"style": "stone" if stone else "wood",
		"arch": 0.75 if stone else 0.4,
		"h0": height_at(a.x, a.y),
		"h1": height_at(b.x, b.y),
	}
	bridges.append(bridge)


## Distance from the creek crossing along dir to where the ground is level again.
func _bank_end(center: Vector2, dir: Vector2, side: Vector2) -> float:
	var t := 0.0
	while t < 14.0:
		var p := center + dir * t
		if minf(water_dist_at(p.x, p.y), minf(water_dist_at(p.x + side.x, p.y + side.y), water_dist_at(p.x - side.x, p.y - side.y))) >= ParkLayout.BANK_WIDTH - 0.3:
			break
		t += 0.25
	return t + 0.5


static func _bridge_name(center: Vector2) -> String:
	var best := "Brücke"
	var best_d := INF
	for anchor: Dictionary in ParkLayout.BRIDGE_NAMES:
		var d := center.distance_to(anchor["pos"])
		if d < best_d:
			best_d = d
			best = anchor["name"]
	return best


func bridge_at(p: Vector2) -> Dictionary:
	for b: Dictionary in bridges:
		if not is_nan(bridge_deck(b, p)):
			return b
	return {}


# --- Ground kinds -----------------------------------------------------------

func _compute_ground() -> void:
	ground.resize(W * H)
	# Water, paths, banks and grass for every cell ...
	for cz in H:
		for cx in W:
			var p := ORIGIN + Vector2(cx + 0.5, cz + 0.5)
			var idx := cz * W + cx
			var wd := water_dist_at(p.x, p.y)
			if wd < 0.0:
				ground[idx] = Ground.WATER
			elif path_dist[idx] <= 0.0:
				ground[idx] = _path_ground(idx)
			elif wd < 1.0:
				ground[idx] = Ground.BANK
			else:
				ground[idx] = Ground.GRASS
	# ... then areas, plazas and walk structures, each within its bounding box.
	# Later passes win: plazas over areas, the first area over later ones, structures over all.
	var keys := ParkLayout.AREAS.keys()
	keys.reverse()
	for key: String in keys:
		var area: Dictionary = ParkLayout.AREAS[key]
		var kind: int = {"gravel": Ground.GRAVEL, "sand": Ground.SAND, "plaza": Ground.PLAZA, "dirt": Ground.TRAIL, "rock": Ground.ROCK}.get(area["ground"], -1)
		if kind < 0:
			continue
		_fill_box(area["pos"], (area["size"] as Vector2).length() * 0.5, func(p: Vector2, idx: int) -> void:
			if ground[idx] != Ground.WATER and in_rect(p, area["pos"], area["size"], area["rot"]):
				ground[idx] = kind)
	for key: String in ParkLayout.PLAZAS:
		var pl: Dictionary = ParkLayout.PLAZAS[key]
		_fill_box(pl["pos"], pl["r"], func(p: Vector2, idx: int) -> void:
			if ground[idx] != Ground.WATER and p.distance_to(pl["pos"]) <= pl["r"]:
				ground[idx] = Ground.PLAZA)
	var pier := ParkLayout.PIER
	_fill_box((pier["from"] + pier["to"]) * 0.5, (pier["from"] as Vector2).distance_to(pier["to"]) * 0.5 + 2.0, func(p: Vector2, idx: int) -> void:
		if Geometry2D.get_closest_point_to_segment(p, pier["from"], pier["to"]).distance_to(p) <= pier["width"] * 0.5:
			ground[idx] = Ground.BRIDGE)
	for br: Dictionary in bridges:
		_fill_box(br["center"], br["length"] * 0.5 + br["width"], func(p: Vector2, idx: int) -> void:
			if not is_nan(bridge_deck(br, p)):
				ground[idx] = Ground.BRIDGE)
	_fill_box(ParkLayout.STEPPING_STONES[2], 6.0, func(p: Vector2, idx: int) -> void:
		if is_on_stones(p):
			ground[idx] = Ground.STONES)


## Calls f(cell_centre, index) for every cell within `reach` metres (as a box) of `c`.
func _fill_box(c: Vector2, reach: float, f: Callable) -> void:
	var lo := to_cell(c - Vector2(reach, reach))
	var hi := to_cell(c + Vector2(reach, reach))
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			f.call(cell_center(Vector2i(cx, cz)), cz * W + cx)


func _path_ground(idx: int) -> int:
	match path_kind[idx]:
		1: return Ground.GRAVEL
		2: return Ground.TRAIL
	return Ground.PATH


static func in_rect(p: Vector2, center: Vector2, size: Vector2, rot: float) -> bool:
	var local := (p - center).rotated(-rot)
	return absf(local.x) <= size.x * 0.5 and absf(local.y) <= size.y * 0.5


# --- Cells ------------------------------------------------------------------

static func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x - ORIGIN.x)), 0, W - 1), clampi(int(floor(p.y - ORIGIN.y)), 0, H - 1))


static func cell_center(c: Vector2i) -> Vector2:
	return ORIGIN + Vector2(c.x + 0.5, c.y + 0.5)


## Inside the city park (not the Nordwald). Visitors and park animals stay in here.
static func in_park(p: Vector2, margin := 0.0) -> bool:
	return absf(p.x) <= ParkLayout.HALF.x - margin and absf(p.y) <= ParkLayout.HALF.y - margin


## Inside the walkable world: city park plus Nordwald.
static func in_world(p: Vector2, margin := 0.0) -> bool:
	return p.x >= ParkLayout.WORLD_MIN.x + margin and p.x <= ParkLayout.WORLD_MAX.x - margin \
		and p.y >= ParkLayout.WORLD_MIN.y + margin and p.y <= ParkLayout.WORLD_MAX.y - margin


func ground_at(p: Vector2) -> int:
	var c := to_cell(p)
	return ground[c.y * W + c.x]


func path_dist_at(p: Vector2) -> float:
	var c := to_cell(p)
	return path_dist[c.y * W + c.x]


func is_water(p: Vector2) -> bool:
	return ground_at(p) == Ground.WATER


func is_solid(p: Vector2, nav := Nav.HUMAN) -> bool:
	if not in_world(p, 0.6):
		return true
	var c := to_cell(p)
	var idx := c.y * W + c.x
	match nav:
		Nav.WATER:
			return ground[idx] != Ground.WATER
		Nav.ANIMAL:
			return ground[idx] == Ground.WATER or (solid[idx] & 2) != 0
	return ground[idx] == Ground.WATER or (solid[idx] & 1) != 0


# --- Obstacles --------------------------------------------------------------

## Marks a circular obstacle. flags: 1 = blocks humans, 2 = blocks animals.
func add_obstacle_circle(center: Vector2, radius: float, flags := 3) -> void:
	var lo := to_cell(center - Vector2(radius, radius))
	var hi := to_cell(center + Vector2(radius, radius))
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var p := cell_center(Vector2i(cx, cz))
			if p.distance_to(center) <= radius + 0.35:
				solid[cz * W + cx] |= flags


func add_obstacle_rect(center: Vector2, size: Vector2, rot: float, flags := 3) -> void:
	var r := size.length() * 0.5
	var lo := to_cell(center - Vector2(r, r))
	var hi := to_cell(center + Vector2(r, r))
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var p := cell_center(Vector2i(cx, cz))
			if in_rect(p, center, size + Vector2(0.5, 0.5), rot):
				solid[cz * W + cx] |= flags


func add_obstacle_ellipse(center: Vector2, radii: Vector2, flags := 3) -> void:
	var lo := to_cell(center - radii)
	var hi := to_cell(center + radii)
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			if ((cell_center(Vector2i(cx, cz)) - center) / radii).length() <= 1.0:
				solid[cz * W + cx] |= flags


## Obstacle along a segment (fences, walls).
func add_obstacle_segment(a: Vector2, b: Vector2, thickness: float, flags := 3) -> void:
	var center := (a + b) * 0.5
	var d := b - a
	add_obstacle_rect(center, Vector2(d.length(), thickness), d.angle(), flags)


func clear_obstacle_rect(center: Vector2, size: Vector2, rot: float) -> void:
	var r := size.length() * 0.5
	var lo := to_cell(center - Vector2(r, r))
	var hi := to_cell(center + Vector2(r, r))
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			if in_rect(cell_center(Vector2i(cx, cz)), center, size, rot):
				solid[cz * W + cx] = 0


# --- Navigation -------------------------------------------------------------

func build_navigation() -> void:
	# Cells inside the 0.6 m margin of is_solid(): only the outermost ring is affected.
	var edge := func(cx: int, cz: int) -> bool: return not in_world(cell_center(Vector2i(cx, cz)), 0.6)
	for nav: int in [Nav.HUMAN, Nav.ANIMAL, Nav.WATER]:
		var g := AStarGrid2D.new()
		g.region = Rect2i(0, 0, W, H)
		g.cell_size = Vector2(CELL, CELL)
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.update()
		var bit := 2 if nav == Nav.ANIMAL else 1
		for cz in H:
			var border_row := cz == 0 or cz == H - 1
			for cx in W:
				var idx := cz * W + cx
				var c := Vector2i(cx, cz)
				var kind := ground[idx]
				var blocked: bool
				if (border_row or cx == 0 or cx == W - 1) and edge.call(cx, cz):
					blocked = true
				elif nav == Nav.WATER:
					blocked = kind != Ground.WATER
				else:
					blocked = kind == Ground.WATER or (solid[idx] & bit) != 0
				if blocked:
					g.set_point_solid(c, true)
				elif nav == Nav.HUMAN:
					g.set_point_weight_scale(c, cell_cost(kind, nav, path_dist[idx]))
				elif nav == Nav.ANIMAL and kind == Ground.BANK:
					g.set_point_weight_scale(c, 1.3)
		_grids[nav] = g


func cell_cost(kind: int, nav: int, pdist := 99.0) -> float:
	if nav != Nav.HUMAN:
		return 1.0
	match kind:
		Ground.PATH, Ground.PLAZA, Ground.BRIDGE:
			return 1.0
		Ground.GRAVEL, Ground.ROCK:
			return 1.05
		Ground.TRAIL, Ground.STONES:
			return 1.4
		Ground.SAND:
			return 1.6
		Ground.BANK:
			return 3.0
	# Grass right next to a path is a little cheaper (corner cutting is human).
	return 1.9 if pdist < 1.5 else 2.4


func grid(nav: int) -> AStarGrid2D:
	return _grids.get(nav)


## Updates one cell after the navigation was built (e.g. a gate opens).
func set_cell_solid(c: Vector2i, is_solid_cell: bool, nav := Nav.HUMAN) -> void:
	var g: AStarGrid2D = _grids.get(nav)
	if g:
		g.set_point_solid(c, is_solid_cell)
