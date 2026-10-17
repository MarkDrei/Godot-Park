class_name RouteArrow
extends Node3D
## The navigation arrow of the driving jobs (DriveJob): painted on the road in front of the
## player's car, in the car's lane, along the way through the streets (CityRoute) to the
## target. Half a block before a crossing where the way turns, it reaches to the crossing and
## bends round the corner there (straight on, then right); to turn round it is a U. Glows like
## the target's light pillar.

const REROUTE := 0.4           # seconds between route updates
const AHEAD := 9.0             # metres of arrow on a straight way
const HALF_BLOCK := 38.0       # a turn this close ahead bends the arrow at its crossing
const AFTER := 10.0            # metres of arrow past the corner
const CORNER := 3.0            # radius of the bend
const HEAD := 3.4              # length of the arrowhead
const STEM := 0.45             # half width of the light stem (the dark rim is wider)
const LIFT := 0.08             # over the asphalt (lane markings lie lower)

var car: Car
var target := Vector2.INF
var route := PackedVector2Array()
var axis := PackedVector2Array()   # the route from the street axis beside the car (on a street)
var info := {}                 # CityRoute.guide(): aim, turn, in, left, at
var path := PackedVector2Array()   # the arrow's centre line on the ground, tail to tip
var _mat: ShaderMaterial
var _mesh: MeshInstance3D
var _im: ImmediateMesh
var _t := 0.0
var _next := 0.0
var _off := 0.0                # the car's smoothed distance right of the route


func _init() -> void:
	name = "RouteArrow"
	top_level = true
	_im = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _im
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://src/shaders/route_arrow.gdshader")
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false


func show_for(c: Car, t: Vector2, color: Color) -> void:
	car = c
	target = t
	_mat.set_shader_parameter("color", color)
	_next = 0.0
	_off = NAN
	visible = car != null


func clear() -> void:
	target = Vector2.INF
	car = null
	route = PackedVector2Array()
	axis = PackedVector2Array()
	info = {}
	path = PackedVector2Array()
	_im.clear_surfaces()
	visible = false


func _process(delta: float) -> void:
	if car == null or not is_instance_valid(car) or target == Vector2.INF:
		visible = false
		return
	_t += delta
	_next -= delta
	var p := car.pos2()
	var fwd := car.forward2() * (1.0 if car.speed >= -0.5 else -1.0)
	if _next <= 0.0 or route.is_empty():
		_next = REROUTE
		route = CityRoute.route(p, fwd, target)
		# On a street the route starts at the car, diagonally to the next crossing; the arrow
		# runs along the street's axis instead, moved into the car's lane.
		axis = route.duplicate()
		var on: Dictionary = CityRoute.snap(p)
		if on["via"] == Vector2.INF and axis.size() >= 2:
			axis[0] = on["pos"]
	info = CityRoute.guide(p, fwd, route)
	path = _path(p, fwd, delta)
	_build(path, car.base_y + LIFT)
	global_position = Vector3.ZERO
	_mat.set_shader_parameter("t", _t)
	visible = true


## The arrow's centre line: from just in front of the car along the route, as far as the next
## turn when it is within half a block, shifted sideways by the car's distance from the route
## (so it lies in the car's lane and turns from lane to lane), the corners rounded.
func _path(p: Vector2, fwd: Vector2, delta: float) -> PackedVector2Array:
	var front := car.length() * 0.5 + 1.0
	if info["turn"] == "back":
		# A U to the left, into the other lane.
		var left := -Car.right_of(fwd)
		var a := p + fwd * front
		var b := a + fwd * 5.0
		return _round(PackedVector2Array([a, b, b + left * 3.5, b + left * 3.5 - fwd * 8.0]))
	var at: float = CityRoute.guide(p, fwd, axis)["at"]
	var total := CityRoute.length(axis)
	var s0 := at + front
	var s1 := s0 + AHEAD
	if (info["turn"] == "left" or info["turn"] == "right") and float(info["in"]) <= HALF_BLOCK:
		s1 = maxf(s1, at + float(info["in"]) + AFTER)
	s1 = minf(s1, total)
	s0 = minf(s0, s1 - 1.0)
	if s1 - s0 < 1.0 or s0 < 0.0:
		return PackedVector2Array()
	# Which side of the axis the car is on.
	var here := CityRoute.slice(axis, at, minf(at + 1.0, total))
	var off := 0.0
	if here.size() >= 2 and here[0].distance_to(here[here.size() - 1]) > 0.1:
		var dir := (here[here.size() - 1] - here[0]).normalized()
		off = clampf((p - here[0]).dot(Car.right_of(dir)), -CityLayout.LANE_EDGE, CityLayout.LANE_EDGE)
	_off = off if is_nan(_off) else lerpf(_off, off, minf(1.0, delta * 10.0))
	return _round(_shift(CityRoute.slice(axis, s0, s1), _off))


## A line moved sideways (right of its direction) by d, the corners mitred.
static func _shift(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size():
		out.append(pts[i] + _side(pts, i) * d)
	return out


## The right-hand normal at point i, mitred at corners (longer, so both sides stay parallel).
static func _side(pts: PackedVector2Array, i: int) -> Vector2:
	var n := pts.size()
	var d0 := (pts[i] - pts[maxi(i - 1, 0)]).normalized()
	var d1 := (pts[mini(i + 1, n - 1)] - pts[i]).normalized()
	if d0 == Vector2.ZERO:
		d0 = d1
	if d1 == Vector2.ZERO:
		d1 = d0
	var n0 := Car.right_of(d0)
	var m := (n0 + Car.right_of(d1)).normalized()
	if m == Vector2.ZERO:
		return n0
	return m / maxf(0.35, m.dot(n0))


## Corners rounded with a short curve.
static func _round(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var d0 := pts[i] - pts[i - 1]
		var d1 := pts[i + 1] - pts[i]
		if d0.length() < 0.01 or d1.length() < 0.01 or absf(d0.normalized().dot(d1.normalized())) > 0.985:
			out.append(pts[i])
			continue
		var r := minf(CORNER, minf(d0.length(), d1.length()) * 0.5)
		var a := pts[i] - d0.normalized() * r
		var b := pts[i] + d1.normalized() * r
		for k in 7:
			var u := k / 6.0
			out.append(a.lerp(pts[i], u).lerp(pts[i].lerp(b, u), u))
	out.append(pts[pts.size() - 1])
	return out


## The flat arrow along the line: a light stem and head on a slightly larger dark rim, so it
## stands out on asphalt and lane markings. UV.x is the distance from the tail (the shader's
## running light band).
func _build(pts: PackedVector2Array, y: float) -> void:
	_im.clear_surfaces()
	if pts.size() < 2:
		return
	var total := CityRoute.length(pts)
	var head := minf(HEAD, total)
	var tip := pts[pts.size() - 1]
	var base_pt := CityRoute.slice(pts, total - head, total)[0]
	var dir := (tip - base_pt).normalized()
	if dir == Vector2.ZERO:
		return
	var stem := CityRoute.slice(pts, 0.0, total - head * 0.7) if total - head > 0.3 else PackedVector2Array()
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 2:
		var light := layer == 1
		var col := Color.WHITE if light else Color(0.12, 0.12, 0.12)
		var h := y + (0.03 if light else 0.0)
		var grow := 0.0 if light else 0.18
		if stem.size() >= 2:
			_ribbon(stem, STEM + grow, h, col)
		var r := Car.right_of(dir)
		var back := base_pt - dir * grow
		var wide := HEAD * 0.55 + grow * 1.6
		var end := tip + dir * grow * 1.4
		_tri([back + r * wide, end, back - r * wide], [total - head, total, total - head], h, col)
	_im.surface_end()


func _ribbon(pts: PackedVector2Array, half: float, y: float, col: Color) -> void:
	var s := 0.0
	for i in range(pts.size() - 1):
		var s1 := s + pts[i].distance_to(pts[i + 1])
		var a := _side(pts, i) * half
		var b := _side(pts, i + 1) * half
		_tri([pts[i] - a, pts[i] + a, pts[i + 1] + b], [s, s, s1], y, col)
		_tri([pts[i] - a, pts[i + 1] + b, pts[i + 1] - b], [s, s1, s1], y, col)
		s = s1


func _tri(q: Array, arc: Array, y: float, col: Color) -> void:
	for k in 3:
		_im.surface_set_color(col)
		_im.surface_set_uv(Vector2(arc[k], 0.0))
		_im.surface_add_vertex(Vector3(q[k].x, y, q[k].y))


## Short German hint for the job panel: "in 40 m rechts", "wenden", "gleich da".
func hint() -> String:
	if info.is_empty():
		return ""
	var dist := int(round(float(info["in"]) / 10.0) * 10.0)
	match info["turn"]:
		"left":
			return "links abbiegen" if dist <= 15 else "in %d m links" % dist
		"right":
			return "rechts abbiegen" if dist <= 15 else "in %d m rechts" % dist
		"back":
			return "bitte wenden"
		"there":
			return "gleich da"
	return "geradeaus"
