class_name CityMap
extends RefCounted
## Writes the Oststadt (CityLayout) into the ParkMap when the town is loaded: ground kinds
## (street, sidewalk, crossing, lot, plaza, grass), buildings as obstacles for everybody
## (bit 2 = cars) and their roof heights (camera, map).

const G := ParkMap.Ground


static func build(map: ParkMap) -> void:
	var lo := ParkMap.to_cell(CityLayout.MIN + Vector2(0.5, 0.5))
	var hi := ParkMap.to_cell(CityLayout.MAX - Vector2(0.5, 0.5))
	# Everything between the blocks is sidewalk, the blocks are yards (grass) ...
	_fill(map, Rect2(CityLayout.MIN, CityLayout.MAX - CityLayout.MIN), G.SIDEWALK)
	for b: Dictionary in CityLayout.blocks():
		_fill(map, b["rect"], G.GRASS)
	# ... then the lots, the kart track, the streets, crosswalks and driveways.
	for id: String in CityLayout.LOTS:
		var lot: Dictionary = CityLayout.LOTS[id]
		var kind: int = {"lot": G.LOT, "plaza": G.PLAZA, "grass": G.GRASS, "dirt": G.LOT}[lot["ground"]]
		_fill(map, lot["rect"], kind)
	_track(map)
	_fill(map, CityLayout.KART_PIT, G.LOT)
	for r: Rect2 in CityLayout.roads():
		_fill(map, r, G.STREET)
	for r: Rect2 in CityLayout.crosswalks():
		_fill(map, r, G.CROSSING)
	for id: String in CityLayout.LOTS:
		for d: Rect2 in CityLayout.LOTS[id].get("drives", []):
			_fill(map, d, G.LOT)
	# Buildings: solid for people, animals and cars, with their roof height.
	for h: Dictionary in CityLayout.houses():
		_building(map, h["rect"], h["h"])
	for b: Dictionary in CityLayout.BUILDINGS:
		if b.get("open_z", false):
			# The car wash is a tunnel: only its long walls are solid.
			var r: Rect2 = b["rect"]
			_building(map, Rect2(r.position.x, r.position.y, 0.6, r.size.y), b["h"])
			_building(map, Rect2(r.end.x - 0.6, r.position.y, 0.6, r.size.y), b["h"])
			_roof_only(map, r, b["h"])
		else:
			_building(map, b["rect"], b["h"])
	map.city_ready = true
	assert(lo.x >= ParkMap.WEST_W and hi.x < ParkMap.W)


## Calls f for the cells whose centres lie in r.
static func _cells(r: Rect2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var lo := ParkMap.to_cell(r.position + Vector2(0.5, 0.5))
	var hi := ParkMap.to_cell(r.end - Vector2(0.5, 0.5))
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			out.append(Vector2i(cx, cz))
	return out


static func _fill(map: ParkMap, r: Rect2, kind: int) -> void:
	var lo := ParkMap.to_cell(r.position + Vector2(0.5, 0.5))
	var hi := ParkMap.to_cell(r.end - Vector2(0.5, 0.5))
	for cz in range(lo.y, hi.y + 1):
		var row := cz * ParkMap.W
		for cx in range(maxi(lo.x, ParkMap.WEST_W), hi.x + 1):
			map.ground[row + cx] = kind


static func _building(map: ParkMap, r: Rect2, height: float) -> void:
	var lo := ParkMap.to_cell(r.position + Vector2(0.5, 0.5))
	var hi := ParkMap.to_cell(r.end - Vector2(0.5, 0.5))
	var dm := clampi(int(height * 10.0), 1, 255)
	for cz in range(lo.y, hi.y + 1):
		var row := cz * ParkMap.W
		for cx in range(lo.x, hi.x + 1):
			map.solid[row + cx] |= 7
			map.roof[row + cx] = dm


static func _roof_only(map: ParkMap, r: Rect2, height: float) -> void:
	var dm := clampi(int(height * 10.0), 1, 255)
	for c in _cells(r):
		map.roof[c.y * ParkMap.W + c.x] = dm


## Kart track: cells within half the track width of the closed centre line become lot.
static func _track(map: ParkMap) -> void:
	var pts: Array = CityLayout.TRACK
	var half := CityLayout.TRACK_WIDTH * 0.5
	var r: Rect2 = CityLayout.LOTS["karting"]["rect"]
	for c in _cells(r):
		var p := ParkMap.cell_center(c)
		if track_distance(p) <= half:
			map.ground[c.y * ParkMap.W + c.x] = G.LOT
	assert(pts.size() > 2)


## Distance from p to the kart track's centre line.
static func track_distance(p: Vector2) -> float:
	var pts: Array = CityLayout.TRACK
	var best := INF
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		best = minf(best, Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p))
	return best
