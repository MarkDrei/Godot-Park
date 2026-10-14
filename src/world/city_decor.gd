class_name CityDecor
extends RefCounted
## Life for the Oststadt's empty places (doc/oststadt.md): back gardens behind the houses
## (fences and hedges, a shed, washing line, trampoline … and fruit trees), the Apfelwiese with
## apple trees to pick and benches, the playground, street furniture (advertising columns, bus
## stops with a bench, bins, post boxes, hydrants, flower tubs, bicycles) and things on the
## lots. Everything merges into one mesh per 65 m area (TownProps, and trees and play things
## by MeshKit.add_mesh), so a tree or a bin costs no draw call of its own; only the benches
## (World benches) go through the builder's batch. Everything is an obstacle in the ParkMap.

const AREA := 90.0              # metres per merged decor mesh
const GARDEN := ["shed", "washing", "trampoline", "set", "beds", "greenhouse", "compost", "sandpit"]
## Trees whose crowns are on the foliage surface (cherry has its own blossom material, and every
## material is one more draw call per area).
const YARD_TREES := ["apple", "birch", "maple", "apple", "oak", "chestnut"]

var b: CityBuilder
var map: ParkMap
var world: World
var rng := RandomNumberGenerator.new()
var _kits := {}                 # Vector2i -> MeshKit
const G := ParkMap.Ground


func _init(builder: CityBuilder) -> void:
	b = builder
	map = builder.map
	world = builder.world
	rng.seed = 6161


func build() -> void:
	_orchard()
	_playground()
	_gardens()
	_yard_trees()
	_street_furniture()
	_bus_stops()
	_lot_margins()
	_lot_markings()
	_lots()
	for key: Vector2i in _kits:
		var mi := MeshInstance3D.new()
		mi.name = "CityDecor_%d_%d" % [key.x, key.y]
		mi.mesh = (_kits[key] as MeshKit).commit()
		mi.visibility_range_end = 240.0
		mi.visibility_range_end_margin = 10.0
		b.root.add_child(mi)


## Draws f(kit) at p turned by yaw into the area's mesh.
func put(p: Vector2, yaw: float, f: Callable) -> void:
	var kit := _kit(p)
	kit.push(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, map.walk_height(p.x, p.y), p.y)))
	f.call(kit)
	kit.pop()


## Draws f(kit) in world coordinates (fences, hedges) into the mesh of the area round `at`,
## lifted to the ground there.
func draw(at: Vector2, f: Callable) -> void:
	var kit := _kit(at)
	kit.push(Transform3D(Basis(), Vector3(0, map.walk_height(at.x, at.y), 0)))
	f.call(kit)
	kit.pop()


func _kit(p: Vector2) -> MeshKit:
	var key := Vector2i(floori(p.x / AREA), floori(p.y / AREA))
	if not _kits.has(key):
		_kits[key] = MeshKit.new()
	return _kits[key]


## Merges a model into the area's mesh at p (on the ground, y on top).
func mesh_at(mesh: Mesh, p: Vector2, yaw := 0.0, scale := 1.0, y := 0.0) -> void:
	_kit(p).add_mesh(mesh, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), Vector3(p.x, map.walk_height(p.x, p.y) + y, p.y)))


func _tree(kind: String, p: Vector2, scale: float) -> void:
	var mesh := ForestModels.apple_tree() if kind == "apple" else NatureModels.tree(kind, rng.randi() % int(NatureModels.TREES[kind]["variants"]))
	var yaw := rng.randf() * TAU
	mesh_at(mesh, p, yaw, scale, -0.05)
	if kind == "apple":
		mesh_at(ForestModels.apples(), p, yaw, scale, -0.05)
	map.add_obstacle_circle(p, 0.4, 3)


## Somebody can't walk here (a house, a lamp, a fence …).
func _blocked(p: Vector2) -> bool:
	var c := ParkMap.to_cell(p)
	return (map.solid[c.y * ParkMap.W + c.x] & 1) != 0


## A back yard: lawn inside a block, not a lot and not taken.
func _yard(p: Vector2) -> bool:
	return map.ground_at(p) == G.GRASS and not _blocked(p) and CityLayout.lot_at(p) == ""


## Every point within r of p is yard (or kind `ground`).
func _free(p: Vector2, r: float, ground := G.GRASS, lots_ok := false) -> bool:
	for k in 9:
		var q := p if k == 0 else p + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * r
		if map.ground_at(q) != ground or _blocked(q):
			return false
		if not lots_ok and CityLayout.lot_at(q) != "":
			return false
	return true


func _near_house(p: Vector2, d: float) -> bool:
	for h: Dictionary in CityLayout.houses():
		if (h["rect"] as Rect2).grow(d).has_point(p):
			return true
	return false


# --- Back gardens ----------------------------------------------------------------------

func _gardens() -> void:
	for h: Dictionary in CityLayout.houses():
		var front: Vector2 = h["front"]
		var back := -front
		var r: Rect2 = h["rect"]
		var c := r.get_center()
		var side := Vector2(-front.y, front.x)
		var half_d := (r.size.y if front.y != 0.0 else r.size.x) * 0.5
		var half_w := (r.size.x if front.y != 0.0 else r.size.y) * 0.5
		var hr := RandomNumberGenerator.new()
		hr.seed = hash(h["id"]) + 77
		var depth := 0
		for k in range(1, 11):
			if not _yard(c + back * (half_d + k)) or not _yard(c + back * (half_d + k) + side * (half_w - 0.5)) \
					or not _yard(c + back * (half_d + k) - side * (half_w - 0.5)):
				break
			depth = k
		if depth < 4:
			continue
		var yaw := atan2(front.x, front.y)
		# A fence or a hedge along one side of the garden.
		var s := 1.0 if hr.randf() < 0.5 else -1.0
		var a := c + back * (half_d + 0.6) + side * s * (half_w - 0.2)
		var e := c + back * (half_d + minf(depth - 0.5, 7.0)) + side * s * (half_w - 0.2)
		if hr.randf() < 0.65:
			var col: Color = [TownProps.WHITE, TownProps.WOOD_LIGHT, Color("6a8a5a")][hr.randi() % 3]
			draw(a, func(kit: MeshKit) -> void: TownProps.fence(kit, Vector3(a.x, 0, a.y), Vector3(e.x, 0, e.y), col))
		else:
			draw(a, func(kit: MeshKit) -> void: TownProps.hedge(kit, Vector3(a.x, 0, a.y), Vector3(e.x, 0, e.y), hr.randf_range(1.0, 1.5)))
		map.add_obstacle_segment(a, e, 0.5, 3)
		# One garden thing behind the house.
		var kind: String = GARDEN[hr.randi() % GARDEN.size()]
		var p := c + back * (half_d + minf(depth * 0.5, 3.6)) + side * hr.randf_range(-half_w * 0.3, half_w * 0.3)
		var size := {"shed": 1.6, "washing": 1.9, "trampoline": 1.8, "set": 1.5, "beds": 1.2, "greenhouse": 1.9, "compost": 0.8, "sandpit": 1.1}[kind] as float
		if _free(p, size * 0.8):
			var shed_col: Color = [Color("6b8a5a"), Color("8a5a34"), Color("a8483a"), Color("4a6a8a")][hr.randi() % 4]
			var parasol: Color = [Color("d8402e"), Color("2e86de"), Color("f2c230"), Color("27ae60")][hr.randi() % 4]
			put(p, yaw + PI, _garden_thing.bind(kind, hr, shed_col, parasol))
			if kind == "washing":
				map.add_obstacle_circle(p + Vector2(cos(-yaw), sin(-yaw)) * 1.7, 0.2, 3)
				map.add_obstacle_circle(p - Vector2(cos(-yaw), sin(-yaw)) * 1.7, 0.2, 3)
			else:
				map.add_obstacle_circle(p, size, 3)
		# A fruit tree at the end of a long garden.
		if depth >= 7:
			var t := c + back * (half_d + depth - 2.0) + side * hr.randf_range(-half_w * 0.4, half_w * 0.4)
			if _free(t, 1.2):
				_tree(["apple", "birch", "apple", "maple"][hr.randi() % 4], t, hr.randf_range(0.75, 0.95))


func _garden_thing(kit: MeshKit, kind: String, hr: RandomNumberGenerator, shed_col: Color, parasol: Color) -> void:
	match kind:
		"shed":
			TownProps.shed(kit, shed_col)
		"washing":
			TownProps.washing_line(kit, hr)
		"trampoline":
			TownProps.trampoline(kit)
		"set":
			TownProps.garden_set(kit, parasol)
		"beds":
			TownProps.raised_bed(kit, hr)
			kit.translate(Vector3(0, 0, 1.4))
			TownProps.raised_bed(kit, hr)
			kit.pop()
		"greenhouse":
			TownProps.greenhouse(kit)
		"compost":
			TownProps.compost(kit)
		"sandpit":
			TownProps.sandpit(kit)


## Trees in what is left of the yards.
func _yard_trees() -> void:
	for blk: Dictionary in CityLayout.blocks():
		var r: Rect2 = blk["rect"]
		var count := 0
		var y := r.position.y + 4.0
		while y < r.end.y - 4.0 and count < 9:
			var x := r.position.x + 4.0
			while x < r.end.x - 4.0 and count < 9:
				var p := Vector2(x + rng.randf_range(-1.5, 1.5), y + rng.randf_range(-1.5, 1.5))
				if _free(p, 2.6) and not _near_house(p, 2.5):
					_tree(YARD_TREES[rng.randi() % YARD_TREES.size()], p, rng.randf_range(0.7, 1.0))
					count += 1
				x += rng.randf_range(7.0, 10.0)
			y += rng.randf_range(7.0, 10.0)


# --- Little parks ----------------------------------------------------------------------

## The Apfelwiese: apple trees to pick, benches along the paths, lamps, a sign at the street.
func _orchard() -> void:
	var lot: Dictionary = CityLayout.LOTS["orchard"]
	var r: Rect2 = lot["rect"]
	var i := 0
	for p: Vector2 in [Vector2(232, 24.5), Vector2(240, 25.5), Vector2(252, 24.5), Vector2(260, 25.5),
			Vector2(232, 41), Vector2(238, 47), Vector2(254, 41), Vector2(260.5, 47)]:
		_apple_spot("town_apple_%d" % i, p)
		i += 1
	for e: Array in [[Vector2(235, 29.4), 0.0], [Vector2(256.5, 29.4), 0.0], [Vector2(236, 36.1), PI], [Vector2(257, 36.1), PI],
			[Vector2(242.4, 42.0), PI / 2]]:
		b._city_bench(e[0], e[1])
	var picnic := Vector2(255.5, 46.0)
	mesh_at(PropModels.picnic_table(), picnic, PI / 2)
	map.add_obstacle_rect(picnic, Vector2(1.9, 1.8), 0.0, 3)
	for p: Vector2 in [Vector2(242.6, 29.6), Vector2(249.2, 36.4), Vector2(249.2, 49.0)]:
		put(p, 0.0, TownProps.park_lamp)
		map.add_obstacle_circle(p, 0.2, 3)
		world.lamps.append(Vector3(p.x, 3.45, p.y))
	for p: Vector2 in [Vector2(238.4, 29.4), Vector2(253.0, 36.2)]:
		put(p, 0.0, TownProps.street_bin)
		map.add_obstacle_circle(p, 0.25, 3)
	_sign(Vector2(251.0, 49.6), 0.0, "Apfelwiese")
	_border(r, Vector2.DOWN)
	for p: Vector2 in [Vector2(228.5, 49.0), Vector2(263.5, 49.0), Vector2(228.5, 22.5), Vector2(264, 33)]:
		mesh_at(NatureModels.bush(rng.randi() % 3, false), p, rng.randf() * TAU)
		map.add_obstacle_circle(p, 0.6, 3)


## An apple tree whose apples can be picked (Gathering), like the Nordwald's orchard.
func _apple_spot(id: String, p: Vector2) -> void:
	var y := map.walk_height(p.x, p.y) - 0.05
	mesh_at(ForestModels.apple_tree(), p, 0.0, 1.0, -0.05)
	var fruit := MeshInstance3D.new()
	fruit.mesh = ForestModels.apples()
	fruit.transform = Transform3D(Basis(), Vector3(p.x, y, p.y))
	fruit.visibility_range_end = 110.0
	b.root.add_child(fruit)
	map.add_obstacle_circle(p, 0.35, 3)
	var spot := {"id": id, "kind": "apple", "pos": Vector3(p.x, y + 0.05, p.y), "nodes": [fruit]}
	world.gather_spots.append(spot)
	if Gameplay.gathering:
		Gameplay.gathering.spots.append(spot)
		Gameplay.gathering._show(spot, Gameplay.gathering.is_ready(spot))


## The playground: swings, slide, sandpit, seesaw, a spring duck and a climbing frame on the
## square, benches for the parents, trees and a fence.
func _playground() -> void:
	var r: Rect2 = CityLayout.LOTS["playground"]["rect"]
	var things := [[PropModels.swing_set(), Vector2(371, -132.5), 0.0, Vector2(3.6, 1.8)],
		[PropModels.slide(), Vector2(380.5, -131.5), PI / 2, Vector2(1.2, 3.6)],
		[PropModels.sandbox(), Vector2(371, -122.5), 0.0, Vector2(3.0, 3.0)],
		[PropModels.seesaw(), Vector2(380, -122), 0.0, Vector2(3.2, 0.8)],
		[PropModels.spring_duck(), Vector2(376, -127), PI, Vector2(0.8, 0.8)],
		[PropModels.climbing_frame(), Vector2(376, -134.5), 0.0, Vector2(2.4, 2.0)]]
	for t: Array in things:
		var p: Vector2 = t[1]
		mesh_at(t[0], p, t[2])
		map.add_obstacle_rect(p, t[3], -float(t[2]), 3)
	for e: Array in [[Vector2(364.2, -133.5), PI / 2], [Vector2(364.2, -120.5), PI / 2], [Vector2(386.5, -127.0), -PI / 2]]:
		b._city_bench(e[0], e[1])
	for p: Vector2 in [Vector2(362.5, -137.5), Vector2(387.5, -137.5), Vector2(387.5, -116.5), Vector2(362.5, -116.5)]:
		_tree(["maple", "chestnut"][rng.randi() % 2], p, 0.85)
	put(Vector2(365.0, -126.0), 0.0, TownProps.street_bin)
	map.add_obstacle_circle(Vector2(365.0, -126.0), 0.25, 3)
	put(Vector2(366.2, -129.6), 0.0, TownProps.park_lamp)
	map.add_obstacle_circle(Vector2(366.2, -129.6), 0.2, 3)
	world.lamps.append(Vector3(366.2, 3.45, -129.6))
	_sign(Vector2(360.4, -131.5), -PI / 2, "Spielplatz")
	_border(r, Vector2.LEFT)


## A low fence round a little park, open on the street side `open` and where houses stand.
func _border(r: Rect2, open: Vector2) -> void:
	var corners := [r.position + Vector2(0.4, 0.4), Vector2(r.end.x - 0.4, r.position.y + 0.4), r.end - Vector2(0.4, 0.4), Vector2(r.position.x + 0.4, r.end.y - 0.4)]
	var outward := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	for k in 4:
		if outward[k] == open:
			continue
		var a: Vector2 = corners[k]
		var e: Vector2 = corners[(k + 1) % 4]
		var n := int(a.distance_to(e) / 2.0)
		for i in n:
			var p0 := a.lerp(e, float(i) / n)
			var p1 := a.lerp(e, float(i + 1) / n)
			if _blocked((p0 + p1) * 0.5) or map.ground_at((p0 + p1) * 0.5) != G.GRASS:
				continue
			draw(p0, func(kit: MeshKit) -> void: TownProps.fence(kit, Vector3(p0.x, 0, p0.y), Vector3(p1.x, 0, p1.y), TownProps.WOOD_LIGHT))
			map.add_obstacle_segment(p0, p1, 0.3, 3)


func _sign(p: Vector2, yaw: float, text: String) -> void:
	put(p, yaw, TownProps.park_sign)
	map.add_obstacle_rect(p, Vector2(2.2, 0.3), -yaw, 3)
	var f := Vector2(sin(yaw), cos(yaw))
	var l := b.label(text, Vector3(p.x + f.x * 0.05, map.walk_height(p.x, p.y) + 1.55, p.y + f.y * 0.05), yaw, 56, Color("f4ead2"), 0)
	l.double_sided = false


# --- Streets ---------------------------------------------------------------------------

## Bins, hydrants, post boxes and flower tubs at the kerb between the lamps, an advertising
## column at a corner of most blocks, bicycles at the market and the gelateria.
func _street_furniture() -> void:
	var n := 0
	for blk: Dictionary in CityLayout.blocks():
		var r: Rect2 = blk["rect"]
		var sides := []
		if r.position.y > CityLayout.MIN.y + 1.0:
			sides.append([Vector2(r.position.x, r.position.y - CityLayout.WALK + 0.55), Vector2(r.end.x, r.position.y - CityLayout.WALK + 0.55), PI])
		if r.end.y < CityLayout.MAX.y - 1.0:
			sides.append([Vector2(r.position.x, r.end.y + CityLayout.WALK - 0.55), Vector2(r.end.x, r.end.y + CityLayout.WALK - 0.55), 0.0])
		if r.position.x > CityLayout.MIN.x + 1.0:
			sides.append([Vector2(r.position.x - CityLayout.WALK + 0.55, r.position.y), Vector2(r.position.x - CityLayout.WALK + 0.55, r.end.y), -PI / 2])
		if r.end.x < CityLayout.MAX.x - 1.0:
			sides.append([Vector2(r.end.x + CityLayout.WALK - 0.55, r.position.y), Vector2(r.end.x + CityLayout.WALK - 0.55, r.end.y), PI / 2])
		for s: Array in sides:
			var a: Vector2 = s[0]
			var e: Vector2 = s[1]
			var yaw: float = s[2]
			var k := maxi(1, int(a.distance_to(e) / 24.0))
			# Between the lamps (they stand at (i + 0.5) / k).
			for i in range(1, k + 1):
				var p := a.lerp(e, float(i) / (k + 1) if k > 1 else 0.25)
				if map.ground_at(p) != G.SIDEWALK or _blocked(p) or _blocked(p + (e - a).normalized() * 1.0) or _blocked(p - (e - a).normalized() * 1.0):
					continue
				n += 1
				match n % 5:
					0, 2:
						put(p, yaw + PI, TownProps.street_bin)
					1:
						put(p, yaw, TownProps.hydrant)
					3:
						put(p, yaw + PI, TownProps.post_box if n % 3 == 0 else (func(kit: MeshKit) -> void: TownProps.flower_tub(kit, rng)))
					4:
						put(p, yaw, func(kit: MeshKit) -> void: TownProps.flower_tub(kit, rng))
				map.add_obstacle_circle(p, 0.3, 3)
		# An advertising column at a corner of the block, on the lawn or the square.
		for corner: Vector2 in [r.position + Vector2(1.6, 1.6), Vector2(r.end.x - 1.6, r.position.y + 1.6),
				r.end - Vector2(1.6, 1.6), Vector2(r.position.x + 1.6, r.end.y - 1.6)]:
			var ground := map.ground_at(corner)
			if (ground == G.GRASS or ground == G.PLAZA) and _free(corner, 1.0, ground, true) and not _near_house(corner, 0.8):
				put(corner, rng.randf() * TAU, func(kit: MeshKit) -> void: TownProps.ad_column(kit, rng))
				map.add_obstacle_circle(corner, 0.75, 3)
				break
	# Bicycles in racks at the market, the gelateria and the driving school.
	for e: Array in [[Vector2(221.5, -38.5), PI / 2], [Vector2(290.5, 50.0), 0.0], [Vector2(305.5, -100.5), 0.0]]:
		var p: Vector2 = e[0]
		var yaw: float = e[1]
		mesh_at(PropModels.bike_rack(), p, yaw)
		for i in 3:
			var off := Vector2(cos(-yaw), sin(-yaw)) * (-0.8 + i * 0.8)
			var col: Color = [Color("c0392b"), Color("2e86de"), Color("27ae60"), Color("f39c12"), Color("2c3e50")][rng.randi() % 5]
			mesh_at(PropModels.bicycle(col), p + off, yaw + PI / 2)
		map.add_obstacle_rect(p, Vector2(2.6, 1.4), -yaw, 3)


## Bus stops with a shelter and a bench, set back from the sidewalk on the block's edge.
func _bus_stops() -> void:
	# [street axis point, direction along the street, side (+1 right of it)]
	for e: Array in [[Vector2(210, -51), Vector2(0, -1), 1.0], [Vector2(210, 25), Vector2(0, -1), 1.0],
			[Vector2(245, -12), Vector2(1, 0), 1.0], [Vector2(245, -12), Vector2(-1, 0), 1.0],
			[Vector2(315, -90), Vector2(1, 0), 1.0], [Vector2(280, -45), Vector2(0, -1), 1.0],
			[Vector2(236, 60), Vector2(-1, 0), 1.0], [Vector2(350, -120), Vector2(0, -1), 1.0]]:
		var c: Vector2 = e[0]
		var along: Vector2 = e[1]
		var out := Car.right_of(along) * float(e[2])
		var edge := CityLayout.BLOCK_GAP + 1.0
		for t in [0.0, 6.0, -6.0, 12.0, -12.0, 18.0, -18.0]:
			var p: Vector2 = c + along * t + out * edge
			var ok := true
			for dx in [-2.0, -1.0, 0.0, 1.0, 2.0]:
				for dz in [-0.5, 0.5]:
					var q: Vector2 = p + along * dx + out * dz
					var gr := map.ground_at(q)
					if _blocked(q) or not (gr == G.GRASS or gr == G.PLAZA):
						ok = false
			if not ok:
				continue
			var yaw := atan2(-out.x, -out.y)    # open towards the street
			put(p, yaw, TownProps.bus_shelter)
			b._city_bench(p - out * 0.2, yaw)
			map.add_obstacle_segment(p + out * 0.6 - along * 1.7, p + out * 0.6 + along * 1.7, 0.3, 3)
			map.add_obstacle_circle(p - out * 0.3 + along * 2.1, 0.15, 3)
			break


# --- Lots ------------------------------------------------------------------------------

## Trees along the lawn strips round the asphalt lots.
func _lot_margins() -> void:
	for id: String in CityLayout.LOTS:
		var lot: Dictionary = CityLayout.LOTS[id]
		if not lot.get("margin", false):
			continue
		var r: Rect2 = (lot["rect"] as Rect2).grow(-CityLayout.LOT_MARGIN * 0.5)
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		for k in 4:
			var a: Vector2 = corners[k]
			var e: Vector2 = corners[(k + 1) % 4]
			var n := int(a.distance_to(e) / 9.0)
			for i in n:
				var p := a.lerp(e, (i + 0.5) / n)
				if map.ground_at(p) != G.GRASS or _blocked(p) or _near_building(p, 2.5):
					continue
				if i % 3 == 1:
					mesh_at(NatureModels.bush(rng.randi() % 3, false), p, rng.randf() * TAU)
					map.add_obstacle_circle(p, 0.6, 3)
				else:
					_tree(["maple", "birch", "chestnut", "maple"][rng.randi() % 4], p, rng.randf_range(0.7, 0.85))


## Painted lines on the lots: the cinema's bays, customer bays at the garage and the petrol
## station's shop, the parking boxes of the depot's trucks, a practice lane at the school.
func _lot_markings() -> void:
	var white := CityBuilder.MARK
	var yellow := Color("e8c030")
	var line := func(kit: MeshKit, a: Vector2, e: Vector2, col: Color, width: float) -> void:
		var d := e - a
		kit.push(Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)), Vector3((a.x + e.x) * 0.5, 0.025, (a.y + e.y) * 0.5)))
		kit.box(Vector3.ZERO, Vector3(width, 0.01, d.length()), col)
		kit.pop()
	draw(Vector2(175, -200), func(kit: MeshKit) -> void:
		for row in 3:
			var z := -212.0 + row * 12.0
			for i in 8:
				var x := 154.0 + i * 6.0
				line.call(kit, Vector2(x, z - 2.6), Vector2(x, z + 2.6), white, 0.12))
	draw(Vector2(230, -126), func(kit: MeshKit) -> void:
		for i in 4:
			var x := 223.5 + i * 5.0
			line.call(kit, Vector2(x, -128.8), Vector2(x, -123.6), white, 0.12)
		line.call(kit, Vector2(223.5, -128.8), Vector2(238.5, -128.8), white, 0.12))
	draw(Vector2(158, -108), func(kit: MeshKit) -> void:
		for i in 3:
			var x := 154.5 + i * 5.0
			line.call(kit, Vector2(x, -110.6), Vector2(x, -105.4), white, 0.12))
	draw(Vector2(372, -206), func(kit: MeshKit) -> void:
		for x: float in [368.0, 376.0]:
			for s: float in [-1.0, 1.0]:
				line.call(kit, Vector2(x + s * 1.8, -211.0), Vector2(x + s * 1.8, -201.0), yellow, 0.15)
			line.call(kit, Vector2(x - 1.8, -211.0), Vector2(x + 1.8, -211.0), yellow, 0.15))
	draw(Vector2(320, -110), func(kit: MeshKit) -> void:
		var x := 306.0
		while x < 338.0:
			line.call(kit, Vector2(x, -110.0), Vector2(x + 2.0, -110.0), white, 0.12)
			x += 4.0
		line.call(kit, Vector2(306.0, -113.6), Vector2(338.0, -113.6), white, 0.12)
		line.call(kit, Vector2(306.0, -106.4), Vector2(338.0, -106.4), white, 0.12)
		line.call(kit, Vector2(334.0, -113.4), Vector2(334.0, -110.2), white, 0.4))


func _near_building(p: Vector2, d: float) -> bool:
	for bd: Dictionary in CityLayout.BUILDINGS:
		if (bd["rect"] as Rect2).grow(d).has_point(p):
			return true
	return false


func _lots() -> void:
	# Drive-in: picnic tables under parasols at the walk-up counter, trees in planters.
	for i in 3:
		var p := Vector2(172.0 + i * 8.0, -28.5)
		mesh_at(PropModels.picnic_table(), p, 0.0, 1.0, 0.012)
		var col: Color = [Color("d8402e"), Color("f2c230"), Color("d8402e")][i]
		put(p, 0.0, func(kit: MeshKit) -> void: TownProps.parasol(kit, col))
		map.add_obstacle_rect(p, Vector2(1.9, 1.8), 0.0, 7)
	for p: Vector2 in [Vector2(197.5, -76.0), Vector2(197.5, -45.0), Vector2(197.5, -30.0), Vector2(186.0, -76.5), Vector2(172.0, -77.0)]:
		_planter_tree(p)
	# Garage: a car up on the lift, drums, pallets.
	var lift := Vector2(262.0, -143.0)
	put(lift, PI / 2, TownProps.car_lift)
	var lifted := b.add(CarModels.car("kombi", Color("7f8c8d")), lift, PI / 2, 1.25)
	lifted.visibility_range_end = 170.0
	map.add_obstacle_rect(lift, Vector2(5.0, 3.6), 0.0, 7)
	for i in 4:
		var p := Vector2(268.5, -148.5 + i * 0.7)
		put(p, 0.0, func(kit: MeshKit) -> void: TownProps.drum(kit, [Color("2e5ea8"), Color("c0392b"), Color("2e5ea8"), Color("3a6a3a")][i]))
	map.add_obstacle_rect(Vector2(268.5, -147.4), Vector2(0.8, 3.0), 0.0, 7)
	put(Vector2(267.5, -129.0), 0.3, func(kit: MeshKit) -> void: TownProps.pallets(kit, 4))
	map.add_obstacle_rect(Vector2(267.5, -129.0), Vector2(1.6, 1.6), 0.0, 7)
	# Petrol station: air and water, flags, an ice chest by the shop.
	put(Vector2(186.0, -108.5), PI, TownProps.air_pump)
	map.add_obstacle_rect(Vector2(186.0, -108.5), Vector2(0.8, 0.8), 0.0, 7)
	for i in 3:
		var p := Vector2(152.5 + i * 1.6, -101.0)
		put(p, PI / 2, func(kit: MeshKit) -> void: TownProps.flag(kit, [Color("c0392b"), Color("2e86de"), Color("f2c230")][i], Color.WHITE))
		map.add_obstacle_circle(p, 0.15, 7)
	# Depot: bottle banks, a gravel heap, barriers and pallets.
	var cols := [Color("2e7a3a"), Color("e8e8e4"), Color("8a5a34"), Color("2e5ea8")]
	for i in 4:
		var p := Vector2(377.0 + i * 2.2, -172.5)
		put(p, PI, func(kit: MeshKit) -> void: TownProps.container(kit, cols[i]))
	map.add_obstacle_rect(Vector2(380.3, -172.5), Vector2(8.8, 1.8), 0.0, 7)
	put(Vector2(384.5, -186.0), 0.0, func(kit: MeshKit) -> void: TownProps.heap(kit, Color("9a948a"), 3.0))
	map.add_obstacle_circle(Vector2(384.5, -186.0), 3.0, 7)
	put(Vector2(364.0, -174.0), 0.0, TownProps.barriers)
	put(Vector2(368.0, -174.0), 0.0, func(kit: MeshKit) -> void: TownProps.pallets(kit, 3))
	map.add_obstacle_rect(Vector2(366.0, -174.0), Vector2(6.0, 1.6), 0.0, 7)


## A tree in a round concrete planter on a lot (cars go round it).
func _planter_tree(p: Vector2) -> void:
	put(p, 0.0, func(kit: MeshKit) -> void:
		kit.cylinder(Vector3.ZERO, 0.5, 1.1, 1.15, 12, Color("b8b2a6"))
		kit.cylinder(Vector3(0, 0.5, 0), 0.02, 1.0, 1.0, 12, Color("4a3424")))
	mesh_at(NatureModels.tree(["maple", "birch"][rng.randi() % 2], rng.randi() % 3), p, rng.randf() * TAU, 0.7, 0.45)
	map.add_obstacle_circle(p, 1.1, 7)
