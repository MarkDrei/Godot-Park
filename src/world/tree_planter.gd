class_name TreePlanter
extends RefCounted
## Where a tree may stand, and planting it, for Vegetation (park and Nordwald) and FairBuilder
## (Westpark): on grass or bank, off paths, water, obstacles and benches, outside the area's own
## keep-out places, at least a gap away from the trees planted so far.

const CELL := 9.0                # metres per bucket of the spacing grid
const HEIGHT := {"oak": 8.0, "maple": 9.0, "birch": 8.0, "pine": 9.5, "fir": 8.5, "willow": 6.5, "cherry": 5.5, "chestnut": 8.0}

var map: ParkMap
var rng: RandomNumberGenerator
var batch: InstanceBatcher
var _keeps_out: Callable         # (p: Vector2) -> bool: outside the area or on one of its places
var _benches: Array              # lists of Bench to keep 2.5 m from
var _grid := {}                  # Vector2i -> Array[Vector2]


func _init(m: ParkMap, r: RandomNumberGenerator, b: InstanceBatcher, keeps_out: Callable, benches: Array) -> void:
	map = m
	rng = r
	batch = b
	_keeps_out = keeps_out
	_benches = benches


func free_at(p: Vector2, trunk: float, gap: float) -> bool:
	# Cheap checks first: most tries end here.
	if not ParkMap.in_bounds(p, 0.0):
		return false
	if map.path_dist_at(p) < trunk + 1.6 or map.water_dist_at(p.x, p.y) < 1.2:
		return false
	var c := ParkMap.to_cell(p)
	if map.solid[c.y * ParkMap.W + c.x] != 0:
		return false
	var kind := map.ground_at(p)
	if kind != ParkMap.Ground.GRASS and kind != ParkMap.Ground.BANK:
		return false
	if _keeps_out.call(p):
		return false
	for list: Array in _benches:
		for b: Bench in list:
			if Vector2(b.position.x, b.position.z).distance_to(p) < 2.5:
				return false
	var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			for q: Vector2 in _grid.get(cell + Vector2i(dx, dz), []):
				if q.distance_to(p) < gap:
					return false
	return true


## Plants a tree (a random variant, turned at random) with its trunk as an obstacle; returns
## {"pos", "kind", "trunk", "height", "ground", "inst"} for the caller's list of trees.
func plant(kind: String, p: Vector2, scale := 1.0) -> Dictionary:
	var info: Dictionary = NatureModels.TREES[kind]
	var variant := rng.randi() % int(info["variants"])
	var ground := map.height_at(p.x, p.y)
	var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(scale, scale, scale))
	var handle := batch.add(NatureModels.tree(kind, variant), Transform3D(basis, Vector3(p.x, ground - 0.05, p.y)), true, 260.0)
	var trunk: float = info["trunk"] * scale
	map.add_obstacle_circle(p, trunk + 0.15)
	var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	if not _grid.has(cell):
		_grid[cell] = []
	_grid[cell].append(p)
	return {"pos": p, "kind": kind, "trunk": trunk, "height": HEIGHT[kind] * scale, "ground": ground, "inst": handle}
