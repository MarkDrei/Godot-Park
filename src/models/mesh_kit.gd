class_name MeshKit
extends RefCounted
## Builds flat-shaded, vertex-coloured low-poly meshes out of primitives.
##
## - Several named surfaces, each with its own material (see Materials).
## - A transform stack (push/pop) for hierarchical composition.
## - Optional rigid skinning: every vertex is bound to `bone` with weight 1,
##   which lets character rigs render as a single skinned mesh.
##
## All polygon helpers take vertices in counter-clockwise order as seen from
## the visible side; the kit flips them to Godot's clockwise front faces.

var skinned := false
var bone := 0

var _surfaces := {}            # surface name -> SurfaceTool
var _order: Array[String] = []
var _st: SurfaceTool
var _xf := Transform3D.IDENTITY
var _stack: Array[Transform3D] = []


func _init(is_skinned := false) -> void:
	skinned = is_skinned
	use("solid")


## Switches the active surface. Surface names map to materials in Materials.
func use(surface: String) -> MeshKit:
	if not _surfaces.has(surface):
		var st := SurfaceTool.new()
		if skinned:
			st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_surfaces[surface] = st
		_order.append(surface)
	_st = _surfaces[surface]
	return self


func push(xf: Transform3D) -> void:
	_stack.append(_xf)
	_xf = _xf * xf


func pop() -> void:
	_xf = _stack.pop_back()


func translate(offset: Vector3) -> void:
	push(Transform3D(Basis(), offset))


func tri(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var wa := _xf * a
	var wb := _xf * b
	var wc := _xf * c
	var n := (wb - wa).cross(wc - wa)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var lin := color.srgb_to_linear()
	for v: Vector3 in [wa, wc, wb]:
		_st.set_color(lin)
		_st.set_normal(n)
		if skinned:
			_st.set_bones(PackedInt32Array([bone, 0, 0, 0]))
			_st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
		_st.add_vertex(v)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	tri(a, b, c, color)
	tri(a, c, d, color)


## Triangle with UV coordinates. A surface gets either only these or only plain tris.
func tri_uv(a: Vector3, b: Vector3, c: Vector3, color: Color, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var wa := _xf * a
	var wb := _xf * b
	var wc := _xf * c
	var n := (wb - wa).cross(wc - wa)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var lin := color.srgb_to_linear()
	for k in 3:
		_st.set_color(lin)
		_st.set_normal(n)
		_st.set_uv([ua, uc, ub][k])
		_st.add_vertex([wa, wc, wb][k])


func quad_uv(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	tri_uv(a, b, c, color, ua, ub, uc)
	tri_uv(a, c, d, color, ua, uc, ud)


## Axis-aligned box (in the current transform) centred at `center`.
func box(center: Vector3, size: Vector3, color: Color, top_color := Color(0, 0, 0, 0)) -> void:
	var h := size * 0.5
	var p := [
		center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
		center + Vector3(h.x, -h.y, h.z), center + Vector3(-h.x, -h.y, h.z),
		center + Vector3(-h.x, h.y, -h.z), center + Vector3(h.x, h.y, -h.z),
		center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z),
	]
	var top := color if top_color.a == 0.0 else top_color
	quad(p[4], p[7], p[6], p[5], top)        # +Y
	quad(p[0], p[1], p[2], p[3], color)      # -Y
	quad(p[3], p[2], p[6], p[7], color)      # +Z
	quad(p[1], p[0], p[4], p[5], color)      # -Z
	quad(p[2], p[1], p[5], p[6], color)      # +X
	quad(p[0], p[3], p[7], p[4], color)      # -X


## Box between two points (a beam/plank), `thickness` is (width, height).
func beam(from: Vector3, to: Vector3, thickness: Vector2, color: Color) -> void:
	var dir := to - from
	var length := dir.length()
	if length < 1e-5:
		return
	var y := dir / length
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	push(Transform3D(Basis(x, y, z), from))
	box(Vector3(0, length * 0.5, 0), Vector3(thickness.x, length, thickness.y), color)
	pop()


## Frustum/cylinder along +Y from `base`. r1 = 0 makes a cone.
func cylinder(base: Vector3, height: float, r0: float, r1: float, segments: int, color: Color,
		caps := true, cap_color := Color(0, 0, 0, 0), phase := 0.0) -> void:
	var cc := color if cap_color.a == 0.0 else cap_color
	var top := base + Vector3(0, height, 0)
	for i in segments:
		var a0 := phase + TAU * i / segments
		var a1 := phase + TAU * (i + 1) / segments
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0 := base + d0 * r0
		var b1 := base + d1 * r0
		var t0 := top + d0 * r1
		var t1 := top + d1 * r1
		if r1 > 0.0001:
			quad(b0, t0, t1, b1, color)
		else:
			tri(b0, top, b1, color)
		if caps:
			if r1 > 0.0001:
				tri(top, t1, t0, cc)
			if r0 > 0.0001:
				tri(base, b0, b1, cc)


## Cylinder between two arbitrary points.
func rod(from: Vector3, to: Vector3, r0: float, r1: float, segments: int, color: Color, caps := true) -> void:
	var dir := to - from
	var length := dir.length()
	if length < 1e-5:
		return
	var y := dir / length
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(y).normalized()
	var z := x.cross(y).normalized()
	push(Transform3D(Basis(x, y, z), from))
	cylinder(Vector3.ZERO, length, r0, r1, segments, color, caps)
	pop()


## Low-poly ellipsoid. `jitter` > 0 displaces vertices for an organic look.
func sphere(center: Vector3, radius: Vector3, color: Color, rings := 4, segments := 6,
		jitter := 0.0, seed := 0, bottom_color := Color(0, 0, 0, 0)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := []
	for r in rings + 1:
		var row := []
		var phi := PI * r / rings
		for s in segments:
			var theta := TAU * s / segments + (0.5 * TAU / segments if r % 2 == 1 else 0.0)
			var d := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
			if jitter > 0.0 and r > 0 and r < rings:
				d *= 1.0 + rng.randf_range(-jitter, jitter)
			row.append(center + d * radius)
		pts.append(row)
	for r in rings:
		var col := color
		if bottom_color.a > 0.0 and r >= rings / 2:
			col = bottom_color
		for s in segments:
			var s1 := (s + 1) % segments
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][s1]
			var c: Vector3 = pts[r + 1][s1]
			var d: Vector3 = pts[r + 1][s]
			if r == 0:
				tri(a, c, d, col)
			elif r == rings - 1:
				tri(a, b, d, col)
			else:
				quad(a, b, c, d, col)


## Solid of revolution around +Y; profile points are (radius, y), bottom to top.
func lathe(profile: PackedVector2Array, segments: int, color: Color, phase := 0.0,
		colors: Array = []) -> void:
	for i in profile.size() - 1:
		var p0 := profile[i]
		var p1 := profile[i + 1]
		var col: Color = colors[i] if i < colors.size() else color
		for s in segments:
			var a0 := phase + TAU * s / segments
			var a1 := phase + TAU * (s + 1) / segments
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var b0 := d0 * p0.x + Vector3(0, p0.y, 0)
			var b1 := d1 * p0.x + Vector3(0, p0.y, 0)
			var t0 := d0 * p1.x + Vector3(0, p1.y, 0)
			var t1 := d1 * p1.x + Vector3(0, p1.y, 0)
			if p1.x < 0.0001:
				tri(b0, t0, b1, col)
			elif p0.x < 0.0001:
				tri(b0, t0, t1, col)
			else:
				quad(b0, t0, t1, b1, col)


## Vertical prism from a polygon given as (x, z) points; orientation is normalised.
func prism(poly: PackedVector2Array, y0: float, y1: float, color: Color,
		top_color := Color(0, 0, 0, 0), bottom := false) -> void:
	var tc := color if top_color.a == 0.0 else top_color
	var pts := poly
	if _signed_area(pts) < 0.0:
		pts = poly.duplicate()
		pts.reverse()
	var idx := Geometry2D.triangulate_polygon(pts)
	for i in range(0, idx.size(), 3):
		var a := pts[idx[i]]
		var b := pts[idx[i + 1]]
		var c := pts[idx[i + 2]]
		if (b - a).cross(c - a) < 0.0:
			var t := b
			b = c
			c = t
		tri(Vector3(a.x, y1, a.y), Vector3(c.x, y1, c.y), Vector3(b.x, y1, b.y), tc)
		if bottom:
			tri(Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(c.x, y0, c.y), color)
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		quad(Vector3(a.x, y0, a.y), Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(b.x, y0, b.y), color)


static func _signed_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		area += poly[i].cross(poly[(i + 1) % poly.size()])
	return area * 0.5


## Flat disc on the XZ plane facing +Y.
func disc(center: Vector3, radius: float, segments: int, color: Color) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		tri(center, center + Vector3(cos(a1), 0, sin(a1)) * radius,
			center + Vector3(cos(a0), 0, sin(a0)) * radius, color)


## Torus around +Y (rings, tyres, life buoys).
func torus(center: Vector3, major: float, minor: float, segments: int, sides: int, color: Color) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		for j in sides:
			var b0 := TAU * j / sides
			var b1 := TAU * (j + 1) / sides
			var p00 := _torus_point(center, major, minor, a0, b0)
			var p10 := _torus_point(center, major, minor, a1, b0)
			var p11 := _torus_point(center, major, minor, a1, b1)
			var p01 := _torus_point(center, major, minor, a0, b1)
			quad(p00, p01, p11, p10, color)


func _torus_point(c: Vector3, major: float, minor: float, a: float, b: float) -> Vector3:
	var ring := Vector3(cos(a), 0, sin(a))
	return c + ring * (major + minor * cos(b)) + Vector3(0, minor * sin(b), 0)


## Builds the ArrayMesh; every surface gets the material of the same name.
func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for name: String in _order:
		var st: SurfaceTool = _surfaces[name]
		var arrays := st.commit_to_arrays()
		var verts = arrays[Mesh.ARRAY_VERTEX]
		if verts == null or verts.size() == 0:
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, Materials.get_material(name))
		mesh.surface_set_name(mesh.get_surface_count() - 1, name)
	return mesh
