class_name CoastSpots
extends RefCounted
## What the Möwenbucht's beach and water give (doc/moewenbucht.md), as Gathering spots: shells
## (now and then amber) along the water's edge, fishing places on the pier head, the mole and the
## quay, each with its catch (Gathering.CATCH). Fishing from a rowing boat: BoatFishing.

## Fishing places: [where to stand, a point on the water to face, catch].
const FISHING := [
	[Vector2(-7.6, 251.2), Vector2(-9, 256), "pier"], [Vector2(7.6, 251.2), Vector2(9, 256), "pier"],
	[Vector2(-8.2, 240.0), Vector2(-13, 240), "pier"], [Vector2(8.2, 240.0), Vector2(13, 240), "pier"],
	[Vector2(128.4, 172.0), Vector2(134, 172), "pier"], [Vector2(128.4, 196.0), Vector2(134, 196), "pier"],
	[Vector2(108.0, 225.2), Vector2(106, 232), "pier"],
	[Vector2(106.0, 148.6), Vector2(106, 154), "harbour"], [Vector2(116.0, 148.6), Vector2(116, 158), "harbour"],
]


static func place(world: World, parent: Node3D) -> void:
	var root := HerbSpots._root(world, parent, "CoastShells")
	var rng := RandomNumberGenerator.new()
	rng.seed = 8787
	var n := 0
	var x := -88.0
	while x < CoastLayout.QUAY_X - 8.0:
		x += rng.randf_range(7.0, 11.0)
		if absf(x - CoastLayout.PIER_X) < 5.0 or CoastLayout.GROYNES.any(func(g: Array) -> bool: return absf(float(g[0]) - x) < 3.0):
			continue
		var p := Vector2(x, CoastLayout.shore_z(x) - rng.randf_range(4.0, 8.0))
		var c := ParkMap.to_cell(p)
		if world.map.ground_at(p) != ParkMap.Ground.SAND or world.map.solid[c.y * ParkMap.W + c.x] != 0:
			continue
		var y := world.map.walk_height(p.x, p.y)
		var handle := root.batcher.add(CoastModels.shells(n), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(p.x, y, p.y)), false, 70.0)
		root.spots.append({"id": "shells_%d" % n, "kind": "shells", "pos": Vector3(p.x, y, p.y), "nodes": [], "inst": handle})
		n += 1
	root.finish(world)
	# The fishing places have no model (not in the batch).
	for i in FISHING.size():
		var f: Array = FISHING[i]
		var p: Vector2 = f[0]
		var q: Vector2 = f[1]
		var spot := {"id": "sea_fish_%d" % i, "kind": "fishing", "catch": f[2], "nodes": [],
			"pos": Vector3(p.x, world.map.walk_height(p.x, p.y), p.y), "face": Vector3(q.x, 0, q.y)}
		world.gather_spots.append(spot)
		if Gameplay.gathering and is_instance_valid(Gameplay.gathering) and Gameplay.gathering.world == world:
			Gameplay.gathering.spots.append(spot)
