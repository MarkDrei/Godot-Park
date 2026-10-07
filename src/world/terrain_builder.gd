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
}
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
	for z in range(cz, mini(cz + CHUNK, ParkMap.H)):
		for x in range(cx, mini(cx + CHUNK, ParkMap.W)):
			var p00 := _v(x, z)
			var p10 := _v(x + 1, z)
			var p01 := _v(x, z + 1)
			var p11 := _v(x + 1, z + 1)
			var kind: int = map.ground[z * ParkMap.W + x]
			var col: Color = lin[kind]
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
	for line: PackedVector2Array in [map.creek, map.creek_out]:
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
	# Pond as an ellipse fan.
	var c := ParkLayout.POND_CENTER
	var r := ParkLayout.POND_RADII + Vector2(1.6, 1.6)
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
	var q := (p - ParkLayout.POND_CENTER) / ParkLayout.POND_RADII
	return q.length() < k


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
		var edge := col.darkened(0.18)
		var lift := 0.05 + index * 0.0015
		var n := pts.size()
		var segs := n if closed else n - 1
		for i in segs:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			if _skip_path_point(a) or _skip_path_point(b):
				continue
			var na := _normal_at(pts, i, closed)
			var nb := _normal_at(pts, (i + 1) % n, closed)
			var al := a + na * half
			var ar := a - na * half
			var bl := b + nb * half
			var br := b - nb * half
			kit.quad(_on_ground(al, lift), _on_ground(bl, lift), _on_ground(br, lift), _on_ground(ar, lift), col)
			if path["kind"] == "main":
				# Low curb stones along both edges.
				for side: float in [1.0, -1.0]:
					if map.path_dist_at(a + na * (half - 0.09) * side) < -0.3 or map.path_dist_at(b + nb * (half - 0.09) * side) < -0.3:
						continue
					var o0 := a + na * half * side
					var o1 := b + nb * half * side
					var i0 := a + na * (half - 0.18) * side
					var i1 := b + nb * (half - 0.18) * side
					if side < 0:
						kit.quad(_on_ground(i0, lift + 0.035), _on_ground(i1, lift + 0.035), _on_ground(o1, lift + 0.035), _on_ground(o0, lift + 0.035), edge)
					else:
						kit.quad(_on_ground(o0, lift + 0.035), _on_ground(o1, lift + 0.035), _on_ground(i1, lift + 0.035), _on_ground(i0, lift + 0.035), edge)
	var mi := MeshInstance3D.new()
	mi.name = "Paths"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _skip_path_point(p: Vector2) -> bool:
	if not ParkMap.in_park(p, 0.5):
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


## Sidewalk and streets around the park.
func _surroundings() -> Node3D:
	var kit := MeshKit.new()
	var half := ParkLayout.HALF
	var walk := 5.0
	var street := 14.0
	var far := 700.0
	# Sidewalk ring.
	_ring(kit, half, half + Vector2(walk, walk), 0.02, Color("b9b4aa"))
	# Street ring.
	_ring(kit, half + Vector2(walk, walk), half + Vector2(walk + street, walk + street), 0.0, Color("4a4a4e"))
	# Lane markings.
	var mid := half + Vector2(walk + street * 0.5, walk + street * 0.5)
	for side in 4:
		var horizontal := side < 2
		var length := mid.x * 2.0 if horizontal else mid.y * 2.0
		var count := int(length / 6.0)
		for i in count:
			var t := -length * 0.5 + (i + 0.25) * 6.0
			var pos: Vector3
			var size: Vector3
			if horizontal:
				pos = Vector3(t, 0.015, mid.y * (1 if side == 0 else -1))
				size = Vector3(3.0, 0.01, 0.2)
			else:
				pos = Vector3(mid.x * (1 if side == 2 else -1), 0.015, t)
				size = Vector3(0.2, 0.01, 3.0)
			kit.box(pos, size, Color("e8e2c8"))
	# Outer city ground.
	_ring(kit, half + Vector2(walk + street, walk + street), Vector2(far, far), 0.02, Color("8d8a82"))
	var mi := MeshInstance3D.new()
	mi.name = "Surroundings"
	mi.mesh = kit.commit()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _ring(kit: MeshKit, inner: Vector2, outer: Vector2, y: float, col: Color) -> void:
	kit.quad(Vector3(-outer.x, y, -outer.y), Vector3(-outer.x, y, -inner.y), Vector3(outer.x, y, -inner.y), Vector3(outer.x, y, -outer.y), col)
	kit.quad(Vector3(-outer.x, y, inner.y), Vector3(-outer.x, y, outer.y), Vector3(outer.x, y, outer.y), Vector3(outer.x, y, inner.y), col)
	kit.quad(Vector3(-outer.x, y, -inner.y), Vector3(-outer.x, y, inner.y), Vector3(-inner.x, y, inner.y), Vector3(-inner.x, y, -inner.y), col)
	kit.quad(Vector3(inner.x, y, -inner.y), Vector3(inner.x, y, inner.y), Vector3(outer.x, y, inner.y), Vector3(outer.x, y, -inner.y), col)
