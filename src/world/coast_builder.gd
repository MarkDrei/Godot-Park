class_name CoastBuilder
extends WorldBuilder
## Builds the Möwenbucht (doc/moewenbucht.md) when it is loaded: terrain, paths and plazas, the
## forecourt with its sign, the promenade with lamps and benches, the stands, the bandstand,
## the dunes with marram grass, sand fences and boardwalks, the beach with Strandkörbe,
## parasols, the lifeguard tower, the volleyball court, sandcastles and the pirate ship, the
## groynes, the pier and its head, the harbour with quay, jetty, cutter, mole and lighthouse, the
## rocks, the sandbank with seals, the buoys and the surf.

const G := ParkMap.Ground
## The stands along the promenade: [id, position, awning colour, sign]. They face the promenade.
const STANDS := [
	["fish_stand", Vector2(-44, 99), Color("2f6fb0"), "FISCHBRÖTCHEN"],
	["ice_stand", Vector2(-22, 99), Color("e07aa8"), "EISDIELE"],
	["kiosk", Vector2(24, 99), Color("e0a32e"), "KIOSK"],
	["souvenirs", Vector2(48, 99), Color("2e9a6a"), "SOUVENIRS"],
]

var coast: Coast
var batch := InstanceBatcher.new(60.0)
var plants := InstanceBatcher.new(40.0)
var _static := MeshKit.new()      # single models merged: one draw call per surface
var _bench_count := 0


func _init(w: World, c: Coast, parent: Node3D) -> void:
	super(w, parent, 8181)
	coast = c


## Terrain, paths and plazas.
func build_ground() -> void:
	var tb := TerrainBuilder.new(map)
	var ground := Node3D.new()
	ground.name = "Ground"
	root.add_child(ground)
	tb.build_chunks(ground, ParkMap.PARK_X0, ParkMap.CITY_X0, ParkMap.COAST_Z0, ParkMap.H)
	root.add_child(tb.paths_mesh(CoastMap.paths(map)))
	root.add_child(tb.plazas_mesh(CoastLayout.PLAZAS, CoastLayout.AREAS))


func build_props() -> void:
	_forecourt()
	_promenade()
	_stands()
	_bandstand()
	_dunes()
	_boardwalks()
	_beach()
	_playground()
	_groynes()
	_pier()
	_harbour()
	_mole()
	_rocks()
	_sandbank()
	_buoys()
	_surf()
	batch.build(root, "CoastProps")
	plants.build(root, "CoastPlants")
	var sm := MeshInstance3D.new()
	sm.name = "CoastStatic"
	sm.mesh = _static.commit()
	root.add_child(sm)


func _put(mesh: Mesh, p: Vector2, yaw := 0.0, y := NAN) -> void:
	_static.add_mesh(mesh, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, gy(p) if is_nan(y) else y, p.y)))


func new_bench(p: Vector2, yaw: float, y := NAN, seats := 3, mesh: Mesh = null) -> Bench:
	_bench_count += 1
	var h := gy(p) if is_nan(y) else y
	var b := place_bench("coast_bench_%d" % _bench_count, Vector3(p.x, h, p.y), yaw, seats, 0.45 if mesh else 0.47)
	batch.add(mesh if mesh else PropModels.bench(1), Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, h, p.y)))
	map.add_obstacle_rect(p, Vector2(1.9 if seats > 2 else 1.4, 0.7), -yaw, ParkMap.BLOCK_PEOPLE)
	world.coast_benches.append(b)
	return b


func _lamp(p: Vector2, y := NAN) -> void:
	var base := Vector3(p.x, gy(p) if is_nan(y) else y, p.y)
	batch.add(CoastModels.sea_lamp(), Transform3D(Basis(), base))
	world.lamps.append(base + Vector3(0, 3.8, 0))
	map.add_obstacle_circle(p, 0.2, ParkMap.BLOCK_PEOPLE)


# --- North strip and promenade -----------------------------------------------------------

## The forecourt behind the Südtor: the sign "MÖWENBUCHT", the info board, bicycles.
func _forecourt() -> void:
	var c := CoastLayout.place("forecourt")
	_put(CoastModels.sign_arch(6.0), c + Vector2(0, 4.0))
	for s: float in [1.0, -1.0]:
		var l := label("MÖWENBUCHT", Vector3(c.x, gy(c) + 3.65, c.y + 4.0 + 0.1 * s), 0.0 if s > 0 else PI, 72, Color.WHITE, 8)
		l.double_sided = false
	var bp := c + Vector2(5.5, -2.0)
	_put(PropModels.info_board(), bp, PI)
	map.add_obstacle_rect(bp, Vector2(1.6, 0.4), 0.0, ParkMap.BLOCK_PEOPLE)
	world.info_boards.append(Vector3(bp.x, gy(bp), bp.y))
	for k in 3:
		var rp := c + Vector2(-5.0 - k * 0.7, -2.5)
		batch.add(PropModels.bicycle([Color("2e86de"), Color("e0a32e"), Color("2e9a6a")][k]), Transform3D(Basis(Vector3.UP, PI / 2), Vector3(rp.x, gy(rp), rp.y)))
	for x: float in [-3.0, 3.0]:
		map.add_obstacle_circle(c + Vector2(x, 4.0), 0.25, ParkMap.BLOCK_PEOPLE)


## Lamps along the promenade's sea side, benches facing the dunes and the sea between them,
## bins.
func _promenade() -> void:
	var path: Dictionary = CoastMap.paths(map).filter(func(p: Dictionary) -> bool: return p["id"] == "coast_promenade")[0]
	var pts: PackedVector2Array = path["points"]
	var half: float = path["width"] * 0.5
	var dist := 0.0
	var next_lamp := 4.0
	var next_bench := 11.0
	for i in range(1, pts.size()):
		dist += pts[i].distance_to(pts[i - 1])
		var t := (pts[i] - pts[i - 1]).normalized()
		var sea := Vector2(-t.y, t.x)
		if sea.y < 0.0:
			sea = -sea
		if pts[i].y > CoastLayout.PROMENADE_Z + 4.0:
			continue   # the bend down to the harbour
		if dist >= next_lamp:
			next_lamp = dist + 20.0
			var lp := pts[i] + sea * (half + 0.5)
			if _free(lp, 1.0):
				_lamp(lp)
		if dist >= next_bench:
			var bp := pts[i] + sea * (half + 0.9)
			if _free(bp, 1.4) and absf(bp.x - CoastLayout.GATE.x) > 6.0:
				next_bench = dist + 15.0
				new_bench(bp, PI)   # its back to the dunes, facing the promenade and the stands
				if int(dist / 15.0) % 3 == 0:
					var bin := bp + Vector2(1.4, 0)
					batch.add(PropModels.bin(), Transform3D(Basis(), Vector3(bin.x, gy(bin), bin.y)))
					map.add_obstacle_circle(bin, 0.3, ParkMap.BLOCK_PEOPLE)
			else:
				next_bench = dist + 2.0


## Whether nothing stands at p yet (r m round it): no obstacle, no path, no deck, no water.
func _free(p: Vector2, r: float) -> bool:
	for q: Vector2 in [p, p + Vector2(r, 0), p - Vector2(r, 0), p + Vector2(0, r), p - Vector2(0, r)]:
		var c := ParkMap.to_cell(q)
		var idx := c.y * ParkMap.W + c.x
		if map.solid[idx] != 0 or map.ground[idx] in [G.WATER, G.BRIDGE, G.ROCK] or (map.path_dist[idx] < 0.0 and q == p):
			return false
	return true


## The four stands north of the promenade (their shops come in phase 2), with a table and
## benches each, and the boat rental's hut at the harbour.
func _stands() -> void:
	for st: Array in STANDS:
		var p: Vector2 = st[1]
		_put(CoastModels.beach_stand(st[2]), p)
		map.add_obstacle_rect(p, Vector2(3.8, 2.8), 0.0, ParkMap.BLOCK_WALKERS)
		for s: float in [1.0, -1.0]:
			var l := label(st[3], Vector3(p.x, gy(p) + 3.15, p.y + 1.25 + 0.04 * s), 0.0 if s > 0 else PI, 44, Color.WHITE, 6)
			l.double_sided = false
		coast.spots[st[0]] = Vector3(p.x, gy(p), p.y + 2.2)
		coast.posts[st[0]] = [Vector3(p.x, gy(p), p.y + 0.3), 0.0]
	var rental := CoastLayout.place("boat_rental")
	_put(CoastModels.beach_stand(Color("2f6fb0")), rental, PI / 2)
	map.add_obstacle_rect(rental, Vector2(2.8, 3.8), 0.0, ParkMap.BLOCK_WALKERS)
	for s: float in [1.0, -1.0]:
		var l := label("BOOTSVERLEIH", Vector3(rental.x + 1.25 + 0.04 * s, gy(rental) + 3.15, rental.y), PI / 2 if s > 0 else -PI / 2, 40, Color.WHITE, 6)
		l.double_sided = false
	coast.posts["boat_rental"] = [Vector3(rental.x + 0.3, gy(rental), rental.y), PI / 2]
	coast.spots["boat_rental"] = Vector3(rental.x + 2.2, gy(rental), rental.y)


## The bandstand west of the stands, its benches in rows facing it.
func _bandstand() -> void:
	var c := CoastLayout.place("bandstand")
	_put(CoastModels.bandstand(), c + Vector2(0, -1.5), 0.0)
	map.add_obstacle_circle(c + Vector2(0, -1.5), 5.4, ParkMap.BLOCK_WALKERS)
	coast.posts["bandstand"] = [Vector3(c.x, gy(c) + 0.6, c.y - 1.5), 0.0]
	for row in 2:
		for k in 3:
			var bp := c + Vector2(-4.2 + k * 4.2, 6.2 + row * 1.9)
			if _free(bp, 1.0):
				new_bench(bp, PI)


# --- Dunes and boardwalks --------------------------------------------------------------------

## Marram grass all over the dunes, sand fences along their crests.
func _dunes() -> void:
	var prng := part_rng(8282)
	for i in 2600:
		var p := Vector2(prng.randf_range(-126.0, CoastLayout.QUAY_X - 4.0), prng.randf_range(CoastLayout.DUNES.x, CoastLayout.DUNES.y + 2.0))
		if CoastLayout.dune(p) < 0.25 and prng.randf() < 0.85:
			continue
		var c := ParkMap.to_cell(p)
		var idx := c.y * ParkMap.W + c.x
		if map.ground[idx] != G.SAND or map.solid[idx] != 0 or map.path_dist[idx] < 0.8 or _near_place(p, 0.5):
			continue
		var s := prng.randf_range(0.8, 1.35)
		plants.add(CoastModels.beach_grass(prng.randi() % 4), Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled(Vector3(s, s, s)),
			Vector3(p.x, gy(p) - 0.03, p.y)), false, 90.0)
	var x := -118.0
	while x < CoastLayout.QUAY_X - 12.0:
		var p := Vector2(x, CoastLayout.DUNES.y - 3.0 + 1.5 * sin(x * 0.11))
		var near_walk := CoastLayout.BOARDWALKS.any(func(b: float) -> bool: return absf(b - x) < 5.0)
		if not near_walk and not _near_place(p, 0.0):
			batch.add(CoastModels.sand_fence(6.0), Transform3D(Basis(Vector3.UP, 0.08 * sin(x)), Vector3(p.x, gy(p) - 0.1, p.y)))
		x += 7.0


## Planks over the dunes from the promenade to the beach (BRIDGE cells, CoastMap).
func _boardwalks() -> void:
	var kit := MeshKit.new()
	kit.use("planks")
	for bx: float in CoastLayout.BOARDWALKS:
		var z0 := CoastLayout.PROMENADE_Z + 2.0
		var z1 := CoastLayout.DUNES.y + 1.5
		var z := z0
		while z < z1:
			var za := z
			var zb := minf(z + 1.0, z1)
			var ya := gy(Vector2(bx, za)) + 0.07
			var yb := gy(Vector2(bx, zb)) + 0.07
			kit.quad_uv(Vector3(bx - 1.2, ya, za), Vector3(bx - 1.2, yb, zb), Vector3(bx + 1.2, yb, zb), Vector3(bx + 1.2, ya, za),
				CoastModels.DRIFT, Vector2(za, -1.2), Vector2(zb, -1.2), Vector2(zb, 1.2), Vector2(za, 1.2))
			z = zb
		kit.use("solid")
		var k := z0
		while k < z1:
			for side: float in [-1.0, 1.0]:
				var q := Vector2(bx + side * 1.25, k)
				kit.box(Vector3(q.x, gy(q) + 0.45, q.y), Vector3(0.08, 0.9, 0.08), CoastModels.DRIFT.darkened(0.15))
			k += 3.0
		for side: float in [-1.0, 1.0]:
			var a := Vector2(bx + side * 1.25, z0)
			var b := Vector2(bx + side * 1.25, z1 - 0.5)
			var steps := int((z1 - z0) / 3.0)
			for s in steps:
				var p0 := a.lerp(b, float(s) / steps)
				var p1 := a.lerp(b, float(s + 1) / steps)
				kit.beam(Vector3(p0.x, gy(p0) + 0.85, p0.y), Vector3(p1.x, gy(p1) + 0.85, p1.y), Vector2(0.05, 0.05), CoastModels.DRIFT)
		kit.use("planks")
	var mi := MeshInstance3D.new()
	mi.name = "Boardwalks"
	mi.mesh = kit.commit()
	root.add_child(mi)


# --- Beach ------------------------------------------------------------------------------

## Strandkörbe in rows (seats for two), parasols with towels, the lifeguard tower, lifebuoys,
## the volleyball court, sandcastles with buckets.
func _beach() -> void:
	var prng := part_rng(8383)
	var v := 0
	for row in 3:
		var z := 143.0 + row * 4.5
		var x := -86.0
		while x < 74.0:
			var p := Vector2(x + prng.randf_range(-0.6, 0.6), z + prng.randf_range(-0.4, 0.4))
			x += prng.randf_range(4.5, 6.5)
			if CoastLayout.land_dist(p) < 9.0 or not _beach_free(p, 1.6):
				continue
			var yaw := prng.randf_range(-0.25, 0.25)   # facing the sea (south)
			new_bench(p, yaw, NAN, 2, CoastModels.strandkorb(v))
			v += 1
	for i in 18:
		var p := Vector2(prng.randf_range(-88.0, 72.0), prng.randf_range(146.0, 168.0))
		if CoastLayout.land_dist(p) < 6.0 or not _beach_free(p, 2.0):
			continue
		batch.add(CoastModels.parasol(i), Transform3D(Basis(Vector3.UP, prng.randf() * TAU), Vector3(p.x, gy(p), p.y)))
		map.add_obstacle_circle(p, 0.25, ParkMap.BLOCK_PEOPLE)
		var tp := p + Vector2(0.9, 0.6)
		batch.add(CoastModels.towel(i), Transform3D(Basis(Vector3.UP, prng.randf_range(-0.4, 0.4)), Vector3(tp.x, gy(tp), tp.y)), false)
	var tower := CoastLayout.place("lifeguard")
	_put(CoastModels.lifeguard_tower(), tower)
	map.add_obstacle_rect(tower, Vector2(2.8, 2.8), 0.0, ParkMap.BLOCK_WALKERS)
	coast.posts["lifeguard"] = [Vector3(tower.x, gy(tower), tower.y + 3.6), 0.0]
	for x: float in [-70.0, -10.0, 44.0]:
		var p := Vector2(x, CoastLayout.shore_z(x) - 12.0)
		if _beach_free(p, 0.6):
			batch.add(CoastModels.lifebuoy_stand(), Transform3D(Basis(Vector3.UP, 0.0), Vector3(p.x, gy(p), p.y)))
			map.add_obstacle_circle(p, 0.25, ParkMap.BLOCK_PEOPLE)
	var court := CoastLayout.place("volleyball")
	_put(CoastModels.volleyball_net(), court)
	map.add_obstacle_rect(court + Vector2(-4.8, 0), Vector2(0.3, 0.3), 0.0, ParkMap.BLOCK_PEOPLE)
	map.add_obstacle_rect(court + Vector2(4.8, 0), Vector2(0.3, 0.3), 0.0, ParkMap.BLOCK_PEOPLE)
	_court_lines(court, Vector2(16, 8))
	var castles := CoastLayout.place("sandcastles")
	for k in 5:
		var p := castles + Vector2(-4.0 + k * 2.1, prng.randf_range(-1.5, 1.5))
		_put(CoastModels.sandcastle(k), p, prng.randf() * TAU)
		map.add_obstacle_circle(p, 0.6, ParkMap.BLOCK_PEOPLE)
		var bk := p + Vector2(0.9, 0.7)
		batch.add(CoastModels.bucket(k), Transform3D(Basis(Vector3.UP, prng.randf() * TAU), Vector3(bk.x, gy(bk), bk.y)), false)


func _beach_free(p: Vector2, r: float) -> bool:
	return _free(p, r) and not _near_place(p, 1.0) and absf(p.x - CoastLayout.PIER_X) > CoastLayout.PIER_HALF + 2.0 + r


## Lines of the volleyball court in the sand.
func _court_lines(c: Vector2, size: Vector2) -> void:
	var h := size * 0.5
	var line := Color("f4f1ea")
	for seg: Array in [[Vector2(-h.x, -h.y), Vector2(h.x, -h.y)], [Vector2(-h.x, h.y), Vector2(h.x, h.y)],
			[Vector2(-h.x, -h.y), Vector2(-h.x, h.y)], [Vector2(h.x, -h.y), Vector2(h.x, h.y)]]:
		var a: Vector2 = c + seg[0]
		var b: Vector2 = c + seg[1]
		var n := int(a.distance_to(b) / 1.0)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			_static.box(Vector3(p.x, gy(p) + 0.02, p.y), Vector3(0.08 if a.x == b.x else 1.02, 0.02, 1.02 if a.x == b.x else 0.08), line)


## The pirate ship in the dunes' western end (to climb on; the playground's sand).
func _playground() -> void:
	var c := CoastLayout.place("playground")
	_put(CoastModels.pirate_ship(), c, 0.4, gy(c) - 0.1)
	map.add_obstacle_ellipse(c, Vector2(2.6, 4.8), ParkMap.BLOCK_WALKERS)


## The groynes: rows of weathered posts from the beach into the sea.
func _groynes() -> void:
	var v := 0
	for g: Array in CoastLayout.GROYNES:
		var a := CoastMap.groyne_start(g[0])
		var n := int(g[1] / 0.45)
		for k in n:
			var p := a + Vector2(0.0, k * 0.45)
			batch.add(CoastModels.post(v), Transform3D(Basis(Vector3.UP, v * 0.7), Vector3(p.x, gy(p) + 0.3, p.y)))
			v += 1


# --- Pier, harbour, mole -----------------------------------------------------------------

## The pier's deck in planks on piles with railings, lamps and benches; the head with the
## pavilion, the telescope and benches round it.
func _pier() -> void:
	var kit := MeshKit.new()
	for d: Dictionary in CoastLayout.decks():
		if (d["a"] as Vector2).x != CoastLayout.PIER_X:
			continue
		_deck(kit, d, d["half"] > 3.0, true)
	var mi := MeshInstance3D.new()
	mi.name = "Pier"
	mi.mesh = kit.commit()
	root.add_child(mi)
	var y := CoastLayout.PIER_Y
	var z := CoastLayout.PIER_Z.x + 24.0
	var side := 1.0
	while z < CoastLayout.PIER_Z.y - 4.0:
		_lamp(Vector2(CoastLayout.PIER_X + side * (CoastLayout.PIER_HALF - 0.25), z), y)
		z += 18.0
		side = -side
	var head := CoastLayout.PIER_HEAD
	_put(CoastModels.pier_pavilion(), head + Vector2(0, 2.0), 0.0, y)
	for k in 8:
		var a := TAU * k / 8.0
		map.add_obstacle_circle(head + Vector2(0, 2.0) + Vector2(cos(a), sin(a)) * 3.2, 0.15, ParkMap.BLOCK_PEOPLE)
	var scope := head + Vector2(6.5, 6.5)
	_put(CoastModels.telescope(), scope, PI, y)
	map.add_obstacle_circle(scope, 0.25, ParkMap.BLOCK_PEOPLE)
	coast.spots["telescope"] = Vector3(scope.x, y, scope.y - 0.8)
	for x: float in [-6.5, 6.5]:
		new_bench(head + Vector2(x, -4.5), PI / 2 if x < 0 else -PI / 2, y)
	new_bench(head + Vector2(-5.0, 6.8), 0.0, y)
	coast.posts["pier_head"] = [Vector3(head.x - 2.0, y, head.y + 6.0), 0.0]


## A deck from CoastLayout.decks: planks across, piles down to the sea floor every 4 m, with
## `rails` a railing on both sides (`head`: also across its ends, open where the pier joins).
func _deck(kit: MeshKit, d: Dictionary, head: bool, rails: bool) -> void:
	var a: Vector2 = d["a"]
	var b: Vector2 = d["b"]
	var half: float = d["half"]
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var length := a.distance_to(b)
	var n := maxi(1, int(ceil(length / 1.0)))
	kit.use("planks")
	for k in n:
		var t0 := float(k) / n
		var t1 := float(k + 1) / n
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		var y0 := lerpf(d["h0"], d["h1"], t0)
		var y1 := lerpf(d["h0"], d["h1"], t1)
		var u0 := t0 * length
		var u1 := t1 * length
		var l0 := p0 + side * half
		var r0 := p0 - side * half
		var l1 := p1 + side * half
		var r1 := p1 - side * half
		kit.quad_uv(Vector3(l0.x, y0, l0.y), Vector3(l1.x, y1, l1.y), Vector3(r1.x, y1, r1.y), Vector3(r0.x, y0, r0.y), CoastModels.DECK,
			Vector2(u0, half), Vector2(u1, half), Vector2(u1, -half), Vector2(u0, -half))
		kit.quad(Vector3(l0.x, y0 - 0.25, l0.y), Vector3(l1.x, y1 - 0.25, l1.y), Vector3(l1.x, y1, l1.y), Vector3(l0.x, y0, l0.y), CoastModels.WOOD)
		kit.quad(Vector3(r0.x, y0, r0.y), Vector3(r1.x, y1, r1.y), Vector3(r1.x, y1 - 0.25, r1.y), Vector3(r0.x, y0 - 0.25, r0.y), CoastModels.WOOD)
	kit.use("solid")
	var piles := maxi(1, int(length / 4.0))
	for k in piles + 1:
		var p := a.lerp(b, float(k) / piles)
		var y := lerpf(d["h0"], d["h1"], float(k) / piles)
		for s: float in [-1.0, 1.0]:
			var q := p + side * s * (half - 0.15)
			var floor_y := gy(q)
			if floor_y < y - 0.3:
				kit.cylinder(Vector3(q.x, floor_y - 0.3, q.y), y - floor_y + 0.2, 0.14, 0.13, 6, CoastModels.WOOD_DARK)
			if rails:
				kit.cylinder(Vector3(q.x, y, q.y), 1.0, 0.05, 0.05, 4, CoastModels.WHITE)
	if not rails:
		return
	for s: float in [-1.0, 1.0]:
		var p0 := a + side * s * (half - 0.15)
		var p1 := b + side * s * (half - 0.15)
		kit.beam(Vector3(p0.x, d["h0"] + 1.0, p0.y), Vector3(p1.x, d["h1"] + 1.0, p1.y), Vector2(0.08, 0.06), CoastModels.WHITE)
		kit.beam(Vector3(p0.x, d["h0"] + 0.5, p0.y), Vector3(p1.x, d["h1"] + 0.5, p1.y), Vector2(0.04, 0.04), CoastModels.WHITE)
	if head:
		for e: Vector2 in [a, b]:
			var p0 := e + side * (half - 0.15)
			var p1 := e - side * (half - 0.15)
			# Open in the middle of the landward end (the pier joins there).
			if e == a:
				var gap := CoastLayout.PIER_HALF + 0.2
				for seg: Array in [[p0, e + side * gap], [e - side * gap, p1]]:
					var s0: Vector2 = seg[0]
					var s1: Vector2 = seg[1]
					kit.beam(Vector3(s0.x, d["h0"] + 1.0, s0.y), Vector3(s1.x, d["h0"] + 1.0, s1.y), Vector2(0.08, 0.06), CoastModels.WHITE)
				continue
			kit.beam(Vector3(p0.x, d["h0"] + 1.0, p0.y), Vector3(p1.x, d["h0"] + 1.0, p1.y), Vector2(0.08, 0.06), CoastModels.WHITE)
	# Railings keep people on the deck.
	for s: float in [-1.0, 1.0]:
		map.add_obstacle_segment(a + side * s * (half + 0.3), b + side * s * (half + 0.3), 0.5, ParkMap.BLOCK_WALKERS)
	if head:
		var gap := CoastLayout.PIER_HALF + 0.4
		map.add_obstacle_segment(b + side * (half + 0.3), b - side * (half + 0.3), 0.5, ParkMap.BLOCK_WALKERS)
		map.add_obstacle_segment(a + side * (half + 0.3), a + side * gap, 0.5, ParkMap.BLOCK_WALKERS)
		map.add_obstacle_segment(a - side * gap, a - side * (half + 0.3), 0.5, ParkMap.BLOCK_WALKERS)


## The harbour: the quay's edge as a wall with bollards, the jetty (boats moored along it),
## the cutter, a lifebuoy.
func _harbour() -> void:
	var kit := MeshKit.new()
	kit.use("masonry")
	var x0 := CoastLayout.QUAY_X + 2.0
	var x1 := CoastLayout.MOLE[0].x - CoastLayout.MOLE_HALF
	var z := CoastLayout.QUAY_Z
	kit.quad(Vector3(x0, CoastLayout.QUAY_Y, z), Vector3(x0, -3.0, z), Vector3(x1, -3.0, z), Vector3(x1, CoastLayout.QUAY_Y, z), CoastModels.STONE)
	var mi := MeshInstance3D.new()
	mi.name = "Quay"
	mi.mesh = kit.commit()
	root.add_child(mi)
	var x := x0 + 2.0
	while x < x1 - 1.0:
		if absf(x - CoastLayout.JETTY[0].x) > 3.0:
			batch.add(CoastModels.bollard(), Transform3D(Basis(), Vector3(x, CoastLayout.QUAY_Y, z - 0.6)))
			map.add_obstacle_circle(Vector2(x, z - 0.6), 0.2, ParkMap.BLOCK_PEOPLE)
		x += 6.0
	# The quay's edge: nobody falls in.
	map.add_obstacle_segment(Vector2(x0, z - 0.1), Vector2(CoastLayout.JETTY[0].x - CoastLayout.JETTY_HALF - 0.2, z - 0.1), 0.4, ParkMap.BLOCK_WALKERS)
	map.add_obstacle_segment(Vector2(CoastLayout.JETTY[0].x + CoastLayout.JETTY_HALF + 0.2, z - 0.1), Vector2(x1, z - 0.1), 0.4, ParkMap.BLOCK_WALKERS)
	var jk := MeshKit.new()
	for d: Dictionary in CoastLayout.decks():
		if (d["a"] as Vector2).x == CoastLayout.JETTY[0].x:
			_deck(jk, d, false, false)
	var jm := MeshInstance3D.new()
	jm.name = "Jetty"
	jm.mesh = jk.commit()
	root.add_child(jm)
	var cutter := CoastLayout.place("cutter")
	_put(CoastModels.cutter(), cutter, PI / 2, ParkLayout.WATER_Y - 0.05)
	coast.posts["cutter"] = [Vector3(cutter.x, CoastLayout.QUAY_Y, z - 2.0), PI]
	coast.posts["harbour"] = [Vector3(102, CoastLayout.QUAY_Y, 141), PI]
	var lb := Vector2(x0 + 1.0, z - 1.4)
	batch.add(CoastModels.lifebuoy_stand(), Transform3D(Basis(Vector3.UP, PI), Vector3(lb.x, CoastLayout.QUAY_Y, lb.y)))
	map.add_obstacle_circle(lb, 0.25, ParkMap.BLOCK_PEOPLE)


## The mole: big stone blocks along its line, a paved top, the lighthouse at its end, lamps.
func _mole() -> void:
	var kit := MeshKit.new()
	var prng := part_rng(8484)
	var pts: Array = CoastLayout.MOLE
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n := int(ceil(a.distance_to(b) / 2.2))
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		for k in n:
			var p := a.lerp(b, (k + 0.5) / n)
			for s: float in [-1.0, 1.0]:
				var q := p + side * s * (CoastLayout.MOLE_HALF + 0.6)
				kit.use("masonry")
				kit.push(Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y) + prng.randf_range(-0.2, 0.2)), Vector3(q.x, ParkLayout.WATER_Y - 0.4, q.y)))
				kit.box(Vector3.ZERO, Vector3(prng.randf_range(1.4, 2.0), prng.randf_range(2.0, 2.8), prng.randf_range(1.8, 2.4)),
					CoastModels.STONE.darkened(prng.randf() * 0.15))
				kit.pop()
	var mi := MeshInstance3D.new()
	mi.name = "Mole"
	mi.mesh = kit.commit()
	root.add_child(mi)
	var light := CoastLayout.place("lighthouse")
	_put(CoastModels.lighthouse(), light, PI * 0.25, CoastLayout.MOLE_Y)
	map.add_obstacle_circle(light, 3.0, ParkMap.BLOCK_WALKERS)
	coast.posts["lighthouse"] = [Vector3(light.x + 2.4, CoastLayout.MOLE_Y, light.y - 2.4), PI * 0.75]
	coast.spots["lighthouse"] = Vector3(light.x + 2.2, CoastLayout.MOLE_Y, light.y - 2.2)
	var beam := MeshInstance3D.new()
	beam.name = "LightBeam"
	beam.mesh = CoastModels.light_beam()
	beam.position = Vector3(light.x, CoastLayout.MOLE_Y + 17.2, light.y)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	coast.light_beam = beam
	for t: float in [0.15, 0.4, 0.65]:
		var p := (pts[0] as Vector2).lerp(pts[1], t) + Vector2(-CoastLayout.MOLE_HALF + 0.6, 0)
		_lamp(p, CoastLayout.MOLE_Y)
	# Walls along the mole's edges.
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var side := Vector2(-(b - a).normalized().y, (b - a).normalized().x)
		for s: float in [-1.0, 1.0]:
			map.add_obstacle_segment(a + side * s * (CoastLayout.MOLE_HALF + 0.2), b + side * s * (CoastLayout.MOLE_HALF + 0.2), 0.6, ParkMap.BLOCK_WALKERS)


# --- Rocks, sandbank, buoys, surf --------------------------------------------------------------

func _rocks() -> void:
	var prng := part_rng(8585)
	for i in 160:
		var p := Vector2(prng.randf_range(-130.0, -88.0), prng.randf_range(126.0, 216.0))
		var depth := CoastLayout.rock_depth(p)
		if depth < -6.0:
			continue
		var s := prng.randf_range(1.2, 3.2) * (1.4 if depth > 4.0 else 1.0)
		_static.add_mesh(CoastModels.rock(prng.randi() % 4), Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled(Vector3(s, s * prng.randf_range(0.6, 1.0), s)),
			Vector3(p.x, gy(p) - 0.4 * s, p.y)))
	for i in 30:
		var p := Vector2(prng.randf_range(-128.0, -110.0), prng.randf_range(130.0, 200.0))
		if CoastLayout.rock_depth(p) < 6.0:
			continue
		var t := NatureModels.tree("pine", prng.randi() % 3)
		var s := prng.randf_range(0.7, 1.0)
		batch.add(t, Transform3D(Basis(Vector3.UP, prng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(p.x, gy(p) - 0.2, p.y)))
		world.coast_trees.append({"pos": p, "kind": "pine", "forest": false})


## The seals on the sandbank (models; phase 4 lets them move).
func _sandbank() -> void:
	var prng := part_rng(8686)
	var c := CoastLayout.SANDBANK
	for k in 4:
		var p := c + Vector2(-7.0 + k * 4.5, prng.randf_range(-1.5, 1.5))
		_put(CoastModels.seal(k), p, prng.randf_range(-PI, PI), gy(p) - 0.05)


## Buoys along the boats' limit (south and the sides).
func _buoys() -> void:
	var v := 0
	var x := -CoastLayout.BUOY_X
	while x <= CoastLayout.BUOY_X:
		_buoy(Vector2(x, CoastLayout.BUOY_Z + 1.0), v)
		v += 1
		x += 13.0
	var z := CoastLayout.shore_z(-120.0) + 40.0
	while z < CoastLayout.BUOY_Z:
		for sx: float in [-1.0]:
			_buoy(Vector2(sx * (CoastLayout.BUOY_X + 1.0), z), v)
			v += 1
		z += 13.0


func _buoy(p: Vector2, v: int) -> void:
	var node := MeshInstance3D.new()
	node.mesh = CoastModels.buoy(v)
	node.position = Vector3(p.x, ParkLayout.WATER_Y - 0.08, p.y)
	node.add_to_group("bobbing")
	root.add_child(node)


## The surf: a strip along the water's edge from the rocks to the harbour, following the sand
## (the foam runs up the beach) and lying on the water further out.
func _surf() -> void:
	var kit := MeshKit.new()
	kit.use("surf")
	var x := -95.0
	var step := 2.0
	var prev := []
	while x <= CoastLayout.QUAY_X - 2.0:
		var edge := Vector2(x, CoastLayout.shore_z(x) - 5.5)
		var outer := Vector2(x, CoastLayout.shore_z(x) + 7.0)
		var a := Vector3(edge.x, maxf(gy(edge), ParkLayout.WATER_Y) + 0.04, edge.y)
		var b := Vector3(outer.x, ParkLayout.WATER_Y + 0.04, outer.y)
		var mid_p := edge.lerp(outer, 0.4)
		var m := Vector3(mid_p.x, maxf(gy(mid_p), ParkLayout.WATER_Y) + 0.04, mid_p.y)
		var cur := [a, m, b]
		if not prev.is_empty():
			var u0 := x - step
			var u1 := x
			kit.quad_uv(prev[0], cur[0], cur[1], prev[1], Color.WHITE, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 0.4), Vector2(u0, 0.4))
			kit.quad_uv(prev[1], cur[1], cur[2], prev[2], Color.WHITE, Vector2(u0, 0.4), Vector2(u1, 0.4), Vector2(u1, 1.0), Vector2(u0, 1.0))
		prev = cur
		x += step
	var mi := MeshInstance3D.new()
	mi.name = "Surf"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _near_place(p: Vector2, margin: float) -> bool:
	for id: String in CoastLayout.PLACES:
		if id in ["promenade", "pier", "mole", "rocks", "sandbank"]:
			continue
		var pl: Dictionary = CoastLayout.PLACES[id]
		if p.distance_to(pl["pos"]) < pl["r"] + margin:
			return true
	for key: String in CoastLayout.AREAS:
		var a: Dictionary = CoastLayout.AREAS[key]
		if ParkMap.in_rect(p, a["pos"], a["size"] + Vector2(margin, margin) * 2.0, a["rot"]):
			return true
	return false
