class_name ForestDecorator
extends RefCounted
## Places the buildings and props of the Nordwald (doc/nordwald.md): lumber camp, sawmill,
## forest inn, the dwarves' office, mine and railway, quarry rocks and beehives.
## Registers obstacles with the map; gameplay hooks (shops, gathering) come on top.

var world: World
var map: ParkMap
var rng := RandomNumberGenerator.new()
var root: Node3D

## Mine railway: polylines (x, z) from the mine portal.
const RAILS := [
	[Vector2(74, -251.0), Vector2(73, -243), Vector2(68, -236)],
	[Vector2(73, -243), Vector2(84, -246), Vector2(94, -247)],
]


func _init(w: World) -> void:
	world = w
	map = w.map
	rng.seed = 777


func build() -> void:
	root = Node3D.new()
	root.name = "Nordwald"
	world.static_root.add_child(root)
	_lumber_camp()
	_sawmill()
	_inn()
	_dwarves()
	_quarry()
	_orchard()
	_farm_shop()
	_forest_benches()


func ground_y(p: Vector2) -> float:
	return map.height_at(p.x, p.y)


## Adds a mesh at p (ground height) turned by yaw; returns its transform.
func put(mesh: Mesh, p: Vector2, yaw := 0.0, obstacle := Vector2.ZERO, y := NAN) -> Transform3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, ground_y(p) if is_nan(y) else y, p.y))
	root.add_child(mi)
	if obstacle != Vector2.ZERO:
		map.add_obstacle_rect(p, obstacle, -yaw)
	return mi.transform


## Text on a sign board given in the mesh's local coordinates (front +Z).
func add_sign(text: String, xf: Transform3D, local: Vector3, size := 40) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = Color("f3ead2")
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.transform = xf * Transform3D(Basis(), local)
	l.double_sided = false
	root.add_child(l)


func _lumber_camp() -> void:
	var hut := put(ForestModels.hut(), Vector2(-46, -167), 0.0, Vector2(4.8, 4.0))
	add_sign("Holzfällerlager", hut, Vector3(0, 2.25, 1.75), 60)
	put(ForestModels.workbench(), Vector2(-35, -166), 0.0, Vector2(2.3, 1.2))
	put(ForestModels.chest(), Vector2(-38.5, -166.5), 0.0, Vector2(1.3, 0.9))
	var chest := FunctionSpot.new()
	chest.name = "StorageChest"
	chest.position = Vector3(-38.5, ground_y(Vector2(-38.5, -165.6)), -165.6)
	chest.radius = 2.0
	chest.prompt_text = "Lagerkiste öffnen"
	chest.action_fn = func(_a: Actor) -> void: UI.open_bag(true)
	world.add_child(chest)
	_station("Workbench", Vector3(-35, 0, -164.6), "An der Werkbank arbeiten", "workbench")
	_station("Campfire", Vector3(-40, 0, -157.4), "Am Lagerfeuer kochen", "campfire")
	put(ForestModels.campfire(), Vector2(-40, -159))
	put(ForestModels.campfire_flames(), Vector2(-40, -159))
	map.add_obstacle_circle(Vector2(-40, -159), 0.9)
	put(ForestModels.chopping_block(), Vector2(-31, -158))
	map.add_obstacle_circle(Vector2(-31, -158), 0.5)
	put(ForestModels.log_pile(3), Vector2(-29, -164), PI / 2, Vector2(3.0, 1.8))
	put(ForestModels.log_pile(2), Vector2(-53, -160), 0.0, Vector2(3.0, 1.4))
	put(ForestModels.axe_target(), Vector2(-51, -151), PI / 2, Vector2(1.0, 2.0))
	put(ForestModels.hammock(), Vector2(-29, -151), 0.0)
	for s: float in [-1.0, 1.0]:
		map.add_obstacle_circle(Vector2(-29 + s * 1.6, -151), 0.2)
	_bench(Vector3(-29, ground_y(Vector2(-29, -151)), -151.15), PI, 1, 0.85, "hammock")
	# Logs around the campfire.
	var fire := Vector2(-40, -159)
	for off: Vector2 in [Vector2(0, -2.4), Vector2(-2.3, 0.6), Vector2(2.3, 0.8)]:
		var p := fire + off
		var yaw := atan2(fire.x - p.x, fire.y - p.y)
		put(ForestModels.log_seat(), p, yaw, Vector2(2.0, 0.5))
		_bench(Vector3(p.x, ground_y(p), p.y), yaw, 2, 0.44)
	_shop_spot("lumber_camp", Vector2(-32.5, -161.5), Vector2(-32.5, -159.7))


func _station(node_name: String, p: Vector3, text: String, station: String) -> void:
	var s := FunctionSpot.new()
	s.name = node_name
	s.position = Vector3(p.x, ground_y(Vector2(p.x, p.z)), p.z)
	s.radius = 2.2
	s.prompt_text = text
	s.action_fn = func(_a: Actor) -> void: UI.open_craft(station)
	world.add_child(s)


func _sawmill() -> void:
	var xf := put(ForestModels.sawmill(), Vector2(-72, -125), 0.0, Vector2(6.2, 1.4))
	add_sign("Sägewerk", xf, Vector3(0, 2.75, 2.6), 90)
	for p: Vector2 in [Vector2(-63, -124), Vector2(-81, -124)]:
		put(ForestModels.log_pile(3), p, PI / 2, Vector2(3.0, 1.8))
	_shop_spot("sawmill", Vector2(-69.5, -121.5), Vector2(-69.5, -119.8))


func _inn() -> void:
	# Faces west, towards the path; the terrace is in front.
	var p := Vector2(28, -152)
	var yaw := -PI / 2
	var xf := put(ForestModels.forest_inn(), p, yaw)
	add_sign("Waldschänke", xf, Vector3(0, 3.05, 1.4), 100)
	var back := xf * Vector3(0, 0, -2.0)
	map.add_obstacle_rect(Vector2(back.x, back.z), Vector2(10.6, 7.1), -yaw)
	for x: float in [-3.0, 3.0]:
		var r := xf * Vector3(x, 0, 5.45)
		map.add_obstacle_rect(Vector2(r.x, r.z), Vector2(4.0, 0.3), -yaw, 1)
		# Benches on the terrace, facing the forest.
		var bp := xf * Vector3(x, 0.12, 3.9)
		var bm := MeshInstance3D.new()
		bm.mesh = PropModels.bench(1)
		bm.transform = Transform3D(Basis(Vector3.UP, yaw), bp)
		root.add_child(bm)
		map.add_obstacle_rect(Vector2(bp.x, bp.z), Vector2(1.9, 0.6), -yaw, 1)
		_bench(bp, yaw, 3, 0.47)
	var v := xf * Vector3(1.6, 0, 2.4)
	var c := xf * Vector3(1.6, 0, 4.2)
	_shop_spot("forest_inn", Vector2(v.x, v.z), Vector2(c.x, c.z))


func _dwarves() -> void:
	var office := put(ForestModels.dwarf_office(), Vector2(34, -238), 0.0, Vector2(5.2, 4.2))
	add_sign("Zwergenkontor", office, Vector3(0, 2.75, 2.4), 90)
	_shop_spot("dwarf_office", Vector2(36.5, -235.3), Vector2(36.5, -233.5))
	put(ForestModels.cooking_pot(), Vector2(30, -236.2), 0.0)
	map.add_obstacle_circle(Vector2(30, -236.2), 0.6)
	var portal := put(ForestModels.mine_portal(), Vector2(74, -251.0), 0.0)
	add_sign("Glück auf!", portal, Vector3(0, 4.1, 0.15), 70)
	for s: float in [-1.0, 1.0]:
		var post := portal * Vector3(s * 1.8, 0, 0)
		map.add_obstacle_circle(Vector2(post.x, post.z), 0.3)
	for line: Array in RAILS:
		for i in line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var d := b - a
			put(ForestModels.rails(d.length()), a, atan2(d.x, d.y), Vector2.ZERO, ground_y(a) - 0.05)
	var carts := [[Vector2(73.6, -248), "", 0.0], [Vector2(68.8, -237.5), "rock", 0.6], [Vector2(90, -246.6), "ore", 1.5]]
	for c: Array in carts:
		put(ForestModels.mine_cart(c[1]), c[0], c[2], Vector2(1.2, 1.6))
		root.get_child(root.get_child_count() - 1).add_to_group("decor_carts")
	put(ForestModels.switch_tower(), Vector2(98, -240), -PI / 2, Vector2(3.4, 3.0))
	add_sign("Stellwerk", Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(98, ground_y(Vector2(98, -240)), -240)), Vector3(0, 3.0, 1.38), 70)


func _quarry() -> void:
	var faces := [[Vector2(47, -244), 7.0], [Vector2(55, -246), 8.0], [Vector2(44, -236), 5.0], [Vector2(80, -236), 5.5],
		[Vector2(63, -247), 6.0]]
	for i in faces.size():
		var p: Vector2 = faces[i][0]
		var s: float = faces[i][1]
		var to_floor := ParkLayout.place("quarry") - p
		put(ForestModels.rock_face(i, s), p, atan2(to_floor.x, to_floor.y), Vector2.ZERO, ground_y(p) - 0.3)
		map.add_obstacle_circle(p, s * 0.45)


## Things to gather (Gathering): placed after the vegetation so trees do not grow on them.
## Each spot: {id, kind, pos, nodes (hidden while it regrows)}.
func gather_spots() -> void:
	root = Node3D.new()
	root.name = "GatherSpots"
	world.static_root.add_child(root)
	# Boulders on the quarry floor.
	var boulders := [Vector2(54, -232), Vector2(60, -227), Vector2(51, -226), Vector2(64, -232), Vector2(57, -238),
		Vector2(68, -228), Vector2(48, -231), Vector2(72, -232), Vector2(62, -222), Vector2(53, -239)]
	for i in boulders.size():
		var p: Vector2 = boulders[i]
		_spot("rock_%d" % i, "rock", p, [ForestModels.boulder(i)], 0.75)
	# Twigs and loose stones in the forest, near the paths so they are found.
	var n_twigs := 0
	var n_pebbles := 0
	for attempt in 600:
		if n_twigs >= 30 and n_pebbles >= 12:
			break
		var p := Vector2(rng.randf_range(-120, 120), rng.randf_range(-262, -98))
		var pd := map.path_dist_at(p)
		if pd < 1.0 or pd > 7.0 or map.ground_at(p) != ParkMap.Ground.GRASS or map.is_solid(p) or Vegetation.in_mountain(p, 3.0):
			continue
		if n_twigs < 30:
			_spot("twigs_%d" % n_twigs, "twigs", p, [ForestModels.twig_bundle()], 0.0)
			n_twigs += 1
		elif p.y < -180 or p.x > 30:
			_spot("pebbles_%d" % n_pebbles, "pebbles", p, [ForestModels.pebbles()], 0.0)
			n_pebbles += 1
	# Berry bushes around the glade.
	var glade := ParkLayout.place("berry_glade")
	for i in 9:
		var a := TAU * i / 9.0 + 0.2
		var p := glade + Vector2(cos(a) * 7.5, sin(a) * 5.5)
		if map.path_dist_at(p) < 1.2:
			p += Vector2(cos(a), sin(a)) * 2.0
		_spot("berries_%d" % i, "berries", p, [ForestModels.berry_bush()], 0.8, [ForestModels.berries()])
	# Ceps in the mushroom glade and under a few forest trees.
	var mg := ParkLayout.place("mushroom_glade")
	var mushrooms: Array[Vector2] = []
	for i in 6:
		var a := TAU * i / 6.0
		mushrooms.append(mg + Vector2(cos(a), sin(a)) * rng.randf_range(2.5, 5.5))
	var k := 0
	for t: Dictionary in world.trees:
		if mushrooms.size() >= 14:
			break
		k += 1
		if t["forest"] and k % 37 == 0:
			mushrooms.append((t["pos"] as Vector2) + Vector2(1.4, 0.6))
	for i in mushrooms.size():
		_spot("mushroom_%d" % i, "mushroom", mushrooms[i], [ForestModels.ceps()], 0.0)
	# Apple trees in the orchard (the fruit hides when picked).
	var orchard := ParkLayout.place("orchard")
	for i in 8:
		var p := orchard + Vector2(-12 + (i % 4) * 7.0, -5 + (i / 4) * 9.0) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		_spot("apple_%d" % i, "apple", p, [ForestModels.apple_tree()], 0.35, [ForestModels.apples()])
	# Fishing spots on the shore of the forest pond.
	var c := ParkLayout.FOREST_POND_CENTER
	var r := ParkLayout.FOREST_POND_RADII
	for i in 4:
		var a: float = [0.6, 1.6, 2.6, -0.4][i]
		var p := c + Vector2(cos(a) * (r.x + 2.6), sin(a) * (r.y + 2.6))
		world.gather_spots.append({"id": "fish_%d" % i, "kind": "fishing", "pos": Vector3(p.x, ground_y(p), p.y), "nodes": [],
			"face": Vector3(c.x, 0, c.y)})


## Adds a gather spot with its meshes; `obstacle` > 0 blocks walking.
## `fruit` meshes are hidden while it regrows, the base meshes stay (bushes, trees).
func _spot(id: String, kind: String, p: Vector2, meshes: Array, obstacle: float, fruit: Array = []) -> void:
	var hide: Array[Node3D] = []
	var yaw := rng.randf() * TAU
	for m: Mesh in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = m
		mi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, ground_y(p) - 0.05, p.y))
		root.add_child(mi)
		if fruit.is_empty():
			hide.append(mi)
	for m: Mesh in fruit:
		var fi := MeshInstance3D.new()
		fi.mesh = m
		fi.transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, ground_y(p) - 0.05, p.y))
		root.add_child(fi)
		hide.append(fi)
	if obstacle > 0.0:
		map.add_obstacle_circle(p, obstacle)
	world.gather_spots.append({"id": id, "kind": kind, "pos": Vector3(p.x, ground_y(p), p.y), "nodes": hide})


func _orchard() -> void:
	for p: Vector2 in [Vector2(106, -131), Vector2(108, -133.5), Vector2(110, -131)]:
		put(ForestModels.beehive(), p, rng.randf_range(-0.3, 0.3), Vector2(0.9, 0.8))
	_shop_spot("beehives", Vector2(103, -134), Vector2(101.2, -134))


func _farm_shop() -> void:
	var p := ParkLayout.place("farm_shop")
	var face: Vector2 = ParkLayout.PLACES["farm_shop"]["face"]
	var d := (face - p).normalized()
	var yaw := atan2(d.x, d.y)
	var xf := put(ForestModels.market_stall(), p, yaw, Vector2(3.2, 1.4))
	add_sign("Hofladen", xf, Vector3(0, 2.55, 0.74), 70)
	_shop_spot("farm_shop", p - d * 1.1, p + d * 1.5)


## Registers a trader: where the vendor stands and where customers stand.
func _shop_spot(id: String, vendor: Vector2, counter: Vector2) -> void:
	var d := vendor - counter
	world.shop_spots[id] = {"pos": Vector3(counter.x, ground_y(counter), counter.y), "yaw": atan2(d.x, d.y),
		"vendor": Vector3(vendor.x, ground_y(vendor), vendor.y)}


var _benches := 0


## A seat for Nordwald people and the player (not counted for "Bankdrücker").
func _bench(pos: Vector3, yaw: float, seats: int, height: float, id := "") -> void:
	var b := Bench.new()
	_benches += 1
	b.setup(id if id != "" else "forestbench_%d" % _benches, pos, yaw, seats, height)
	world.static_root.add_child(b)
	world.register_bench(b, false)
	world.forest_benches.append(b)


## Park benches for a rest in the Nordwald: along the forest roads, at the forest pond, in
## the berry glade and at the orchard.
func _forest_benches() -> void:
	for path: Dictionary in ParkLayout.PATHS:
		if path["id"] not in ["forest_main", "forest_camp", "forest_sawmill", "forest_east"]:
			continue
		var pts := PackedVector2Array(path["points"])
		var half: float = path["width"] * 0.5
		var dist := 0.0
		var next := 14.0
		var side := 1.0
		for i in range(1, pts.size()):
			var seg := pts[i] - pts[i - 1]
			var t := seg.normalized()
			var n := Vector2(-t.y, t.x)
			while next <= dist + seg.length():
				var q := pts[i - 1] + t * (next - dist)
				next += 30.0
				for s: float in [side, -side]:
					var p := q + n * s * (half + 1.25)
					if _bench_spot_ok(p):
						_park_bench(p, ParkDecorator.yaw_to(p, q))
						side = -s
						break
			dist += seg.length()
	# At the forest pond, between the fishing spots, looking over the water.
	var c := ParkLayout.FOREST_POND_CENTER
	var r := ParkLayout.FOREST_POND_RADII
	for a: float in [-1.5, -2.6, 2.1]:
		_bench_near(c + Vector2(cos(a) * (r.x + 4.5), sin(a) * (r.y + 4.5)), c)
	# In the middle of the berry glade, inside the ring of bushes.
	var glade := ParkLayout.place("berry_glade")
	_bench_near(glade + Vector2(0, 2.0), glade + Vector2(0, -2))
	# At the edge of the orchard, looking at the apple trees.
	var orchard := ParkLayout.place("orchard")
	_bench_near(orchard + Vector2(-3, 10.5), orchard)


## The first good spot within 3 m of `p`, facing `look`.
func _bench_near(p: Vector2, look: Vector2) -> void:
	for d: Vector2 in [Vector2.ZERO, Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(0, 1.5), Vector2(0, -1.5),
			Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		if _bench_spot_ok(p + d, false):
			_park_bench(p + d, ParkDecorator.yaw_to(p + d, look))
			return
	push_warning("no spot for a forest bench near %s" % p)


func _park_bench(p: Vector2, yaw: float) -> void:
	put(PropModels.bench(1), p, yaw, Vector2(1.9, 0.6))
	_bench(Vector3(p.x, ground_y(p), p.y), yaw, 3, 0.47)


## Dry, beside the path, flat, free of buildings and rocks, and not next to another seat.
## Benches along the roads also keep clear of the forest places (they have their own).
func _bench_spot_ok(p: Vector2, along_road := true) -> bool:
	if not ParkLayout.in_forest(p) or not ParkMap.in_world(p, 4.0) or Vegetation.in_mountain(p, 3.0):
		return false
	if map.water_dist_at(p.x, p.y) < 2.5 or map.path_dist_at(p) < 0.4 or not map.bridge_at(p).is_empty():
		return false
	if absf(ground_y(p + Vector2(1, 0)) - ground_y(p - Vector2(1, 0))) > 0.35 \
			or absf(ground_y(p + Vector2(0, 1)) - ground_y(p - Vector2(0, 1))) > 0.35:
		return false
	for d: Vector2 in [Vector2.ZERO, Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(0, -1.2)]:
		if map.is_solid(p + d):
			return false
	for b: Bench in world.forest_benches:
		if Vector2(b.position.x, b.position.z).distance_to(p) < (12.0 if along_road else 4.0):
			return false
	if along_road:
		for id: String in ParkLayout.PLACES:
			var pl: Dictionary = ParkLayout.PLACES[id]
			if pl.get("forest", false) and p.distance_to(pl["pos"]) < pl["r"] + 2.0:
				return false
		for key: String in ParkLayout.AREAS:
			var a: Dictionary = ParkLayout.AREAS[key]
			if ParkMap.in_rect(p, a["pos"], a["size"] + Vector2(2, 2), a["rot"]):
				return false
	return true
