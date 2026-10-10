class_name CityBuilder
extends RefCounted
## Builds the meshes and props of the Oststadt from CityLayout and the ground kinds CityMap
## wrote into the ParkMap: roads, sidewalks with curbs, markings and crosswalks, low houses,
## the buildings and props of the lots, lamps, trees, signs, benches and the outskirts.
## Registers obstacles, lamps and benches with the World. Cars come from City.

const G := ParkMap.Ground
const MARK := Color("ecebe4")

var world: World
var map: ParkMap
var root: Node3D
var batch := InstanceBatcher.new(65.0)
var rng := RandomNumberGenerator.new()


func _init(w: World, parent: Node3D) -> void:
	world = w
	map = w.map
	root = parent
	rng.seed = 5150


## Ground, curbs and markings.
func build_ground() -> void:
	_ground()
	_curbs()
	_markings()
	_outskirts()


## Houses, lot buildings and props, street furniture.
func build_props() -> void:
	_houses()
	_buildings()
	_cinema()
	_karting()
	_scrapyard()
	_depot()
	_petrol()
	_garage()
	_school()
	_drive_in()
	_market()
	_church_and_taxi()
	_lamps()
	_street_trees()
	_street_signs()
	batch.build(root, "CityProps")


func add(mesh: Mesh, p: Vector2, yaw := 0.0, y := 0.0, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, y, p.y))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


func label(text: String, pos: Vector3, yaw: float, size := 48, color := Color("f3ead2"), outline := 8) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.7)
	l.position = pos
	l.rotation.y = yaw
	l.double_sided = true
	l.visibility_range_end = 90.0
	root.add_child(l)
	return l


# --- Ground ---------------------------------------------------------------------------

## Look of a ground kind: [surface, height, colour]. Lots of the scrapyard look like dirt.
func _look(kind: int, center: Vector2) -> Array:
	match kind:
		G.STREET, G.CROSSING:
			return ["asphalt", 0.0, Color("4a4a4e")]
		G.LOT:
			if (CityLayout.LOTS["scrapyard"]["rect"] as Rect2).has_point(center):
				return ["earth", 0.012, Color("8a7a60")]
			if CityMap.track_distance(center) < 4.0 and (CityLayout.LOTS["karting"]["rect"] as Rect2).has_point(center):
				return ["asphalt", 0.012, Color("3e3e44")]
			return ["asphalt", 0.012, Color("58585e")]
		G.SIDEWALK:
			return ["paved", ParkMap.CURB_Y, Color("b9b4aa")]
		G.PLAZA:
			return ["cobbles", ParkMap.CURB_Y, Color("c4b49e")]
	return ["ground", 0.06, Color(0.42, 0.62, 0.29, 1.0)]


## The ground as rectangles: runs of equal cells per row, merged with the rows below.
func _ground() -> void:
	var kit := MeshKit.new()
	for r: Array in ground_rects():
		var rect: Rect2 = r[0]
		var look := _look(r[1], rect.get_center())
		var surface: String = look[0]
		kit.use(surface)
		var y: float = look[1]
		if surface in ["paved", "cobbles"]:
			# u runs along the longer side, so pavers follow the sidewalk.
			TerrainBuilder._rect_uv(kit, rect.position.x, rect.position.y, rect.end.x, rect.end.y, y, look[2], rect.size.x >= rect.size.y)
		else:
			TerrainBuilder._rect(kit, rect.position.x, rect.position.y, rect.end.x, rect.end.y, y, look[2])
	var mi := MeshInstance3D.new()
	mi.name = "CityGround"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## [Rect2, ground kind] covering the Oststadt cells (greedy merge of row runs). The scrapyard
## and kart track split from other lots, so their looks don't leak.
func ground_rects() -> Array:
	var out := []
	var active := {}    # "x0_x1_key" -> [x0, x1, key, kind, z_start]
	var z0 := ParkMap.to_cell(CityLayout.MIN + Vector2(0.5, 0.5)).y
	var z1 := ParkMap.to_cell(CityLayout.MAX - Vector2(0.5, 0.5)).y
	var cx0 := ParkMap.WEST_W
	var cx1 := ParkMap.W
	for cz in range(z0, z1 + 2):
		var runs := {}
		if cz <= z1:
			var start := cx0
			var key := _key(cx0, cz)
			for cx in range(cx0 + 1, cx1 + 1):
				var k := _key(cx, cz) if cx < cx1 else -1
				if k != key:
					runs["%d_%d_%d" % [start, cx, key]] = [start, cx, key]
					start = cx
					key = k
		for id: String in active.keys():
			if not runs.has(id):
				var a: Array = active[id]
				var ax0: int = a[0]
				var ax1: int = a[1]
				var az: int = a[4]
				out.append([Rect2(ParkMap.ORIGIN.x + ax0, ParkMap.ORIGIN.y + az, ax1 - ax0, cz - az), a[3]])
				active.erase(id)
		for id: String in runs:
			if not active.has(id):
				var r: Array = runs[id]
				active[id] = [r[0], r[1], r[2], r[2] % 100, cz]
	return out


## Ground kind of a cell plus 100 for the scrapyard, 200 for the kart track (same kind, other look).
func _key(cx: int, cz: int) -> int:
	var kind: int = map.ground[cz * ParkMap.W + cx]
	if kind == G.LOT:
		var p := ParkMap.cell_center(Vector2i(cx, cz))
		if (CityLayout.LOTS["scrapyard"]["rect"] as Rect2).has_point(p):
			return kind + 100
		if (CityLayout.LOTS["karting"]["rect"] as Rect2).has_point(p) and not CityLayout.KART_PIT.has_point(p):
			return kind + 200
	return kind


static func _raised(kind: int) -> bool:
	return kind == G.SIDEWALK or kind == G.PLAZA or kind == G.GRASS


## Curb faces where a sidewalk, plaza or lawn meets the road or a lot.
func _curbs() -> void:
	var kit := MeshKit.new()
	kit.use("curb")
	var col := Color("9a958c")
	var cz0 := ParkMap.to_cell(CityLayout.MIN + Vector2(0.5, 0.5)).y
	var cz1 := ParkMap.to_cell(CityLayout.MAX - Vector2(0.5, 0.5)).y
	# Faces between columns (running along z) ...
	for cx in range(ParkMap.WEST_W, ParkMap.W - 1):
		var start := -1
		var dir := 0
		for cz in range(cz0, cz1 + 2):
			var d := 0
			if cz <= cz1:
				var a: int = map.ground[cz * ParkMap.W + cx]
				var b: int = map.ground[cz * ParkMap.W + cx + 1]
				if _raised(a) and not _raised(b):
					d = 1
				elif _raised(b) and not _raised(a):
					d = -1
			if d != dir:
				if dir != 0:
					_curb_face(kit, Vector2(ParkMap.ORIGIN.x + cx + 1, ParkMap.ORIGIN.y + start), Vector2(ParkMap.ORIGIN.x + cx + 1, ParkMap.ORIGIN.y + cz), dir > 0, col, false)
				start = cz
				dir = d
	# ... and between rows (running along x).
	for cz in range(cz0, cz1):
		var start := -1
		var dir := 0
		for cx in range(ParkMap.WEST_W, ParkMap.W + 1):
			var d := 0
			if cx < ParkMap.W:
				var a: int = map.ground[cz * ParkMap.W + cx]
				var b: int = map.ground[(cz + 1) * ParkMap.W + cx]
				if _raised(a) and not _raised(b):
					d = 1
				elif _raised(b) and not _raised(a):
					d = -1
			if d != dir:
				if dir != 0:
					_curb_face(kit, Vector2(ParkMap.ORIGIN.x + start, ParkMap.ORIGIN.y + cz + 1), Vector2(ParkMap.ORIGIN.x + cx, ParkMap.ORIGIN.y + cz + 1), dir > 0, col, true)
				start = cx
				dir = d
	var mi := MeshInstance3D.new()
	mi.name = "CityCurbs"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Vertical curb face from a to b; the raised side is before the line (raised_first) or after.
func _curb_face(kit: MeshKit, a: Vector2, b: Vector2, raised_first: bool, col: Color, along_x: bool) -> void:
	var up := Vector3(0, ParkMap.CURB_Y, 0)
	var p0 := Vector3(a.x, 0.0, a.y)
	var p1 := Vector3(b.x, 0.0, b.y)
	var u0 := Vector2(a.x if along_x else a.y, 0)
	var u1 := Vector2(b.x if along_x else b.y, 0)
	# The face looks from the raised side to the low side (counter-clockwise from there).
	if raised_first != along_x:
		kit.quad_uv(p1, p0, p0 + up, p1 + up, col, u1, u0, u0, u1)
	else:
		kit.quad_uv(p0, p1, p1 + up, p0 + up, col, u0, u1, u1, u0)


## Lane lines, parking bays and zebra crossings.
func _markings() -> void:
	var kit := MeshKit.new()
	var y := 0.015
	var crossings := CityLayout.crossings()
	var near_crossing := func(p: Vector2) -> bool:
		for c: Dictionary in crossings:
			var q: Vector2 = c["pos"]
			if absf(p.x - q.x) < CityLayout.BLOCK_GAP + 0.5 and absf(p.y - q.y) < CityLayout.BLOCK_GAP + 0.5:
				return true
		return false
	var drives: Array[Rect2] = []
	for id: String in CityLayout.LOTS:
		for d: Rect2 in CityLayout.LOTS[id].get("drives", []):
			drives.append(d.grow(0.5))
	for s: Dictionary in CityLayout.X_STREETS:
		var x: float = s["x"]
		var z: float = CityLayout.Z_STREETS[0]["z"]
		while z < CityLayout.Z_STREETS[-1]["z"]:
			var p := Vector2(x, z + 1.5)
			if not near_crossing.call(p):
				kit.box(Vector3(x, y, z + 1.5), Vector3(0.15, 0.01, 3.0), MARK)
			for side: float in [-1.0, 1.0]:
				var q := Vector2(x + side * CityLayout.LANE_EDGE, z + 1.5)
				if not near_crossing.call(q) and not (x == CityLayout.X_STREETS[0]["x"] and side < 0):
					kit.box(Vector3(q.x, y, q.y), Vector3(0.12, 0.01, 3.0), MARK)
			z += 6.0
	for s: Dictionary in CityLayout.Z_STREETS:
		var z: float = s["z"]
		var x: float = CityLayout.X_STREETS[0]["x"]
		while x < CityLayout.X_STREETS[-1]["x"]:
			var p := Vector2(x + 1.5, z)
			if not near_crossing.call(p):
				kit.box(Vector3(x + 1.5, y, z), Vector3(3.0, 0.01, 0.15), MARK)
			for side: float in [-1.0, 1.0]:
				var q := Vector2(x + 1.5, z + side * CityLayout.LANE_EDGE)
				if not near_crossing.call(q):
					kit.box(Vector3(q.x, y, q.y), Vector3(3.0, 0.01, 0.12), MARK)
			x += 6.0
	# Bay separators on the parking strips.
	for bay: Dictionary in CityLayout.parking_bays():
		var p: Vector2 = bay["pos"]
		var yaw: float = bay["yaw"]
		var f := Vector2(sin(yaw), cos(yaw))
		var e := p - f * CityLayout.BAY * 0.5
		kit.push(Transform3D(Basis(Vector3.UP, yaw), Vector3(e.x, y, e.y)))
		kit.box(Vector3.ZERO, Vector3(2.4, 0.01, 0.12), MARK)
		kit.pop()
	# Zebra crossings: stripes along the walking direction.
	for r: Rect2 in CityLayout.crosswalks():
		var across_x := r.size.x > r.size.y    # the street runs along x: stripes along z
		var n := int((r.size.x if across_x else r.size.y) / 1.0)
		for i in n:
			if across_x:
				kit.box(Vector3(r.position.x + 0.5 + i, y, r.get_center().y), Vector3(0.55, 0.01, r.size.y - 0.4), Color("f4f4f0"))
			else:
				kit.box(Vector3(r.get_center().x, y, r.position.y + 0.5 + i), Vector3(r.size.x - 0.4, 0.01, 0.55), Color("f4f4f0"))
	# Kart track: red-white kerbs and the start line.
	var pts: Array = CityLayout.TRACK
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var d := (b - a)
		var steps := int(d.length() / 1.0)
		var nrm := Vector2(-d.y, d.x).normalized()
		for k in steps:
			var c := a + d * (k + 0.5) / steps
			for s: float in [-1.0, 1.0]:
				var e := c + nrm * s * (CityLayout.TRACK_WIDTH * 0.5 - 0.3)
				if CityMap.track_distance(e) < CityLayout.TRACK_WIDTH * 0.5 - 0.6:
					continue   # on another part of the track (hairpin, joints)
				kit.push(Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), Vector3(e.x, 0.025, e.y)))
				kit.box(Vector3.ZERO, Vector3(0.5, 0.02, 1.0), Color("d0352b") if k % 2 == 0 else Color("f4f4f0"))
				kit.pop()
	var start := kart_start()
	kit.push(Transform3D(Basis(Vector3.UP, start[1]), Vector3(start[0].x, 0.026, start[0].y)))
	for i in 7:
		for j in 2:
			kit.box(Vector3(-3.0 + i * 1.0, 0.0, -0.25 + j * 0.5), Vector3(0.5, 0.02, 0.5),
				Color("f4f4f0") if (i + j) % 2 == 0 else Color("1a1a1a"))
	kit.pop()
	var mi := MeshInstance3D.new()
	mi.name = "CityMarkings"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## Ground and streets around the town, low houses and woods as a backdrop (no obstacles).
func _outskirts() -> void:
	var kit := MeshKit.new()
	var far := 900.0
	var e := CityLayout.MAX.x
	var s := CityLayout.MAX.y
	var n := CityLayout.MIN.y
	var x0 := CityLayout.MIN.x
	kit.use("paved")
	TerrainBuilder._rect_uv(kit, x0, s, e + 5.0, s + 5.0, 0.02, Color("b9b4aa"), true)
	TerrainBuilder._rect_uv(kit, e, n - 30.0, e + 5.0, s, 0.02, Color("b9b4aa"), false)
	kit.use("asphalt")
	TerrainBuilder._rect(kit, x0 + 5.0, s + 5.0, far, s + 19.0, 0.0, Color("4a4a4e"))
	TerrainBuilder._rect(kit, e + 5.0, n - 30.0, e + 19.0, s + 5.0, 0.0, Color("4a4a4e"))
	kit.use("solid")
	TerrainBuilder._rect(kit, x0, s + 19.0, far, far, 0.02, Color("8d8a82"))
	TerrainBuilder._rect(kit, e + 19.0, -far, far, s + 19.0, 0.02, Color("8d8a82"))
	TerrainBuilder._rect(kit, x0, -far, e + 19.0, n, 0.02, TerrainBuilder.FOREST_GRASS.darkened(0.1))
	var mi := MeshInstance3D.new()
	mi.name = "CityOutskirts"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# Low houses beyond the outer streets, woods in the north.
	var hk := MeshKit.new()
	var z := n - 20.0
	while z < s + 60.0:
		var w := rng.randf_range(9.0, 14.0)
		var h := {"id": "out_e_%d" % int(z), "rect": Rect2(e + 25.0, z, rng.randf_range(9.0, 12.0), w), "front": Vector2.LEFT,
			"floors": 2 + rng.randi() % 2, "roof": "gable" if rng.randf() < 0.6 else "flat",
			"color": CityLayout.HOUSE_COLORS[rng.randi() % CityLayout.HOUSE_COLORS.size()],
			"roof_color": CityLayout.ROOF_COLORS[rng.randi() % CityLayout.ROOF_COLORS.size()]}
		if h["floors"] == 3:
			h["roof"] = "flat"
		CityModels.house_into(hk, h)
		z += w + rng.randf_range(0.5, 3.0)
	var x := x0 + 45.0
	while x < e + 40.0:
		var w := rng.randf_range(9.0, 14.0)
		var h := {"id": "out_s_%d" % int(x), "rect": Rect2(x, s + 25.0, w, rng.randf_range(9.0, 12.0)), "front": Vector2.UP,
			"floors": 2 + rng.randi() % 2, "roof": "gable" if rng.randf() < 0.6 else "flat",
			"color": CityLayout.HOUSE_COLORS[rng.randi() % CityLayout.HOUSE_COLORS.size()],
			"roof_color": CityLayout.ROOF_COLORS[rng.randi() % CityLayout.ROOF_COLORS.size()]}
		if h["floors"] == 3:
			h["roof"] = "flat"
		CityModels.house_into(hk, h)
		x += w + rng.randf_range(0.5, 3.0)
	var hm := MeshInstance3D.new()
	hm.name = "CityOutskirtHouses"
	hm.mesh = hk.commit()
	hm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hm)
	# Hills far in the east and south-east close the view.
	for m: Array in [[Vector2(560, -160), Vector2(90, 70), 30.0], [Vector2(600, 20), Vector2(110, 80), 24.0], [Vector2(470, 220), Vector2(120, 60), 18.0]]:
		var hill := MeshInstance3D.new()
		hill.mesh = NatureModels.massif(m[1], m[2], 13, 0.75)
		hill.position = Vector3(m[0].x, -1.5, m[0].y)
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(hill)
	for i in 160:
		var p := Vector2(rng.randf_range(e + 45.0, e + 120.0), rng.randf_range(n - 40.0, s + 80.0))
		var kind: String = ["oak", "maple", "birch", "chestnut"][rng.randi() % 4]
		var sc := rng.randf_range(0.9, 1.3)
		batch.add(NatureModels.tree(kind, rng.randi() % int(NatureModels.TREES[kind]["variants"])),
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(p.x, -0.05, p.y)), true, 400.0)
	var kinds := ["fir", "pine", "fir", "oak", "birch"]
	for i in 260:
		var p := Vector2(rng.randf_range(x0 - 4.0, e + 60.0), rng.randf_range(n - 60.0, n - 4.0))
		var kind: String = kinds[rng.randi() % kinds.size()]
		var sc := rng.randf_range(0.9, 1.4)
		batch.add(NatureModels.tree(kind, rng.randi() % int(NatureModels.TREES[kind]["variants"])),
			Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(p.x, -0.05, p.y)), true, 320.0)


# --- Buildings --------------------------------------------------------------------------

## Houses, one mesh per block (culled by distance).
func _houses() -> void:
	var by_block := {}
	for h: Dictionary in CityLayout.houses():
		if not by_block.has(h["block"]):
			by_block[h["block"]] = MeshKit.new()
		CityModels.house_into(by_block[h["block"]], h)
	for id: String in by_block:
		var mi := MeshInstance3D.new()
		mi.name = "Houses_" + id
		mi.mesh = (by_block[id] as MeshKit).commit()
		mi.visibility_range_end = 420.0
		root.add_child(mi)
	# Front gardens: a hedge or a bin beside some doors.
	for h: Dictionary in CityLayout.houses():
		var front: Vector2 = h["front"]
		var door: Vector2 = h["door"]
		var side := Vector2(-front.y, front.x)
		if rng.randf() < 0.6:
			var p := door + side * rng.randf_range(2.0, 3.5) + front * 0.3
			if map.ground_at(p) == G.GRASS:
				batch.add(CityModels.wheelie_bin([Color("3a6a3a"), Color("2a4a8a"), Color("5a5a5e"), Color("c8a020")][rng.randi() % 4]),
					Transform3D(Basis(Vector3.UP, atan2(front.x, front.y)), Vector3(p.x, 0.06, p.y)), true, 120.0)
				map.add_obstacle_circle(p, 0.35, 3)


func _buildings() -> void:
	var kit := MeshKit.new()
	for b: Dictionary in CityLayout.BUILDINGS:
		CityModels.building_into(kit, b)
	var mi := MeshInstance3D.new()
	mi.name = "LotBuildings"
	mi.mesh = kit.commit()
	root.add_child(mi)
	# Signs on the buildings.
	label("TANKSTELLE", Vector3(157.0, 3.4, -127.9 + 8.1), 0.0, 64, Color("c0392b"), 6)
	label("WASCHSTRASSE", Vector3(195.0, 4.0, -137.1), PI, 56, Color("f4f4f4"), 6)
	label("KFZ-MEISTER KURT", Vector3(237.0, 5.4, -134.9), 0.0, 72, Color("2a4a8a"), 6)
	label("FAHRSCHULE\nFRIEDRICH", Vector3(296.0, 4.6, -98.9), 0.0, 56, Color("2e86de"), 6)
	label("TAXI-ZENTRALE", Vector3(156.0, 4.8, 9.1), 0.0, 56, Color("2a2a2a"), 6)
	label("GELATERIA GIANNI", Vector3(298.0, 4.8, 48.1), 0.0, 56, Color("c0392b"), 6)
	label("BETRIEBSHOF", Vector3(375.0, 5.6, -214.9), 0.0, 80, Color("e8602e"), 6)
	label("ZUM DURCHFAHRER", Vector3(174.0, 3.7, -39.9), 0.0, 64, Color("f2c230"), 8)
	label("SCHROTT & TEILE", Vector3(296.5, 2.4, -177.9), 0.0, 40, Color("f2c230"), 6)


func _cinema() -> void:
	var lot: Rect2 = CityLayout.LOTS["cinema"]["rect"]
	var cx := lot.get_center().x
	add(CityModels.cinema_screen(), Vector2(cx, lot.position.y + 3.0), 0.0)
	map.add_obstacle_rect(Vector2(cx - 8.0, lot.position.y + 2.5), Vector2(2.0, 1.6), 0.0, 7)
	map.add_obstacle_rect(Vector2(cx + 8.0, lot.position.y + 2.5), Vector2(2.0, 1.6), 0.0, 7)
	for spot: Dictionary in cinema_spots():
		var p: Vector2 = spot["post"]
		batch.add(CityModels.speaker_post(), Transform3D(Basis(Vector3.UP, PI / 2), Vector3(p.x, 0.0, p.y)), true, 140.0)
		map.add_obstacle_circle(p, 0.2, 7)
	add(CityModels.booth(Color("2c3e50")), Vector2(182.5, -173.5), -PI / 2)
	map.add_obstacle_rect(Vector2(182.5, -173.5), Vector2(2.6, 2.6), 0.0, 7)
	add(CityModels.booth(Color("c0392b")), Vector2(155.0, -177.5), 0.0)
	map.add_obstacle_rect(Vector2(155.0, -177.5), Vector2(2.6, 2.6), 0.0, 7)
	label("AUTOKINO", Vector3(cx, 13.2, lot.position.y + 2.8), 0.0, 160, Color("f2c230"), 10).visibility_range_end = 400.0
	label("KASSE", Vector3(181.1, 2.95, -173.5), -PI / 2, 40)
	label("POPCORN", Vector3(155.0, 3.05, -176.1), 0.0, 40)


## Start line of the kart track: [centre, yaw of a line across the track].
static func kart_start() -> Array:
	var a: Vector2 = CityLayout.TRACK[0]
	var b: Vector2 = CityLayout.TRACK[1]
	var d := b - a
	return [(a + b) * 0.5, atan2(d.x, d.y)]


## Parking spots of the drive-in cinema: {pos (car centre), yaw (facing the screen), post}.
static func cinema_spots() -> Array:
	var out := []
	var lot: Rect2 = CityLayout.LOTS["cinema"]["rect"]
	for row in 3:
		var z := lot.position.y + 19.0 + row * 12.0
		for i in 7:
			var x := lot.position.x + 7.0 + i * 6.0
			out.append({"pos": Vector2(x, z), "yaw": PI, "post": Vector2(x - 2.6, z - 0.6)})
	return out


func _karting() -> void:
	var pts: Array = CityLayout.TRACK
	var half := CityLayout.TRACK_WIDTH * 0.5 + 0.6
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var d := b - a
		var nrm := Vector2(-d.y, d.x).normalized()
		var steps := int(d.length() / 2.0)
		for k in steps:
			var c := a + d * (k + 0.5) / steps
			for s: float in [-1.0, 1.0]:
				var e := c + nrm * s * half
				if CityMap.track_distance(e) < half - 0.3 or CityLayout.KART_PIT.grow(1.0).has_point(e):
					continue
				batch.add(CityModels.tyre_wall(), Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(e.x, 0.06, e.y)), true, 160.0)
				map.add_obstacle_circle(e, 0.5, 7)
	var start := kart_start()
	add(CityModels.start_gantry(CityLayout.TRACK_WIDTH + 1.0), start[0], start[1])
	label("KARTBAHN", Vector3(227.0, 3.6, -173.9), 0.0, 64, Color("f2c230"), 6)


func _scrapyard() -> void:
	var lot: Rect2 = CityLayout.LOTS["scrapyard"]["rect"]
	add(CityModels.crane(), Vector2(328.0, -200.0), PI)
	map.add_obstacle_rect(Vector2(328.0, -200.0), Vector2(3.0, 3.0), 0.0, 7)
	# Stacks of wrecks along the north and east fence.
	var cols := [Color("8a3b2b"), Color("2a4a8a"), Color("5a6a4a"), Color("7a7a7e"), Color("a87a3a")]
	for i in 7:
		var p := Vector2(lot.position.x + 5.0 + i * 6.5, lot.position.y + 4.0)
		var n := 1 + rng.randi() % 3
		for k in n:
			batch.add(CityModels.wreck(cols[(i + k) % cols.size()], k), Transform3D(Basis(Vector3.UP, PI / 2 + rng.randf_range(-0.15, 0.15)), Vector3(p.x, 0.02 + k * 0.92, p.y)), true, 200.0)
		map.add_obstacle_rect(p, Vector2(4.2, 2.0), 0.0, 7)
	for i in 4:
		var p := Vector2(lot.end.x - 4.0, lot.position.y + 14.0 + i * 6.0)
		for k in 1 + rng.randi() % 2:
			batch.add(CityModels.wreck(cols[(i + k + 2) % cols.size()], k + 3), Transform3D(Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)), Vector3(p.x, 0.02 + k * 0.92, p.y)), true, 200.0)
		map.add_obstacle_rect(p, Vector2(2.0, 4.2), 0.0, 7)
	for i in 5:
		var p := Vector2(lot.position.x + 4.0 + i * 1.6, lot.end.y - 21.0)
		batch.add(CityModels.tyre_stack(2 + i % 3), Transform3D(Basis(), Vector3(p.x, 0.0, p.y)), true, 120.0)
		map.add_obstacle_circle(p, 0.5, 7)
	# Fence around the yard (open at the gate).
	var gate: Rect2 = CityLayout.LOTS["scrapyard"]["drives"][0]
	for side in 4:
		var a := lot.position
		var b := Vector2(lot.end.x, lot.position.y)
		match side:
			1: a = Vector2(lot.end.x, lot.position.y); b = lot.end
			2: a = lot.end; b = Vector2(lot.position.x, lot.end.y)
			3: a = Vector2(lot.position.x, lot.end.y); b = lot.position
		var steps := int(a.distance_to(b) / 3.0)
		for k in steps:
			var p0 := a.lerp(b, float(k) / steps)
			var p1 := a.lerp(b, float(k + 1) / steps)
			var mid := (p0 + p1) * 0.5
			if side == 2 and mid.x > gate.position.x - 0.5 and mid.x < gate.end.x + 0.5:
				continue
			var d := p1 - p0
			batch.add(PropModels.fence_segment(d.length()), Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(p0.x, 0.0, p0.y)), true, 160.0)
			map.add_obstacle_segment(p0, p1, 0.4, 7)


func _depot() -> void:
	for i in 3:
		add(CityModels.garage_door(), Vector2(366.0 + i * 8.0, -214.95), 0.0)


func _petrol() -> void:
	add(CityModels.petrol_canopy(), Vector2(176.0, -125.0), 0.0)
	for z: float in [-128.0, -122.0]:
		batch.add(CityModels.petrol_pump(), Transform3D(Basis(), Vector3(172.0, 0.0, z)), true, 150.0)
		batch.add(CityModels.petrol_pump(), Transform3D(Basis(), Vector3(180.0, 0.0, z)), true, 150.0)
		map.add_obstacle_rect(Vector2(172.0, z), Vector2(1.2, 2.4), 0.0, 7)
		map.add_obstacle_rect(Vector2(180.0, z), Vector2(1.2, 2.4), 0.0, 7)
	for x: float in [171.5, 180.5]:
		for z: float in [-127.5, -122.5]:
			map.add_obstacle_circle(Vector2(x, z), 0.2, 7)
	add(CityModels.pylon(), Vector2(197.5, -104.0), PI)
	map.add_obstacle_rect(Vector2(197.5, -104.0), Vector2(1.6, 0.4), 0.0, 7)
	add(CityModels.wash_brushes(), Vector2(195.0, -127.0), 0.0)


func _garage() -> void:
	for i in 3:
		add(CityModels.garage_door(), Vector2(228.0 + i * 9.0, -134.95), 0.0)
	for i in 4:
		var p := Vector2(255.0 + i * 1.5, -133.0)
		batch.add(CityModels.tyre_stack(3 + i % 2), Transform3D(Basis(), Vector3(p.x, 0.0, p.y)), true, 120.0)
		map.add_obstacle_circle(p, 0.45, 7)


## Practice lot of the driving school: a row of cones along the fence (the parking boxes
## are painted by the parking game).
func _school() -> void:
	for i in 12:
		var p := Vector2(292.0 + i * 4.0, -149.5)
		batch.add(CityModels.traffic_cone(), Transform3D(Basis(), Vector3(p.x, 0.012, p.y)), true, 120.0)
		map.add_obstacle_circle(p, 0.25, 7)


func _drive_in() -> void:
	var post := drive_in_points()
	add(CityModels.burger_sign(), Vector2(196.0, -78.0), 0.0)
	map.add_obstacle_circle(Vector2(196.0, -78.0), 0.3, 7)
	add(CityModels.order_post(), post["order_post"], -PI / 2)
	map.add_obstacle_rect(post["order_post"], Vector2(0.6, 0.6), 0.0, 7)
	# Pickup window in the west wall and the lane arrows.
	var w: Vector2 = post["window"]
	var kit := MeshKit.new()
	kit.box(Vector3(0, 1.45, 0), Vector3(0.06, 1.1, 1.8), Color("2b3a48"))
	kit.box(Vector3(-0.3, 0.95, 0), Vector3(0.6, 0.06, 1.8), Color("e8e2d0"))
	kit.box(Vector3(-0.4, 2.15, 0), Vector3(0.8, 0.08, 2.2), Color("f2c230"))
	add(kit.commit(), w + Vector2(0.03, 0), 0.0)
	label("ABHOLUNG", Vector3(w.x - 0.1, 2.5, w.y), -PI / 2, 36, Color("f4f4f4"), 6)
	var arrows := MeshKit.new()
	for z in [-76.0, -66.0, -36.0]:
		arrows.box(Vector3(160.0, 0.02, z), Vector3(0.25, 0.01, 2.2), MARK)
		arrows.push(Transform3D(Basis(Vector3.UP, 0.0), Vector3(160.0, 0.02, z + 1.3)))
		arrows.tri(Vector3(-0.6, 0, 0), Vector3(0.6, 0, 0), Vector3(0, 0, 0.9), MARK)
		arrows.pop()
	arrows.box(Vector3(157.6, 0.016, -50.0), Vector3(0.12, 0.01, 44.0), Color("f2c230"))
	arrows.box(Vector3(163.0, 0.016, -50.0), Vector3(0.12, 0.01, 44.0), Color("f2c230"))
	add(arrows.commit(), Vector2.ZERO, 0.0, 0.0, false)
	# Parking bays east of the building.
	var lines := MeshKit.new()
	for i in 6:
		lines.box(Vector3(186.0, 0.016, -66.0 + i * 3.0), Vector3(5.0, 0.01, 0.12), MARK)
	add(lines.commit(), Vector2.ZERO, 0.0, 0.0, false)


## Drive-in points: the lane runs south along the building's west wall, the driver's side
## (left) faces the order post and the window.
static func drive_in_points() -> Dictionary:
	return {"order_post": Vector2(162.6, -67.0), "order_car": Vector2(160.3, -67.0),
		"window": Vector2(166.0, -50.0), "window_car": Vector2(160.3, -50.0)}


func _market() -> void:
	var c := CityLayout.place("market")
	add(CityModels.market_fountain(), c, 0.0)
	map.add_obstacle_circle(c, 3.3, 7)
	var decorator_benches := 0
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := c + Vector2(cos(a), sin(a)) * 7.5
		_city_bench(p, atan2(c.x - p.x, c.y - p.y))
		decorator_benches += 1
	for i in 8:
		var a := TAU * i / 8.0
		var p := c + Vector2(cos(a) * 15.0, sin(a) * 12.0)
		var kind := "maple" if i % 2 == 0 else "chestnut"
		batch.add(NatureModels.tree(kind, i % 3), Transform3D(Basis(Vector3.UP, a).scaled(Vector3(0.85, 0.85, 0.85)), Vector3(p.x, ParkMap.CURB_Y, p.y)), true, 260.0)
		map.add_obstacle_circle(p, 0.5, 7)
	for i in 6:
		var p := Vector2(CityLayout.LOTS["market"]["rect"].position.x + 1.0, c.y - 12.0 + i * 4.8)
		batch.add(CityModels.bollard(), Transform3D(Basis(), Vector3(p.x, ParkMap.CURB_Y, p.y)), true, 90.0)


func _city_bench(p: Vector2, yaw: float) -> Bench:
	var b := Bench.new()
	b.setup("citybench_%d" % world.city_benches.size(), Vector3(p.x, ParkMap.CURB_Y, p.y), yaw, 3, 0.47)
	root.add_child(b)
	batch.add(PropModels.bench(1), Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, ParkMap.CURB_Y, p.y)), true, 140.0)
	map.add_obstacle_rect(p, Vector2(1.9, 0.6), -yaw, 1)
	world.register_bench(b, false)
	world.city_benches.append(b)
	return b


func _church_and_taxi() -> void:
	# Graves and a path in the churchyard.
	var lot: Rect2 = CityLayout.LOTS["church"]["rect"]
	for i in 8:
		var p := Vector2(lot.position.x + 30.0 + (i % 4) * 4.0, lot.position.y + 23.0 + (i / 4) * 3.5)
		var kit := MeshKit.new()
		kit.box(Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.15), Color("8a847a"))
		batch.add(kit.commit(), Transform3D(Basis(), Vector3(p.x, 0.06, p.y)), true, 90.0)
	label("ST. MARTIN", Vector3(299.0, 9.0, -50.92), 0.0, 48, Color("3a2a10"), 0)
	for i in 3:
		var p := Vector2(196.0 - i * 6.0, 13.0)
		var lines := MeshKit.new()
		lines.box(Vector3(0, 0.016, 0), Vector3(0.12, 0.01, 5.0), MARK)
		add(lines.commit(), p + Vector2(3.0, -2.5), 0.0, 0.0, false)


func _lamps() -> void:
	for blk: Dictionary in CityLayout.blocks():
		var r: Rect2 = blk["rect"]
		var sides := []
		if r.position.y > CityLayout.MIN.y + 1.0:
			sides.append([Vector2(r.position.x, r.position.y - CityLayout.WALK + 0.5), Vector2(r.end.x, r.position.y - CityLayout.WALK + 0.5), PI])
		if r.end.y < CityLayout.MAX.y - 1.0:
			sides.append([Vector2(r.position.x, r.end.y + CityLayout.WALK - 0.5), Vector2(r.end.x, r.end.y + CityLayout.WALK - 0.5), 0.0])
		if r.position.x > CityLayout.MIN.x + 1.0:
			sides.append([Vector2(r.position.x - CityLayout.WALK + 0.5, r.position.y), Vector2(r.position.x - CityLayout.WALK + 0.5, r.end.y), -PI / 2])
		if r.end.x < CityLayout.MAX.x - 1.0:
			sides.append([Vector2(r.end.x + CityLayout.WALK - 0.5, r.position.y), Vector2(r.end.x + CityLayout.WALK - 0.5, r.end.y), PI / 2])
		for s: Array in sides:
			var a: Vector2 = s[0]
			var b: Vector2 = s[1]
			var yaw: float = s[2]
			var length := a.distance_to(b)
			var n := maxi(1, int(length / 24.0))
			for i in n:
				var p := a.lerp(b, (i + 0.5) / n)
				if map.ground_at(p) != G.SIDEWALK:
					continue
				batch.add(CityModels.street_lamp(), Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, ParkMap.CURB_Y, p.y)), true, 220.0)
				map.add_obstacle_circle(p, 0.2, 3)
				var arm := Vector2(sin(yaw), cos(yaw)) * 1.3
				world.lamps.append(Vector3(p.x + arm.x, 4.8, p.y + arm.y))
	# The park side of the Parkstraße.
	var z := CityLayout.Z_STREETS[0]["z"] + 12.0
	while z < CityLayout.Z_STREETS[-1]["z"]:
		var p := Vector2(134.3, z)
		if map.ground_at(p) == G.SIDEWALK:
			batch.add(CityModels.street_lamp(), Transform3D(Basis(Vector3.UP, PI / 2), Vector3(p.x, ParkMap.CURB_Y, p.y)), true, 220.0)
			map.add_obstacle_circle(p, 0.2, 3)
			world.lamps.append(Vector3(p.x + 1.3, 4.8, p.y))
		z += 24.0


## Trees between the parking bays (every sixth bay); they block cars too.
func _street_trees() -> void:
	var kinds := ["maple", "chestnut", "oak", "maple"]
	var i := 0
	for bay: Dictionary in CityLayout.parking_bays():
		i += 1
		if not bay.get("tree", false):
			continue
		var p: Vector2 = bay["pos"]
		var kind: String = kinds[i % kinds.size()]
		batch.add(NatureModels.tree(kind, i % 3), Transform3D(Basis(Vector3.UP, i * 1.3).scaled(Vector3(0.75, 0.75, 0.75)), Vector3(p.x, 0.0, p.y)), true, 260.0)
		map.add_obstacle_circle(p, 0.6, 7)
	# Planters on the sidewalks at the market.
	for p: Vector2 in [Vector2(216.2, -66.0), Vector2(216.2, -36.0)]:
		batch.add(CityModels.planter(), Transform3D(Basis(), Vector3(p.x, ParkMap.CURB_Y, p.y)), true, 120.0)


## Street name signs at the north-east corner of every crossing.
func _street_signs() -> void:
	for c: Dictionary in CityLayout.crossings():
		var p: Vector2 = c["pos"] + Vector2(CityLayout.ROAD_HALF + 0.6, -CityLayout.ROAD_HALF - 0.6)
		if map.ground_at(p) != G.SIDEWALK:
			p = c["pos"] + Vector2(-CityLayout.ROAD_HALF - 0.6, CityLayout.ROAD_HALF + 0.6)
			if map.ground_at(p) != G.SIDEWALK:
				continue
		batch.add(CityModels.sign_pole(), Transform3D(Basis(), Vector3(p.x, ParkMap.CURB_Y, p.y)), true, 120.0)
		map.add_obstacle_circle(p, 0.15, 3)
		for s: float in [-1.0, 1.0]:
			var lz := label(c["x_street"], Vector3(p.x + s * 0.035, ParkMap.CURB_Y + 2.25, p.y), PI / 2 * s, 30, Color.WHITE, 0)
			lz.double_sided = false
			var lx := label(c["z_street"], Vector3(p.x, ParkMap.CURB_Y + 2.6, p.y + s * 0.035), 0.0 if s > 0 else PI, 30, Color.WHITE, 0)
			lx.double_sided = false
