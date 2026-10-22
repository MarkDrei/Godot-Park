class_name CoastBackdrop
extends RefCounted
## The Möwenbucht's horizon and its stand-in (doc/moewenbucht.md):
## - horizon(): always there (the sea is seen from everywhere): the sea to the horizon, finely
##   divided over the bay for its swells, the cliff west of the bay and the little harbour town
##   east of it, beyond the area's edges.
## - build(): the bay as seen from the park until it is loaded or while it sleeps: the beach and
##   the dunes as a coarse mesh, the stands, the pier, the mole with the lighthouse.

const STEP := 6.0
## The sea mesh: fine over the bay, 20 m quads round it (RING), 100 m quads out to SEA's edges.
## The rectangles' edges lie on the coarser grids; none reaches north of z 100 (the park's
## creek and ponds lie in the same plane).
const FINE := Rect2(-140, 140, 280, 160)
const FINE_STEP := 2.5
const RING := Rect2(-240, 100, 480, 300)
const SEA := Rect2(-1140, 100, 2280, 1100)
## The cliff west of the bay and the harbour town east of it (beyond the area).
const CLIFF := Rect2(-230, 118, 100, 100)
const TOWN := Rect2(130, 90, 220, 58)


static func build(world: World) -> Node3D:
	var root := Node3D.new()
	root.name = "CoastBackdrop"
	var kit := MeshKit.new()
	var lo := ParkLayout.COAST_MIN
	var hi := ParkLayout.COAST_MAX
	# Built round its middle, so its view range counts from there.
	var mid_xz := (lo + hi) * 0.5
	kit.push(Transform3D(Basis(), Vector3(-mid_xz.x, 0, -mid_xz.y)))
	var nx := int((hi.x - lo.x) / STEP)
	var nz := int((hi.y - lo.y) / STEP)
	var grass := Color("7fa452")
	var sand := Color("e0cc95")
	for iz in nz:
		for ix in nx:
			var p00 := lo + Vector2(ix, iz) * STEP
			var p11 := p00 + Vector2(STEP, STEP)
			var mid := (p00 + p11) * 0.5
			if CoastLayout.land_dist(mid) < -STEP:
				continue
			var v := func(p: Vector2) -> Vector3: return Vector3(p.x, CoastLayout.height(p) - 0.12, p.y)
			var col := grass if mid.y < CoastLayout.PROMENADE_Z else sand
			if CoastLayout.in_rocks(mid):
				col = CoastModels.STONE
			kit.quad(v.call(p00), v.call(Vector2(p00.x, p11.y)), v.call(p11), v.call(Vector2(p11.x, p00.y)), col)
	kit.box(Vector3(0, 0.05, CoastLayout.PROMENADE_Z), Vector3(250, 0.1, 5.0), Color("c4b79e"))
	for st: Array in CoastBuilder.STANDS:
		var p: Vector2 = st[1]
		_add(kit, CoastModels.beach_stand(st[2]), p, PI)
	_add(kit, CoastModels.bandstand(), CoastLayout.place("bandstand"), PI)
	_add(kit, CoastModels.lifeguard_tower(), CoastLayout.place("lifeguard"))
	_add(kit, CoastModels.pirate_ship(), CoastLayout.place("playground"), 0.4)
	kit.box(Vector3(CoastLayout.PIER_X, CoastLayout.PIER_Y - 0.1, (CoastLayout.PIER_Z.x + CoastLayout.PIER_Z.y) * 0.5),
		Vector3(CoastLayout.PIER_HALF * 2.0, 0.2, CoastLayout.PIER_Z.y - CoastLayout.PIER_Z.x), CoastModels.DECK)
	kit.box(Vector3(CoastLayout.PIER_HEAD.x, CoastLayout.PIER_Y - 0.1, CoastLayout.PIER_HEAD.y),
		Vector3(CoastLayout.PIER_HEAD_SIZE.x, 0.2, CoastLayout.PIER_HEAD_SIZE.y), CoastModels.DECK)
	kit.add_mesh(CoastModels.pier_pavilion(), Transform3D(Basis(), Vector3(CoastLayout.PIER_HEAD.x, CoastLayout.PIER_Y, CoastLayout.PIER_HEAD.y)))
	for i in CoastLayout.MOLE.size() - 1:
		var a: Vector2 = CoastLayout.MOLE[i]
		var b: Vector2 = CoastLayout.MOLE[i + 1]
		kit.push(Transform3D(Basis(Vector3.UP, atan2(-(b - a).y, (b - a).x)), Vector3((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)))
		kit.box(Vector3(0, CoastLayout.MOLE_Y * 0.5 - 0.5, 0), Vector3(a.distance_to(b) + 3.0, CoastLayout.MOLE_Y + 1.0, CoastLayout.MOLE_HALF * 2.0), CoastModels.STONE)
		kit.pop()
	kit.add_mesh(CoastModels.lighthouse(), Transform3D(Basis(), Vector3(CoastLayout.place("lighthouse").x, CoastLayout.MOLE_Y, CoastLayout.place("lighthouse").y)))
	kit.pop()
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = kit.commit()
	ground.position = Vector3(mid_xz.x, 0, mid_xz.y)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.visibility_range_end = 300.0   # from the Burg or the Oststadt's east it is too far
	root.add_child(ground)
	world.coast_backdrop = root
	return root


static func _add(kit: MeshKit, mesh: Mesh, p: Vector2, yaw := 0.0) -> void:
	kit.add_mesh(mesh, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, CoastLayout.height(p), p.y)))


## The sea to the horizon, the cliff and the harbour town: always shown.
static func horizon() -> Node3D:
	var root := Node3D.new()
	root.name = "CoastHorizon"
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = sea_mesh()
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sea)
	for part: Array in [["Cliff", CLIFF], ["HarbourTown", TOWN]]:
		var r: Rect2 = part[1]
		var c := r.get_center()
		var land := MeshInstance3D.new()
		land.name = part[0]
		land.mesh = _cliff(c) if part[0] == "Cliff" else _town(c)
		land.position = Vector3(c.x, 0, c.y)
		land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		land.visibility_range_end = 280.0   # from the Burg or the town's far east they are too far
		root.add_child(land)
	return root


## The sea: a grid of FINE_STEP over the bay (the swells move its vertices), coarse rings of
## growing quads round it out to SEA's edges. One draw call.
static func sea_mesh() -> Mesh:
	var kit := MeshKit.new()
	kit.use("sea")
	var y := ParkLayout.WATER_Y
	var col := Color.WHITE
	var nx := int(FINE.size.x / FINE_STEP)
	var nz := int(FINE.size.y / FINE_STEP)
	for iz in nz:
		for ix in nx:
			var x0 := FINE.position.x + ix * FINE_STEP
			var z0 := FINE.position.y + iz * FINE_STEP
			var x1 := x0 + FINE_STEP
			var z1 := z0 + FINE_STEP
			if CoastLayout.land_dist(Vector2(x0 + FINE_STEP * 0.5, z0 + FINE_STEP * 0.5)) > 4.0 and x0 >= ParkLayout.COAST_MIN.x and x1 <= ParkLayout.COAST_MAX.x:
				continue   # dry land: no water under it
			kit.quad(Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), col)
	# Coarse quads round the fine part.
	for ring: Array in [[20.0, FINE, RING], [100.0, RING, SEA]]:
		var step: float = ring[0]
		var inner: Rect2 = ring[1]
		var outer: Rect2 = ring[2]
		var z := outer.position.y
		while z < outer.end.y - 0.01:
			var x := outer.position.x
			while x < outer.end.x - 0.01:
				if not inner.intersects(Rect2(x, z, step, step)):
					kit.quad(Vector3(x, y, z), Vector3(x, y, z + step), Vector3(x + step, y, z + step), Vector3(x + step, y, z), col)
				x += step
			z += step
	return kit.commit()


## The cliff west of the bay (grass on top, rock falling into the sea, pines), beyond the
## area's edge; built round `centre`.
static func _cliff(centre: Vector2) -> Mesh:
	var kit := MeshKit.new()
	kit.push(Transform3D(Basis(), Vector3(-centre.x, 0, -centre.y)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	# The cliff: a ridge from the Westpark's south street down to the sea.
	var step := 5.0
	var cliff_h := func(p: Vector2) -> float:
		var depth := CoastLayout.SEA_CLIFF_Z - p.y + 6.0 * sin(p.x * 0.05)
		var top := 9.0 + 3.0 * sin(p.x * 0.07) + 2.0 * cos(p.y * 0.09)
		var rise := smoothstep(CLIFF.position.y, CLIFF.position.y + 30.0, p.y)
		return lerpf(0.0, top, rise) * smoothstep(-4.0, 6.0, depth) + lerpf(ParkLayout.WATER_Y - 3.0, 0.0, smoothstep(-4.0, 0.0, depth))
	var nx := int(CLIFF.size.x / step)
	var nz := int(CLIFF.size.y / step)
	for iz in nz:
		for ix in nx:
			var p00 := CLIFF.position + Vector2(ix, iz) * step
			var p11 := p00 + Vector2(step, step)
			var v := func(p: Vector2) -> Vector3: return Vector3(p.x, cliff_h.call(p), p.y)
			var a: Vector3 = v.call(p00)
			var b: Vector3 = v.call(Vector2(p00.x, p11.y))
			var c: Vector3 = v.call(p11)
			var d: Vector3 = v.call(Vector2(p11.x, p00.y))
			var steep := absf(a.y - c.y) > 2.5 or absf(b.y - d.y) > 2.5
			var col := CoastModels.STONE if steep or a.y < 0.3 else Color("789a4a")
			kit.quad(a, b, c, d, col)
	for i in 40:
		var p := Vector2(rng.randf_range(CLIFF.position.x, CLIFF.end.x - 6.0), rng.randf_range(CLIFF.position.y + 20.0, CoastLayout.SEA_CLIFF_Z - 12.0))
		var s := rng.randf_range(0.8, 1.2)
		kit.add_mesh(NatureModels.tree("pine", rng.randi() % 3), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
			Vector3(p.x, cliff_h.call(p) - 0.1, p.y)))
	kit.pop()
	return kit.commit()


## The harbour town east of the bay: ground to the quay, low houses, a quay wall, boats, a
## breakwater; built round `centre`.
static func _town(centre: Vector2) -> Mesh:
	var kit := MeshKit.new()
	kit.push(Transform3D(Basis(), Vector3(-centre.x, 0, -centre.y)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4343
	var town := Color("b9b4aa")
	kit.use("paved")
	TerrainBuilder.ground_rect_uv(kit, TOWN.position.x, TOWN.position.y, TOWN.end.x, TOWN.end.y + 6.0, 0.035, town, true)
	kit.use("masonry")
	kit.quad(Vector3(TOWN.position.x, 0.02, TOWN.end.y + 6.0), Vector3(TOWN.position.x, -2.5, TOWN.end.y + 6.0),
		Vector3(TOWN.end.x, -2.5, TOWN.end.y + 6.0), Vector3(TOWN.end.x, 0.02, TOWN.end.y + 6.0), CoastModels.STONE)
	kit.use("solid")
	var colors := [Color("d8c8a8"), Color("b5654a"), Color("e9e4d6"), Color("8fb0c8"), Color("c9a37a"), Color("e8d8b0")]
	var x := TOWN.position.x + 6.0
	while x < TOWN.end.x - 8.0:
		var w := rng.randf_range(8.0, 13.0)
		var depth := rng.randf_range(8.0, 11.0)
		var h := rng.randf_range(5.0, 8.5)
		PropModels.building_into(kit, Vector3(x + w * 0.5, 0, TOWN.position.y + 8.0 + depth * 0.5), Vector3(w - 1.0, h, depth),
			colors[rng.randi() % colors.size()], rng.randi())
		x += w
	for k in 4:
		var bp := Vector3(TOWN.position.x + 30.0 + k * 38.0, ParkLayout.WATER_Y - 0.08, TOWN.end.y + 10.0)
		kit.add_mesh(CoastModels.boat("rowboat", [Color("c8553d"), Color("2f6fb0"), Color("e9e4d6")][k % 3]),
			Transform3D(Basis(Vector3.UP, PI / 2 + rng.randf_range(-0.2, 0.2)), bp))
	# A breakwater with a green light at its end.
	kit.use("masonry")
	kit.box(Vector3(250, -0.5, TOWN.end.y + 40.0), Vector3(150, 2.4, 5.0), CoastModels.STONE)
	kit.use("solid")
	kit.cylinder(Vector3(178, 0.7, TOWN.end.y + 40.0), 4.0, 0.9, 0.7, 8, Color("2e8a4a"))
	kit.pop()
	return kit.commit()
