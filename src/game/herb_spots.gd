class_name HerbSpots
extends RefCounted
## Where the herbs and berries for the potions grow (doc/burg.md), as Gathering spots of kind
## "herb" (spot["item"] = the herb): chamomile on the city park's meadows, elder in its hedges,
## woodruff under the Nordwald's trees, wild garlic along its brook, lavender in the Kirmes's
## gardens, St John's wort on the castle's herb slope, rose hips and elder in its hedges. Each
## area places its own when it is built, with its own random sequence (nothing else moves).

## Herb clumps are small: not drawn beyond this (metres). They and the bushes are instanced
## per area (one InstanceBatcher, few draw calls); a picked one is hidden by its handle.
const RANGE := 40.0


## City park and Nordwald (World.build, before the navigation).
static func place_park(world: World) -> void:
	var root := _root(world, world.static_root, "ParkHerbs")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8181
	var map := world.map
	for anchor: Vector2 in [ParkLayout.place("great_meadow"), ParkLayout.place("picnic")]:
		_scatter(world, root, rng, "chamomile", anchor, 18.0, 3, func(p: Vector2) -> bool: return ParkMap.in_park(p, 4.0))
	for anchor: Vector2 in [Vector2(-118, 40), Vector2(118, -60), Vector2(-60, 82), Vector2(90, 80)]:
		_scatter(world, root, rng, "elder", anchor, 10.0, 1, func(p: Vector2) -> bool: return ParkMap.in_park(p, 3.0))
	# Woodruff under forest trees, wild garlic along the brook.
	var n := 0
	var k := 0
	for t: Dictionary in world.trees:
		if n >= 8:
			break
		k += 1
		if not t["forest"] or k % 41 != 0:
			continue
		var p: Vector2 = (t["pos"] as Vector2) + Vector2(-1.6, 1.0)
		if _free(map, p):
			_herb(world, root, "woodruff", n, p)
			n += 1
	n = 0
	var brook := map.brook
	for i in range(1, brook.size() - 1, maxi(1, brook.size() / 14)):
		if n >= 8:
			break
		var d := (brook[i + 1] - brook[i - 1]).normalized()
		var side := Vector2(-d.y, d.x) * (4.2 if n % 2 == 0 else -4.2)
		var p := brook[i] + side
		if _free(map, p):
			_herb(world, root, "wild_garlic", n, p)
			n += 1
	root.finish(world)


## The Kirmes's gardens: lavender round the rose arbour and in the light garden.
static func place_fair(world: World, parent: Node3D) -> void:
	var root := _root(world, parent, "FairHerbs")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8282
	for anchor: Vector2 in [FairLayout.place("oasis_roses"), FairLayout.place("oasis_lights")]:
		_scatter(world, root, rng, "lavender", anchor, 10.0, 3, func(p: Vector2) -> bool: return ParkMap.in_fair(p, 3.0))
	root.finish(world)


## The castle: St John's wort on the herb slope, rose hips and elder in the hedges (BurgBuilder,
## before the navigation).
static func place_burg(world: World, parent: Node3D) -> void:
	var root := _root(world, parent, "BurgHerbs")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8383
	var ok := func(p: Vector2) -> bool:
		return ParkMap.in_burg(p, 3.0) and not BurgLayout.in_castle(p, -3.0) and not BurgLayout.in_mountain(p, -3.0)
	_scatter(world, root, rng, "st_johns_wort", BurgLayout.place("herb_slope"), 22.0, 8, ok)
	_scatter(world, root, rng, "rose_hip", BurgLayout.place("hedges"), 20.0, 6, ok)
	_scatter(world, root, rng, "elder", BurgLayout.place("hedges") + Vector2(0, 30), 14.0, 3, ok)
	root.finish(world)


## Collects an area's herbs: `finish` builds them under `parent`.
class Batch:
	var batcher := InstanceBatcher.new(65.0)
	var parent: Node3D
	var name := ""
	var spots: Array[Dictionary] = []

	func finish(world: World) -> void:
		batcher.build(parent, name)
		for spot in spots:
			spot["batch"] = batcher
			world.gather_spots.append(spot)
			if Gameplay.gathering and is_instance_valid(Gameplay.gathering) and Gameplay.gathering.world == world:
				Gameplay.gathering.spots.append(spot)
				Gameplay.gathering.show_spot(spot, Gameplay.gathering.is_ready(spot))


static func _root(_world: World, parent: Node3D, name: String) -> Batch:
	var b := Batch.new()
	b.parent = parent
	b.name = name
	return b


## `count` spots of `item` within `radius` of `anchor` where `ok` holds.
static func _scatter(world: World, root: Batch, rng: RandomNumberGenerator, item: String, anchor: Vector2, radius: float,
		count: int, ok: Callable) -> void:
	var placed := 0
	var have := root.spots.filter(func(s: Dictionary) -> bool: return s.get("item", "") == item).size() \
		+ world.gather_spots.filter(func(s: Dictionary) -> bool: return s.get("item", "") == item).size()
	for attempt in 80:
		if placed >= count:
			break
		var p := anchor + Vector2(rng.randf_range(-radius, radius), rng.randf_range(-radius, radius))
		if not ok.call(p) or not _free(world.map, p):
			continue
		var near := func(s: Dictionary) -> bool: return Vector2(s["pos"].x, s["pos"].z).distance_to(p) < 3.0
		if world.gather_spots.any(near) or root.spots.any(near):
			continue
		_herb(world, root, item, have + placed, p)
		placed += 1


## Grass without obstacles, off the paths and the water (not is_solid: that depends on whether
## the area is awake, the spots must not).
static func _free(map: ParkMap, p: Vector2) -> bool:
	var c := ParkMap.to_cell(p)
	return map.ground_at(p) == ParkMap.Ground.GRASS and (map.solid[c.y * ParkMap.W + c.x] & ParkMap.BLOCK_PEOPLE) == 0 \
		and map.path_dist_at(p) > 1.4 and map.water_dist_at(p.x, p.y) > 1.5


## A spot: a clump (hidden while it regrows), or for elder and rose hips a bush (stays) with
## its berries (hidden).
static func _herb(world: World, root: Batch, item: String, i: int, p: Vector2) -> void:
	var y := world.map.walk_height(p.x, p.y) - 0.03
	var xf := Transform3D(Basis(Vector3.UP, float(i) * 2.3), Vector3(p.x, y, p.y))
	if item in ["elder", "rose_hip"]:
		root.batcher.add(NatureModels.bush(i % 3, false), xf, true, 140.0)
		world.map.add_obstacle_circle(p, 0.7, ParkMap.BLOCK_PEOPLE)
	var mesh := NatureModels.bush_fruit(item) if item in ["elder", "rose_hip"] else NatureModels.herb(item)
	var handle := root.batcher.add(mesh, xf, false, RANGE if not item in ["elder", "rose_hip"] else 90.0)
	root.spots.append({"id": "herb_%s_%d" % [item, i], "kind": "herb", "item": item, "pos": Vector3(p.x, y + 0.03, p.y),
		"nodes": [], "inst": handle})
