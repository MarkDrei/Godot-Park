class_name Vegetation
extends RefCounted
## Scatters trees, bushes, flowers, grass, reeds, lily pads and rocks.
## Trees get obstacles and are registered with the World (squirrels climb them).

var world: World
var map: ParkMap
var rng := RandomNumberGenerator.new()
var trees_batch := InstanceBatcher.new(130.0)
var small_batch := InstanceBatcher.new(48.0)
var _tree_grid := {}   # Vector2i (9 m cells) -> Array[Vector2]


func _init(w: World) -> void:
	world = w
	map = w.map
	rng.seed = 1234


func build() -> void:
	_avenue()
	_scatter_trees()
	_forest_trees()
	_water_plants()
	_bushes_and_flowers()
	_forest_floor()
	_grass()
	trees_batch.build(world.static_root, "Trees")
	small_batch.build(world.static_root, "Plants")


func _free_for_tree(p: Vector2, trunk: float, gap: float) -> bool:
	if not ParkMap.in_world(p, 5.0):
		return false
	if map.path_dist_at(p) < trunk + 1.6:
		return false
	var wd := map.water_dist_at(p.x, p.y)
	if wd < 1.2:
		return false
	var c := ParkMap.to_cell(p)
	if map.solid[c.y * ParkMap.W + c.x] != 0:
		return false
	var kind := map.ground_at(p)
	if kind != ParkMap.Ground.GRASS and kind != ParkMap.Ground.BANK:
		return false
	if in_mountain(p, 4.0):
		return false
	for id: String in ParkLayout.PLACES:
		var pl: Dictionary = ParkLayout.PLACES[id]
		if p.distance_to(pl["pos"]) < pl["r"] + 2.0:
			return false
	for key: String in ParkLayout.AREAS:
		var a: Dictionary = ParkLayout.AREAS[key]
		if ParkMap.in_rect(p, a["pos"], a["size"] + Vector2(4, 4), a["rot"]):
			return false
	for m: Dictionary in ParkLayout.MEADOWS:
		var q: Vector2 = (p - m["pos"]) / m["radii"]
		if q.length() < 1.0:
			return false
	for b: Bench in world.benches:
		if Vector2(b.position.x, b.position.z).distance_to(p) < 2.5:
			return false
	var c9 := Vector2i(floori(p.x / 9.0), floori(p.y / 9.0))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for q: Vector2 in _tree_grid.get(c9 + Vector2i(dx, dz), []):
				if q.distance_to(p) < gap:
					return false
	return true


func _plant(kind: String, p: Vector2, scale := 1.0) -> void:
	var info: Dictionary = NatureModels.TREES[kind]
	var variant := rng.randi() % int(info["variants"])
	var gy := map.height_at(p.x, p.y)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale, scale))
	trees_batch.add(NatureModels.tree(kind, variant), Transform3D(basis, Vector3(p.x, gy - 0.05, p.y)), true, 260.0)
	var trunk: float = info["trunk"] * scale
	map.add_obstacle_circle(p, trunk + 0.15)
	var height := {"oak": 8.0, "maple": 9.0, "birch": 8.0, "pine": 9.5, "fir": 8.5, "willow": 6.5, "cherry": 5.5, "chestnut": 8.0}
	world.trees.append({"pos": p, "kind": kind, "trunk": trunk, "height": height[kind] * scale, "ground": gy,
		"forest": ParkLayout.in_forest(p)})
	var c9 := Vector2i(floori(p.x / 9.0), floori(p.y / 9.0))
	if not _tree_grid.has(c9):
		_tree_grid[c9] = []
	_tree_grid[c9].append(p)


## Cherry avenue along the north entrance.
func _avenue() -> void:
	for z in range(-86, -64, 5):
		for side: float in [-1.0, 1.0]:
			var p := Vector2(side * 4.4 - 0.3 * (z + 86) / 22.0 * 7.0 * 0.0, float(z))
			if map.path_dist_at(p) < 1.5:
				p.x += side * 1.2
			if _free_for_tree(p, 0.3, 3.0):
				_plant("cherry", p, rng.randf_range(0.9, 1.1))


func _zone_kind(p: Vector2, wd: float) -> String:
	if wd < 6.0:
		return "willow" if rng.randf() < 0.55 else ["oak", "birch"][rng.randi() % 2]
	# Pine grove in the north-west.
	if p.x < -60 and p.y < -55:
		return ["pine", "fir", "fir", "birch"][rng.randi() % 4]
	if p.x > 80 and p.y < -40:
		return ["fir", "pine", "birch", "maple"][rng.randi() % 4]
	if p.distance_to(Vector2(-95, 40)) < 25:
		return ["birch", "birch", "maple", "cherry"][rng.randi() % 4]
	var pick := rng.randf()
	if pick < 0.28:
		return "oak"
	if pick < 0.46:
		return "maple"
	if pick < 0.6:
		return "chestnut"
	if pick < 0.72:
		return "birch"
	if pick < 0.8:
		return "cherry"
	if pick < 0.9:
		return "fir"
	return "pine"


func _scatter_trees() -> void:
	var attempts := 9000
	var target := 520
	for i in attempts:
		if world.trees.size() >= target:
			break
		var p := Vector2(rng.randf_range(-124, 124), rng.randf_range(-84, 84))
		var wd := map.water_dist_at(p.x, p.y)
		var dense := (p.x < -60 and p.y < -55) or (p.x > 80 and p.y < -40) or absf(p.x) > 112 or absf(p.y) > 74
		var gap := 5.0 if dense else 8.5
		var kind := _zone_kind(p, wd)
		var trunk: float = NatureModels.TREES[kind]["trunk"]
		if not _free_for_tree(p, trunk, gap):
			continue
		_plant(kind, p, rng.randf_range(0.85, 1.2))


## Inside the rock massif at the north edge (plus a margin in metres).
static func in_mountain(p: Vector2, margin := 0.0) -> bool:
	var q := (p - ParkLayout.MOUNTAIN_CENTER) / (ParkLayout.MOUNTAIN_RADII + Vector2(margin, margin))
	return q.length() < 1.0


func _forest_kind(p: Vector2) -> String:
	# Conifers for felling in the west, light birch and pine near the quarry, mixed elsewhere.
	if p.x < -50:
		return ["fir", "fir", "pine", "fir", "birch"][rng.randi() % 5]
	if p.y < -215 and p.x > 20:
		return ["pine", "birch", "pine", "fir"][rng.randi() % 4]
	return ["oak", "maple", "chestnut", "birch", "fir", "oak", "pine", "maple"][rng.randi() % 8]


## Nordwald: denser than the park, conifers in the west.
func _forest_trees() -> void:
	var lo := ParkLayout.WORLD_MIN + Vector2(6, 6)
	var target := world.trees.size() + 620
	for i in 12000:
		if world.trees.size() >= target:
			break
		var p := Vector2(rng.randf_range(lo.x, -lo.x), rng.randf_range(lo.y, ParkLayout.FOREST_EDGE - 5.0))
		var kind := _forest_kind(p)
		var gap := 4.6 if p.x < -50 else 5.8
		if not _free_for_tree(p, NatureModels.TREES[kind]["trunk"], gap):
			continue
		_plant(kind, p, rng.randf_range(0.9, 1.25))


## Undergrowth in the Nordwald: bushes along paths, ferns of grass, stumps, logs and mushrooms.
func _forest_floor() -> void:
	var lo := ParkLayout.WORLD_MIN + Vector2(4, 4)
	var hi := Vector2(-lo.x, ParkLayout.FOREST_EDGE - 3.0)
	var placed := 0
	for i in 2600:
		if placed > 260:
			break
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if map.path_dist_at(p) < 1.2 or not _free_for_tree(p, 0.8, 1.8):
			continue
		var s := rng.randf_range(0.8, 1.4)
		small_batch.add(NatureModels.bush(rng.randi() % 5, rng.randf() < 0.15), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
			Vector3(p.x, map.height_at(p.x, p.y) - 0.1, p.y)), true, 140.0)
		map.add_obstacle_circle(p, 0.7 * s, 1)
		placed += 1
	for i in 110:
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if not _free_for_tree(p, 0.8, 2.0):
			continue
		var pick := rng.randf()
		var mesh: Mesh = NatureModels.rock(rng.randi() % 6)
		if pick < 0.35:
			mesh = NatureModels.stump()
		elif pick < 0.6:
			mesh = NatureModels.log_mesh()
		small_batch.add(mesh, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, map.height_at(p.x, p.y) - 0.08, p.y)), true, 120.0)
		map.add_obstacle_circle(p, 0.6, 1)
	for t: Dictionary in world.trees:
		if t["forest"] and rng.randf() < 0.18:
			var p: Vector2 = t["pos"] + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
			small_batch.add(NatureModels.mushroom(false), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, map.height_at(p.x, p.y), p.y)), false, 40.0)
	for i in 9000:
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if map.ground_at(p) != ParkMap.Ground.GRASS or map.path_dist_at(p) < 0.2 or in_mountain(p):
			continue
		var s := rng.randf_range(0.9, 1.7)
		small_batch.add(NatureModels.grass_tuft(rng.randi() % 4), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
			Vector3(p.x, map.height_at(p.x, p.y) - 0.02, p.y)), false, 45.0)


func _water_plants() -> void:
	for line: PackedVector2Array in map.water_lines():
		for i in range(0, line.size(), 3):
			if rng.randf() < 0.45:
				continue
			var n := TerrainBuilder._normal_at(line, i) * (1.0 if rng.randf() < 0.5 else -1.0)
			var p := line[i] + n * (ParkLayout.CREEK_HALF_WIDTH + rng.randf_range(-0.3, 0.6))
			if not map.bridge_at(p).is_empty() or not ParkMap.in_world(p, 2.0) or map.path_dist_at(p) < 1.0:
				continue
			small_batch.add(NatureModels.reeds(rng.randi() % 4), Transform3D(Basis(Vector3.UP, rng.randf() * TAU),
				Vector3(p.x, map.height_at(p.x, p.y) - 0.1, p.y)), false, 90.0)
	# Reeds around the pond, lily pads on it.
	for i in 70:
		var a := rng.randf() * TAU
		var r := ParkLayout.POND_RADII * rng.randf_range(0.98, 1.06)
		var p := ParkLayout.POND_CENTER + Vector2(cos(a) * r.x, sin(a) * r.y)
		if p.distance_to(ParkLayout.place("pier")) < 4.0 or map.path_dist_at(p) < 1.0 or p.distance_to(Vector2(48, -6)) < 3.0:
			continue
		small_batch.add(NatureModels.reeds(rng.randi() % 4), Transform3D(Basis(Vector3.UP, rng.randf() * TAU),
			Vector3(p.x, map.height_at(p.x, p.y) - 0.1, p.y)), false, 90.0)
	for i in 34:
		var a := rng.randf() * TAU
		var k := rng.randf_range(0.45, 0.9)
		var p := ParkLayout.POND_CENTER + Vector2(cos(a) * ParkLayout.POND_RADII.x * k, sin(a) * ParkLayout.POND_RADII.y * k)
		if p.distance_to(ParkLayout.ISLAND_CENTER) < ParkLayout.ISLAND_RADIUS + 1.0 or p.distance_to(Vector2(40, 16)) < 3.0:
			continue
		small_batch.add(NatureModels.lily_pad(rng.randi() % 4), Transform3D(Basis(Vector3.UP, rng.randf() * TAU),
			Vector3(p.x, ParkLayout.WATER_Y + 0.02, p.y)), false, 80.0)
	# The island gets a weeping willow and some rocks.
	_plant("willow", ParkLayout.ISLAND_CENTER + Vector2(-1.0, 0.5), 0.8)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var p := ParkLayout.ISLAND_CENTER + Vector2(cos(a), sin(a)) * 3.4
		small_batch.add(NatureModels.rock(i), Transform3D(Basis(Vector3.UP, a), Vector3(p.x, map.height_at(p.x, p.y) - 0.1, p.y)), true, 120.0)


func _bushes_and_flowers() -> void:
	var placed := 0
	for i in 2600:
		if placed > 320:
			break
		var p := Vector2(rng.randf_range(-124, 124), rng.randf_range(-84, 84))
		var near_path := map.path_dist_at(p)
		if near_path < 1.2 or near_path > 6.0:
			continue
		if not _free_for_tree(p, 0.8, 1.8):
			continue
		var flowering := rng.randf() < 0.35
		var s := rng.randf_range(0.7, 1.3)
		small_batch.add(NatureModels.bush(rng.randi() % 5, flowering), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
			Vector3(p.x, map.height_at(p.x, p.y) - 0.1, p.y)), true, 140.0)
		map.add_obstacle_circle(p, 0.7 * s, 1)
		placed += 1
	# Wild flower patches on lawns.
	for patch in 70:
		var c := Vector2(rng.randf_range(-120, 120), rng.randf_range(-80, 80))
		if map.ground_at(c) != ParkMap.Ground.GRASS or map.path_dist_at(c) < 1.0:
			continue
		var v := rng.randi() % 7
		for k in 14:
			var p := c + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
			if map.ground_at(p) != ParkMap.Ground.GRASS or map.path_dist_at(p) < 0.5:
				continue
			small_batch.add(NatureModels.flower(v if rng.randf() < 0.7 else rng.randi() % 7),
				Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, map.height_at(p.x, p.y), p.y)), false, 60.0)
	# Rocks, stumps and logs.
	for i in 60:
		var p := Vector2(rng.randf_range(-124, 124), rng.randf_range(-84, 84))
		if not _free_for_tree(p, 0.8, 2.0):
			continue
		var pick := rng.randf()
		var mesh: Mesh = NatureModels.rock(rng.randi() % 6)
		if pick < 0.2:
			mesh = NatureModels.stump()
		elif pick < 0.35:
			mesh = NatureModels.log_mesh()
		small_batch.add(mesh, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, map.height_at(p.x, p.y) - 0.08, p.y)), true, 120.0)
		map.add_obstacle_circle(p, 0.6, 1)
	# Mushrooms under trees.
	for t: Dictionary in world.trees:
		if rng.randf() < 0.12:
			var p: Vector2 = t["pos"] + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
			small_batch.add(NatureModels.mushroom(false), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, map.height_at(p.x, p.y), p.y)), false, 40.0)


func _grass() -> void:
	var count := 0
	for i in 26000:
		if count >= 9000:
			break
		var p := Vector2(rng.randf_range(-128, 128), rng.randf_range(-88, 88))
		var kind := map.ground_at(p)
		if kind != ParkMap.Ground.GRASS and kind != ParkMap.Ground.BANK:
			continue
		if map.path_dist_at(p) < 0.2:
			continue
		var s := rng.randf_range(0.8, 1.5)
		small_batch.add(NatureModels.grass_tuft(rng.randi() % 4), Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
			Vector3(p.x, map.height_at(p.x, p.y) - 0.02, p.y)), false, 45.0)
		count += 1
