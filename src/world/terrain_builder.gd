class_name TerrainBuilder
extends RefCounted
## Builds the ground, water, path and plaza meshes from a ParkMap.
## Ground is written straight into arrays (faster than SurfaceTool for ~100k triangles).

const CHUNK := 20
const GROUND_COLORS := {
	ParkMap.Ground.GRASS: Color("6fa04a"),
	ParkMap.Ground.PATH: Color("a89a80"),
	ParkMap.Ground.GRAVEL: Color("c3ad86"),
	ParkMap.Ground.SAND: Color("e3cf98"),
	ParkMap.Ground.WATER: Color("4f5a3a"),
	ParkMap.Ground.BANK: Color("7c7a48"),
	ParkMap.Ground.PLAZA: Color("aaa293"),
	ParkMap.Ground.TRAIL: Color("9c8560"),
	ParkMap.Ground.BRIDGE: Color("6c7044"),
	ParkMap.Ground.STONES: Color("4f5a3a"),
	ParkMap.Ground.ROCK: Color("948f86"),
}
const FOREST_GRASS := Color("4f7f3a")
const PATH_COLORS := {"main": Color("c4b79e"), "side": Color("d2bf96"), "trail": Color("a78b62")}

var map: ParkMap


func _init(park_map: ParkMap) -> void:
	map = park_map


func build(parent: Node3D) -> void:
	var ground := Node3D.new()
	ground.name = "Ground"
	parent.add_child(ground)
	for cz in range(0, ParkMap.H, CHUNK):
		for cx in range(0, ParkMap.W, CHUNK):
			var mi := MeshInstance3D.new()
			mi.mesh = _ground_chunk(cx, cz)
			mi.name = "Chunk_%d_%d" % [cx, cz]
			ground.add_child(mi)
	parent.add_child(_water())
	parent.add_child(_paths())
	parent.add_child(_plazas())
	parent.add_child(_surroundings())


func _ground_chunk(cx: int, cz: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var lin := {}
	for k: int in GROUND_COLORS:
		lin[k] = GROUND_COLORS[k].srgb_to_linear()
	var forest_floor := FOREST_GRASS.srgb_to_linear()
	for z in range(cz, mini(cz + CHUNK, ParkMap.H)):
		# Darker, mossier grass in the Nordwald.
		var forest := smoothstep(ParkLayout.FOREST_EDGE + 2.0, ParkLayout.FOREST_EDGE - 10.0, ParkMap.ORIGIN.y + z)
		for x in range(cx, mini(cx + CHUNK, ParkMap.W)):
			var p00 := _v(x, z)
			var p10 := _v(x + 1, z)
			var p01 := _v(x, z + 1)
			var p11 := _v(x + 1, z + 1)
			var kind: int = map.ground[z * ParkMap.W + x]
			if _under_ribbon(x, z, kind):
				kind = ParkMap.Ground.GRASS
			var col: Color = lin[kind]
			if kind == ParkMap.Ground.GRASS and forest > 0.0:
				col = col.lerp(forest_floor, forest)
			col.a = 1.0 if kind == ParkMap.Ground.GRASS else 0.0
			# Alternate the diagonal for a less regular faceting.
			if (x + z) % 2 == 0:
				_tri(verts, normals, colors, p00, p01, p11, col)
				_tri(verts, normals, colors, p00, p11, p10, col)
			else:
				_tri(verts, normals, colors, p00, p01, p10, col)
				_tri(verts, normals, colors, p10, p01, p11, col)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Materials.get_material("ground"))
	return mesh


## A path cell that the smooth path surface covers: drawn as grass, so the 1 m cells never
## show as a staircase along the path edges.
func _under_ribbon(x: int, z: int, kind: int) -> bool:
	if kind != ParkMap.Ground.PATH and kind != ParkMap.Ground.GRAVEL and kind != ParkMap.Ground.TRAIL:
		return false
	var idx := z * ParkMap.W + x
	if map.path_dist[idx] > 0.0 or kind != map._path_ground(idx):
		return false
	var p := ParkMap.cell_center(Vector2i(x, z))
	for key: String in ParkLayout.AREAS:
		var area: Dictionary = ParkLayout.AREAS[key]
		if area["ground"] != "grass" and ParkMap.in_rect(p, area["pos"], area["size"] + Vector2(2, 2), area["rot"]):
			return false    # keep gravel and dirt yards whole where a path runs into them
	return not _skip_path_point(p)


func _v(x: int, z: int) -> Vector3:
	return Vector3(ParkMap.ORIGIN.x + x, map.heights[z * (ParkMap.W + 1) + x], ParkMap.ORIGIN.y + z)


## Appends a triangle given counter-clockwise from above (emitted clockwise for Godot).
static func _tri(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray,
		a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0.0:
		n = -n
		var t := b
		b = c
		c = t
	verts.append(a)
	verts.append(c)
	verts.append(b)
	for i in 3:
		normals.append(n)
		colors.append(col)


func _water() -> Node3D:
	var root := Node3D.new()
	root.name = "Water"
	var kit := MeshKit.new()
	kit.use("water")
	var y := ParkLayout.WATER_Y
	var col := Color("3d8aa0")
	for line: PackedVector2Array in map.water_lines():
		var half := ParkLayout.CREEK_HALF_WIDTH + 1.6
		for i in line.size() - 1:
			var a := line[i]
			var b := line[i + 1]
			if _in_pond(a, 0.9) and _in_pond(b, 0.9):
				continue
			var na := _normal_at(line, i) * half
			var nb := _normal_at(line, i + 1) * half
			kit.quad(Vector3(a.x + na.x, y, a.y + na.y), Vector3(b.x + nb.x, y, b.y + nb.y),
				Vector3(b.x - nb.x, y, b.y - nb.y), Vector3(a.x - na.x, y, a.y - na.y), col)
	# Ponds as ellipse fans.
	for pond: Array in ParkLayout.ponds():
		var c: Vector2 = pond[0]
		var r: Vector2 = pond[1] + Vector2(1.6, 1.6)
		var n := 40
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			kit.tri(Vector3(c.x, y, c.y), Vector3(c.x + cos(a1) * r.x, y, c.y + sin(a1) * r.y),
				Vector3(c.x + cos(a0) * r.x, y, c.y + sin(a0) * r.y), col)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


static func _in_pond(p: Vector2, k: float) -> bool:
	for pond: Array in ParkLayout.ponds():
		if ((p - pond[0]) / pond[1]).length() < k:
			return true
	return false


## Left-pointing unit normal of a polyline at point i.
static func _normal_at(line: PackedVector2Array, i: int, closed := false) -> Vector2:
	var n := line.size()
	var prev := line[(i - 1 + n) % n] if (closed or i > 0) else line[i]
	var next := line[(i + 1) % n] if (closed or i < n - 1) else line[i]
	var t := (next - prev).normalized()
	return Vector2(-t.y, t.x)


func _paths() -> Node3D:
	var kit := MeshKit.new()
	kit.use("solid")
	var index := 0
	for path: Dictionary in map.paths:
		index += 1
		var pts: PackedVector2Array = path["points"]
		var closed: bool = path["closed"]
		var half: float = path["width"] * 0.5
		var col: Color = PATH_COLORS[path["kind"]]
		var lift := 0.05 + index * 0.0015
		var curb: bool = path["kind"] == "main"
		var n := pts.size()
		var offs := PackedVector2Array()
		for i in n:
			offs.append(_miter_at(pts, i, closed))
		var segs := n if closed else n - 1
		for i in segs:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			var oa := offs[i]
			var ob := offs[(i + 1) % n]
			# Short pieces that follow the terrain; ends are clipped exactly at bridges.
			var steps := maxi(1, ceili(a.distance_to(b) / 0.8))
			for k in steps:
				var t0 := float(k) / steps
				var t1 := float(k + 1) / steps
				var skip0 := _skip_path_point(a.lerp(b, t0))
				var skip1 := _skip_path_point(a.lerp(b, t1))
				if skip0 and skip1:
					continue
				if skip0 != skip1:
					var lo := t0
					var hi := t1
					for it in 10:
						var mid := (lo + hi) * 0.5
						if _skip_path_point(a.lerp(b, mid)) == skip0:
							lo = mid
						else:
							hi = mid
					if skip0:
						t0 = hi
					else:
						t1 = lo
				_ribbon(kit, a.lerp(b, t0), a.lerp(b, t1), oa.lerp(ob, t0) * half, oa.lerp(ob, t1) * half, half, lift, col, curb)
		if not closed:
			# Round ends, so paths meet other paths and plazas without square corners.
			for e: Array in [[pts[0], pts[0] - pts[1]], [pts[n - 1], pts[n - 1] - pts[n - 2]]]:
				var c: Vector2 = e[0]
				if not _skip_path_point(c):
					_end_cap(kit, c, (e[1] as Vector2).normalized(), half, lift, col)
	var mi := MeshInstance3D.new()
	mi.name = "Paths"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Left offset at point i of a path, scaled at bends so the path keeps its width.
static func _miter_at(pts: PackedVector2Array, i: int, closed: bool) -> Vector2:
	var avg := _normal_at(pts, i, closed)
	var n := pts.size()
	if not closed and (i == 0 or i == n - 1):
		return avg
	var t := (pts[(i + 1) % n] - pts[i]).normalized()
	var d := avg.dot(Vector2(-t.y, t.x))
	return avg / maxf(d, 0.5)


## One piece of path surface from a to b (left offsets oa, ob), with curbs on main paths.
func _ribbon(kit: MeshKit, a: Vector2, b: Vector2, oa: Vector2, ob: Vector2, half: float, lift: float, col: Color, curb: bool) -> void:
	kit.quad(_on_ground(a + oa, lift), _on_ground(b + ob, lift), _on_ground(b - ob, lift), _on_ground(a - oa, lift), col)
	if not curb:
		return
	# Low curb stones along both edges, except where another path joins.
	var edge := col.darkened(0.18)
	var k := (half - 0.18) / half
	var ck := (half - 0.09) / half
	var y := lift + 0.06
	for side: float in [1.0, -1.0]:
		if _path_dist_smooth(a + oa * ck * side) < -0.3 or _path_dist_smooth(b + ob * ck * side) < -0.3:
			continue
		var o0 := a + oa * side
		var o1 := b + ob * side
		var i0 := a + oa * k * side
		var i1 := b + ob * k * side
		# Top and the outer face down into the ground, so the curb never floats or sinks.
		var top0 := _on_ground(o0, y)
		var top1 := _on_ground(o1, y)
		var low0 := _on_ground(o0, -0.12)
		var low1 := _on_ground(o1, -0.12)
		if side < 0:
			kit.quad(_on_ground(i0, y), _on_ground(i1, y), top1, top0, edge)
			kit.quad(top0, top1, low1, low0, edge.darkened(0.1))
		else:
			kit.quad(top0, top1, _on_ground(i1, y), _on_ground(i0, y), edge)
			kit.quad(top0, low0, low1, top1, edge.darkened(0.1))


## Distance to the nearest path edge, interpolated between cell centres (the cell value
## alone is off by up to half a metre, which broke curbs into dashes).
func _path_dist_smooth(p: Vector2) -> float:
	var f := p - ParkMap.ORIGIN - Vector2(0.5, 0.5)
	var x := clampi(int(floor(f.x)), 0, ParkMap.W - 2)
	var z := clampi(int(floor(f.y)), 0, ParkMap.H - 2)
	var tx := clampf(f.x - x, 0.0, 1.0)
	var tz := clampf(f.y - z, 0.0, 1.0)
	var i := z * ParkMap.W + x
	var d := map.path_dist
	return lerpf(lerpf(d[i], d[i + 1], tx), lerpf(d[i + ParkMap.W], d[i + ParkMap.W + 1], tx), tz)


## Half disc at an open path end, pointing along out.
func _end_cap(kit: MeshKit, c: Vector2, out: Vector2, half: float, lift: float, col: Color) -> void:
	var left := Vector2(-out.y, out.x)
	var steps := 8
	var centre := _on_ground(c, lift)
	for s in steps:
		var a0 := PI * s / steps
		var a1 := PI * (s + 1) / steps
		var p0 := c + (left * cos(a0) + out * sin(a0)) * half
		var p1 := c + (left * cos(a1) + out * sin(a1)) * half
		kit.tri(centre, _on_ground(p0, lift), _on_ground(p1, lift), col)


func _skip_path_point(p: Vector2) -> bool:
	if not ParkMap.in_world(p, 0.5):
		return true
	if map.water_dist_at(p.x, p.y) < 0.6:
		return true
	return not map.bridge_at(p).is_empty()


func _on_ground(p: Vector2, lift: float) -> Vector3:
	return Vector3(p.x, map.height_at(p.x, p.y) + lift, p.y)


func _plazas() -> Node3D:
	var kit := MeshKit.new()
	var tiles := [Color("c2b9a9"), Color("c9c1b2"), Color("bbb2a2")]
	for key: String in ParkLayout.PLAZAS:
		var pl: Dictionary = ParkLayout.PLAZAS[key]
		var c: Vector2 = pl["pos"]
		var r: float = pl["r"]
		var y := map.height_at(c.x, c.y) + 0.07
		var rings := maxi(2, int(r / 1.2))
		for ring in rings:
			var r0 := r * ring / rings
			var r1 := r * (ring + 1) / rings
			var sectors := 8 + ring * 6
			for s in sectors:
				var a0 := TAU * s / sectors
				var a1 := TAU * (s + 1) / sectors
				var col: Color = tiles[(ring + s) % 3]
				var p0 := Vector3(c.x + cos(a0) * r0, y, c.y + sin(a0) * r0)
				var p1 := Vector3(c.x + cos(a1) * r0, y, c.y + sin(a1) * r0)
				var p2 := Vector3(c.x + cos(a1) * r1, y, c.y + sin(a1) * r1)
				var p3 := Vector3(c.x + cos(a0) * r1, y, c.y + sin(a0) * r1)
				if ring == 0:
					kit.tri(p0, p2, p3, col)
				else:
					kit.quad(p0, p1, p2, p3, col)
		# Border ring.
		var n := 48
		for s in n:
			var a0 := TAU * s / n
			var a1 := TAU * (s + 1) / n
			var o0 := Vector3(c.x + cos(a0) * (r + 0.3), y + 0.04, c.y + sin(a0) * (r + 0.3))
			var o1 := Vector3(c.x + cos(a1) * (r + 0.3), y + 0.04, c.y + sin(a1) * (r + 0.3))
			var i0 := Vector3(c.x + cos(a0) * r, y + 0.04, c.y + sin(a0) * r)
			var i1 := Vector3(c.x + cos(a1) * r, y + 0.04, c.y + sin(a1) * r)
			kit.quad(i0, i1, o1, o0, Color("8f877a"))
	for key: String in ParkLayout.AREAS:
		var area: Dictionary = ParkLayout.AREAS[key]
		if area["ground"] != "plaza":
			continue
		var c2: Vector2 = area["pos"]
		var size: Vector2 = area["size"]
		var y2 := map.height_at(c2.x, c2.y) + 0.07
		for i in int(size.x):
			for j in int(size.y):
				var x0 := c2.x - size.x * 0.5 + i
				var z0 := c2.y - size.y * 0.5 + j
				kit.quad(Vector3(x0, y2, z0), Vector3(x0, y2, z0 + 1), Vector3(x0 + 1, y2, z0 + 1), Vector3(x0 + 1, y2, z0),
					tiles[(i + j) % 3])
	var mi := MeshInstance3D.new()
	mi.name = "Plazas"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Sidewalk and streets around the park, forest floor around the Nordwald.
func _surroundings() -> Node3D:
	var kit := MeshKit.new()
	var lo := ParkLayout.WORLD_MIN
	var hi := ParkLayout.WORLD_MAX
	var edge := ParkLayout.FOREST_EDGE
	var walk := 5.0
	var street := 14.0
	var far := 700.0
	var outer := walk + street
	var pave := Color("b9b4aa")
	var asphalt := Color("4a4a4e")
	var city := Color("8d8a82")
	var forest := FOREST_GRASS.darkened(0.1)
	# Sidewalks along the south, west and east of the park, streets running on along the forest.
	_rect(kit, lo.x - walk, hi.y, hi.x + walk, hi.y + walk, 0.02, pave)
	_rect(kit, lo.x - walk, edge, lo.x, hi.y, 0.02, pave)
	_rect(kit, hi.x, edge, hi.x + walk, hi.y, 0.02, pave)
	_rect(kit, lo.x - walk, lo.y - 40.0, lo.x, edge, 0.02, forest)
	_rect(kit, hi.x, lo.y - 40.0, hi.x + walk, edge, 0.02, forest)
	_rect(kit, lo.x - outer, hi.y + walk, hi.x + outer, hi.y + outer, 0.0, asphalt)
	_rect(kit, lo.x - outer, lo.y - 40.0, lo.x - walk, hi.y + walk, 0.0, asphalt)
	_rect(kit, hi.x + walk, lo.y - 40.0, hi.x + outer, hi.y + walk, 0.0, asphalt)
	# Lane markings.
	var mid := walk + street * 0.5
	var t := lo.x - outer + 3.0
	while t < hi.x + outer - 3.0:
		kit.box(Vector3(t, 0.015, hi.y + mid), Vector3(3.0, 0.01, 0.2), Color("e8e2c8"))
		t += 6.0
	t = lo.y - 38.0
	while t < hi.y + walk:
		for x: float in [lo.x - mid, hi.x + mid]:
			kit.box(Vector3(x, 0.015, t), Vector3(0.2, 0.01, 3.0), Color("e8e2c8"))
		t += 6.0
	# City ground beyond the streets; forest floor north of the park and between the streets.
	_rect(kit, -far, hi.y + outer, far, far, 0.02, city)
	_rect(kit, -far, edge, lo.x - outer, hi.y + outer, 0.02, city)
	_rect(kit, hi.x + outer, edge, far, hi.y + outer, 0.02, city)
	_rect(kit, -far, -far, lo.x - outer, edge, 0.02, forest)
	_rect(kit, hi.x + outer, -far, far, edge, 0.02, forest)
	_rect(kit, lo.x - outer, -far, hi.x + outer, lo.y - 40.0, 0.02, forest)
	_rect(kit, lo.x, lo.y - 40.0, hi.x, lo.y, 0.02, forest)
	var mi := MeshInstance3D.new()
	mi.name = "Surroundings"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Flat rectangle from (x0, z0) to (x1, z1), facing up.
static func _rect(kit: MeshKit, x0: float, z0: float, x1: float, z1: float, y: float, col: Color) -> void:
	kit.quad(Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1), Vector3(x1, y, z0), col)
