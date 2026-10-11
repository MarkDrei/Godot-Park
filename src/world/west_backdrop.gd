class_name WestBackdrop
extends RefCounted
## The park as seen from the Oststadt while the park sleeps (World.enter_area): a coarse
## ground (grass, forest floor, paths, water), low-poly trees where the real trees stand and
## the fences with their two gates. A few thousand triangles instead of the park's 1.5 million.

const STEP := 4.0
const WATER := Color("3f7fa8")
const LEAVES := Color("4f8a3a")
const NEEDLES := Color("2f5f34")
const TRUNK := Color("6b4f36")
const FENCE := Color("2b2f2c")
const STONE := Color("cfc3a8")
const HEDGE := Color("3e6b32")


static func build(world: World) -> Node3D:
	var root := Node3D.new()
	root.name = "WestBackdrop"
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = _ground(world.map)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ground)
	var fence := MeshInstance3D.new()
	fence.name = "Fence"
	fence.mesh = _fence()
	root.add_child(fence)
	var batch := InstanceBatcher.new(130.0)
	var leafy := _tree(false)
	var conifer := _tree(true)
	for t: Dictionary in world.trees:
		var p: Vector2 = t["pos"]
		var s: float = t["height"] / 8.0
		var mesh := conifer if t["kind"] in ["pine", "fir"] else leafy
		batch.add(mesh, Transform3D(Basis(Vector3.UP, p.x * 0.7 + p.y).scaled(Vector3(s, s, s)), Vector3(p.x, t["ground"] - 0.05, p.y)), false)
	batch.build(root, "Trees")
	return root


## One quad per 4 m cell, coloured by what lies at its centre.
static func _ground(map: ParkMap) -> ArrayMesh:
	var kit := MeshKit.new()
	var lo := ParkLayout.WORLD_MIN
	var x1 := ParkLayout.CITY_EDGE
	var z := lo.y
	while z < ParkLayout.WORLD_MAX.y - 0.01:
		var x := lo.x
		while x < x1 - 0.01:
			var c := Vector2(x + STEP * 0.5, z + STEP * 0.5)
			var col: Color
			var kind := map.ground_at(c)
			if kind == ParkMap.Ground.WATER:
				col = WATER
			elif kind == ParkMap.Ground.GRASS:
				col = TerrainBuilder.FOREST_GRASS if ParkLayout.in_forest(c) else TerrainBuilder.GROUND_COLORS[kind]
			else:
				col = TerrainBuilder.GROUND_COLORS.get(kind, TerrainBuilder.GROUND_COLORS[ParkMap.Ground.GRASS])
			var h := func(px: float, pz: float) -> float:
				return ParkLayout.WATER_Y if kind == ParkMap.Ground.WATER else map.height_at(px, pz)
			var xe := minf(x + STEP, x1)
			var ze := z + STEP
			kit.quad(Vector3(x, h.call(x, z), z), Vector3(x, h.call(x, ze), ze), Vector3(xe, h.call(xe, ze), ze),
				Vector3(xe, h.call(xe, z), z), col)
			x += STEP
		z += STEP
	return kit.commit()


## The fence between park and town like the real one (stone posts, iron rails, a hedge
## behind; split rails along the Nordwald), open at the Osttor and the forest gate east.
static func _fence() -> ArrayMesh:
	var kit := MeshKit.new()
	var x := ParkLayout.CITY_EDGE - 0.3
	var gates := [ParkLayout.place("gate_e").y, ParkLayout.place("gate_forest_e").y]
	var z := ParkLayout.WORLD_MIN.y + 1.0
	while z < ParkLayout.WORLD_MAX.y - 1.0:
		var in_gate := gates.filter(func(g: float) -> bool: return z >= g - 2.6 and z < g + 2.6)
		if not in_gate.is_empty():
			z = in_gate[0] + 2.6
			continue
		var z1 := minf(z + 6.0, ParkLayout.WORLD_MAX.y - 1.0)
		for g: float in gates:
			if z < g - 2.6 and z1 > g - 2.6:
				z1 = g - 2.6
		var mid := (z + z1) * 0.5
		var span := z1 - z
		if mid < ParkLayout.FOREST_EDGE:
			# Split-rail fence along the Nordwald.
			kit.box(Vector3(x, 0.55, z), Vector3(0.18, 1.1, 0.18), TRUNK)
			kit.box(Vector3(x, 0.85, mid), Vector3(0.1, 0.1, span), TRUNK)
			kit.box(Vector3(x, 0.45, mid), Vector3(0.1, 0.1, span), TRUNK)
			z = z1
			continue
		kit.box(Vector3(x, 0.6, z), Vector3(0.4, 1.2, 0.4), STONE)
		kit.box(Vector3(x, 1.0, mid), Vector3(0.05, 0.06, span), FENCE)
		kit.box(Vector3(x, 0.2, mid), Vector3(0.05, 0.06, span), FENCE)
		var b := z + 0.25
		while b < z1 - 0.1:
			kit.box(Vector3(x, 0.6, b), Vector3(0.03, 0.9, 0.03), FENCE)
			b += 0.5
		kit.box(Vector3(x - 1.0, 0.55, mid), Vector3(0.9, 1.1, span), HEDGE)
		z = z1
	for g: float in gates:
		for side: float in [-2.6, 2.6]:
			kit.box(Vector3(x, 1.25, g + side), Vector3(0.7, 2.5, 0.7), STONE)
	return kit.commit()


## A tree of about 50 triangles: a ball of leaves or a cone of needles on a trunk.
static func _tree(needles: bool) -> ArrayMesh:
	var kit := MeshKit.new()
	kit.box(Vector3(0, 1.0, 0), Vector3(0.4, 2.0, 0.4), TRUNK)
	if needles:
		kit.cylinder(Vector3(0, 1.4, 0), 7.0, 2.2, 0.0, 6, NEEDLES)
	else:
		kit.sphere(Vector3(0, 4.2, 0), Vector3(2.6, 2.4, 2.6), LEAVES, 3, 6)
	return kit.commit()
